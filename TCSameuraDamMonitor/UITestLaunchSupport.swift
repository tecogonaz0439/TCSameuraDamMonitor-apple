// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation
import SwiftData

#if DEBUG
@MainActor
enum UITestLaunchSupport {
    enum Scenario: String {
        case dashboardLoaded
        case dashboardError
        case firstLaunch
        case historicalSaved
        case historicalEmpty
        case historicalSearchDuplicate
        case historicalSearchError
        case debugEnabled
        case debugDisabled
        case otherStorageRateMessagesCustomized
        case graphComparisonError
        case otherDamDashboard
        case graphPerfBaseline
        case dailyHistoryLoaded

        var seedsRealtimeData: Bool {
            switch self {
            case .dashboardError, .firstLaunch, .historicalEmpty, .historicalSearchError, .otherStorageRateMessagesCustomized:
                return false
            case .dashboardLoaded, .historicalSaved, .historicalSearchDuplicate, .debugEnabled, .debugDisabled, .graphComparisonError, .otherDamDashboard, .graphPerfBaseline, .dailyHistoryLoaded:
                return true
            }
        }

        var seedsHistoricalData: Bool {
            switch self {
            case .historicalSaved, .historicalSearchDuplicate:
                return true
            case .dashboardLoaded, .dashboardError, .firstLaunch, .historicalEmpty, .historicalSearchError, .debugEnabled, .debugDisabled, .otherStorageRateMessagesCustomized, .graphComparisonError, .otherDamDashboard, .graphPerfBaseline, .dailyHistoryLoaded:
                return false
            }
        }
    }

    struct Configuration {
        let scenario: Scenario
        let defaults: UserDefaults

        func makeAppModel() -> DamAppModel {
            DamAppModel(
                network: MlitNetworkDataSource(fetcher: Self.fixtureFetcher, headerFetcher: Self.fixtureHeaderFetcher),
                networkAvailability: FixtureNetworkAvailability(isNetworkAvailable: scenario != .dashboardError),
                settingsRepository: SettingsRepository(defaults: defaults),
                dashboardCardExpansionRepository: DashboardCardExpansionRepository(defaults: defaults),
                widgetGroupDefaults: nil,
                widgetStandardDefaults: defaults,
                historicalComparisonService: scenario == .graphComparisonError
                    ? HistoricalComparisonService(
                        assetStore: HistoricalComparisonAssetStore(dataLoader: { _ in
                            Thread.sleep(forTimeInterval: 3)
                            return nil
                        })
                    )
                    : HistoricalComparisonService(),
                debugDataSessionService: DebugDataSessionService(backupRootURL: Self.debugDataBackupRootURL)
            )
        }

        func prepareDefaults() {
            guard ProcessInfo.processInfo.environment["TCSMDM_UI_TEST_PRESERVE_DEFAULTS"] != "1" else {
                return
            }
            defaults.removePersistentDomain(forName: Self.defaultsSuiteName)
            try? FileManager.default.removeItem(at: Self.debugDataBackupRootURL)
            var settings = AppSettings()
            settings.showNotification = false
            settings.updateOnBoot = false
            settings.autoUpdateEnabled = false
            settings.initialAutoUpdateDialogShown = scenario != .firstLaunch
            settings.debugSettingsVisible = scenario == .debugEnabled
            settings.debugModeEnabled = false
            settings.debugSimulateMode = .none
            if scenario == .otherStorageRateMessagesCustomized {
                settings.otherState80_100 = "😎"
                settings.otherMsg80_100 = "Custom message"
                settings.otherMsg80_100Ja = "カスタムメッセージ"
            }
            if scenario == .otherDamDashboard {
                settings.targetDamId = "1368010125140"
                settings.realtimeDataSource = .mlitDirect
            }
            settings.recalculateInitialNextRequestedUpdate()
            SettingsRepository(defaults: defaults).save(settings)
        }

        private static var debugDataBackupRootURL: URL {
            let cacheRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            return cacheRoot
                .appendingPathComponent("TCSameuraDamMonitorUITests", isDirectory: true)
                .appendingPathComponent("debug-data-backup", isDirectory: true)
        }

