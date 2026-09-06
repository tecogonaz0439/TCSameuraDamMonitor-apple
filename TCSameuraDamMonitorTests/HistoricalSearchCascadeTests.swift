// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Testing
import Foundation
import SwiftData
import TCSameuraDamCore
@testable import TCSameuraDamMonitor

/// 過去データ検索の sudmonitor カスケード(バンドル → sudmonitor 月次 → sudmonitor 日次 → MLIT)の統合テスト。
///
/// [DamAppModel] に [FixtureFetcher] / [HeaderFixtureFetcher] / [FixedNetworkAvailability] を注入し、
/// `searchHistorical` を通じてカスケード・フォールバック・ログ文言・重複排除を検証します。
/// 月次実フィクスチャ(202607_monthly.dat)は `#filePath` 相対で読み込みます。
@Suite("Historical search sudmonitor cascade", .serialized)
@MainActor
struct HistoricalSearchCascadeTests {
    private let damId = "1368080700010"
    private let historyBase = "https://sudmonitor.kusugami-lab.net/v1/history"
    private let mlitHTMLURL = "https://www1.river.go.jp/cgi-bin/DspDamData.exe?KIND=1&ID=1368080700010&BGNDATE=20260701&ENDDATE=20260731&KAWABOU=NO"
    private let mlitHTML = Data(#"<html><body><a href="/dat/dam-history.dat">dat</a></body></html>"#.utf8)
    private let mlitDatURL = "https://www1.river.go.jp/dat/dam-history.dat"

    private func monthlyURL(month: SudmonitorHistoryMonth) -> String {
        "\(historyBase)/\(damId)/\(SudmonitorHistoricalClient.monthlyFileName(damId: damId, month: month))"
    }

    private func julyMonthlyURL() -> String {
        monthlyURL(month: SudmonitorHistoryMonth(year: 2026, month: 7))
    }

    private func augustMonthlyURL() -> String {
        monthlyURL(month: SudmonitorHistoryMonth(year: 2026, month: 8))
    }

    private func latestURL() -> String {
        "\(historyBase)/\(damId)/latest.dat"
    }

    private func makeAppModel(
        sudFetcher: HeaderFixtureFetcher,
        mlitFetcher: FixtureFetcher,
        historicalAssets: HistoricalAssetStore = HistoricalAssetStore(entries: []),
        networkAvailable: Bool = true,
        defaults: UserDefaults
    ) -> DamAppModel {
        DamAppModel(
            network: MlitNetworkDataSource(fetcher: mlitFetcher.fetch, headerFetcher: sudFetcher.fetch),
            networkAvailability: FixedNetworkAvailability(isNetworkAvailable: networkAvailable),
            historicalAssets: historicalAssets,
            settingsRepository: SettingsRepository(defaults: defaults),
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults
        )
    }

    private func mlitResponses(datBytes: Data) -> [String: Data] {
        [
            mlitHTMLURL: mlitHTML,
            mlitDatURL: datBytes,
        ]
    }

    @Test("sudmonitor monthly covers July 2026 with 744 rows without MLIT access")
    func sudmonitorMonthlyCoversJuly2026With744Rows() async throws {
        let fixtureBytes = sudmonitorFixtureData(named: "202607_monthly.dat")
        let sudFetcher = HeaderFixtureFetcher(responses: [
            julyMonthlyURL(): (fixtureBytes, [
                "X-TCS-Dam-Id": damId,
                "X-TCS-History-Start": "2026-07-01T01:00:00+09:00",
                "X-TCS-History-End": "2026-07-31T24:00:00+09:00",
            ]),
        ])
        let mlitFetcher = FixtureFetcher(responses: [:])
        let defaults = try testDefaults()
        let appModel = makeAppModel(sudFetcher: sudFetcher, mlitFetcher: mlitFetcher, defaults: defaults)
        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)
        let dam = try #require(DamListData.dam(id: damId))

        await appModel.searchHistorical(
            damConfig: dam,
            startDate: try jstDate(year: 2026, month: 7, day: 1),
            endDate: try jstDate(year: 2026, month: 7, day: 31)
        )

        #expect(appModel.errorMessage == nil)
        #expect(appModel.historicalRows.count == 744)
        #expect(appModel.historicalRows.first?.time == "2026/7/1 01:00")
        #expect(appModel.historicalRows.last?.time == "2026/7/31 24:00")
        #expect(Set(appModel.historicalRows.map(\.time)).count == 744)
        #expect(mlitFetcher.requestedURLs.isEmpty)
        let successLog = appModel.debugLogs.first { $0.message == "Historical search succeeded." }
        let log = try #require(successLog)
        #expect(log.details.contains("Data Source: sudmonitor.kusugami-lab.net"))
        #expect(log.details.contains("Dam name: Sameura Dam"))
        #expect(log.details.contains("Period(Start): 2026-07-01T00:00:00+09:00"))
        #expect(log.details.contains("Period(End): 2026-07-31T00:00:00+09:00"))
    }

    @Test("sudmonitor unavailable falls back to MLIT full range")
    func sudmonitorUnavailableFallsBackToMlitFullRange() async throws {
        let sudFetcher = HeaderFixtureFetcher(failures: [
            julyMonthlyURL(): DamCoreMlitURLPolicyError.badHTTPStatus(503),
            augustMonthlyURL(): DamCoreMlitURLPolicyError.badHTTPStatus(503),
            latestURL(): DamCoreMlitURLPolicyError.badHTTPStatus(503),
        ])
        let datBytes = historicalDatData(rows: [
            realtimeDatRow("2026/7/1", "01:00", storageVolume: 72000, storagePercentage: 61.2),
            realtimeDatRow("2026/7/1", "02:00", storageVolume: 72010, storagePercentage: 62.3),
        ])
        let mlitFetcher = FixtureFetcher(responses: mlitResponses(datBytes: datBytes))
        let defaults = try testDefaults()
        let appModel = makeAppModel(sudFetcher: sudFetcher, mlitFetcher: mlitFetcher, defaults: defaults)
        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)
        let dam = try #require(DamListData.dam(id: damId))

