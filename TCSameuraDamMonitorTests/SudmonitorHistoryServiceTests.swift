// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Testing
import Foundation
import CryptoKit
import Observation
import SwiftData
import TCSameuraDamCore
@testable import TCSameuraDamMonitor

/// sudmonitor 日次過去データの取得・保存・クールダウン判定 [SudmonitorHistoryService] のテスト。
///
/// 注入フェッチャ ([HeaderFixtureFetcher]) と in-memory SwiftData を使い、
/// fetch→upsert・404/5xx・期間ヘッダー欠落・フォールバック・cooldown・機能ゲート・
/// 初回起動（未保存時のみ）を検証します。
@Suite("Sudmonitor daily history service", .serialized)
@MainActor
struct SudmonitorHistoryServiceTests {
    private let damId = "1368080700010"
    private let latestURL = "https://sudmonitor.kusugami-lab.net/v1/history/1368080700010/latest.dat"

    private func makeService(fetcher: HeaderFixtureFetcher, clock: TestClock) -> SudmonitorHistoryService {
        SudmonitorHistoryService(sudmonitorClient: SudmonitorHistoricalClient(
            network: MlitNetworkDataSource(headerFetcher: fetcher.fetch),
            now: { clock.current }
        ))
    }

    private func makeAppModel(sudFetcher: HeaderFixtureFetcher, defaults: UserDefaults) -> DamAppModel {
        makeAppModel(sudFetch: sudFetcher.fetch, defaults: defaults)
    }

    private func makeAppModel(sudFetcher: GatedHeaderFixtureFetcher, defaults: UserDefaults) -> DamAppModel {
        makeAppModel(sudFetch: sudFetcher.fetch, defaults: defaults)
    }

    private func makeAppModel(sudFetch: @escaping MlitNetworkDataSource.HeaderFetcher, defaults: UserDefaults) -> DamAppModel {
        DamAppModel(
            network: MlitNetworkDataSource(fetcher: FixtureFetcher(responses: [:]).fetch, headerFetcher: sudFetch),
            networkAvailability: FixedNetworkAvailability(isNetworkAvailable: true),
            settingsRepository: SettingsRepository(defaults: defaults),
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults,
            debugDataSessionService: DebugDataSessionService(backupRootURL: Self.temporaryBackupRootURL())
        )
    }