        func seed(modelContainer: ModelContainer) {
            let context = ModelContext(modelContainer)
            if scenario.seedsRealtimeData {
                let data = scenario == .otherDamDashboard ? Self.otherDamRealtimeData
                    : scenario == .graphPerfBaseline ? Self.perfBaselineRealtimeData
                    : Self.realtimeData
                let encoded = try? JSONEncoder().encode(data)
                if let encoded {
                    context.insert(DamDataRecord(encodedData: encoded, lastFetchTime: Self.fixtureFetchDate, rawDatBytes: nil))
                }
            }
            if scenario.seedsHistoricalData {
                let meta = scenario == .historicalSearchDuplicate ? Self.duplicateSearchMeta : Self.savedHistoricalMeta
                context.insert(HistoricalSearchMetaRecord(meta: meta))
                for row in Self.historicalRows {
                    context.insert(HistoricalDamDataRecord(searchMetaId: meta.id, data: row, timeMillis: TimeFormatters.millis(fromDamTime: row.time)))
                }
            }
            if scenario == .debugEnabled {
                context.insert(DebugLogRecord(entry: DebugLogEntry(id: UUID(uuidString: "00000000-0000-0000-0000-000000000301")!, timestamp: Self.fixtureFetchDate, message: "UI test debug log.", details: "Seeded from UI test fixture.")))
            }
            if scenario == .dailyHistoryLoaded {
                context.insert(SudmonitorHistoryRecord(
                    damId: AppSettings.defaultDamId,
                    periodStartDay: "20260601",
                    periodEndDay: "20260630",
                    fetchedAt: Self.fixtureFetchDate,
                    nextUpdateAt: Self.dailyHistoryNextUpdateAt,
                    rawDatBytes: Self.dailyHistoryRawDat,
                    rawDatFileName: "latest.dat"
                ))
            }
            try? context.save()
        }

        private static func fixtureFetcher(_ urlString: String) async throws -> Data {
            throw URLError(.notConnectedToInternet)
        }

        /// sudmonitor 中継取得(ヘッダー付き)のフィクスチャ。日次 latest.dat のみ更新済み
        /// フィクスチャを返し、それ以外は実通信を行わず失敗する。
        private static func fixtureHeaderFetcher(_ urlString: String) async throws -> (Data, [String: String]) {
            if urlString == dailyHistoryLatestURL {
                return (dailyHistoryUpdatedRawDat, dailyHistoryUpdatedHeaders)
            }
            throw URLError(.notConnectedToInternet)
        }

        /// sudmonitor 日次過去データ latest.dat の取得 URL。
        private static var dailyHistoryLatestURL: String {
            "\(RealtimeDataSource.sudmonitorBaseURL)/v1/history/\(AppSettings.defaultDamId)/latest.dat"
        }

        /// 手動更新時に取得される更新済み日次過去データのフィクスチャ(シード済みレコードと異なる期間)。
        private static var dailyHistoryUpdatedRawDat: Data {
            var data = Data([0xEF, 0xBB, 0xBF])
            let text = """
            水系名,吉野川
            河川名,吉野川
            観測所名,早明浦ダム
            観測所記号,\(AppSettings.defaultDamId)
            2026/6/2,01:00,0, ,232000, ,12.5, ,10.2, ,83.0, 
            2026/6/17,01:00,0, ,233000, ,12.8, ,10.4, ,84.0, 
            2026/7/2,01:00,0, ,234000, ,13.0, ,10.5, ,85.0, 
            """
            data.append(Data(text.utf8))
            return data
        }

        /// 更新済み日次過去データに付与するフィクスチャレスポンスヘッダー。
        private static var dailyHistoryUpdatedHeaders: [String: String] {
            [
                "X-TCS-Dam-Id": AppSettings.defaultDamId,
                "X-TCS-History-Since": "2026-06-02T01:00:00+09:00",
                "X-TCS-History-Until": "2026-07-02T24:00:00+09:00",
                "X-TCS-Next-Update-At": "2026-07-02T15:13:00Z",
            ]
        }

        static var defaultsSuiteName: String {
            "net.tecogonaz.TCSameuraDamMonitor.UITests.\(ProcessInfo.processInfo.environment["TCSMDM_UI_TEST_RUN_ID"] ?? "default")"
        }

        private static var fixtureFetchDate: Date {
            TimeFormatters.iso8601JST.date(from: "2026-06-12T05:15:00+09:00") ?? Date(timeIntervalSinceReferenceDate: 802296900)
        }

        private static var realtimeData: DamData {
            DamData(
                observationStationId: AppSettings.defaultDamId,
                observationStationName: "早明浦ダム",
                riverSystemName: "吉野川",
                riverName: "吉野川",
                updatedAt: "2026/06/12 05:00",
                catchmentAverageRainfall: 0.0,
                storageVolume: 231_000.0,
                storageVolumeForMessage: 231_000.0,
                storageVolumeTrend: .up,
                inflow: 12.34,
                inflowTrend: .unknown,
                outflow: 10.11,
                outflowTrend: .unknown,
                storagePercentage: 81.25,
                storagePercentageTrend: .up,
                storagePercentageTime: "2026/06/12 05:00",
                storagePercentageDayChange: 1.25,
                storagePercentageDayChangeTrend: .up,
                storagePercentageWeekChange: 2.5,
                storagePercentageWeekChangeTrend: .up,
                historicalData: realtimeRows
            )
        }