        await appModel.searchHistorical(
            damConfig: dam,
            startDate: try jstDate(year: 2026, month: 7, day: 1),
            endDate: try jstDate(year: 2026, month: 7, day: 31)
        )

        #expect(appModel.errorMessage == nil)
        // ギャップ [7/1, 8/1) と交差する月は 7 月のみ → 月次 1 回 + latest 1 回、両方失敗 → MLIT 委譲
        #expect(sudFetcher.requestedURLs == [
            julyMonthlyURL(),
            latestURL(),
        ])
        #expect(mlitFetcher.requestedURLs == [mlitHTMLURL, mlitDatURL])
        #expect(appModel.historicalRows.count == 2)
        let log = try #require(appModel.debugLogs.first { $0.message == "Historical search succeeded." })
        #expect(log.details.contains("Data Source: MLIT"))
    }

    @Test("sudmonitor monthly 404 falls back to MLIT")
    func sudmonitorMonthly404FallsBackToMlit() async throws {
        let sudFetcher = HeaderFixtureFetcher(responses: [:])
        let datBytes = historicalDatData(rows: [
            realtimeDatRow("2026/7/1", "01:00", storageVolume: 72000, storagePercentage: 61.2),
        ])
        let mlitFetcher = FixtureFetcher(responses: mlitResponses(datBytes: datBytes))
        let defaults = try testDefaults()
        let appModel = makeAppModel(sudFetcher: sudFetcher, mlitFetcher: mlitFetcher, defaults: defaults)
        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)
        let dam = try #require(DamListData.dam(id: damId))

        await appModel.searchHistorical(
            damConfig: dam,
            startDate: try jstDate(year: 2026, month: 7, day: 1),
            endDate: try jstDate(year: 2026, month: 7, day: 31)
        )

        #expect(appModel.errorMessage == nil)
        // ギャップ [7/1, 8/1) と交差する月は 7 月のみ(排他境界の翌月初は含まない)→ 月次 1 回 + latest 1 回
        #expect(sudFetcher.requestedURLs == [
            julyMonthlyURL(),
            latestURL(),
        ])
        #expect(mlitFetcher.requestedURLs == [mlitHTMLURL, mlitDatURL])
        #expect(appModel.historicalRows.count == 1)
        let log = try #require(appModel.debugLogs.first { $0.message == "Historical search succeeded." })
        #expect(log.details.contains("Data Source: MLIT"))
    }

    @Test("sudmonitor monthly partial coverage with latest 404 falls back to MLIT")
    func sudmonitorMonthlyPartialCoverageLatest404FallsBackToMlit() async throws {
        let fixtureBytes = sudmonitorFixtureData(named: "202607_monthly.dat")
        let sudFetcher = HeaderFixtureFetcher(responses: [
            julyMonthlyURL(): (fixtureBytes, [
                "X-TCS-Dam-Id": damId,
                "X-TCS-History-Start": "2026-07-01T01:00:00+09:00",
                "X-TCS-History-End": "2026-07-10T23:00:00+09:00",
            ]),
        ])
        let datBytes = historicalDatData(rows: [
            realtimeDatRow("2026/7/1", "01:00", storageVolume: 72000, storagePercentage: 61.2),
        ])
        let mlitFetcher = FixtureFetcher(responses: mlitResponses(datBytes: datBytes))
        let defaults = try testDefaults()
        let appModel = makeAppModel(sudFetcher: sudFetcher, mlitFetcher: mlitFetcher, defaults: defaults)
        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)
        let dam = try #require(DamListData.dam(id: damId))

        await appModel.searchHistorical(
            damConfig: dam,
            startDate: try jstDate(year: 2026, month: 7, day: 1),
            endDate: try jstDate(year: 2026, month: 7, day: 31)
        )

        #expect(appModel.errorMessage == nil)
        // 月次(部分カバー 7/1〜7/10)→ 残ギャップ [7/11, 8/1) の月は 7 月のみ → 7 月は取得済み → latest 404 → MLIT 委譲
        #expect(sudFetcher.requestedURLs == [
            julyMonthlyURL(),
            latestURL(),
        ])
        #expect(mlitFetcher.requestedURLs == [mlitHTMLURL, mlitDatURL])
        #expect(appModel.historicalRows.count == 1)
        let log = try #require(appModel.debugLogs.first { $0.message == "Historical search succeeded." })
        #expect(log.details.contains("Data Source: MLIT"))
    }

    @Test("sudmonitor latest covers cross-month range")
    func sudmonitorLatestCoversCrossMonthRange() async throws {
        let latestBytes = historicalDatData(rows: [
            realtimeDatRow("2026/7/31", "01:00", storageVolume: 131980, storagePercentage: 68.9),
            realtimeDatRow("2026/7/31", "24:00", storageVolume: 131650, storagePercentage: 68.7),
            realtimeDatRow("2026/8/1", "01:00", storageVolume: 131400, storagePercentage: 68.5),
            realtimeDatRow("2026/8/1", "02:00", storageVolume: 131200, storagePercentage: 68.3),
        ])
        let sudFetcher = HeaderFixtureFetcher(responses: [
            "\(historyBase)/\(damId)/latest.dat": (latestBytes, [
                "X-TCS-Dam-Id": damId,
                "X-TCS-History-Since": "2026-07-31T00:00:00+09:00",
                "X-TCS-History-Until": "2026-08-02T00:00:00+09:00",
            ]),
        ])
        let mlitFetcher = FixtureFetcher(responses: [:])
        let defaults = try testDefaults()
        let appModel = makeAppModel(sudFetcher: sudFetcher, mlitFetcher: mlitFetcher, defaults: defaults)
        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)
        let dam = try #require(DamListData.dam(id: damId))

        await appModel.searchHistorical(
            damConfig: dam,
            startDate: try jstDate(year: 2026, month: 7, day: 31),
            endDate: try jstDate(year: 2026, month: 8, day: 1)
        )

        #expect(appModel.errorMessage == nil)
        // 2026-07 月次 404 → 2026-08 月次 404 → latest が 8/1 24:00(=8/2 00:00) までカバー
        #expect(sudFetcher.requestedURLs.count == 3)
        #expect(mlitFetcher.requestedURLs.isEmpty)
        #expect(appModel.historicalRows.map(\.time) == [
            "2026/7/31 01:00",
            "2026/7/31 24:00",
            "2026/8/1 01:00",
            "2026/8/1 02:00",
        ])
        #expect(appModel.historicalRows.map(\.storagePercentage) == [68.9, 68.7, 68.5, 68.3])
    }

    @Test("bundle and sudmonitor merge deduplicates preferring bundle rows")
    func bundleAndSudmonitorMergeDedupePrefersBundleRows() async throws {
        let bundleEntry = historicalEntry(start: "202606010100", end: "202606302400", filePath: "bundle.dat")
        let bundleBytes = historicalDatData(rows: [
            realtimeDatRow("2026/6/30", "01:00", storageVolume: 61000, storagePercentage: 61.2),
            realtimeDatRow("2026/7/1", "01:00", storageVolume: 70000, storagePercentage: 70.0),
        ])
        let store = HistoricalAssetStore(entries: [bundleEntry]) { entry in
            entry.filePath == "bundle.dat" ? bundleBytes : nil
        }
        let fixtureBytes = sudmonitorFixtureData(named: "202607_monthly.dat")
        let sudFetcher = HeaderFixtureFetcher(responses: [
            julyMonthlyURL(): (fixtureBytes, [
                "X-TCS-Dam-Id": damId,
                "X-TCS-History-Start": "2026-07-01T01:00:00+09:00",
                "X-TCS-History-End": "2026-07-31T24:00:00+09:00",
            ]),
        ])
        let mlitFetcher = FixtureFetcher(responses: [:])
        let defaults = try testDefaults()
        let appModel = makeAppModel(
            sudFetcher: sudFetcher,
            mlitFetcher: mlitFetcher,
            historicalAssets: store,
            defaults: defaults
        )
        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)
        let dam = try #require(DamListData.dam(id: damId))

        await appModel.searchHistorical(
            damConfig: dam,
            startDate: try jstDate(year: 2026, month: 6, day: 30),
            endDate: try jstDate(year: 2026, month: 7, day: 1)
        )

        #expect(appModel.errorMessage == nil)
        #expect(mlitFetcher.requestedURLs.isEmpty)
        // バンドル(6/30, 7/1)と月次実フィクスチャ(7/1 01:00〜24:00)をマージし、同一時刻はバンドル優先
        #expect(appModel.historicalRows.count == 25)
        #expect(appModel.historicalRows.first?.time == "2026/6/30 01:00")
        let mergedFirstOfJuly = try #require(
            appModel.historicalRows.first { $0.time == "2026/7/1 01:00" }
        )
        #expect(mergedFirstOfJuly.storagePercentage == Float(70.0))
        #expect(appModel.historicalRows.last?.time == "2026/7/1 24:00")
    }

    @Test("mlit direct data source does not probe sudmonitor")
    func mlitDirectDataSourceDoesNotProbeSudmonitor() async throws {
        let defaults = try testDefaults()
        var settings = AppSettings()
        settings.general.historicalDataSource = .mlitDirect
        SettingsRepository(defaults: defaults).save(settings)

        let datBytes = historicalDatData(rows: [
            realtimeDatRow("2026/7/1", "01:00", storageVolume: 72000, storagePercentage: 61.2),
        ])
        let sudFetcher = HeaderFixtureFetcher(responses: [:])
        let mlitFetcher = FixtureFetcher(responses: mlitResponses(datBytes: datBytes))
        let appModel = makeAppModel(sudFetcher: sudFetcher, mlitFetcher: mlitFetcher, defaults: defaults)
        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)
        let dam = try #require(DamListData.dam(id: damId))

        await appModel.searchHistorical(
            damConfig: dam,
            startDate: try jstDate(year: 2026, month: 7, day: 1),
            endDate: try jstDate(year: 2026, month: 7, day: 31)
        )

        #expect(appModel.errorMessage == nil)
        #expect(sudFetcher.requestedURLs.isEmpty)
        #expect(mlitFetcher.requestedURLs == [mlitHTMLURL, mlitDatURL])
        let log = try #require(appModel.debugLogs.first { $0.message == "Historical search succeeded." })
        #expect(log.details.contains("Data Source: MLIT"))
    }

    @Test("bundle complete search does not emit success log")
    func bundleCompleteSearchDoesNotEmitSuccessLog() async throws {
        let bundleEntry = historicalEntry(start: "202606010100", end: "202606302400", filePath: "bundle.dat")
        let bundleBytes = historicalDatData(rows: [
            realtimeDatRow("2026/6/1", "01:00", storageVolume: 61000, storagePercentage: 61.2),
            realtimeDatRow("2026/6/30", "23:00", storageVolume: 62000, storagePercentage: 62.3),
        ])
        let store = HistoricalAssetStore(entries: [bundleEntry]) { entry in
            entry.filePath == "bundle.dat" ? bundleBytes : nil
        }
        let sudFetcher = HeaderFixtureFetcher(responses: [:])
        let mlitFetcher = FixtureFetcher(responses: [:])
        let defaults = try testDefaults()
        let appModel = makeAppModel(
            sudFetcher: sudFetcher,
            mlitFetcher: mlitFetcher,
            historicalAssets: store,
            defaults: defaults
        )
        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)
        let dam = try #require(DamListData.dam(id: damId))

        await appModel.searchHistorical(
            damConfig: dam,
            startDate: try jstDate(year: 2026, month: 6, day: 1),
            endDate: try jstDate(year: 2026, month: 6, day: 30)
        )

        #expect(appModel.errorMessage == nil)
        #expect(sudFetcher.requestedURLs.isEmpty)
        #expect(mlitFetcher.requestedURLs.isEmpty)
        #expect(appModel.historicalRows.count == 2)
        #expect(!appModel.debugLogs.contains { $0.message == "Historical search succeeded." })
    }

    @Test("duplicate search does not emit failure log")
    func duplicateSearchDoesNotEmitFailureLog() async throws {
        let sudFetcher = HeaderFixtureFetcher(failures: [
            julyMonthlyURL(): DamCoreMlitURLPolicyError.badHTTPStatus(503),
            "\(historyBase)/\(damId)/latest.dat": DamCoreMlitURLPolicyError.badHTTPStatus(503),
        ])
        let datBytes = historicalDatData(rows: [
            realtimeDatRow("2026/7/1", "01:00", storageVolume: 72000, storagePercentage: 61.2),
        ])
        let mlitFetcher = FixtureFetcher(responses: mlitResponses(datBytes: datBytes))
        let defaults = try testDefaults()
        let appModel = makeAppModel(sudFetcher: sudFetcher, mlitFetcher: mlitFetcher, defaults: defaults)
        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)
        let dam = try #require(DamListData.dam(id: damId))
        let start = try jstDate(year: 2026, month: 7, day: 1)
        let end = try jstDate(year: 2026, month: 7, day: 31)

        await appModel.searchHistorical(damConfig: dam, startDate: start, endDate: end)
        #expect(appModel.errorMessage == nil)

        await appModel.searchHistorical(damConfig: dam, startDate: start, endDate: end)

        #expect(appModel.errorMessage == AppError.duplicateHistoricalSearch.localizedDescription)
        #expect(!appModel.debugLogs.contains { $0.message == "Historical search failed." })
    }

    @Test("MLIT fetch failure logs failure with new details")
    func mlitFetchFailureLogsFailureWithNewDetails() async throws {
        let sudFetcher = HeaderFixtureFetcher(responses: [:])
        let mlitFetcher = FixtureFetcher(responses: [:])
        let defaults = try testDefaults()
        let appModel = makeAppModel(sudFetcher: sudFetcher, mlitFetcher: mlitFetcher, defaults: defaults)
        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)
        let dam = try #require(DamListData.dam(id: damId))

        await appModel.searchHistorical(
            damConfig: dam,
            startDate: try jstDate(year: 2026, month: 7, day: 1),
            endDate: try jstDate(year: 2026, month: 7, day: 31)
        )

        #expect(appModel.errorMessage != nil)
        let log = try #require(appModel.debugLogs.first { $0.message == "Historical search failed." })
        #expect(log.details.contains("Data Source: MLIT"))
        #expect(log.details.contains("Dam name: Sameura Dam"))
        #expect(log.details.contains("Period(Start): 2026-07-01T00:00:00+09:00"))
        #expect(log.details.contains("Period(End): 2026-07-31T00:00:00+09:00"))
        #expect(log.details.contains("Reason:"))
    }

    @Test("network unavailable does not probe sudmonitor or MLIT and does not log")
    func networkUnavailableDoesNotProbeAndDoesNotLog() async throws {
        let sudFetcher = HeaderFixtureFetcher(responses: [:])
        let mlitFetcher = FixtureFetcher(responses: [:])
        let defaults = try testDefaults()
        let appModel = makeAppModel(
            sudFetcher: sudFetcher,
            mlitFetcher: mlitFetcher,
            networkAvailable: false,
            defaults: defaults
        )
        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)
        let dam = try #require(DamListData.dam(id: damId))

        await appModel.searchHistorical(
            damConfig: dam,
            startDate: try jstDate(year: 2026, month: 7, day: 1),
            endDate: try jstDate(year: 2026, month: 7, day: 31)
        )

        #expect(appModel.errorMessage == AppError.networkUnavailable.localizedDescription)
        #expect(sudFetcher.requestedURLs.isEmpty)
        #expect(mlitFetcher.requestedURLs.isEmpty)
        #expect(appModel.debugLogs.isEmpty)
    }

    // MARK: - プランナユーティリティ直接テスト

    @Test func complementIntervalsProducesGaps() throws {
        let d1 = try jstDate(year: 2026, month: 7, day: 1)
        let d5 = try jstDate(year: 2026, month: 7, day: 5)
        let d10 = try jstDate(year: 2026, month: 7, day: 10)
        let d15 = try jstDate(year: 2026, month: 7, day: 15)
        let d20 = try jstDate(year: 2026, month: 7, day: 20)
        let d30 = try jstDate(year: 2026, month: 7, day: 30)
        let required = DateInterval(start: d1, end: d30)
        let covered = [DateInterval(start: d5, end: d10), DateInterval(start: d15, end: d20)]

        let gaps = HistoricalSearchService.complementIntervals(covered, required)

        #expect(gaps == [
            DateInterval(start: d1, end: d5),
            DateInterval(start: d10, end: d15),
            DateInterval(start: d20, end: d30),
        ])
    }

    @Test func mergedIntervalsMergesAdjacentAndOverlapping() throws {
        let d1 = try jstDate(year: 2026, month: 7, day: 1)
        let d5 = try jstDate(year: 2026, month: 7, day: 5)
        let d8 = try jstDate(year: 2026, month: 7, day: 8)
        let d9 = try jstDate(year: 2026, month: 7, day: 9)
        let d10 = try jstDate(year: 2026, month: 7, day: 10)
        let d11 = try jstDate(year: 2026, month: 7, day: 11)
        let d12 = try jstDate(year: 2026, month: 7, day: 12)
        let intervals = [
            DateInterval(start: d10, end: d12),
            DateInterval(start: d1, end: d5),
            DateInterval(start: d5, end: d8),
            DateInterval(start: d9, end: d11),
        ]

        let merged = HistoricalSearchService.mergedIntervals(intervals)

        #expect(merged == [
            DateInterval(start: d1, end: d8),
            DateInterval(start: d9, end: d12),
        ])
    }

    @Test func monthsIntersectingEnumeratesUniqueMonths() throws {
        // ギャップ終端は排他境界のため、月の計算は最後に含まれる日(= end の前日)基準。
        // [7/15, 8/1) = 7/15〜7/31 → 7 月のみ
        let julyOnly = [
            DateInterval(
                start: try jstDate(year: 2026, month: 7, day: 15),
                end: try jstDate(year: 2026, month: 8, day: 1)
            ),
        ]
        #expect(HistoricalSearchService.monthsIntersecting(julyOnly) == [
            SudmonitorHistoryMonth(year: 2026, month: 7),
        ])

        // [7/31, 8/2) = 7/31〜8/1 → 7 月と 8 月
        let crossMonth = [
            DateInterval(
                start: try jstDate(year: 2026, month: 7, day: 31),
                end: try jstDate(year: 2026, month: 8, day: 2)
            ),
        ]
        #expect(HistoricalSearchService.monthsIntersecting(crossMonth) == [
            SudmonitorHistoryMonth(year: 2026, month: 7),
            SudmonitorHistoryMonth(year: 2026, month: 8),
        ])

        // 重複する複数ギャップは重複排除される
        #expect(HistoricalSearchService.monthsIntersecting(julyOnly + crossMonth) == [
            SudmonitorHistoryMonth(year: 2026, month: 7),
            SudmonitorHistoryMonth(year: 2026, month: 8),
        ])
    }

    @Test func coverageIntervalHandles24HourEndNotation() throws {
        let response = SudmonitorHistoricalResponse(
            bytes: Data(),
            damIdHeader: nil,
            since: "2026-07-01T01:00:00+09:00",
            until: "2026-07-31T24:00:00+09:00"
        )

        let interval = HistoricalSearchService.coverageInterval(
            from: response,
            requiredStart: try jstDate(year: 2026, month: 7, day: 1),
            requiredEnd: try jstDate(year: 2026, month: 8, day: 1)
        )

        #expect(interval == DateInterval(
            start: try jstDate(year: 2026, month: 7, day: 1),
            end: try jstDate(year: 2026, month: 8, day: 1)
        ))
    }

    @Test func coverageIntervalMidnightUntilMeansPreviousDay() throws {
        let response = SudmonitorHistoricalResponse(
            bytes: Data(),
            damIdHeader: nil,
            since: "2026-07-31T01:00:00+09:00",
            until: "2026-08-02T00:00:00+09:00"
        )

        let interval = HistoricalSearchService.coverageInterval(
            from: response,
            requiredStart: try jstDate(year: 2026, month: 7, day: 31),
            requiredEnd: try jstDate(year: 2026, month: 8, day: 2)
        )

        // until 00:00 は前日(8/1)までをカバー: 排他境界は 8/2 00:00
        #expect(interval == DateInterval(
            start: try jstDate(year: 2026, month: 7, day: 31),
            end: try jstDate(year: 2026, month: 8, day: 2)
        ))
    }

    @Test func coverageIntervalMissingHeadersReturnsNil() throws {
        let requiredStart = try jstDate(year: 2026, month: 7, day: 1)
        let requiredEnd = try jstDate(year: 2026, month: 8, day: 1)

        let missingBoth = SudmonitorHistoricalResponse(bytes: Data(), damIdHeader: nil, since: nil, until: nil)
        #expect(HistoricalSearchService.coverageInterval(
            from: missingBoth,
            requiredStart: requiredStart,
            requiredEnd: requiredEnd
        ) == nil)

        let missingUntil = SudmonitorHistoricalResponse(
            bytes: Data(),
            damIdHeader: nil,
            since: "2026-07-01T01:00:00+09:00",
            until: nil
        )
        #expect(HistoricalSearchService.coverageInterval(
            from: missingUntil,
            requiredStart: requiredStart,
            requiredEnd: requiredEnd
        ) == nil)

        let unparseable = SudmonitorHistoricalResponse(
            bytes: Data(),
            damIdHeader: nil,
            since: "not-a-date",
            until: "2026-07-31T24:00:00+09:00"
        )
        #expect(HistoricalSearchService.coverageInterval(
            from: unparseable,
            requiredStart: requiredStart,
            requiredEnd: requiredEnd
        ) == nil)
    }

    // MARK: - D8: 読込済み日次過去データのローカルカバレッジ化

    private func seedDailyHistory(
        in context: ModelContext,
        startDay: String,
        endDay: String,
        bytes: Data
    ) {
        context.insert(SudmonitorHistoryRecord(
            damId: damId,
            periodStartDay: startDay,
            periodEndDay: endDay,
            fetchedAt: Date(),
            nextUpdateAt: nil,
            rawDatBytes: bytes
        ))
        try? context.save()
    }

    @Test("D8: subset search of the loaded daily period never touches sudmonitor or MLIT")
    func dailyRecordSubsetSearchUsesLocalCoverageWithoutNetworkAccess() async throws {
        let dailyBytes = historicalDatData(rows: [
            realtimeDatRow("2026/7/1", "01:00", storageVolume: 70000, storagePercentage: 60.0),
            realtimeDatRow("2026/7/5", "01:00", storageVolume: 70100, storagePercentage: 61.0),
            realtimeDatRow("2026/7/10", "01:00", storageVolume: 70200, storagePercentage: 62.0),
            realtimeDatRow("2026/7/10", "24:00", storageVolume: 70210, storagePercentage: 62.5),
            realtimeDatRow("2026/7/31", "01:00", storageVolume: 70300, storagePercentage: 63.0),
        ])
        let sudFetcher = HeaderFixtureFetcher(responses: [:])
        let mlitFetcher = FixtureFetcher(responses: [:])
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()
        seedDailyHistory(in: context, startDay: "20260701", endDay: "20260731", bytes: dailyBytes)
        let appModel = makeAppModel(sudFetcher: sudFetcher, mlitFetcher: mlitFetcher, defaults: defaults)
        appModel.configure(modelContext: context, launchContext: .background)
        let dam = try #require(DamListData.dam(id: damId))

        await appModel.searchHistorical(
            damConfig: dam,
            startDate: try jstDate(year: 2026, month: 7, day: 5),
            endDate: try jstDate(year: 2026, month: 7, day: 10)
        )

        #expect(appModel.errorMessage == nil)
        #expect(sudFetcher.requestedURLs.isEmpty, "読込済み期間の真部分集合は sudmonitor にアクセスしない")
        #expect(mlitFetcher.requestedURLs.isEmpty)
        #expect(appModel.historicalRows.map(\.time) == ["2026/7/5 01:00", "2026/7/10 01:00", "2026/7/10 24:00"])
        #expect(appModel.historicalRows.map(\.storagePercentage) == [61.0, 62.0, 62.5])
    }

    @Test("D8: superset search fetches only the remaining gap monthly file and merges the daily fragment")
    func dailyRecordSupersetSearchCallsMonthlyForRemainingGapOnly() async throws {
        let dailyBytes = historicalDatData(rows: [
            realtimeDatRow("2026/7/20", "01:00", storageVolume: 70000, storagePercentage: 61.0),
            realtimeDatRow("2026/7/25", "01:00", storageVolume: 70100, storagePercentage: 61.5),
            realtimeDatRow("2026/7/31", "01:00", storageVolume: 70200, storagePercentage: 62.0),
        ])
        let fixtureBytes = sudmonitorFixtureData(named: "202607_monthly.dat")
        let sudFetcher = HeaderFixtureFetcher(responses: [
            julyMonthlyURL(): (fixtureBytes, [
                "X-TCS-Dam-Id": damId,
                "X-TCS-History-Start": "2026-07-01T01:00:00+09:00",
                "X-TCS-History-End": "2026-07-31T24:00:00+09:00",
            ]),
        ])
        let mlitFetcher = FixtureFetcher(responses: [:])
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()
        seedDailyHistory(in: context, startDay: "20260720", endDay: "20260731", bytes: dailyBytes)
        let appModel = makeAppModel(sudFetcher: sudFetcher, mlitFetcher: mlitFetcher, defaults: defaults)
        appModel.configure(modelContext: context, launchContext: .background)
        let dam = try #require(DamListData.dam(id: damId))

        await appModel.searchHistorical(
            damConfig: dam,
            startDate: try jstDate(year: 2026, month: 7, day: 1),
            endDate: try jstDate(year: 2026, month: 7, day: 31)
        )

        #expect(appModel.errorMessage == nil)
        // 日次レコード [7/20, 8/1) が初期カバーに統合され、残ギャップ [7/1, 7/20) のみ月次で取得される
        #expect(sudFetcher.requestedURLs == [julyMonthlyURL()])
        #expect(mlitFetcher.requestedURLs.isEmpty)
        #expect(appModel.historicalRows.count == 744)
        // 同時刻はローカル(日次)フラグメント優先でマージされる(月次フィクスチャの 7/25 01:00 は 83.7%)
        let dailyPriorityRow = try #require(appModel.historicalRows.first { $0.time == "2026/7/25 01:00" })
        #expect(dailyPriorityRow.storagePercentage == Float(61.5))
    }

    @Test("D8: partial overlap search fetches only the remaining gap monthly file")
    func dailyRecordPartialOverlapSearchCallsMonthlyForRemainingGapOnly() async throws {
        let dailyBytes = historicalDatData(rows: [
            realtimeDatRow("2026/7/20", "01:00", storageVolume: 70000, storagePercentage: 61.0),
            realtimeDatRow("2026/7/25", "01:00", storageVolume: 70100, storagePercentage: 61.5),
            realtimeDatRow("2026/7/31", "01:00", storageVolume: 70200, storagePercentage: 62.0),
        ])
        let monthlyBytes = historicalDatData(rows: [
            realtimeDatRow("2026/7/15", "01:00", storageVolume: 69000, storagePercentage: 60.0),
            realtimeDatRow("2026/7/16", "01:00", storageVolume: 69050, storagePercentage: 60.5),
        ])
        let sudFetcher = HeaderFixtureFetcher(responses: [
            julyMonthlyURL(): (monthlyBytes, [
                "X-TCS-Dam-Id": damId,
                "X-TCS-History-Start": "2026-07-15T01:00:00+09:00",
                "X-TCS-History-End": "2026-07-19T24:00:00+09:00",
            ]),
        ])
        let mlitFetcher = FixtureFetcher(responses: [:])
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()
        seedDailyHistory(in: context, startDay: "20260720", endDay: "20260731", bytes: dailyBytes)
        let appModel = makeAppModel(sudFetcher: sudFetcher, mlitFetcher: mlitFetcher, defaults: defaults)
        appModel.configure(modelContext: context, launchContext: .background)
        let dam = try #require(DamListData.dam(id: damId))

        await appModel.searchHistorical(
            damConfig: dam,
            startDate: try jstDate(year: 2026, month: 7, day: 15),
            endDate: try jstDate(year: 2026, month: 7, day: 31)
        )

        #expect(appModel.errorMessage == nil)
        // 日次レコード [7/20, 8/1) + 月次 [7/15, 7/20) で全区間をカバー → latest は呼ばれない
        #expect(sudFetcher.requestedURLs == [julyMonthlyURL()])
        #expect(mlitFetcher.requestedURLs.isEmpty)
        #expect(appModel.historicalRows.map(\.time) == [
            "2026/7/15 01:00",
            "2026/7/16 01:00",
            "2026/7/20 01:00",
            "2026/7/25 01:00",
            "2026/7/31 01:00",
        ])
    }

    @Test("D8: unloaded daily history keeps the legacy cascade")
    func unloadedDailyHistoryKeepsLegacyCascade() async throws {
        let fixtureBytes = sudmonitorFixtureData(named: "202607_monthly.dat")
        let sudFetcher = HeaderFixtureFetcher(responses: [
            julyMonthlyURL(): (fixtureBytes, [
                "X-TCS-Dam-Id": damId,
                "X-TCS-History-Start": "2026-07-01T01:00:00+09:00",
                "X-TCS-History-End": "2026-07-31T24:00:00+09:00",
            ]),
        ])
        let mlitFetcher = FixtureFetcher(responses: [:])
        let defaults = try testDefaults()
        let appModel = makeAppModel(sudFetcher: sudFetcher, mlitFetcher: mlitFetcher, defaults: defaults)
        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)
        let dam = try #require(DamListData.dam(id: damId))

        await appModel.searchHistorical(
            damConfig: dam,
            startDate: try jstDate(year: 2026, month: 7, day: 1),
            endDate: try jstDate(year: 2026, month: 7, day: 31)
        )

        #expect(appModel.errorMessage == nil)
        #expect(sudFetcher.requestedURLs == [julyMonthlyURL()])
        #expect(appModel.historicalRows.count == 744)
    }

    // MARK: - D2: 検索拒否(完全に同一の期間のみ)

    @Test("D2: identical period to the loaded daily record is rejected")
    func identicalPeriodToLoadedDailyRecordIsRejected() async throws {
        let dailyBytes = historicalDatData(rows: [
            realtimeDatRow("2026/7/1", "01:00", storageVolume: 70000, storagePercentage: 60.0),
            realtimeDatRow("2026/7/31", "01:00", storageVolume: 70300, storagePercentage: 63.0),
        ])
        let sudFetcher = HeaderFixtureFetcher(responses: [:])
        let mlitFetcher = FixtureFetcher(responses: [:])
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()
        seedDailyHistory(in: context, startDay: "20260701", endDay: "20260731", bytes: dailyBytes)
        let appModel = makeAppModel(sudFetcher: sudFetcher, mlitFetcher: mlitFetcher, defaults: defaults)
        appModel.configure(modelContext: context, launchContext: .background)
        let dam = try #require(DamListData.dam(id: damId))

        await appModel.searchHistorical(
            damConfig: dam,
            startDate: try jstDate(year: 2026, month: 7, day: 1),
            endDate: try jstDate(year: 2026, month: 7, day: 31)
        )

        #expect(appModel.errorMessage == AppError.historicalSearchMatchesLoadedDaily.localizedDescription)
        #expect(sudFetcher.requestedURLs.isEmpty)
        #expect(mlitFetcher.requestedURLs.isEmpty)
        #expect(!appModel.debugLogs.contains { $0.message == "Historical search failed." })
    }

    @Test("D2: subset period inside the loaded daily record is allowed")
    func subsetPeriodOfLoadedDailyRecordIsAllowed() async throws {
        let dailyBytes = historicalDatData(rows: [
            realtimeDatRow("2026/7/1", "01:00", storageVolume: 70000, storagePercentage: 60.0),
            realtimeDatRow("2026/7/25", "01:00", storageVolume: 70100, storagePercentage: 61.5),
            realtimeDatRow("2026/7/31", "01:00", storageVolume: 70300, storagePercentage: 63.0),
        ])
        let sudFetcher = HeaderFixtureFetcher(responses: [:])
        let mlitFetcher = FixtureFetcher(responses: [:])
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()
        seedDailyHistory(in: context, startDay: "20260701", endDay: "20260731", bytes: dailyBytes)
        let appModel = makeAppModel(sudFetcher: sudFetcher, mlitFetcher: mlitFetcher, defaults: defaults)
        appModel.configure(modelContext: context, launchContext: .background)
        let dam = try #require(DamListData.dam(id: damId))

        await appModel.searchHistorical(
            damConfig: dam,
            startDate: try jstDate(year: 2026, month: 7, day: 25),
            endDate: try jstDate(year: 2026, month: 7, day: 25)
        )

        #expect(appModel.errorMessage == nil)
        #expect(sudFetcher.requestedURLs.isEmpty)
        #expect(mlitFetcher.requestedURLs.isEmpty)
        #expect(appModel.historicalRows.map(\.time) == ["2026/7/25 01:00"])
    }

    @Test("D2: superset period containing the loaded daily record is allowed")
    func supersetPeriodOfLoadedDailyRecordIsAllowed() async throws {
        let dailyBytes = historicalDatData(rows: [
            realtimeDatRow("2026/7/20", "01:00", storageVolume: 70000, storagePercentage: 61.0),
            realtimeDatRow("2026/7/25", "01:00", storageVolume: 70100, storagePercentage: 61.5),
            realtimeDatRow("2026/7/31", "01:00", storageVolume: 70200, storagePercentage: 62.0),
        ])
        let fixtureBytes = sudmonitorFixtureData(named: "202607_monthly.dat")
        let sudFetcher = HeaderFixtureFetcher(responses: [
            julyMonthlyURL(): (fixtureBytes, [
                "X-TCS-Dam-Id": damId,
                "X-TCS-History-Start": "2026-07-01T01:00:00+09:00",
                "X-TCS-History-End": "2026-07-31T24:00:00+09:00",
            ]),
        ])
        let mlitFetcher = FixtureFetcher(responses: [:])
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()
        seedDailyHistory(in: context, startDay: "20260720", endDay: "20260731", bytes: dailyBytes)
        let appModel = makeAppModel(sudFetcher: sudFetcher, mlitFetcher: mlitFetcher, defaults: defaults)
        appModel.configure(modelContext: context, launchContext: .background)
        let dam = try #require(DamListData.dam(id: damId))

        await appModel.searchHistorical(
            damConfig: dam,
            startDate: try jstDate(year: 2026, month: 7, day: 1),
            endDate: try jstDate(year: 2026, month: 7, day: 31)
        )

        #expect(appModel.errorMessage == nil)
        #expect(sudFetcher.requestedURLs == [julyMonthlyURL()])
        #expect(mlitFetcher.requestedURLs.isEmpty)
        #expect(appModel.historicalRows.count == 744)
    }

    @Test("D2: partial overlap with the loaded daily record is allowed")
    func partialOverlapPeriodOfLoadedDailyRecordIsAllowed() async throws {
        let dailyBytes = historicalDatData(rows: [
            realtimeDatRow("2026/7/20", "01:00", storageVolume: 70000, storagePercentage: 61.0),
            realtimeDatRow("2026/7/25", "01:00", storageVolume: 70100, storagePercentage: 61.5),
            realtimeDatRow("2026/7/31", "01:00", storageVolume: 70200, storagePercentage: 62.0),
        ])
        let monthlyBytes = historicalDatData(rows: [
            realtimeDatRow("2026/7/15", "01:00", storageVolume: 69000, storagePercentage: 60.0),
            realtimeDatRow("2026/7/16", "01:00", storageVolume: 69050, storagePercentage: 60.5),
        ])
        let sudFetcher = HeaderFixtureFetcher(responses: [
            julyMonthlyURL(): (monthlyBytes, [
                "X-TCS-Dam-Id": damId,
                "X-TCS-History-Start": "2026-07-15T01:00:00+09:00",
                "X-TCS-History-End": "2026-07-19T24:00:00+09:00",
            ]),
        ])
        let mlitFetcher = FixtureFetcher(responses: [:])
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()
        seedDailyHistory(in: context, startDay: "20260720", endDay: "20260731", bytes: dailyBytes)
        let appModel = makeAppModel(sudFetcher: sudFetcher, mlitFetcher: mlitFetcher, defaults: defaults)
        appModel.configure(modelContext: context, launchContext: .background)
        let dam = try #require(DamListData.dam(id: damId))

        await appModel.searchHistorical(
            damConfig: dam,
            startDate: try jstDate(year: 2026, month: 7, day: 15),
            endDate: try jstDate(year: 2026, month: 7, day: 31)
        )

        #expect(appModel.errorMessage == nil)
        #expect(sudFetcher.requestedURLs == [julyMonthlyURL()])
        #expect(mlitFetcher.requestedURLs.isEmpty)
        #expect(appModel.historicalRows.map(\.time) == [
            "2026/7/15 01:00",
            "2026/7/16 01:00",
            "2026/7/20 01:00",
            "2026/7/25 01:00",
            "2026/7/31 01:00",
        ])
    }

    @Test("D2: mlitDirect gate neither rejects nor covers with the loaded daily record")
    func mlitDirectGateIgnoresLoadedDailyRecord() async throws {
        let dailyBytes = historicalDatData(rows: [
            realtimeDatRow("2026/7/1", "01:00", storageVolume: 70000, storagePercentage: 60.0),
            realtimeDatRow("2026/7/31", "01:00", storageVolume: 70300, storagePercentage: 63.0),
        ])
        let datBytes = historicalDatData(rows: [
            realtimeDatRow("2026/7/1", "01:00", storageVolume: 72000, storagePercentage: 61.2),
        ])
        let sudFetcher = HeaderFixtureFetcher(responses: [:])
        let mlitFetcher = FixtureFetcher(responses: mlitResponses(datBytes: datBytes))
        let defaults = try testDefaults()
        var settings = AppSettings()
        settings.general.historicalDataSource = .mlitDirect
        SettingsRepository(defaults: defaults).save(settings)
        let context = try inMemoryModelContext()
        seedDailyHistory(in: context, startDay: "20260701", endDay: "20260731", bytes: dailyBytes)
        let appModel = makeAppModel(sudFetcher: sudFetcher, mlitFetcher: mlitFetcher, defaults: defaults)
        appModel.configure(modelContext: context, launchContext: .background)
        let dam = try #require(DamListData.dam(id: damId))

        await appModel.searchHistorical(
            damConfig: dam,
            startDate: try jstDate(year: 2026, month: 7, day: 1),
            endDate: try jstDate(year: 2026, month: 7, day: 31)
        )

        #expect(appModel.errorMessage == nil)
        #expect(sudFetcher.requestedURLs.isEmpty)
        #expect(mlitFetcher.requestedURLs == [mlitHTMLURL, mlitDatURL])
    }
}