    /// テスト用の一時 Debug データ待避先を作成します(実ユーザーデータへの書込を防ぐ)。
    private static func temporaryBackupRootURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("tcsmdm-debug-backup-\(UUID().uuidString)", isDirectory: true)
    }

    private func dailyHeaders(
        since: String = "2026-07-01T01:00:00+09:00",
        until: String = "2026-07-31T24:00:00+09:00",
        nextUpdateAt: String? = "2026-07-31T15:13:00Z"
    ) -> [String: String] {
        var headers = [
            "X-TCS-Dam-Id": damId,
            "X-TCS-History-Since": since,
            "X-TCS-History-Until": until,
        ]
        if let nextUpdateAt {
            headers["X-TCS-Next-Update-At"] = nextUpdateAt
        }
        return headers
    }

    private func seedRecord(
        in context: ModelContext,
        damId: String = "1368080700010",
        startDay: String = "20260701",
        endDay: String = "20260731",
        fetchedAt: Date,
        nextUpdateAt: Date?
    ) {
        context.insert(SudmonitorHistoryRecord(
            damId: damId,
            periodStartDay: startDay,
            periodEndDay: endDay,
            fetchedAt: fetchedAt,
            nextUpdateAt: nextUpdateAt,
            rawDatBytes: Data("old".utf8)
        ))
        try? context.save()
    }

    private func records(in context: ModelContext) throws -> [SudmonitorHistoryRecord] {
        try context.fetch(FetchDescriptor<SudmonitorHistoryRecord>())
    }

    @Test func fetchStoresSingleRecordWithPeriodAndNextUpdateAt() async throws {
        let bytes = Data("sample dat bytes".utf8)
        let fetcher = HeaderFixtureFetcher(responses: [
            latestURL: (bytes, dailyHeaders()),
        ])
        let clock = TestClock(now: try jstDateTime(year: 2026, month: 7, day: 15, hour: 12, minute: 0))
        let service = makeService(fetcher: fetcher, clock: clock)
        let context = try inMemoryModelContext()

        let outcome = await service.fetchAndStore(
            damId: damId,
            context: context,
            historicalDataSource: .sudmonitor,
            now: clock.current
        )

        guard case .stored = outcome else {
            Issue.record("Expected stored but got \(outcome)")
            return
        }
        #expect(fetcher.requestedURLs == [latestURL])
        let records = try records(in: context)
        #expect(records.count == 1)
        let record = try #require(records.first)
        #expect(record.damId == damId)
        #expect(record.periodStartDay == "20260701")
        #expect(record.periodEndDay == "20260731")
        #expect(record.fetchedAt == clock.current)
        // 2026-07-31T15:13:00Z = 2026-08-01 00:13 JST
        let expectedNextUpdateAt = try #require(Calendar.jst.date(
            from: DateComponents(year: 2026, month: 8, day: 1, hour: 0, minute: 13)
        ))
        #expect(record.nextUpdateAt == expectedNextUpdateAt)
        #expect(record.rawDatBytes == bytes)
        #expect(record.rawDatFileName == "latest.dat")
    }

    @Test func refetchOverwritesExistingRecordAndUpdatesPeriod() async throws {
        let firstFetcher = HeaderFixtureFetcher(responses: [
            latestURL: (Data("first".utf8), dailyHeaders()),
        ])
        let secondFetcher = HeaderFixtureFetcher(responses: [
            latestURL: (
                Data("second".utf8),
                dailyHeaders(
                    since: "2026-07-02T01:00:00+09:00",
                    until: "2026-08-01T24:00:00+09:00",
                    nextUpdateAt: "2026-08-01T15:13:00Z"
                )
            ),
        ])
        let clock = TestClock(now: try jstDateTime(year: 2026, month: 7, day: 15, hour: 12, minute: 0))
        let context = try inMemoryModelContext()

        let firstService = makeService(fetcher: firstFetcher, clock: clock)
        let first = await firstService.fetchAndStore(damId: damId, context: context, historicalDataSource: .sudmonitor, now: clock.current)
        guard case .stored = first else {
            Issue.record("Expected stored but got \(first)")
            return
        }

        clock.current = try jstDateTime(year: 2026, month: 7, day: 16, hour: 12, minute: 0)
        let secondService = makeService(fetcher: secondFetcher, clock: clock)
        let second = await secondService.fetchAndStore(damId: damId, context: context, historicalDataSource: .sudmonitor, now: clock.current)
        guard case .stored = second else {
            Issue.record("Expected stored but got \(second)")
            return
        }

        let records = try records(in: context)
        #expect(records.count == 1, "damId ごとに1件へ上書きされる")
        let record = try #require(records.first)
        #expect(record.periodStartDay == "20260702")
        #expect(record.periodEndDay == "20260801")
        #expect(record.fetchedAt == clock.current)
        #expect(record.rawDatBytes == Data("second".utf8))
        // 2026-08-01T15:13:00Z = 2026-08-02 00:13 JST
        let expectedNextUpdateAt = try #require(Calendar.jst.date(
            from: DateComponents(year: 2026, month: 8, day: 2, hour: 0, minute: 13)
        ))
        #expect(record.nextUpdateAt == expectedNextUpdateAt)
        #expect(firstFetcher.requestedURLs == [latestURL])
        #expect(secondFetcher.requestedURLs == [latestURL])
    }

    @Test func fetchAndStoreKeepsOtherDamsRecords() async throws {
        let fetcher = HeaderFixtureFetcher(responses: [
            latestURL: (Data("sample".utf8), dailyHeaders()),
        ])
        let clock = TestClock(now: try jstDateTime(year: 2026, month: 7, day: 15, hour: 12, minute: 0))
        let service = makeService(fetcher: fetcher, clock: clock)
        let context = try inMemoryModelContext()
        seedRecord(
            in: context,
            damId: "9999999999999",
            startDay: "20260601",
            endDay: "20260630",
            fetchedAt: clock.current,
            nextUpdateAt: nil
        )

        let outcome = await service.fetchAndStore(damId: damId, context: context, historicalDataSource: .sudmonitor, now: clock.current)

        guard case .stored = outcome else {
            Issue.record("Expected stored but got \(outcome)")
            return
        }
        let records = try records(in: context)
        #expect(records.count == 2)
        let other = try #require(records.first { $0.damId == "9999999999999" })
        #expect(other.periodStartDay == "20260601")
        #expect(other.rawDatBytes == Data("old".utf8))
    }

    @Test func fetch404SkipsSilentlyWithoutCreatingRecord() async throws {
        let fetcher = HeaderFixtureFetcher(responses: [:])
        let clock = TestClock(now: try jstDateTime(year: 2026, month: 7, day: 15, hour: 12, minute: 0))
        let service = makeService(fetcher: fetcher, clock: clock)
        let context = try inMemoryModelContext()

        let outcome = await service.fetchAndStore(damId: damId, context: context, historicalDataSource: .sudmonitor, now: clock.current)

        guard case .skippedNotFound = outcome else {
            Issue.record("Expected skippedNotFound but got \(outcome)")
            return
        }
        #expect(fetcher.requestedURLs == [latestURL])
        #expect(try records(in: context).isEmpty)
    }

    @Test func fetch5xxReturnsFailureAndKeepsExistingRecord() async throws {
        let fetcher = HeaderFixtureFetcher(failures: [
            latestURL: DamCoreMlitURLPolicyError.badHTTPStatus(503),
        ])
        let clock = TestClock(now: try jstDateTime(year: 2026, month: 7, day: 15, hour: 12, minute: 0))
        let service = makeService(fetcher: fetcher, clock: clock)
        let context = try inMemoryModelContext()
        seedRecord(in: context, fetchedAt: clock.current, nextUpdateAt: nil)

        let outcome = await service.fetchAndStore(damId: damId, context: context, historicalDataSource: .sudmonitor, now: clock.current)

        guard case .failure = outcome else {
            Issue.record("Expected failure but got \(outcome)")
            return
        }
        let record = try #require(try records(in: context).first)
        #expect(record.rawDatBytes == Data("old".utf8))
    }

    @Test func fetchMissingPeriodHeadersSkipsWithoutCreatingRecord() async throws {
        let fetcher = HeaderFixtureFetcher(responses: [
            latestURL: (Data("sample".utf8), ["X-TCS-Dam-Id": damId]),
        ])
        let clock = TestClock(now: try jstDateTime(year: 2026, month: 7, day: 15, hour: 12, minute: 0))
        let service = makeService(fetcher: fetcher, clock: clock)
        let context = try inMemoryModelContext()

        let outcome = await service.fetchAndStore(damId: damId, context: context, historicalDataSource: .sudmonitor, now: clock.current)

        guard case .skippedInvalidPeriod = outcome else {
            Issue.record("Expected skippedInvalidPeriod but got \(outcome)")
            return
        }
        #expect(try records(in: context).isEmpty)
    }

    @Test func fetchUnparseablePeriodHeadersSkipsWithoutCreatingRecord() async throws {
        let fetcher = HeaderFixtureFetcher(responses: [
            latestURL: (
                Data("sample".utf8),
                dailyHeaders(since: "not-a-date", until: "2026-07-31T24:00:00+09:00")
            ),
        ])
        let clock = TestClock(now: try jstDateTime(year: 2026, month: 7, day: 15, hour: 12, minute: 0))
        let service = makeService(fetcher: fetcher, clock: clock)
        let context = try inMemoryModelContext()

        let outcome = await service.fetchAndStore(damId: damId, context: context, historicalDataSource: .sudmonitor, now: clock.current)

        guard case .skippedInvalidPeriod = outcome else {
            Issue.record("Expected skippedInvalidPeriod but got \(outcome)")
            return
        }
        #expect(try records(in: context).isEmpty)
    }

    @Test func fallbackNextUpdateAtIsNextDay0013JST() throws {
        let evening = try jstDateTime(year: 2026, month: 7, day: 15, hour: 23, minute: 59)
        let expected = try jstDateTime(year: 2026, month: 7, day: 16, hour: 0, minute: 13)
        #expect(SudmonitorHistoryService.fallbackNextUpdateAt(from: evening) == expected)
        let morning = try jstDateTime(year: 2026, month: 7, day: 15, hour: 0, minute: 0)
        #expect(SudmonitorHistoryService.fallbackNextUpdateAt(from: morning) == expected)
    }

    @Test func fetchStoresFallbackNextUpdateAtWhenHeaderMissing() async throws {
        let fetcher = HeaderFixtureFetcher(responses: [
            latestURL: (Data("sample".utf8), dailyHeaders(nextUpdateAt: nil)),
        ])
        let clock = TestClock(now: try jstDateTime(year: 2026, month: 7, day: 15, hour: 12, minute: 0))
        let service = makeService(fetcher: fetcher, clock: clock)
        let context = try inMemoryModelContext()

        let outcome = await service.fetchAndStore(damId: damId, context: context, historicalDataSource: .sudmonitor, now: clock.current)

        guard case .stored = outcome else {
            Issue.record("Expected stored but got \(outcome)")
            return
        }
        let record = try #require(try records(in: context).first)
        let expectedNextUpdateAt = try #require(SudmonitorHistoryService.fallbackNextUpdateAt(from: clock.current))
        #expect(record.nextUpdateAt == expectedNextUpdateAt)
    }

    @Test func autoFetchOneHourAndTwelveHoursSkipWhileNextUpdateAtInFuture() async throws {
        let fetcher = HeaderFixtureFetcher(responses: [:])
        let clock = TestClock(now: try jstDateTime(year: 2026, month: 7, day: 15, hour: 12, minute: 0))
        let service = makeService(fetcher: fetcher, clock: clock)
        let context = try inMemoryModelContext()
        seedRecord(
            in: context,
            fetchedAt: clock.current,
            nextUpdateAt: clock.current.addingTimeInterval(3600)
        )

        let oneHour = await service.autoFetch(interval: .oneHour, damId: damId, context: context, historicalDataSource: .sudmonitor, now: clock.current)
        guard case .skippedByCooldown = oneHour else {
            Issue.record("Expected skippedByCooldown but got \(oneHour)")
            return
        }
        let twelveHours = await service.autoFetch(interval: .twelveHours, damId: damId, context: context, historicalDataSource: .sudmonitor, now: clock.current)
        guard case .skippedByCooldown = twelveHours else {
            Issue.record("Expected skippedByCooldown but got \(twelveHours)")
            return
        }
        #expect(fetcher.requestedURLs.isEmpty)
    }

    @Test func autoFetchOneDayAndOneWeekExecuteRegardlessOfCooldown() async throws {
        let fetcher = HeaderFixtureFetcher(responses: [
            latestURL: (Data("sample".utf8), dailyHeaders()),
        ])
        let clock = TestClock(now: try jstDateTime(year: 2026, month: 7, day: 15, hour: 12, minute: 0))
        let service = makeService(fetcher: fetcher, clock: clock)
        let context = try inMemoryModelContext()
        seedRecord(
            in: context,
            fetchedAt: clock.current,
            nextUpdateAt: clock.current.addingTimeInterval(3600)
        )

        let oneDay = await service.autoFetch(interval: .oneDay, damId: damId, context: context, historicalDataSource: .sudmonitor, now: clock.current)
        guard case .stored = oneDay else {
            Issue.record("Expected stored but got \(oneDay)")
            return
        }
        let oneWeek = await service.autoFetch(interval: .oneWeek, damId: damId, context: context, historicalDataSource: .sudmonitor, now: clock.current)
        guard case .stored = oneWeek else {
            Issue.record("Expected stored but got \(oneWeek)")
            return
        }
        #expect(fetcher.requestedURLs == [latestURL, latestURL])
        #expect(try records(in: context).count == 1)
    }

    @Test func autoFetchShortIntervalsExecuteAfterNextUpdateAtPassed() async throws {
        let fetcher = HeaderFixtureFetcher(responses: [
            latestURL: (Data("sample".utf8), dailyHeaders()),
        ])
        let clock = TestClock(now: try jstDateTime(year: 2026, month: 7, day: 15, hour: 12, minute: 0))
        let service = makeService(fetcher: fetcher, clock: clock)
        let context = try inMemoryModelContext()
        seedRecord(
            in: context,
            fetchedAt: clock.current,
            nextUpdateAt: clock.current.addingTimeInterval(-3600)
        )

        let oneHour = await service.autoFetch(interval: .oneHour, damId: damId, context: context, historicalDataSource: .sudmonitor, now: clock.current)

        guard case .stored = oneHour else {
            Issue.record("Expected stored but got \(oneHour)")
            return
        }
        #expect(fetcher.requestedURLs == [latestURL])
    }

    @Test func autoFetchShortIntervalsExecuteWhenNoRecordExists() async throws {
        let fetcher = HeaderFixtureFetcher(responses: [
            latestURL: (Data("sample".utf8), dailyHeaders()),
        ])
        let clock = TestClock(now: try jstDateTime(year: 2026, month: 7, day: 15, hour: 12, minute: 0))
        let service = makeService(fetcher: fetcher, clock: clock)
        let context = try inMemoryModelContext()

        let twelveHours = await service.autoFetch(interval: .twelveHours, damId: damId, context: context, historicalDataSource: .sudmonitor, now: clock.current)

        guard case .stored = twelveHours else {
            Issue.record("Expected stored but got \(twelveHours)")
            return
        }
        #expect(fetcher.requestedURLs == [latestURL])
    }

    @Test func gateDisabledMakesFetchAndAutoFetchNoop() async throws {
        let fetcher = HeaderFixtureFetcher(responses: [:])
        let clock = TestClock(now: try jstDateTime(year: 2026, month: 7, day: 15, hour: 12, minute: 0))
        let service = makeService(fetcher: fetcher, clock: clock)
        let context = try inMemoryModelContext()

        let outcome = await service.fetchAndStore(damId: damId, context: context, historicalDataSource: .mlitDirect, now: clock.current)
        guard case .gateDisabled = outcome else {
            Issue.record("Expected gateDisabled but got \(outcome)")
            return
        }
        let auto = await service.autoFetch(interval: .oneDay, damId: damId, context: context, historicalDataSource: .mlitDirect, now: clock.current)
        guard case .gateDisabled = auto else {
            Issue.record("Expected gateDisabled but got \(auto)")
            return
        }
        #expect(fetcher.requestedURLs.isEmpty)
        #expect(try records(in: context).isEmpty)
    }

    @Test func manualUpdateBlockedWhileCooldownActive() async throws {
        let fetcher = HeaderFixtureFetcher(responses: [:])
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()
        seedRecord(
            in: context,
            fetchedAt: Date(),
            nextUpdateAt: Date().addingTimeInterval(3600)
        )
        let appModel = makeAppModel(sudFetcher: fetcher, defaults: defaults)
        appModel.configure(modelContext: context, launchContext: .background)

        let message = await appModel.performSudmonitorHistoryManualUpdate()

        #expect(message != nil)
        #expect(fetcher.requestedURLs.isEmpty)
    }

    @Test func manualUpdateExecutesAfterCooldownExpired() async throws {
        let fetcher = HeaderFixtureFetcher(responses: [
            latestURL: (Data("sample".utf8), dailyHeaders()),
        ])
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()
        seedRecord(
            in: context,
            fetchedAt: Date(),
            nextUpdateAt: Date().addingTimeInterval(-3600)
        )
        let appModel = makeAppModel(sudFetcher: fetcher, defaults: defaults)
        appModel.configure(modelContext: context, launchContext: .background)

        let message = await appModel.performSudmonitorHistoryManualUpdate()

        #expect(message == nil)
        #expect(fetcher.requestedURLs == [latestURL])
        let records = try records(in: context)
        #expect(records.count == 1)
        #expect(records.first?.rawDatBytes == Data("sample".utf8))
    }

    @Test func validatesBundledDebugDatAndKeepsAllRows() throws {
        let resourceURL = try #require(
            Bundle.main.url(
                forResource: "historical_daily_sameura",
                withExtension: "dat",
                subdirectory: "Resources/debug"
            ) ?? Bundle.main.url(forResource: "historical_daily_sameura", withExtension: "dat")
        )
        let bytes = try Data(contentsOf: resourceURL)

        let validated = try SudmonitorHistoryService.validateDebugDat(bytes, damId: damId)

        #expect(bytes.count == 40_519)
        #expect(SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
            == "6518129422064ec6c67d46e9d14ad45ea78bec6ce6610d6a71d0ccefc94dee69")
        #expect(validated.periodStartDay == "20260509")
        #expect(validated.periodEndDay == "20260608")
        #expect(validated.rows.count == 744)
        #expect(validated.rows.first?.time == "2026/5/9 01:00")
        #expect(validated.rows.last?.time == "2026/6/8 24:00")
    }

    @Test func storeDebugDatReplacesTargetOnlyAndClearsNextUpdateAt() throws {
        let now = try jstDateTime(year: 2026, month: 8, day: 17, hour: 12, minute: 0)
        let context = try inMemoryModelContext()
        seedRecord(
            in: context,
            damId: damId,
            fetchedAt: now.addingTimeInterval(-3600),
            nextUpdateAt: now.addingTimeInterval(3600)
        )
        seedRecord(
            in: context,
            damId: "9999999999999",
            fetchedAt: now,
            nextUpdateAt: nil
        )
        let service = makeService(fetcher: HeaderFixtureFetcher(), clock: TestClock(now: now))
        let bytes = debugDailyDat(rows: [
            ("2026/5/9", "01:00"),
            ("2026/5/9", "02:00"),
            ("2026/5/9", "24:00"),
        ])

        let outcome = service.storeDebugDat(
            bytes,
            rawDatFileName: "selected.dat",
            damId: damId,
            context: context,
            now: now
        )

        guard case .stored = outcome else {
            Issue.record("Expected stored but got \(outcome)")
            return
        }
        let saved = try #require(try records(in: context).first { $0.damId == damId })
        #expect(saved.periodStartDay == "20260509")
        #expect(saved.periodEndDay == "20260509")
        #expect(saved.fetchedAt == now)
        #expect(saved.nextUpdateAt == nil)
        #expect(saved.rawDatBytes == bytes)
        #expect(saved.rawDatFileName == "selected.dat")
        #expect(try records(in: context).contains { $0.damId == "9999999999999" })
    }

    @Test func debugDatRejectsStationMismatchWithoutReplacingExistingRecord() throws {
        let now = Date()
        let context = try inMemoryModelContext()
        seedRecord(in: context, fetchedAt: now, nextUpdateAt: nil)
        let service = makeService(fetcher: HeaderFixtureFetcher(), clock: TestClock(now: now))
        let bytes = debugDailyDat(
            stationId: "9999999999999",
            rows: [("2026/5/9", "01:00"), ("2026/5/9", "24:00")]
        )

        let outcome = service.storeDebugDat(
            bytes,
            rawDatFileName: "wrong.dat",
            damId: damId,
            context: context,
            now: now
        )

        guard case .failure(let error) = outcome else {
            Issue.record("Expected failure but got \(outcome)")
            return
        }
        #expect(error as? SudmonitorHistoryDebugDatError == .stationMismatch)
        #expect(try records(in: context).first { $0.damId == damId }?.rawDatBytes == Data("old".utf8))
    }

    @Test func debugDatRequiresDailyBoundaries() {
        let invalidStart = debugDailyDat(rows: [
            ("2026/5/9", "02:00"),
            ("2026/5/9", "24:00"),
        ])
        let invalidEnd = debugDailyDat(rows: [
            ("2026/5/9", "01:00"),
            ("2026/5/9", "23:00"),
        ])

        #expect(throws: SudmonitorHistoryDebugDatError.invalidBoundary) {
            _ = try SudmonitorHistoryService.validateDebugDat(invalidStart, damId: damId)
        }
        #expect(throws: SudmonitorHistoryDebugDatError.invalidBoundary) {
            _ = try SudmonitorHistoryService.validateDebugDat(invalidEnd, damId: damId)
        }
    }

    @Test func debugDatRejectsInvalidOrNonIncreasingTimestamps() {
        let invalid2401 = debugDailyDat(rows: [
            ("2026/5/9", "01:00"),
            ("2026/5/9", "24:01"),
            ("2026/5/10", "24:00"),
        ])
        let outOfOrder = debugDailyDat(rows: [
            ("2026/5/9", "01:00"),
            ("2026/5/9", "03:00"),
            ("2026/5/9", "02:00"),
            ("2026/5/9", "24:00"),
        ])
        let duplicate = debugDailyDat(rows: [
            ("2026/5/9", "01:00"),
            ("2026/5/9", "01:00"),
            ("2026/5/9", "24:00"),
        ])

        for bytes in [invalid2401, outOfOrder, duplicate] {
            #expect(throws: SudmonitorHistoryDebugDatError.invalidChronology) {
                _ = try SudmonitorHistoryService.validateDebugDat(bytes, damId: damId)
            }
        }
    }

    @Test func debugDatRejectsEmptyOrUnparseableData() {
        #expect(throws: SudmonitorHistoryDebugDatError.invalidData) {
            _ = try SudmonitorHistoryService.validateDebugDat(Data(), damId: damId)
        }
        #expect(throws: SudmonitorHistoryDebugDatError.invalidData) {
            _ = try SudmonitorHistoryService.validateDebugDat(Data([0xFF, 0xFF, 0xFF]), damId: damId)
        }
    }

    @Test func initialStartupFetchesOnlyWhenRecordMissing() async throws {
        let fetcher = HeaderFixtureFetcher(responses: [
            latestURL: (Data("sample".utf8), dailyHeaders()),
        ])
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()

        let first = makeAppModel(sudFetcher: fetcher, defaults: defaults)
        first.configure(modelContext: context, launchContext: .foreground)
        try await waitUntil { first.damLoadStatus != .initial }

        let firstHistoryRequestCount = fetcher.requestedURLs.filter { $0 == latestURL }.count
        #expect(try records(in: context).count == 1)
        #expect(firstHistoryRequestCount == 1)

        let second = makeAppModel(sudFetcher: fetcher, defaults: defaults)
        second.configure(modelContext: context, launchContext: .foreground)
        try await waitUntil { second.damLoadStatus != .initial }

        #expect(fetcher.requestedURLs.filter { $0 == latestURL }.count == firstHistoryRequestCount, "保存済みのため再取得しない")
        #expect(try records(in: context).count == 1)
    }

    @Test func storedManualUpdateBumpsRevisionsAndRefreshesRows() async throws {
        let newDat = debugDailyDat(rows: [
            (date: "2026/7/1", time: "01:00"),
            (date: "2026/7/31", time: "01:00"),
        ])
        let fetcher = HeaderFixtureFetcher(responses: [
            latestURL: (newDat, dailyHeaders()),
        ])
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()
        seedRecord(
            in: context,
            fetchedAt: Date(),
            nextUpdateAt: Date().addingTimeInterval(-3600)
        )
        let appModel = makeAppModel(sudFetcher: fetcher, defaults: defaults)
        appModel.configure(modelContext: context, launchContext: .background)
        let revisionBefore = appModel.sudmonitorHistoryRevision
        let graphRevisionBefore = appModel.graphDataRevision
        #expect(appModel.sudmonitorHistoryRows.isEmpty, "旧レコードのrawはパース不能のため空")

        let message = await appModel.performSudmonitorHistoryManualUpdate()

        #expect(message == nil)
        #expect(appModel.sudmonitorHistoryRevision == revisionBefore + 1)
        #expect(appModel.graphDataRevision == graphRevisionBefore + 1)
        #expect(appModel.isSudmonitorHistoryAvailable)
        let record = try #require(appModel.sudmonitorHistoryRecord)
        #expect(record.periodStartDay == "20260701")
        #expect(record.periodEndDay == "20260731")
        #expect(appModel.sudmonitorHistoryRows.count == 2)
    }

    @Test func failedManualUpdateDoesNotBumpRevision() async throws {
        let fetcher = HeaderFixtureFetcher(failures: [latestURL: URLError(.timedOut)])
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()
        seedRecord(
            in: context,
            fetchedAt: Date(),
            nextUpdateAt: Date().addingTimeInterval(-3600)
        )
        let appModel = makeAppModel(sudFetcher: fetcher, defaults: defaults)
        appModel.configure(modelContext: context, launchContext: .background)
        let revisionBefore = appModel.sudmonitorHistoryRevision

        let message = await appModel.performSudmonitorHistoryManualUpdate()

        #expect(message != nil)
        #expect(appModel.sudmonitorHistoryRevision == revisionBefore)
    }

    @Test func cooldownSkippedManualUpdateDoesNotBumpRevision() async throws {
        let fetcher = HeaderFixtureFetcher(responses: [:])
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()
        seedRecord(
            in: context,
            fetchedAt: Date(),
            nextUpdateAt: Date().addingTimeInterval(3600)
        )
        let appModel = makeAppModel(sudFetcher: fetcher, defaults: defaults)
        appModel.configure(modelContext: context, launchContext: .background)
        let revisionBefore = appModel.sudmonitorHistoryRevision

        let message = await appModel.performSudmonitorHistoryManualUpdate()

        #expect(message != nil)
        #expect(appModel.sudmonitorHistoryRevision == revisionBefore)
        #expect(fetcher.requestedURLs.isEmpty)
    }

    @Test func observationFiresWhenDailyRecordIsStored() async throws {
        let newDat = debugDailyDat(rows: [
            (date: "2026/7/1", time: "01:00"),
            (date: "2026/7/31", time: "01:00"),
        ])
        let fetcher = HeaderFixtureFetcher(responses: [
            latestURL: (newDat, dailyHeaders()),
        ])
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()
        seedRecord(
            in: context,
            fetchedAt: Date(),
            nextUpdateAt: Date().addingTimeInterval(-3600)
        )
        let appModel = makeAppModel(sudFetcher: fetcher, defaults: defaults)
        appModel.configure(modelContext: context, launchContext: .background)
        let fired = ObservationFireBox()
        withObservationTracking {
            _ = appModel.isSudmonitorHistoryAvailable
        } onChange: {
            fired.markFired()
        }

        let message = await appModel.performSudmonitorHistoryManualUpdate()

        #expect(message == nil)
        #expect(fired.didFire, "保存変更で Observation 追跡が発火し UI が再評価される")
    }

    @Test func widgetBridgeImportBumpsRevision() async throws {
        let defaults = try testDefaults()
        let settingsRepository = SettingsRepository(defaults: defaults)
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.autoUpdateEnabled = false
        settings.updateOnBoot = false
        settings.initialAutoUpdateDialogShown = true
        settingsRepository.save(settings)

        let context = try inMemoryModelContext()
        seedRecord(
            in: context,
            fetchedAt: try jstDateTime(year: 2026, month: 7, day: 1, hour: 0, minute: 30),
            nextUpdateAt: nil
        )

        let bridgeFetchTime = try jstDateTime(year: 2026, month: 7, day: 31, hour: 0, minute: 20)
        let bridge = DamCoreDailyHistoryBridge(
            stationId: damId,
            dataUrl: latestURL,
            fetchedAt: bridgeFetchTime,
            nextUpdateAt: try jstDateTime(year: 2026, month: 8, day: 1, hour: 0, minute: 13),
            since: "2026-07-01T01:00:00+09:00",
            until: "2026-07-31T24:00:00+09:00",
            rawBytes: debugDailyDat(rows: [
                (date: "2026/7/2", time: "01:00"),
                (date: "2026/7/31", time: "01:00"),
            ]),
            rawDatFileName: "latest.dat"
        )
        defaults.set(try JSONEncoder().encode(bridge), forKey: WidgetDefaultsKey.dailyHistoryBridgeV1)

        let appModel = makeAppModel(sudFetcher: HeaderFixtureFetcher(responses: [:]), defaults: defaults)
        appModel.configure(modelContext: context, launchContext: .background)
        let revisionBefore = appModel.sudmonitorHistoryRevision

        appModel.completeForegroundStartupIfNeeded(reason: "sceneActive")
        try await waitUntil { appModel.sudmonitorHistoryRevision > revisionBefore }

        let record = try #require(appModel.sudmonitorHistoryRecord)
        #expect(record.fetchedAt == bridgeFetchTime)
        #expect(record.periodEndDay == "20260731")
    }

    @Test func debugDatStoreBumpsRevision() async throws {
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()
        let backupRoot = Self.temporaryBackupRootURL()
        let appModel = DamAppModel(
            network: MlitNetworkDataSource(fetcher: FixtureFetcher(responses: [:]).fetch, headerFetcher: HeaderFixtureFetcher(responses: [:]).fetch),
            networkAvailability: FixedNetworkAvailability(isNetworkAvailable: true),
            settingsRepository: SettingsRepository(defaults: defaults),
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults,
            debugDataSessionService: DebugDataSessionService(backupRootURL: backupRoot)
        )
        appModel.configure(modelContext: context, launchContext: .background)
        appModel.updateDebugModeEnabled(true)
        #expect(appModel.settings.debugModeEnabled)
        let revisionBefore = appModel.sudmonitorHistoryRevision

        let message = await appModel.performSudmonitorHistoryManualUpdate()

        #expect(message == nil)
        #expect(appModel.sudmonitorHistoryRevision == revisionBefore + 1)
        let record = try #require(appModel.sudmonitorHistoryRecord)
        #expect(record.rawDatFileName == "historical_daily_sameura.dat")
        try? FileManager.default.removeItem(at: backupRoot)
    }

    @Test func debugRestoreBumpsRevision() async throws {
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()
        let backupRoot = Self.temporaryBackupRootURL()
        let appModel = DamAppModel(
            network: MlitNetworkDataSource(fetcher: FixtureFetcher(responses: [:]).fetch, headerFetcher: HeaderFixtureFetcher(responses: [:]).fetch),
            networkAvailability: FixedNetworkAvailability(isNetworkAvailable: true),
            settingsRepository: SettingsRepository(defaults: defaults),
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults,
            debugDataSessionService: DebugDataSessionService(backupRootURL: backupRoot)
        )
        appModel.configure(modelContext: context, launchContext: .background)
        seedRecord(
            in: context,
            fetchedAt: Date(),
            nextUpdateAt: nil
        )
        appModel.updateDebugModeEnabled(true)
        #expect(appModel.settings.debugModeEnabled)
        let revisionBefore = appModel.sudmonitorHistoryRevision

        appModel.updateDebugModeEnabled(false)

        #expect(!appModel.settings.debugModeEnabled)
        #expect(appModel.sudmonitorHistoryRevision == revisionBefore + 1)
        #expect(appModel.sudmonitorHistoryRecord != nil, "待避前のレコードが復元される")
        try? FileManager.default.removeItem(at: backupRoot)
    }

    @Test func autoUpdateStoredBumpsRevisionInNonDebugPath() async throws {
        let fetcher = HeaderFixtureFetcher(responses: [
            latestURL: (Data("auto".utf8), dailyHeaders()),
        ])
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()
        seedRecord(
            in: context,
            fetchedAt: Date(),
            nextUpdateAt: Date().addingTimeInterval(-3600)
        )
        let appModel = makeAppModel(sudFetcher: fetcher, defaults: defaults)
        appModel.configure(modelContext: context, launchContext: .background)
        let revisionBefore = appModel.sudmonitorHistoryRevision
        let graphRevisionBefore = appModel.graphDataRevision

        await appModel.fetchSudmonitorHistoryAutoUpdate()

        #expect(fetcher.requestedURLs == [latestURL])
        #expect(appModel.sudmonitorHistoryRevision == revisionBefore + 1, "非Debug自動更新の .stored もリビジョンを進める")
        #expect(appModel.graphDataRevision == graphRevisionBefore + 1)
        #expect(!appModel.isSudmonitorHistoryAutoUpdateRunning, "完了後はフラグをクリアする")
        let record = try #require(appModel.sudmonitorHistoryRecord)
        #expect(record.rawDatBytes == Data("auto".utf8))
    }

    @Test func autoUpdateSkippedByCooldownDoesNotBumpRevision() async throws {
        let fetcher = HeaderFixtureFetcher(responses: [:])
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()
        seedRecord(
            in: context,
            fetchedAt: Date(),
            nextUpdateAt: Date().addingTimeInterval(3600)
        )
        let appModel = makeAppModel(sudFetcher: fetcher, defaults: defaults)
        appModel.configure(modelContext: context, launchContext: .background)
        appModel.settings.autoUpdateInterval = .oneHour
        let revisionBefore = appModel.sudmonitorHistoryRevision

        await appModel.fetchSudmonitorHistoryAutoUpdate()

        #expect(fetcher.requestedURLs.isEmpty)
        #expect(appModel.sudmonitorHistoryRevision == revisionBefore)
        #expect(!appModel.isSudmonitorHistoryAutoUpdateRunning)
    }

    @Test func manualUpdateSetsOnlyManualFlagWhileRunning() async throws {
        let fetcher = GatedHeaderFixtureFetcher(responses: [
            latestURL: (Data("sample".utf8), dailyHeaders()),
        ])
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()
        seedRecord(
            in: context,
            fetchedAt: Date(),
            nextUpdateAt: Date().addingTimeInterval(-3600)
        )
        let appModel = makeAppModel(sudFetcher: fetcher, defaults: defaults)
        appModel.configure(modelContext: context, launchContext: .background)

        let updateTask = Task { await appModel.performSudmonitorHistoryManualUpdate() }
        try await waitUntil { appModel.isSudmonitorHistoryManualRunning }
        #expect(!appModel.isSudmonitorHistoryInitialRunning)
        #expect(!appModel.isSudmonitorHistoryAutoUpdateRunning)

        fetcher.release()
        let message = await updateTask.value

        #expect(message == nil)
        #expect(!appModel.isSudmonitorHistoryManualRunning, "完了後はフラグをクリアする")
    }

    @Test func initialFetchSetsOnlyInitialFlagWhileRunning() async throws {
        let fetcher = GatedHeaderFixtureFetcher(responses: [
            latestURL: (Data("sample".utf8), dailyHeaders()),
        ])
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()
        let appModel = makeAppModel(sudFetcher: fetcher, defaults: defaults)
        appModel.configure(modelContext: context, launchContext: .background)

        let fetchTask = Task { await appModel.fetchSudmonitorHistoryIfNeeded(workType: "Daily history initial load") }
        try await waitUntil { appModel.isSudmonitorHistoryInitialRunning }
        #expect(!appModel.isSudmonitorHistoryManualRunning)
        #expect(!appModel.isSudmonitorHistoryAutoUpdateRunning)

        fetcher.release()
        await fetchTask.value

        #expect(!appModel.isSudmonitorHistoryInitialRunning, "完了後はフラグをクリアする")
        #expect(try records(in: context).count == 1)
    }

    @Test func manualUpdateBlockedWhileDailyAutoUpdateRunning() async throws {
        let fetcher = GatedHeaderFixtureFetcher(responses: [
            latestURL: (Data("sample".utf8), dailyHeaders()),
        ])
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()
        let appModel = makeAppModel(sudFetcher: fetcher, defaults: defaults)
        appModel.configure(modelContext: context, launchContext: .background)

        let autoTask = Task { await appModel.fetchSudmonitorHistoryAutoUpdate() }
        try await waitUntil { appModel.isSudmonitorHistoryAutoUpdateRunning }

        let message = await appModel.performSudmonitorHistoryManualUpdate()

        #expect(message == AppText.mainAutorenewInProgress)

        fetcher.release()
        await autoTask.value
        #expect(fetcher.requestedURLs == [latestURL], "ブロックされた手動更新は新規取得を開始しない")
    }

    @Test func manualUpdateBlockedWhileInitialFetchRunning() async throws {
        let fetcher = GatedHeaderFixtureFetcher(responses: [
            latestURL: (Data("sample".utf8), dailyHeaders()),
        ])
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()
        let appModel = makeAppModel(sudFetcher: fetcher, defaults: defaults)
        appModel.configure(modelContext: context, launchContext: .background)

        let initialTask = Task { await appModel.fetchSudmonitorHistoryIfNeeded(workType: "Daily history initial load") }
        try await waitUntil { appModel.isSudmonitorHistoryInitialRunning }

        let message = await appModel.performSudmonitorHistoryManualUpdate()

        #expect(message == AppText.mainAutorenewInProgress)

        fetcher.release()
        await initialTask.value
        #expect(fetcher.requestedURLs == [latestURL], "ブロックされた手動更新は新規取得を開始しない")
    }

    @Test func manualUpdateBlockedWhileRealtimeAutoUpdateRunning() async throws {
        let fetcher = HeaderFixtureFetcher(responses: [:])
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()
        let appModel = makeAppModel(sudFetcher: fetcher, defaults: defaults)
        appModel.configure(modelContext: context, launchContext: .background)
        appModel.isAutoUpdateRunning = true

        let message = await appModel.performSudmonitorHistoryManualUpdate()

        #expect(message == AppText.mainAutorenewInProgress)
        #expect(fetcher.requestedURLs.isEmpty)
    }

    @Test func manualUpdateBlockedWhileManualUpdateRunning() async throws {
        let fetcher = GatedHeaderFixtureFetcher(responses: [
            latestURL: (Data("sample".utf8), dailyHeaders()),
        ])
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()
        seedRecord(
            in: context,
            fetchedAt: Date(),
            nextUpdateAt: Date().addingTimeInterval(-3600)
        )
        let appModel = makeAppModel(sudFetcher: fetcher, defaults: defaults)
        appModel.configure(modelContext: context, launchContext: .background)

        let firstTask = Task { await appModel.performSudmonitorHistoryManualUpdate() }
        try await waitUntil { appModel.isSudmonitorHistoryManualRunning }

        let secondMessage = await appModel.performSudmonitorHistoryManualUpdate()

        #expect(secondMessage == AppText.mainManualUpdateInProgress)

        fetcher.release()
        let firstMessage = await firstTask.value

        #expect(firstMessage == nil)
        #expect(fetcher.requestedURLs == [latestURL], "再手動更新は新規取得を開始しない")
    }

    @Test func concurrentDailyFetchesAreSkippedWhileAnotherFetchRunning() async throws {
        let fetcher = GatedHeaderFixtureFetcher(responses: [
            latestURL: (Data("sample".utf8), dailyHeaders()),
        ])
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()
        let appModel = makeAppModel(sudFetcher: fetcher, defaults: defaults)
        appModel.configure(modelContext: context, launchContext: .background)

        let initialTask = Task { await appModel.fetchSudmonitorHistoryIfNeeded(workType: "Daily history initial load") }
        try await waitUntil { appModel.isSudmonitorHistoryInitialRunning }

        await appModel.fetchSudmonitorHistoryAutoUpdate()
        await appModel.fetchSudmonitorHistoryForDamChange()

        #expect(!appModel.isSudmonitorHistoryAutoUpdateRunning, "自動更新取得はスキップされる")
        #expect(appModel.isSudmonitorHistoryInitialRunning, "初回取得のみが実行中を維持する")

        fetcher.release()
        await initialTask.value

        #expect(fetcher.requestedURLs == [latestURL], "スキップされた取得はネットワークアクセスしない")
        #expect(!appModel.isSudmonitorHistoryInitialRunning)
    }
}