        private static var realtimeRows: [DamHistoricalData] {
            [
                DamHistoricalData(time: "2026/06/12 01:00", catchmentAverageRainfall: 0, storagePercentage: 80.25, storageVolume: 229_000, inflow: 11.0, outflow: 10.0),
                DamHistoricalData(time: "2026/06/12 02:00", catchmentAverageRainfall: 0, storagePercentage: 80.50, storageVolume: 229_500, inflow: 11.5, outflow: 10.0),
                DamHistoricalData(time: "2026/06/12 03:00", catchmentAverageRainfall: 0, storagePercentage: 80.75, storageVolume: 230_000, inflow: 12.0, outflow: 10.1),
                DamHistoricalData(time: "2026/06/12 04:00", catchmentAverageRainfall: 0, storagePercentage: 81.00, storageVolume: 230_500, inflow: 12.2, outflow: 10.1),
                DamHistoricalData(time: "2026/06/12 05:00", catchmentAverageRainfall: 0, storagePercentage: 81.25, storageVolume: 231_000, inflow: 12.34, outflow: 10.11),
            ]
        }

        private static var perfBaselineRealtimeData: DamData {
            let base = realtimeData
            return DamData(
                observationStationId: base.observationStationId,
                observationStationName: base.observationStationName,
                riverSystemName: base.riverSystemName,
                riverName: base.riverName,
                updatedAt: base.updatedAt,
                catchmentAverageRainfall: base.catchmentAverageRainfall,
                storageVolume: base.storageVolume,
                storageVolumeForMessage: base.storageVolumeForMessage,
                storageVolumeTrend: base.storageVolumeTrend,
                inflow: base.inflow,
                inflowTrend: base.inflowTrend,
                outflow: base.outflow,
                outflowTrend: base.outflowTrend,
                storagePercentage: base.storagePercentage,
                storagePercentageTrend: base.storagePercentageTrend,
                storagePercentageTime: base.storagePercentageTime,
                storagePercentageDayChange: base.storagePercentageDayChange,
                storagePercentageDayChangeTrend: base.storagePercentageDayChangeTrend,
                storagePercentageWeekChange: base.storagePercentageWeekChange,
                storagePercentageWeekChangeTrend: base.storagePercentageWeekChangeTrend,
                historicalData: perfBaselineRows
            )
        }

        private static let perfBaselineRows: [DamHistoricalData] = {
            guard let url = Bundle.main.url(forResource: "531368080700010202605241048683", withExtension: "dat", subdirectory: "Resources/debug")
                ?? Bundle.main.url(forResource: "531368080700010202605241048683", withExtension: "dat"),
                let data = try? Data(contentsOf: url) else {
                return realtimeRows
            }
            guard let parsed = try? MlitDamParser().parseHistoricalDat(
                data,
                damConfigId: AppSettings.defaultDamId,
                startDate: "20260601",
                endDate: "20260609"
            ),
                !parsed.1.isEmpty else {
                return realtimeRows
            }
            return parsed.1
        }()

        private static var otherDamRealtimeData: DamData {
            let base = realtimeData
            return DamData(
                observationStationId: "1368010125140",
                observationStationName: "別ダム",
                riverSystemName: base.riverSystemName,
                riverName: base.riverName,
                updatedAt: base.updatedAt,
                catchmentAverageRainfall: base.catchmentAverageRainfall,
                storageVolume: base.storageVolume,
                storageVolumeForMessage: base.storageVolumeForMessage,
                storageVolumeTrend: base.storageVolumeTrend,
                inflow: base.inflow,
                inflowTrend: base.inflowTrend,
                outflow: base.outflow,
                outflowTrend: base.outflowTrend,
                storagePercentage: base.storagePercentage,
                storagePercentageTrend: base.storagePercentageTrend,
                storagePercentageTime: base.storagePercentageTime,
                storagePercentageDayChange: base.storagePercentageDayChange,
                storagePercentageDayChangeTrend: base.storagePercentageDayChangeTrend,
                storagePercentageWeekChange: base.storagePercentageWeekChange,
                storagePercentageWeekChangeTrend: base.storagePercentageWeekChangeTrend,
                historicalData: base.historicalData
            )
        }