/// 応答ヘッダー付きフェッチ用の注入フェッチャ(このファイルのテスト専用)。
private final class HeaderFixtureFetcher: @unchecked Sendable {
    private let responses: [String: (Data, [String: String])]
    private let failures: [String: any Error]
    private nonisolated(unsafe) var urls: [String] = []

    init(
        responses: [String: (Data, [String: String])] = [:],
        failures: [String: any Error] = [:]
    ) {
        self.responses = responses
        self.failures = failures
    }

    var requestedURLs: [String] {
        urls
    }

    func fetch(urlString: String) async throws -> (Data, [String: String]) {
        urls.append(urlString)
        if let error = failures[urlString] {
            throw error
        }
        guard let entry = responses[urlString] else {
            throw DamCoreMlitURLPolicyError.badHTTPStatus(404)
        }
        return entry
    }
}

/// MLIT フェッチ用の注入フェッチャ(このファイルのテスト専用)。
private final class FixtureFetcher: @unchecked Sendable {
    private let responses: [String: Data]
    private nonisolated(unsafe) var urls: [String] = []

    init(responses: [String: Data]) {
        self.responses = responses
    }

    var requestedURLs: [String] {
        urls
    }

    func fetch(urlString: String) async throws -> Data {
        urls.append(urlString)
        guard let data = responses[urlString] else {
            throw URLError(.fileDoesNotExist)
        }
        return data
    }
}