/// Observation 追跡の発火を記録するスレッド安全な箱(このファイルのテスト専用)。
private final class ObservationFireBox: @unchecked Sendable {
    private nonisolated(unsafe) var fired = false

    func markFired() {
        fired = true
    }

    var didFire: Bool {
        fired
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

/// `release()` まで応答を保留できるレスポンスヘッダー付きフェッチャ(このファイルのテスト専用)。
///
/// 取得の中断点を作り、取得実行中のフラグ・ブロック判定を観察するために使う。
private final class GatedHeaderFixtureFetcher: @unchecked Sendable {
    private let responses: [String: (Data, [String: String])]
    private let lock = NSLock()
    private nonisolated(unsafe) var urls: [String] = []
    private var pendingContinuations: [CheckedContinuation<Void, Never>] = []
    private var released = false

    init(responses: [String: (Data, [String: String])] = [:]) {
        self.responses = responses
    }

    var requestedURLs: [String] {
        lock.lock()
        defer { lock.unlock() }
        return urls
    }

    /// `release()` が呼ばれるまで中断してから、登録済みレスポンスを返します。
    func fetch(urlString: String) async throws -> (Data, [String: String]) {
        recordRequest(urlString)
        await waitUntilReleased()
        guard let entry = responses[urlString] else {
            throw DamCoreMlitURLPolicyError.badHTTPStatus(404)
        }
        return entry
    }

    private func recordRequest(_ urlString: String) {
        lock.lock()
        urls.append(urlString)
        lock.unlock()
    }

    private func waitUntilReleased() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if released {
                lock.unlock()
                continuation.resume()
            } else {
                pendingContinuations.append(continuation)
                lock.unlock()
            }
        }
    }