        private static var historicalRows: [DamHistoricalData] {
            [
                DamHistoricalData(time: "2026/05/01 01:00", catchmentAverageRainfall: 2.0, storagePercentage: 78.0, storageVolume: 220_000, inflow: 18.0, outflow: 12.0),
                DamHistoricalData(time: "2026/05/01 02:00", catchmentAverageRainfall: 1.0, storagePercentage: 78.5, storageVolume: 221_000, inflow: 17.0, outflow: 12.0),
                DamHistoricalData(time: "2026/05/02 01:00", catchmentAverageRainfall: 0.0, storagePercentage: 79.0, storageVolume: 222_000, inflow: 15.0, outflow: 12.0),
            ]
        }

        private static var savedHistoricalMeta: HistoricalSearchMeta {
            HistoricalSearchMeta(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
                observationStationId: AppSettings.defaultDamId,
                observationStationName: "早明浦ダム",
                riverSystemName: "吉野川",
                riverName: "吉野川",
                damConfigId: AppSettings.defaultDamId,
                searchBgnDate: "20260501",
                searchEndDate: "20260502",
                fetchedAt: fixtureFetchDate,
                sortOrder: 0,
                isPinned: true,
                dataStartTimeStr: "2026/05/01 01:00",
                dataEndTimeStr: "2026/05/02 01:00",
                dataStartStoragePct: 78.0,
                dataEndStoragePct: 79.0,
                dataMinStoragePct: 78.0,
                dataMaxStoragePct: 79.0
            )
        }

        private static var duplicateSearchMeta: HistoricalSearchMeta {
            let start = TimeFormatters.jstDay.string(from: DisplayFormatters.startOfJSTDay(DisplayFormatters.thirtyDaysAgoStart()))
            let end = TimeFormatters.jstDay.string(from: DisplayFormatters.startOfJSTDay(DisplayFormatters.yesterdayStart()))
            var meta = savedHistoricalMeta
            meta.sortOrder = 0
            return HistoricalSearchMeta(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!,
                observationStationId: meta.observationStationId,
                observationStationName: meta.observationStationName,
                riverSystemName: meta.riverSystemName,
                riverName: meta.riverName,
                damConfigId: meta.damConfigId,
                searchBgnDate: start,
                searchEndDate: end,
                fetchedAt: meta.fetchedAt,
                sortOrder: meta.sortOrder,
                isPinned: meta.isPinned,
                dataStartTimeStr: meta.dataStartTimeStr,
                dataEndTimeStr: meta.dataEndTimeStr,
                dataStartStoragePct: meta.dataStartStoragePct,
                dataEndStoragePct: meta.dataEndStoragePct,
                dataMinStoragePct: meta.dataMinStoragePct,
                dataMaxStoragePct: meta.dataMaxStoragePct
            )
        }

        /// sudmonitor 日次過去データの次回更新予定時刻(フィクスチャ取得時刻の翌日 00:13 JST)。
        private static var dailyHistoryNextUpdateAt: Date {
            TimeFormatters.iso8601JST.date(from: "2026-06-13T00:13:00+09:00") ?? Date(timeIntervalSinceReferenceDate: 802296900)
        }

        /// sudmonitor 日次過去データ(latest.dat 相当)のフィクスチャバイナリ。
        private static var dailyHistoryRawDat: Data {
            var data = Data([0xEF, 0xBB, 0xBF])
            let text = """
            水系名,吉野川
            河川名,吉野川
            観測所名,早明浦ダム
            観測所記号,\(AppSettings.defaultDamId)
            2026/6/1,01:00,0, ,229000, ,10.0, ,9.0, ,81.0, 
            2026/6/12,01:00,0, ,230000, ,11.0, ,9.5, ,81.5, 
            2026/6/30,01:00,0, ,231000, ,12.0, ,10.0, ,82.0, 
            """
            data.append(Data(text.utf8))
            return data
        }
    }

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing")
            || ProcessInfo.processInfo.environment["TCSMDM_UI_TESTING"] == "1"
    }

    static var currentConfiguration: Configuration? {
        guard isEnabled else { return nil }
        let rawScenario = ProcessInfo.processInfo.environment["TCSMDM_UI_SCENARIO"] ?? Scenario.dashboardLoaded.rawValue
        let scenario = Scenario(rawValue: rawScenario) ?? .dashboardLoaded
        let suiteName = Configuration.defaultsSuiteName
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        return Configuration(scenario: scenario, defaults: defaults)
    }
}

private struct FixtureNetworkAvailability: NetworkAvailabilityProviding {
    let isNetworkAvailable: Bool
}
#endif