/// 固定のネットワーク接続可能性を返すプロバイダ(このファイルのテスト専用)。
private struct FixedNetworkAvailability: NetworkAvailabilityProviding {
    private let available: Bool

    init(isNetworkAvailable: Bool) {
        available = isNetworkAvailable
    }

    nonisolated var isNetworkAvailable: Bool {
        available
    }
}

private func utf8BOMData(_ text: String) -> Data {
    var data = Data([0xEF, 0xBB, 0xBF])
    data.append(Data(text.utf8))
    return data
}

private func realtimeDatData(rows: [String]) -> Data {
    utf8BOMData("""
    水系名,吉野川
    河川名,吉野川
    観測所名,早明浦ダム
    観測所記号,1368080700010
    \(rows.joined(separator: "\n"))
    """)
}

private func historicalDatData(rows: [String]) -> Data {
    realtimeDatData(rows: rows)
}

private func realtimeDatRow(_ date: String, _ time: String, storageVolume: Float, storagePercentage: Float) -> String {
    "\(date),\(time),0, ,\(storageVolume), ,0, ,0, ,\(storagePercentage), "
}

private func historicalEntry(start: String, end: String, filePath: String, stationId: String = "1368080700010") -> HistoricalDatFileEntry {
    HistoricalDatFileEntry(stationId: stationId, startDatetime: start, endDatetime: end, filePath: filePath)
}

private func testDefaults() throws -> UserDefaults {
    let suiteName = "test.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

@MainActor
private func inMemoryModelContext() throws -> ModelContext {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: DamDataRecord.self,
        HistoricalSearchMetaRecord.self,
        HistoricalDamDataRecord.self,
        DebugLogRecord.self,
        SudmonitorHistoryRecord.self,
        configurations: configuration
    )
    return ModelContext(container)
}

private func jstDate(year: Int, month: Int, day: Int) throws -> Date {
    try #require(Calendar.jst.date(from: DateComponents(year: year, month: month, day: day)))
}

/// sudmonitor フィクスチャを `#filePath` 相対で読み込みます。
private func sudmonitorFixtureData(named name: String) -> Data {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appending(path: "Fixtures/sudmonitor/\(name)")
    return try! Data(contentsOf: url)
}