    /// 中断中の全フェッチを解放します。
    func release() {
        lock.lock()
        let continuations = pendingContinuations
        pendingContinuations = []
        released = true
        lock.unlock()
        for continuation in continuations {
            continuation.resume()
        }
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

/// テスト用に現在日時を制御するクロック(このファイルのテスト専用)。
private final class TestClock: @unchecked Sendable {
    nonisolated(unsafe) var current: Date

    init(now: Date) {
        current = now
    }
}

/// テスト用の一時 UserDefaults を作成します。
private func testDefaults() throws -> UserDefaults {
    let suiteName = "test.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

/// 5モデル(SudmonitorHistoryRecord を含む)で in-memory SwiftData モデルコンテキストを作成します。
@MainActor
private func inMemoryModelContext() throws -> ModelContext {
    let schema = Schema([
        DamDataRecord.self,
        HistoricalSearchMetaRecord.self,
        HistoricalDamDataRecord.self,
        DebugLogRecord.self,
        SudmonitorHistoryRecord.self,
    ])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: configuration)
    return ModelContext(container)
}

private func jstDateTime(year: Int, month: Int, day: Int, hour: Int, minute: Int) throws -> Date {
    try #require(Calendar.jst.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)))
}

private func debugDailyDat(
    stationId: String = "1368080700010",
    rows: [(date: String, time: String)]
) -> Data {
    let header = """
    水系名,吉野川
    河川名,吉野川
    観測所名,早明浦ダム
    観測所記号,\(stationId)

    """
    let body = rows.map { row in
        "\(row.date),\(row.time),0.0, ,179550, ,19.33, ,29.70, ,100.0, "
    }.joined(separator: "\n")
    return Data([0xEF, 0xBB, 0xBF]) + Data("\(header)\(body)\n".utf8)
}

@MainActor
private func waitUntil(
    timeout: TimeInterval = 3,
    intervalNanoseconds: UInt64 = 20_000_000,
    _ condition: @escaping @MainActor () -> Bool
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return }
        try await Task.sleep(nanoseconds: intervalNanoseconds)
    }
    #expect(condition(), "Timed out waiting for async condition")
}
