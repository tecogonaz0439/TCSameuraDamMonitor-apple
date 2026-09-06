// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Testing
@testable import TCSameuraDamMonitor

@Suite("Debug settings")
struct DebugSettingsTests {
    @Test func defaultsUseIndependentBundledDatSelections() {
        let settings = AppSettings(locale: Locale(identifier: "en"))

        #expect(settings.debugRealtimeDatSelectionMode == .bundled)
        #expect(settings.debugRealtimeDatFileName == nil)
        #expect(settings.debugHistoricalDailyDatSelectionMode == .bundled)
        #expect(settings.debugHistoricalDailyDatFileName == nil)
        #expect(settings.debugRealtimeDataEndDate == nil)
        #expect(settings.debugRealtimeDataPeriodAutoAdvanceEnabled)
    }

    @Test func currentPayloadRoundTripsIndependentSelections() throws {
        let endDate = Date(timeIntervalSinceReferenceDate: 123_456)
        let original = AppSettingsDebug(
            modeEnabled: true,
            settingsVisible: true,
            simulateMode: .loadingFailure,
            realtimeDatSelectionMode: .latest,
            realtimeDatFileName: "realtime.dat",
            historicalDailyDatSelectionMode: .userSelected,
            historicalDailyDatFileName: "daily.dat",
            realtimeDataEndDate: endDate,
            realtimeDataPeriodAutoAdvanceEnabled: false
        )

        let decoded = try JSONDecoder().decode(AppSettingsDebug.self, from: JSONEncoder().encode(original))

        #expect(decoded == original)
    }

    @Test func legacyPayloadMapsRealtimeModeAndDefaultsDailySelection() throws {
        let endDate = Date(timeIntervalSinceReferenceDate: 654_321)
        let legacy = LegacyDebugSettings(
            modeEnabled: true,
            settingsVisible: true,
            simulateMode: .networkUnavailable,
            disableRefreshCooldown: false,
            datFileMode: "realtime",
            datFileName: "legacy.dat",
            dataEndDate: endDate,
            dataPeriodAutoAdvanceEnabled: false
        )

        let decoded = try JSONDecoder().decode(AppSettingsDebug.self, from: JSONEncoder().encode(legacy))

        #expect(decoded.modeEnabled)
        #expect(decoded.settingsVisible)
        #expect(decoded.simulateMode == .networkUnavailable)
        #expect(decoded.realtimeDatSelectionMode == .latest)
        #expect(decoded.realtimeDatFileName == "legacy.dat")
        #expect(decoded.historicalDailyDatSelectionMode == .bundled)
        #expect(decoded.historicalDailyDatFileName == nil)
        #expect(decoded.realtimeDataEndDate == endDate)
        #expect(!decoded.realtimeDataPeriodAutoAdvanceEnabled)
    }

    @Test func resettingDebugSettingsResetsBothDatSelections() {
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.debugSettingsVisible = true
        settings.debugModeEnabled = true
        settings.debugRealtimeDatSelectionMode = .userSelected
        settings.debugRealtimeDatFileName = "realtime.dat"
        settings.debugHistoricalDailyDatSelectionMode = .latest
        settings.debugHistoricalDailyDatFileName = "daily.dat"
        settings.debugRealtimeDataEndDate = Date()
        settings.debugRealtimeDataPeriodAutoAdvanceEnabled = false

        let reset = settings.resettingDebugSettings()

        #expect(!reset.debugSettingsVisible)
        #expect(!reset.debugModeEnabled)
        #expect(reset.debugRealtimeDatSelectionMode == .bundled)
        #expect(reset.debugRealtimeDatFileName == nil)
        #expect(reset.debugHistoricalDailyDatSelectionMode == .bundled)
        #expect(reset.debugHistoricalDailyDatFileName == nil)
        #expect(reset.debugRealtimeDataEndDate == nil)
        #expect(reset.debugRealtimeDataPeriodAutoAdvanceEnabled)
    }

    @Test func localizedLabelsMatchCrossPlatformContract() {
        let ja = Locale(identifier: "ja")
        let en = Locale(identifier: "en")

        #expect(AppLocalized.text("settings.debugRealtimeDatFile", locale: ja) == "デバッグ用 .dat ファイル(リアルタイムデータ)")
        #expect(AppLocalized.text("settings.debugHistoricalDailyDatFile", locale: en) == "Debug .dat file (daily historical data)")
        #expect(AppLocalized.text("settings.exportHistoricalDailyDat", locale: ja) == ".dat ファイル(過去データ(日次))をエクスポート")
        #expect(AppLocalized.text("common.open", locale: ja) == "開く")
        #expect(AppLocalized.text("common.open", locale: en) == "Open")
    }
}

private struct LegacyDebugSettings: Encodable {
    let modeEnabled: Bool
    let settingsVisible: Bool
    let simulateMode: DebugSimulateMode
    let disableRefreshCooldown: Bool
    let datFileMode: String
    let datFileName: String?
    let dataEndDate: Date?
    let dataPeriodAutoAdvanceEnabled: Bool
}
