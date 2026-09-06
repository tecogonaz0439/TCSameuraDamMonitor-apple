// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Testing
import Foundation
import CoreGraphics
import CoreLocation
import SwiftData
import TCSameuraDamCore
@testable import TCSameuraDamMonitor

#if os(macOS)
import AppKit
#endif

@Suite("Dashboard card expansion persistence")
@MainActor
struct DashboardCardExpansionPersistenceTests {
    @Test func stateDefaultsMissingKeysAndOnlyUpdatesRequestedKey() {
        var state = DashboardCardExpansionState()

        state.set(false, for: .realtimeLatest)

        #expect(!state[.realtimeLatest])
        for key in DashboardCardExpansionKey.allCases where key != .realtimeLatest {
            #expect(state[key])
        }
    }

    @Test func defaultsEveryCardToExpanded() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = DashboardCardExpansionRepository(defaults: defaults)

        let state = repository.load()

        for key in DashboardCardExpansionKey.allCases {
            #expect(state[key], "Expected \(key.rawValue) to default to expanded")
        }
    }

    @Test func savesAndRestoresEveryCardIndependently() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = DashboardCardExpansionRepository(defaults: defaults)

        for (index, key) in DashboardCardExpansionKey.allCases.enumerated() {
            repository.save(index.isMultiple(of: 2), for: key)
        }

        let restored = DashboardCardExpansionRepository(defaults: defaults).load()
        for (index, key) in DashboardCardExpansionKey.allCases.enumerated() {
            #expect(restored[key] == index.isMultiple(of: 2))
        }
    }

    @Test func realtimeAndHistoricalCardsWithSameNameRemainSeparate() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = DashboardCardExpansionRepository(defaults: defaults)

        repository.save(false, for: .realtimeObservation)

        let restored = repository.load()
        #expect(!restored[.realtimeObservation])
        #expect(restored[.historicalObservation])

        repository.save(false, for: .historicalHistory)
        let updated = repository.load()
        #expect(updated[.realtimeHistory])
        #expect(!updated[.historicalHistory])
    }

    @Test func savingCardStateDoesNotModifyAppSettings() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settingsData = Data("sentinel-settings".utf8)
        defaults.set(settingsData, forKey: "app.settings.v2")
        let repository = DashboardCardExpansionRepository(defaults: defaults)

        repository.save(false, for: .realtimeGraph)

        #expect(defaults.data(forKey: "app.settings.v2") == settingsData)
        let restored = repository.load()
        #expect(!restored[.realtimeGraph])
        for key in DashboardCardExpansionKey.allCases where key != .realtimeGraph {
            #expect(restored[key])
        }
    }

    private func makeDefaults() throws -> (UserDefaults, String) {
        let name = "DashboardCardExpansionPersistenceTests.\(UUID().uuidString)"
        return (try #require(UserDefaults(suiteName: name)), name)
    }
}

@Suite("Widget localization")
struct WidgetLocalizationTests {
    @Test func dayChangeLabelUsesPreviousDayWording() throws {
        let plugInsURL = try #require(Bundle.main.builtInPlugInsURL)
        let widgetBundle = try #require(Bundle(
            url: plugInsURL.appendingPathComponent("TCSameuraDamMonitorWidgetExtension.appex")
        ))
        let japaneseLocalizationURL = try #require(widgetBundle.url(
            forResource: "ja",
            withExtension: "lproj"
        ))
        let japaneseBundle = try #require(Bundle(url: japaneseLocalizationURL))

        #expect(japaneseBundle.localizedString(
            forKey: "widget.dayChange",
            value: nil,
            table: nil
        ) == "前日比")
    }
}

@Suite("MLIT URL policy")
struct MlitURLPolicyTests {
    @Test func acceptsOnlyHTTPSMLITHost() throws {
        let url = try MlitURLPolicy.validatedMLITURL(from: "https://www1.river.go.jp/cgi-bin/DspDamData.exe?ID=1368080700010")
        #expect(url.absoluteString == "https://www1.river.go.jp/cgi-bin/DspDamData.exe?ID=1368080700010")
        #expect(throws: AppError.invalidMLITURL) {
            _ = try MlitURLPolicy.validatedMLITURL(from: "http://www1.river.go.jp/cgi-bin/DspDamData.exe")
        }
        #expect(throws: AppError.invalidMLITURL) {
            _ = try MlitURLPolicy.validatedMLITURL(from: "https://example.com/file.dat")
        }
    }

    @Test func validatedCoreMLITURLReturnsURLOrThrows() throws {
        let url = try MlitURLPolicy.validatedCoreMLITURL(from: "https://www1.river.go.jp/cgi-bin/DspDamData.exe?ID=1368080700010")
        #expect(url.absoluteString == "https://www1.river.go.jp/cgi-bin/DspDamData.exe?ID=1368080700010")
        #expect(throws: MlitURLPolicyError.invalidMLITURL) {
            _ = try MlitURLPolicy.validatedCoreMLITURL(from: "http://www1.river.go.jp/cgi-bin/DspDamData.exe")
        }
    }

    @Test func allowedURLChecks() throws {
        let mlitURL = try #require(URL(string: "https://www1.river.go.jp/cgi-bin/DspDamData.exe"))
        let datURL = try #require(URL(string: "https://www1.river.go.jp/dat/1368080700010.dat"))
        let externalURL = try #require(URL(string: "https://example.com/dat/1.dat"))

        #expect(MlitURLPolicy.isAllowedMLITURL(mlitURL))
        #expect(!MlitURLPolicy.isAllowedMLITURL(externalURL))

        #expect(MlitURLPolicy.isAllowedDatURL(datURL))
        #expect(!MlitURLPolicy.isAllowedDatURL(mlitURL))
        #expect(!MlitURLPolicy.isAllowedDatURL(externalURL))
    }

    @Test func redirectRejectingDelegateRejectsRedirect() {
        let delegate = DamCoreRedirectRejectingDelegate()
        let session = URLSession.shared
        let task = session.dataTask(with: URL(string: "https://example.com")!)
        let response = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 302, httpVersion: nil, headerFields: nil)!
        let request = URLRequest(url: URL(string: "https://example.com/redirect")!)

        var callbackCalled = false
        delegate.urlSession(session, task: task, willPerformHTTPRedirection: response, newRequest: request) { newRequest in
            #expect(newRequest == nil)
            callbackCalled = true
        }
        #expect(callbackCalled)
    }

    @Test func resolvesOnlyMLITDatLinks() throws {
        #expect(MlitURLPolicy.resolvedDatURL(from: "/dat/DspDamData_1368080700010.dat")?.absoluteString == "https://www1.river.go.jp/dat/DspDamData_1368080700010.dat")
        #expect(MlitURLPolicy.resolvedDatURL(from: "http://www1.river.go.jp/dat/DspDamData_1368080700010.dat")?.absoluteString == "https://www1.river.go.jp/dat/DspDamData_1368080700010.dat")
        #expect(MlitURLPolicy.resolvedDatURL(from: "https://www1.river.go.jp/dat/not-dat.txt") == nil)
        #expect(MlitURLPolicy.resolvedDatURL(from: "https://example.com/dat/DspDamData_1368080700010.dat") == nil)
    }

    @Test func sudmonitorPolicyAllowsSudmonitorDatURLAndRejectsOthers() throws {
        let policy = DamCoreURLPolicy.sudmonitor(userAgent: "TCSameuraDamMonitor-Apple/1.0.0")
        let url = try policy.validatedURL(from: "https://sudmonitor.kusugami-lab.net/v1/realtime/1368080700010/latest.dat")
        #expect(url.absoluteString == "https://sudmonitor.kusugami-lab.net/v1/realtime/1368080700010/latest.dat")
        #expect(policy.isAllowedDatURL(url))
        #expect(throws: DamCoreMlitURLPolicyError.invalidMLITURL) {
            _ = try policy.validatedURL(from: "https://www1.river.go.jp/cgi-bin/DspDamData.exe")
        }
        #expect(throws: DamCoreMlitURLPolicyError.invalidMLITURL) {
            _ = try policy.validatedURL(from: "http://sudmonitor.kusugami-lab.net/v1/realtime/1368080700010/latest.dat")
        }
    }

    @Test func sudmonitorPolicyRequiresDatSuffixForDatURLs() throws {
        let policy = DamCoreURLPolicy.sudmonitor(userAgent: "TCSameuraDamMonitor-Apple/1.0.0")
        let datURL = try #require(URL(string: "https://sudmonitor.kusugami-lab.net/v1/realtime/1368080700010/latest.dat"))
        let jsonURL = try #require(URL(string: "https://sudmonitor.kusugami-lab.net/v1/status.json"))
        #expect(policy.isAllowedURL(datURL))
        #expect(policy.isAllowedDatURL(datURL))
        #expect(policy.isAllowedURL(jsonURL))
        #expect(!policy.isAllowedDatURL(jsonURL))
    }

    @Test func appSudmonitorURLValidationMapsToAppError() {
        #expect(throws: AppError.invalidMLITURL) {
            _ = try MlitURLPolicy.validatedSudmonitorURL(from: "https://example.com/latest.dat")
        }
    }

    @Test func mlitPolicyPresetKeepsMlitHost() {
        #expect(DamCoreURLPolicy.mlit.allowedHost == "www1.river.go.jp")
        #expect(DamCoreMlitURLPolicy.allowedHost == "www1.river.go.jp")
        #expect(DamCoreMlitURLPolicy.isAllowedMLITURL(URL(string: "https://www1.river.go.jp/cgi-bin/DspDamData.exe")!))
    }
}

#if os(macOS)
@Suite("macOS main window presenter")
@MainActor
struct MacMainWindowPresenterTests {
    @Test func recognizesMainWindowByIdentifier() {
        #expect(MacMainWindowPresenter.isMainWindow(identifier: MacMainWindowPresenter.mainWindowIdentifier, title: ""))
    }

    @Test func recognizesMainWindowByTitleFallback() {
        #expect(MacMainWindowPresenter.isMainWindow(identifier: nil, title: AppText.appName))
    }

    @Test func recognizesLocalizedMainWindowTitlesByFallback() {
        #expect(MacMainWindowPresenter.isMainWindow(identifier: nil, title: "Sameura Dam Monitor", expectedTitle: "Sameura Dam Monitor"))
        #expect(MacMainWindowPresenter.isMainWindow(identifier: nil, title: "早明浦ダム 貯水率モニタ", expectedTitle: "早明浦ダム 貯水率モニタ"))
    }

    @Test func recognizesLocalizedMainWindowMenuItems() {
        #expect(MacMainWindowPresenter.isMainWindowMenuItem(title: "Sameura Dam Monitor", expectedTitle: "Sameura Dam Monitor"))
        #expect(MacMainWindowPresenter.isMainWindowMenuItem(title: "早明浦ダム 貯水率モニタ", expectedTitle: "早明浦ダム 貯水率モニタ"))
    }

    @Test func rejectsUnrelatedWindow() {
        let settingsIdentifier = NSUserInterfaceItemIdentifier("settings")
        #expect(!MacMainWindowPresenter.isMainWindow(identifier: settingsIdentifier, title: "Settings"))
    }
}

@Suite("macOS system settings destinations")
@MainActor
struct MacSystemSettingsDestinationTests {
    @Test func languageDestinationOpensLanguageAndRegion() {
        let url = SettingsSystemDestination.languageAndRegionURL

        #expect(url.scheme == "x-apple.systempreferences")
        #expect(url.absoluteString.hasSuffix("com.apple.Localization-Settings.extension"))
        #expect(url.absoluteString == "x-apple.systempreferences:com.apple.Localization-Settings.extension")
    }
}
#endif

@Suite("MLIT network data source")
struct MlitNetworkDataSourceTests {
    @Test func fetchBytesBuildsMLITRequestAndReturnsValidatedData() async throws {
        let expected = Data("ok".utf8)
        let dataSource = MlitNetworkDataSource { urlString in
            #expect(urlString == "https://www1.river.go.jp/dat/1368080700010.dat")
            return expected
        }

        let actual = try await dataSource.fetchBytes("https://www1.river.go.jp/dat/1368080700010.dat")

        #expect(actual == expected)
    }

    @Test func fetchBytesRejectsInvalidURL() async throws {
        let dataSource = MlitNetworkDataSource { _ in
            Data()
        }

        await #expect(throws: AppError.invalidMLITURL) {
            _ = try await dataSource.fetchBytes("https://example.com/not-mlit")
        }
    }

    @Test func fetchBytesRejectsOversizedContentLength() async throws {
        let dataSource = MlitNetworkDataSource { _ in
            throw DamCoreMlitURLPolicyError.responseTooLarge
        }

        await #expect(throws: MlitNetworkError.responseTooLarge) {
            _ = try await dataSource.fetchBytes("https://www1.river.go.jp/dat/1368080700010.dat")
        }
    }

    @Test func fetchBytesRejectsOversizedBody() async throws {
        let dataSource = MlitNetworkDataSource { _ in
            throw DamCoreMlitURLPolicyError.responseTooLarge
        }

        await #expect(throws: MlitNetworkError.responseTooLarge) {
            _ = try await dataSource.fetchBytes("https://www1.river.go.jp/dat/1368080700010.dat")
        }
    }

    @Test func fetchBytesRejectsBadHTTPStatus() async throws {
        let dataSource = MlitNetworkDataSource { _ in
            throw DamCoreMlitURLPolicyError.badHTTPStatus(503)
        }

        let error = await #expect(throws: MlitNetworkError.self) {
            _ = try await dataSource.fetchBytes("https://www1.river.go.jp/dat/1368080700010.dat")
        }
        #expect(error == .transport)
    }
}

@Suite("MLIT parser")
@MainActor
struct MlitDamParserTests {
    @Test func extractsAllowedDatURLFromHTML() throws {
        let html = #"<html><body><a href="/dat/1368080700010_202602220520.dat">dat</a></body></html>"#
        let url = try MlitDamParser().parseHTMLForDatURL(Data(html.utf8))
        #expect(url == "https://www1.river.go.jp/dat/1368080700010_202602220520.dat")
    }

    @Test func rejectsExternalDatURLFromHTML() throws {
        let html = #"<html><body><a href="https://example.com/1368080700010.dat">dat</a></body></html>"#
        #expect(throws: MlitParserError.datURLNotFound) {
            _ = try MlitDamParser().parseHTMLForDatURL(Data(html.utf8))
        }
    }

    @Test func parseHTMLForDatURLThrowsUnsupportedEncoding() {
        let invalidData = Data([0xFF, 0xFF, 0xFF])
        #expect(throws: MlitParserError.unsupportedEncoding) {
            _ = try MlitDamParser().parseHTMLForDatURL(invalidData)
        }
    }

    @Test func parsesRealtimeDatAndTrend() throws {
        let data = utf8BOMData("""
        水系名,吉野川
        河川名,吉野川
        観測所名,早明浦ダム
        観測所記号,1368080700010
        2026/02/22,04:20,0, ,69000, ,0, ,0, ,69.00, 
        2026/02/22,04:30,0, ,70000, ,0, ,0, ,70.00, 
        2026/02/22,04:40,0, ,71000, ,0, ,0, ,71.00, 
        2026/02/22,04:50,0, ,72000, ,0, ,0, ,72.00, 
        2026/02/22,05:00,0, ,73000, ,0, ,0, ,73.00, 
        2026/02/22,05:10,0, ,70000, ,0, ,0, ,70.00, 
        2026/02/22,05:20,0, ,75000, ,0, ,0, ,75.25, 
        """)
        let parsed = try MlitDamParser().parseRealtimeDat(data, stationId: "1368080700010", stationName: "早明浦ダム")
        #expect(parsed.observationStationId == "1368080700010")
        #expect(parsed.observationStationName == "早明浦ダム")
        #expect(parsed.riverSystemName == "吉野川")
        #expect(parsed.riverName == "吉野川")
        #expect(parsed.updatedAt == "2026/02/22 05:20")
        #expect(parsed.catchmentAverageRainfall == 0.0)
        #expect(parsed.storageVolume == 75000.0)
        #expect(parsed.storageVolumeForMessage == 75000.0)
        #expect(parsed.storageVolumeTrend == .up)
        #expect(parsed.inflow == 0.0)
        #expect(parsed.inflowTrend == .flat)
        #expect(parsed.outflow == 0.0)
        #expect(parsed.outflowTrend == .flat)
        #expect(parsed.storagePercentage == Float(75.25))
        #expect(parsed.storagePercentageTrend == .up)
        #expect(parsed.storagePercentageTime == "2026/02/22 05:20")
        #expect(parsed.storagePercentageDayChange == Float(6.25))
        #expect(parsed.storagePercentageDayChangeTrend == .up)
        #expect(parsed.storagePercentageWeekChange == Float(6.25))
        #expect(parsed.storagePercentageWeekChangeTrend == .up)
        #expect(parsed.historicalData.count == 7)
    }

    @Test func realtimeDayChangeUsesExactTwentyFourHourOffsetWhenEnoughRowsExist() throws {
        let data = realtimeDatData(
            rows: try tenMinuteRealtimeRows(
                start: jstDateTime(year: 2026, month: 2, day: 21, hour: 5, minute: 20),
                count: 145,
                storagePercentage: { Float(100 + $0) }
            )
        )

        let parsed = try MlitDamParser().parseRealtimeDat(data, stationId: "1368080700010", stationName: "早明浦ダム")

        #expect(parsed.updatedAt == "2026/02/22 05:20")
        #expect(parsed.storagePercentage == Float(244))
        #expect(parsed.storagePercentageDayChange == Float(144))
        #expect(parsed.storagePercentageDayChangeTrend == .up)
        #expect(parsed.storagePercentageWeekChange == Float(144))
        #expect(parsed.storagePercentageWeekChangeTrend == .up)
        #expect(parsed.historicalData.count == 145)
    }

    @Test func realtimeTrendDirectionalChanges() throws {
        let data = utf8BOMData("""
        水系名,吉野川
        河川名,吉野川
        観測所名,早明浦ダム
        観測所記号,1368080700010
        2026/02/22,04:20,0, ,76000, ,0, ,0, ,76.00, 
        2026/02/22,04:30,0, ,75000, ,0, ,0, ,75.00, 
        2026/02/22,04:40,0, ,75000, ,0, ,0, ,75.00, 
        2026/02/22,04:50,0, ,75000, ,0, ,0, ,75.00, 
        2026/02/22,05:00,0, ,75000, ,0, ,0, ,75.00, 
        2026/02/22,05:10,0, ,75000, ,0, ,0, ,75.00, 
        2026/02/22,05:20,0, ,74000, ,0, ,0, ,74.00, 
        """)
        let parsed = try MlitDamParser().parseRealtimeDat(data, stationId: "1368080700010", stationName: "早明浦ダム")
        #expect(parsed.storagePercentageTrend == .down)
        #expect(parsed.storageVolumeTrend == .down)
    }

    @Test func parseRealtimeDatThrowsNoDataRows() throws {
        let data = utf8BOMData("""
        水系名,吉野川
        河川名,吉野川
        """)
        #expect(throws: MlitParserError.noDataRows) {
            _ = try MlitDamParser().parseRealtimeDat(data, stationId: "1", stationName: "Test")
        }
    }

    @Test func realtimeStoragePercentageDoesNotCarryAcrossHour() throws {
        let data = utf8BOMData("""
        水系名,吉野川
        河川名,吉野川
        観測所名,早明浦ダム
        観測所記号,1368080700010
        2026/02/22,04:50,0, ,72000, ,0, ,0, ,72.00, 
        2026/02/22,05:00,0, ,73000, ,0, ,0, ,0,$
        """)

        let parsed = try MlitDamParser().parseRealtimeDat(data, stationId: "1368080700010", stationName: "早明浦ダム")

        #expect(parsed.storagePercentage == nil)
        #expect(!parsed.isAllObservationDataInvalid)
    }

    @Test func realtimeAllInvalidLatestRowIsDetected() throws {
        let data = utf8BOMData("""
        水系名,吉野川
        河川名,吉野川
        観測所名,早明浦ダム
        観測所記号,1368080700010
        2026/02/22,05:00,0,$,73000,$,0,$,0,$,70.00,$
        """)

        let parsed = try MlitDamParser().parseRealtimeDat(data, stationId: "1368080700010", stationName: "早明浦ダム")

        #expect(parsed.isAllObservationDataInvalid)
        #expect(parsed.storageVolumeForMessage == nil)
    }

    @Test func realtimeDebugDataEndDateFiltersRows() throws {
        let data = utf8BOMData("""
        水系名,吉野川
        河川名,吉野川
        観測所名,早明浦ダム
        観測所記号,1368080700010
        2026/02/22,05:00,0, ,73000, ,0, ,0, ,73.00,
        2026/02/22,05:10,0, ,74000, ,0, ,0, ,74.00,
        2026/02/22,05:20,0, ,75000, ,0, ,0, ,75.00,
        """)
        let endDate = try jstDateTime(year: 2026, month: 2, day: 22, hour: 5, minute: 10)

        let parsed = try MlitDamParser().parseRealtimeDat(
            data,
            stationId: "1368080700010",
            stationName: "早明浦ダム",
            debugDataEndDate: endDate
        )

        #expect(parsed.updatedAt == "2026/02/22 05:10")
        #expect(parsed.storagePercentage == Float(74))
        #expect(parsed.historicalData.count == 2)
    }

    @Test func realtimeDebugDataTimesAreSorted() throws {
        let data = utf8BOMData("""
        水系名,吉野川
        河川名,吉野川
        観測所名,早明浦ダム
        観測所記号,1368080700010
        2026/02/22,05:20,0, ,75000, ,0, ,0, ,75.00,
        2026/02/22,05:00,0, ,73000, ,0, ,0, ,73.00,
        2026/02/22,05:10,0, ,74000, ,0, ,0, ,74.00,
        """)

        let times = try MlitDamParser().realtimeDataTimes(data)

        #expect(times.map { TimeFormatters.jstDisplay.string(from: $0) } == [
            "2026/02/22 05:00",
            "2026/02/22 05:10",
            "2026/02/22 05:20"
        ])
    }

    @Test func realtimeDebugDataEndDate2400NormalizesStoragePercentage() throws {
        let data = utf8BOMData("""
        水系名,吉野川
        河川名,吉野川
        観測所名,早明浦ダム
        観測所記号,1368080700010
        2026/02/21,24:00,0.0, ,53940, ,3.01, ,14.70, ,41.1,
        2026/02/22,00:10,0.0, ,53940, ,3.01, ,14.70, ,0.0,-
        """)
        let endDate = try jstDateTime(year: 2026, month: 2, day: 22, hour: 0, minute: 10)

        let parsed = try MlitDamParser().parseRealtimeDat(
            data,
            stationId: "1368080700010",
            stationName: "早明浦ダム",
            debugDataEndDate: endDate
        )

        #expect(parsed.updatedAt == "2026/02/22 00:10")
        #expect(parsed.storagePercentage == Float(41.1))
        #expect(parsed.historicalData.count == 2)
    }

    @Test func realtimeDebugDataEndDate2400OnlyRow() throws {
        let data = utf8BOMData("""
        水系名,吉野川
        河川名,吉野川
        観測所名,早明浦ダム
        観測所記号,1368080700010
        2026/02/21,24:00,0.0, ,53940, ,3.01, ,14.70, ,41.1,
        """)
        let endDate = try jstDateTime(year: 2026, month: 2, day: 22, hour: 0, minute: 0)

        let parsed = try MlitDamParser().parseRealtimeDat(
            data,
            stationId: "1368080700010",
            stationName: "早明浦ダム",
            debugDataEndDate: endDate
        )

        #expect(parsed.updatedAt == "2026/02/21 24:00")
        #expect(parsed.storagePercentage == Float(41.1))
        #expect(parsed.historicalData.count == 1)
    }

    @Test func parsesHistoricalDatCorrectly() throws {
        let data = utf8BOMData("""
        水系名,吉野川
        河川名,吉野川
        観測所名,早明浦ダム
        観測所記号,1368080700010
        2026/02/22,04:20,0, ,69000, ,0, ,0, ,69.00, 
        2026/02/22,04:30,0, ,70000, ,0, ,0, ,70.00, 
        """)
        let (meta, rows) = try MlitDamParser().parseHistoricalDat(
            data,
            damConfigId: "1368080700010",
            startDate: "20260222",
            endDate: "20260222"
        )
        #expect(meta.observationStationId == "1368080700010")
        #expect(meta.observationStationName == "早明浦ダム")
        #expect(meta.riverSystemName == "吉野川")
        #expect(meta.riverName == "吉野川")
        #expect(meta.searchBgnDate == "20260222")
        #expect(meta.searchEndDate == "20260222")
        #expect(meta.dataStartStoragePct == 69.00)
        #expect(meta.dataEndStoragePct == 70.00)
        #expect(meta.dataMinStoragePct == 69.00)
        #expect(meta.dataMaxStoragePct == 70.00)
        #expect(rows.count == 2)
        #expect(rows[0].time == "2026/02/22 04:20")
        #expect(rows[0].storagePercentage == 69.00)
        #expect(rows[1].time == "2026/02/22 04:30")
        #expect(rows[1].storagePercentage == 70.00)
    }

    @Test func parseHistoricalDatThrowsNoHistoricalRows() throws {
        let data = utf8BOMData("""
        水系名,吉野川
        河川名,吉野川
        """)
        #expect(throws: MlitParserError.noHistoricalRows) {
            _ = try MlitDamParser().parseHistoricalDat(
                data,
                damConfigId: "1368080700010",
                startDate: "20260222",
                endDate: "20260222"
            )
        }
    }

    @Test func storageVolumeForMessageWalksBackPastMissingLatestValue() throws {
        let data = utf8BOMData("""
        水系名,吉野川
        河川名,吉野川
        観測所名,早明浦ダム
        観測所記号,1368080700010
        2026/02/22,05:00,0, ,73000, ,0, ,0, ,73.00, 
        2026/02/22,05:10,0, ,74000,$,0, ,0, ,74.00, 
        """)
        let parsed = try MlitDamParser().parseRealtimeDat(data, stationId: "1368080700010", stationName: "早明浦ダム")
        #expect(parsed.storageVolume == nil)
        #expect(parsed.storageVolumeForMessage == 73000.0)
    }

    @Test func storageVolumeForMessageWalksBackAcrossConsecutiveMissingValues() throws {
        let data = utf8BOMData("""
        水系名,吉野川
        河川名,吉野川
        観測所名,早明浦ダム
        観測所記号,1368080700010
        2026/02/22,04:50,0, ,72000, ,0, ,0, ,72.00, 
        2026/02/22,05:00,0, ,73000, ,0, ,0, ,73.00, 
        2026/02/22,05:10,0, ,74000,$,0, ,0, ,74.00, 
        2026/02/22,05:20,0, ,75000,$,0, ,0, ,75.00, 
        """)
        let parsed = try MlitDamParser().parseRealtimeDat(data, stationId: "1368080700010", stationName: "早明浦ダム")
        #expect(parsed.storageVolume == nil)
        #expect(parsed.storageVolumeForMessage == 73000.0)
    }

    @Test func storageVolumeForMessageIsNilWhenAllValuesAreMissing() throws {
        let data = utf8BOMData("""
        水系名,吉野川
        河川名,吉野川
        観測所名,早明浦ダム
        観測所記号,1368080700010
        2026/02/22,05:00,0, ,73000,$,0, ,0, ,73.00, 
        2026/02/22,05:10,0, ,74000,$,0, ,0, ,74.00, 
        """)
        let parsed = try MlitDamParser().parseRealtimeDat(data, stationId: "1368080700010", stationName: "早明浦ダム")
        #expect(parsed.storageVolume == nil)
        #expect(parsed.storageVolumeForMessage == nil)
    }
}

@Suite("Android parity rules")
@MainActor
struct AndroidParityRuleTests {
    @Test("Storage rate thresholds ≥80%, ≥60%, ≥40%, ≥20%, >0%, =0% match Android specification",
        arguments: [
            (Float(80), "😊"),
            (Float(60), "😌"),
            (Float(40), "😨"),
            (Float(20), "😰"),
            (Float(0.1), "😱"),
            (Float(0), "😇"),
        ])
    func storageRateThresholdYieldsCorrectStateEmoji(percentage: Float, expectedState: String) {
        let settings = AppSettings(locale: Locale(identifier: "en"))
        #expect(settings.stateMessage(for: percentage, isJapanese: false).0 == expectedState)
    }

    @Test("Storage rate boundary values map to the expected configured state",
        arguments: [
            (Float(105), "state80_100"),
            (Float(80), "state80_100"),
            (Float(79.99), "state60_80"),
            (Float(60), "state60_80"),
            (Float(59.99), "state40_60"),
            (Float(40), "state40_60"),
            (Float(39.99), "state20_40"),
            (Float(20), "state20_40"),
            (Float(19.99), "state0_20"),
            (Float(0.01), "state0_20"),
            (Float(0), "state0"),
            (Float(-5), "state0"),
        ])
    func storageRateThresholdsBoundariesAndEdgeCases(percentage: Float, expectedStateKey: String) {
        let settings = AppSettings(locale: Locale(identifier: "en"))
        let expectedState: String
        switch expectedStateKey {
        case "state80_100": expectedState = settings.state80_100
        case "state60_80": expectedState = settings.state60_80
        case "state40_60": expectedState = settings.state40_60
        case "state20_40": expectedState = settings.state20_40
        case "state0_20": expectedState = settings.state0_20
        default: expectedState = settings.state0
        }
        #expect(settings.stateMessage(for: percentage, isJapanese: false).0 == expectedState)
    }

    @Test func nextRunTimeCalculatesCorrectIntervals() throws {
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.autoUpdateInterval = .oneHour
        let anchor = try jstDateTime(year: 2026, month: 6, day: 12, hour: 5, minute: 15)
        settings.nextRequestedUpdate = anchor

        let before = try jstDateTime(year: 2026, month: 6, day: 12, hour: 4, minute: 0)
        #expect(settings.nextRunTime(after: before) == anchor)

        let after = try jstDateTime(year: 2026, month: 6, day: 12, hour: 5, minute: 20)
        let expectedNext = anchor.addingTimeInterval(3600) 
        #expect(settings.nextRunTime(after: after) == expectedNext)

        let closeBefore = try jstDateTime(year: 2026, month: 6, day: 12, hour: 5, minute: 5)
        #expect(settings.nextRunTimeWithMinAdvance(after: closeBefore) == expectedNext)
    }

    @Test func storageRateNilStatesDistinguishNoStorageAndAllInvalid() {
        let settings = AppSettings(locale: Locale(identifier: "en"))

        let noStorage = settings.storageRateMessage(for: nil, isJapanese: false, isAllDataInvalid: false)
        let allInvalid = settings.storageRateMessage(for: nil, isJapanese: false, isAllDataInvalid: true)

        #expect(noStorage.0 == settings.stateAllAbnormal)
        #expect(noStorage.1 == settings.msgAllAbnormal)
        #expect(allInvalid.0 == settings.stateAllDataInvalid)
        #expect(allInvalid.1 == settings.msgAllDataInvalid)
    }

    @Test func storageRateMessageDisabledReturnsBlankForAllStates() {
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.showStorageRateMessage = false

        #expect(settings.storageRateMessage(for: Float(80), isJapanese: false) == ("", ""))
        #expect(settings.storageRateMessage(for: nil, isJapanese: false, isAllDataInvalid: true) == ("", ""))
    }

    @Test func storageRateMessagesAreSeparatedForSameuraAndOtherDams() {
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.msg80_100 = "sameura"
        settings.otherMsg80_100 = "other"

        #expect(settings.stateMessage(for: Float(80), isJapanese: false).1 == "other")
        #expect(settings.stateMessage(for: Float(80), isJapanese: false, isSameura: true).1 == "sameura")
    }

    @Test func statusTextSwitchesFieldsByIsSameura() {
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.msg80_100 = "sameura"
        settings.msg80_100Ja = "sameura ja"
        settings.otherMsg80_100 = "other"
        settings.otherMsg80_100Ja = "other ja"

        #expect(DisplayFormatters.statusText(settings: settings, percentage: Float(85)).contains("other"))
        #expect(DisplayFormatters.statusText(settings: settings, percentage: Float(85), isSameura: true).contains("sameura"))
        #expect(DisplayFormatters.statusText(
            settings: settings,
            percentage: Float(85),
            isSameura: true,
            storageVolumeForMessage: Float(100000)
        ).contains("sameura"))
    }

    @Test func sameuraClassificationUsesRateFirstThenVolume() {
        let settings = AppSettings(locale: Locale(identifier: "en"))
        func message(_ percentage: Float, volume: Float?) -> String {
            settings.stateMessage(for: percentage, isJapanese: false, isSameura: true, storageVolumeForMessage: volume).1
        }
        #expect(message(80, volume: nil) == settings.msg80_100)
        #expect(message(80.1, volume: nil) == settings.msg80_100)
        #expect(message(100.1, volume: nil) == settings.msg80_100)
        #expect(message(120, volume: 0) == settings.msg80_100)
        #expect(message(0, volume: 50000) == settings.msg0)
        #expect(message(-0.1, volume: nil) == settings.msg0)
        #expect(message(79.9, volume: 80000) == settings.msg60_80)
        #expect(message(79.9, volume: 79999.9) == settings.msg40_60)
        #expect(message(79.9, volume: 60000) == settings.msg40_60)
        #expect(message(79.9, volume: 59999.9) == settings.msg20_40)
        #expect(message(79.9, volume: 40000) == settings.msg20_40)
        #expect(message(79.9, volume: 39999.9) == settings.msg0_20)
    }

    @Test func sameuraClassificationFallsBackToRateWhenVolumeMissing() {
        let settings = AppSettings(locale: Locale(identifier: "en"))
        func message(_ percentage: Float) -> String {
            settings.stateMessage(for: percentage, isJapanese: false, isSameura: true, storageVolumeForMessage: nil).1
        }
        #expect(message(79.9) == settings.msg60_80)
        #expect(message(59.9) == settings.msg40_60)
        #expect(message(39.9) == settings.msg20_40)
        #expect(message(19.9) == settings.msg0_20)
    }

    @Test func sameuraMessageSwitchesJapaneseAndNonJapaneseFields() {
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.msg60_80 = "en text"
        settings.msg60_80Ja = "ja text"

        #expect(settings.stateMessage(for: Float(75), isJapanese: false, isSameura: true, storageVolumeForMessage: 90000).1 == "en text")
        #expect(settings.stateMessage(for: Float(75), isJapanese: true, isSameura: true, storageVolumeForMessage: 90000).1 == "ja text")
    }

    @Test func sameuraNilPercentageUsesExistingAbnormalFields() {
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.msgAllAbnormal = "abnormal"
        settings.otherMsgAllAbnormal = "other abnormal"

        #expect(settings.storageRateMessage(for: nil, isJapanese: false, isSameura: true).1 == "abnormal")
        #expect(settings.storageRateMessage(for: nil, isJapanese: false, isAllDataInvalid: true, isSameura: true).1 == settings.msgAllDataInvalid)
    }

    @Test func otherClassificationMapsZeroAndNegativeToZeroPercent() {
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.otherMsg0 = "zero"
        settings.otherMsg0_20 = "low"

        #expect(settings.stateMessage(for: Float(0), isJapanese: false).1 == "zero")
        #expect(settings.stateMessage(for: Float(-5), isJapanese: false).1 == "zero")
        #expect(settings.stateMessage(for: Float(0.01), isJapanese: false).1 == "low")
    }

    @Test func resetOtherStorageRateMessagesAppliesGeneralPreset() {
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.otherState80_100 = "X"
        settings.otherMsg80_100 = "custom"
        settings.otherMsg80_100Ja = "custom ja"
        settings.otherMsgAllDataInvalid = "custom invalid"
        settings.otherMsgAllDataInvalidJa = "custom invalid ja"

        settings.resetOtherStorageRateMessages()

        let jaLocale = Locale(identifier: "ja")
        #expect(settings.otherState80_100 == "😊")
        #expect(settings.otherMsg80_100 == StorageMessagePreset.nonJa80_100.message())
        #expect(settings.otherMsg80_100Ja == StorageMessagePreset.nonJa80_100.message())
        #expect(settings.otherMsgAllDataInvalid == StorageMessagePreset.allDataInvalidNonJa.message())
        #expect(settings.otherMsgAllDataInvalidJa == StorageMessagePreset.allDataInvalidJa.message(locale: jaLocale))
    }

    @Test func otherStorageRateResetConfirmationTracksManualChanges() {
        var settings = AppSettings(locale: Locale(identifier: "en"))
        #expect(!settings.needsOtherStorageRateMessagesResetConfirmation())
        settings.otherMsg60_80 = "custom"
        #expect(settings.needsOtherStorageRateMessagesResetConfirmation())
        settings.resetOtherStorageRateMessages()
        #expect(!settings.needsOtherStorageRateMessagesResetConfirmation())
    }

    @Test func storageRateMessageDecodeCompatibilityFillsOtherFields() throws {
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.msg80_100 = "existing"
        settings.msg80_100Ja = "既存"
        let encoded = try JSONEncoder().encode(settings)

        var object = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var nested = try #require(object["messages"] as? [String: Any])
        for key in nested.keys where key.hasPrefix("other") {
            nested.removeValue(forKey: key)
        }
        object["messages"] = nested
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(AppSettings.self, from: legacyData)
        #expect(decoded.msg80_100 == "existing")
        #expect(decoded.msg80_100Ja == "既存")
        #expect(decoded.otherMsg80_100 == StorageMessagePreset.nonJa80_100.message())
        #expect(decoded.otherState80_100 == "😊")
        #expect(decoded.otherMsgAllDataInvalidJa == StorageMessagePreset.allDataInvalidJa.message(locale: Locale(identifier: "ja")))
    }

    @Test func storageRateMessageEncodeDecodeRoundTripPreservesAllFields() throws {
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.otherMsg40_60 = "custom other"
        settings.otherMsg40_60Ja = "カスタム"
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(decoded == settings)
        #expect(decoded.otherMsg40_60 == "custom other")
        #expect(decoded.otherMsg40_60Ja == "カスタム")
    }

    @Test func widgetMessagesIncludeOtherPrefixedKeys() {
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.otherMsg80_100 = "other high"
        settings.otherMsg80_100Ja = "その他の高い"
        let messages = settings.widgetMessages(isJapanese: false)
        #expect(messages["80_100"] == "😊 \(settings.msg80_100)")
        #expect(messages["other_80_100"] == "😊 other high")
        let messagesJa = settings.widgetMessages(isJapanese: true)
        #expect(messagesJa["other_80_100"] == "😊 その他の高い")
        let keys = messages.keys.filter { $0.hasPrefix("other_") }.sorted()
        #expect(keys == [
            "other_0", "other_0_20", "other_20_40", "other_40_60",
            "other_60_80", "other_80_100", "other_abnormal", "other_all_data_invalid"
        ])
    }

    @Test func storageRateDescriptorsCoverWidgetKeysAndProxyProperties() {
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.msg80_100 = "high"
        settings.msgAllDataInvalid = "invalid"
        let descriptors = AppSettings.storageRateMessageDescriptors
        let keys = descriptors.map(\.widgetKey)

        #expect(keys == [
            .storage80_100,
            .storage60_80,
            .storage40_60,
            .storage20_40,
            .storage0_20,
            .storage0,
            .abnormal,
            .allDataInvalid
        ])
        #expect(descriptors.first { $0.widgetKey == .storage80_100 }.map { settings[keyPath: $0.message] } == "high")
        #expect(descriptors.first { $0.widgetKey == .allDataInvalid }.map { settings[keyPath: $0.message] } == "invalid")
    }

    @Test func otherMessageDescriptorsCoverWidgetBackedMessages() {
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.msgInitialMessage = "open app"
        settings.msgDataDistributionStopped = "stopped"
        let descriptors = AppSettings.otherMessageDescriptors
        let fields = descriptors.map(\.field)

        #expect(fields == [
            .initialMessage,
            .networkUnavailable,
            .loadingError,
            .dataDistributionStopped,
            .dataDistributionResumed
        ])
        #expect(descriptors.compactMap(\.widgetKey) == [
            .initial,
            .dataDistributionStopped,
            .dataDistributionResumed
        ])
        #expect(descriptors.first { $0.field == .initialMessage }.map { settings[keyPath: $0.message] } == "open app")
        #expect(descriptors.first { $0.field == .dataDistributionStopped }.map { settings[keyPath: $0.message] } == "stopped")
    }

    @Test func resetStorageRateMessagesDeleteClearsMessagesAndRestoresStates() {
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.state80_100 = "x"
        settings.msg80_100 = "custom"
        settings.msg80_100Ja = "custom ja"
        settings.stateAllDataInvalid = "y"
        settings.msgAllDataInvalid = "custom invalid"
        settings.msgAllDataInvalidJa = "custom invalid ja"

        settings.resetStorageRateMessages(mode: .delete)

        #expect(settings.state80_100 == "😊")
        #expect(settings.state60_80 == "😌")
        #expect(settings.state40_60 == "😨")
        #expect(settings.state20_40 == "😰")
        #expect(settings.state0_20 == "😱")
        #expect(settings.state0 == "😇")
        #expect(settings.stateAllAbnormal == "😑")
        #expect(settings.stateAllDataInvalid == "😴")
        let bodiesAreEmpty = storageRateMessageBodies(settings).allSatisfy { $0.isEmpty }
        #expect(bodiesAreEmpty)
    }

    @Test func resetStorageRateMessagesJapanesePresetAppliesAndroidUdonPreset() {
        var settings = AppSettings(locale: Locale(identifier: "en"))

        settings.resetStorageRateMessages(mode: .japanese)

        #expect(settings.msg80_100 == StorageMessagePreset.nonJa80_100.message())
        #expect(settings.msg80_100Ja == AppLocalized.text("storage.defaultMsg.ja.80_100", locale: Locale(identifier: "ja")))
        #expect(settings.msg20_40Ja == "旧大川村役場の建屋が…")
        #expect(settings.msg0 == StorageMessagePreset.nonJa0.message())
        #expect(settings.msg0Ja == AppLocalized.text("storage.defaultMsg.ja.0", locale: Locale(identifier: "ja")))
        #expect(settings.msgAllAbnormal == StorageMessagePreset.allAbnormalNonJa.message())
        #expect(settings.msgAllAbnormalJa == StorageMessagePreset.allAbnormalJa.message(locale: Locale(identifier: "ja")))
        #expect(settings.msgAllDataInvalid == StorageMessagePreset.allDataInvalidNonJa.message())
        #expect(settings.msgAllDataInvalidJa == StorageMessagePreset.allDataInvalidJa.message(locale: Locale(identifier: "ja")))
    }

    @Test func resetStorageRateMessagesGeneralPresetAppliesGeneralMessages() {
        var settings = AppSettings(locale: Locale(identifier: "ja"))

        settings.resetStorageRateMessages(mode: .nonJapanese)

        #expect(settings.msg80_100 == StorageMessagePreset.nonJa80_100.message())
        #expect(settings.msg80_100Ja == StorageMessagePreset.nonJa80_100.message())
        #expect(settings.msg0 == StorageMessagePreset.nonJa0.message())
        #expect(settings.msg0Ja == StorageMessagePreset.nonJa0.message())
        #expect(settings.msgAllAbnormal == StorageMessagePreset.allAbnormalNonJa.message())
        #expect(settings.msgAllAbnormalJa == StorageMessagePreset.allAbnormalJa.message(locale: Locale(identifier: "ja")))
        #expect(settings.msgAllDataInvalid == StorageMessagePreset.allDataInvalidNonJa.message())
        #expect(settings.msgAllDataInvalidJa == StorageMessagePreset.allDataInvalidJa.message(locale: Locale(identifier: "ja")))
    }

    @Test func storageRateResetConfirmationOnlyForManualChanges() {
        var settings = AppSettings(locale: Locale(identifier: "en"))
        #expect(!settings.needsStorageRateMessagesResetConfirmation())

        settings.resetStorageRateMessages(mode: .delete)
        #expect(!settings.needsStorageRateMessagesResetConfirmation())

        settings.resetStorageRateMessages(mode: .japanese)
        #expect(!settings.needsStorageRateMessagesResetConfirmation())

        settings.resetStorageRateMessages(mode: .nonJapanese)
        #expect(!settings.needsStorageRateMessagesResetConfirmation())

        settings.msg80_100 = "custom"
        #expect(settings.needsStorageRateMessagesResetConfirmation())
    }

    @Test func otherMessagesResetConfirmationOnlyForManualChanges() {
        var settings = AppSettings(locale: Locale(identifier: "en"))
        #expect(!settings.needsOtherMessagesResetConfirmation())

        settings.resetOtherMessages()
        #expect(!settings.needsOtherMessagesResetConfirmation())

        settings.msgInitialMessage = "custom"
        #expect(settings.needsOtherMessagesResetConfirmation())
    }

    @Test("Default non-storage user-facing messages match Android parity copy")
    func otherMessagesMatchAndroidDefaults() {
        let settings = AppSettings(locale: Locale(identifier: "en"))

        #expect(settings.initialMessageText(isJapanese: false) == "🥺 Please launch the app")
        #expect(settings.networkUnavailableText(isJapanese: false) == "😢 No network connection")
        #expect(settings.loadingErrorText(isJapanese: false) == "😵 Failed to fetch observation data")
        #expect(settings.dataDistributionStoppedText(isJapanese: false) == "😪 Observation data distribution has stopped")
        #expect(settings.dataDistributionResumedText(isJapanese: false) == "🥱 Observation data distribution has resumed")
    }

    @Test("Widget fetch log entry type supports old and typed formats",
        arguments: [
            ("TestDam", WidgetFetchLog.EntryType.auto),
            ("i;TestDam", WidgetFetchLog.EntryType.initial),
            ("a;TestDam", WidgetFetchLog.EntryType.auto),
            ("b;TestDam", WidgetFetchLog.EntryType.boot),
        ])
    func widgetFetchLogEntryParsesOldAndNewFormat(payloadPrefix: String, expectedType: WidgetFetchLog.EntryType) {
        let now = Date().timeIntervalSinceReferenceDate
        let entry = "\(now);\(payloadPrefix);2026/06/09 10:00;2026/06/09 10:00"

        #expect(WidgetFetchLog.parseType(entry: entry) == expectedType)
    }

    @Test func initialAutoUpdateTimeIsInAndroidRandomizationWindow() throws {
        var settings = AppSettings(locale: Locale(identifier: "en"))
        let now = try #require(Calendar.jst.date(from: DateComponents(year: 2026, month: 5, day: 25, hour: 1, minute: 0)))
        settings.recalculateInitialNextRequestedUpdate(after: now) {
            AppSettings.initialAutoUpdateStartMinuteOfDay
        }
        let start = Calendar.jst.dateComponents([.year, .month, .day, .weekday, .hour, .minute], from: settings.nextRequestedUpdate)
        #expect(start.year == 2026)
        #expect(start.month == 6)
        #expect(start.day == 1)
        #expect(start.weekday == 2) 
        #expect(start.hour == 0)
        #expect(start.minute == 15)

        settings.recalculateInitialNextRequestedUpdate(after: now) {
            AppSettings.initialAutoUpdateEndMinuteOfDay
        }
        let end = Calendar.jst.dateComponents([.year, .month, .day, .weekday, .hour, .minute], from: settings.nextRequestedUpdate)
        #expect(end.year == 2026)
        #expect(end.month == 6)
        #expect(end.day == 1)
        #expect(end.weekday == 2) 
        #expect(end.hour == 5)
        #expect(end.minute == 59)
    }

    @Test func defaultAutoUpdateTimeStaysFiveFifteenJST() throws {
        var settings = AppSettings(locale: Locale(identifier: "en"))
        let now = try #require(Calendar.jst.date(from: DateComponents(year: 2026, month: 5, day: 25, hour: 1, minute: 0)))
        settings.recalculateNextRequestedUpdate(after: now)
        let components = Calendar.jst.dateComponents([.hour, .minute], from: settings.nextRequestedUpdate)
        #expect(components.hour == 5)
        #expect(components.minute == 15)
    }

    @Test func missedDuePolicyChoosesForegroundRecoveryAction() throws {
        let due = try jstDateTime(year: 2026, month: 5, day: 25, hour: 5, minute: 15)
        let now = try jstDateTime(year: 2026, month: 5, day: 25, hour: 5, minute: 30)
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.autoUpdateEnabled = true
        settings.nextRequestedUpdate = due

        #expect(AutoUpdateMissedDuePolicy.missedDueDate(settings: settings, now: now) == due)
        #expect(AutoUpdateMissedDuePolicy.recoveryAction(
            autoUpdateEnabled: true,
            dueAt: due,
            now: now,
            startupUpdateScheduled: false,
            widgetLastFetchAt: nil
        ) == .fetchLatest)
        #expect(AutoUpdateMissedDuePolicy.recoveryAction(
            autoUpdateEnabled: true,
            dueAt: due,
            now: now,
            startupUpdateScheduled: true,
            widgetLastFetchAt: nil
        ) == .none)
        #expect(AutoUpdateMissedDuePolicy.recoveryAction(
            autoUpdateEnabled: true,
            dueAt: due,
            now: now,
            startupUpdateScheduled: false,
            widgetLastFetchAt: now
        ) == .importWidget)

        settings.autoUpdateEnabled = false
        #expect(AutoUpdateMissedDuePolicy.missedDueDate(settings: settings, now: now) == nil)
    }

    @Test func missedDuePolicyHandlesBoundaryAndStaleWidgetFetches() throws {
        let due = try jstDateTime(year: 2026, month: 5, day: 25, hour: 5, minute: 15)
        let beforeDue = try jstDateTime(year: 2026, month: 5, day: 25, hour: 5, minute: 14)
        let staleWidgetFetch = try jstDateTime(year: 2026, month: 5, day: 25, hour: 5, minute: 0)
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.autoUpdateEnabled = true
        settings.nextRequestedUpdate = due

        #expect(AutoUpdateMissedDuePolicy.missedDueDate(settings: settings, now: beforeDue) == nil)
        #expect(AutoUpdateMissedDuePolicy.missedDueDate(settings: settings, now: due) == due)
        #expect(AutoUpdateMissedDuePolicy.recoveryAction(
            autoUpdateEnabled: true,
            dueAt: due,
            now: due,
            startupUpdateScheduled: false,
            widgetLastFetchAt: staleWidgetFetch
        ) == .fetchLatest)
        #expect(AutoUpdateMissedDuePolicy.recoveryAction(
            autoUpdateEnabled: true,
            dueAt: due,
            now: due,
            startupUpdateScheduled: false,
            widgetLastFetchAt: due
        ) == .importWidget)
    }

    @Test func backgroundConfigureDefersForegroundStartupSideEffects() throws {
        clearSettingsAndWidgetDefaults()
        let appModel = DamAppModel()
        let due = Date(timeIntervalSinceNow: -60 * 60)
        appModel.settings.autoUpdateEnabled = true
        appModel.settings.updateOnBoot = false
        appModel.settings.nextRequestedUpdate = due

        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)

        #expect(appModel.settings.nextRequestedUpdate == due)
    }

    @Test func foregroundActivationCompletesDeferredStartupOnce() throws {
        clearSettingsAndWidgetDefaults()
        let appModel = DamAppModel()
        let due = Date(timeIntervalSinceNow: -60 * 60)
        appModel.settings.autoUpdateEnabled = true
        appModel.settings.updateOnBoot = false
        appModel.settings.autoUpdateInterval = .oneHour
        appModel.settings.nextRequestedUpdate = due

        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)
        appModel.completeForegroundStartupIfNeeded(reason: "sceneActive")
        let nextAfterForeground = appModel.settings.nextRequestedUpdate
        appModel.completeForegroundStartupIfNeeded(reason: "sceneActiveAgain")

        #expect(nextAfterForeground > due)
        #expect(appModel.settings.nextRequestedUpdate == nextAfterForeground)
    }

    @Test func publishedLimitsMatchAndroid() {
        #expect(DamAppModel.maxHistoricalSearchCount == 16)
        #expect(DamAppModel.maxDebugLogCount == 128)
        #expect(DamAppModel.manualRefreshCooldown == TimeInterval(10 * 60))
        #expect(MlitURLPolicy.maxResponseBytes == 5 * 1024 * 1024)
    }

    @Test func debugSettingsDefaultHiddenAndResetMatchesAndroid() {
        var settings = AppSettings(locale: Locale(identifier: "en"))
        #expect(!settings.debugSettingsVisible)
        #expect(!settings.debugModeEnabled)
        #expect(settings.debugRealtimeDatSelectionMode == .bundled)
        #expect(settings.debugHistoricalDailyDatSelectionMode == .bundled)
        #expect(settings.debugRealtimeDataPeriodAutoAdvanceEnabled)

        settings.debugSettingsVisible = true
        settings.debugModeEnabled = true
        settings.debugSimulateMode = .loadingFailure
        settings.debugRealtimeDatSelectionMode = .userSelected
        settings.debugRealtimeDatFileName = "selected.dat"
        settings.debugHistoricalDailyDatSelectionMode = .latest
        settings.debugHistoricalDailyDatFileName = "daily.dat"
        settings.debugRealtimeDataEndDate = Date()
        settings.debugRealtimeDataPeriodAutoAdvanceEnabled = false

        let reset = settings.resettingDebugSettings()

        #expect(!reset.debugSettingsVisible)
        #expect(!reset.debugModeEnabled)
        #expect(reset.debugSimulateMode == .none)
        #expect(reset.debugRealtimeDatSelectionMode == .bundled)
        #expect(reset.debugRealtimeDatFileName == nil)
        #expect(reset.debugHistoricalDailyDatSelectionMode == .bundled)
        #expect(reset.debugHistoricalDailyDatFileName == nil)
        #expect(reset.debugRealtimeDataEndDate == nil)
        #expect(reset.debugRealtimeDataPeriodAutoAdvanceEnabled)
    }

    @Test func debugRealtimeDataEndDateUpdateDoesNotReenterSettingsMutation() throws {
        let appModel = DamAppModel()
        let date = try jstDateTime(year: 2026, month: 2, day: 22, hour: 5, minute: 20)

        appModel.updateDebugRealtimeDataEndDate(date)

        #expect(appModel.settings.debugRealtimeDataEndDate != nil)
    }

    @Test("Trend color emphasis is applied only to directional changes",
        arguments: [
            (Trend.up, true),
            (Trend.down, true),
            (Trend.flat, false),
            (Trend.unknown, false),
        ])
    func trendColorEmphasisAppliesOnlyToDirectionalChanges(trend: Trend, expected: Bool) {
        #expect(DisplayFormatters.usesTrendColor(trend) == expected)
    }

    @Test("Realtime sidebar trend color is suppressed while selected",
        arguments: [
            (Trend.up, false, true),
            (Trend.down, false, true),
            (Trend.up, true, false),
            (Trend.down, true, false),
            (Trend.flat, false, false),
            (Trend.flat, true, false),
            (Trend.unknown, false, false),
            (Trend.unknown, true, false),
        ])
    func realtimeSidebarTrendColorRespectsSelection(trend: Trend, isSelected: Bool, expected: Bool) {
        #expect(SidebarRealtimeLabel.shouldUseTrendColor(trend, isSelected: isSelected) == expected)
    }

    @Test("Change formatter maps nil, positive, and negative values",
        arguments: [
            (Optional<Float>.none, "--"),
            (Float(1.25), "+1.25"),
            (Float(-3.5), "-3.50"),
        ])
    func changeFormattingUsesMissingTextWhenNil(value: Float?, expected: String) {
        #expect(DisplayFormatters.change(value) == expected)
    }

    @Test func realtimeStatusMenuLinesMatchRealtimeSidebarData() {
        let settings = AppSettings()
        let data = damData(storagePercentage: Float(82.345))
        let lines = RealtimeStatusMenuLines.make(
            data: data,
            damConfig: nil,
            settings: settings,
            damLoadStatus: .success
        )

        #expect(lines.title == DisplayFormatters.localizedDamName(nil))
        let expectedTime = DamCoreJSTSupport.appendingJstSuffix("2026/05/25 05:00", isLocalJst: DisplayFormatters.isJST)
        #expect(lines.detail == "\(expectedTime) 82.35%")
        #expect(lines.timeText == expectedTime)
        #expect(lines.percentText == "82.35%")
        #expect(lines.status == DisplayFormatters.statusText(
            settings: settings,
            percentage: data.storagePercentage,
            isSameura: data.observationStationId == AppSettings.defaultDamId,
            storageVolumeForMessage: data.storageVolumeForMessage
        ))
        #expect(lines.trend == .flat)
    }

    @Test func realtimeStatusMenuLinesUseSameuraFieldsForSameuraDam() {
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.msg80_100 = "sameura"
        settings.msg80_100Ja = "sameura ja"
        settings.otherMsg80_100 = "other"
        settings.otherMsg80_100Ja = "other ja"
        let data = damData(storagePercentage: Float(82.345))
        let lines = RealtimeStatusMenuLines.make(
            data: data,
            damConfig: nil,
            settings: settings,
            damLoadStatus: .success
        )
        #expect(lines.status == "😊 sameura ja")
    }

    @Test func realtimeStatusMenuLinesUseOtherFieldsForNonSameuraDam() {
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.msg80_100 = "sameura"
        settings.msg80_100Ja = "sameura ja"
        settings.otherMsg80_100 = "other"
        settings.otherMsg80_100Ja = "other ja"
        let data = damData(storagePercentage: Float(82.345), observationStationId: "123456789012")
        let lines = RealtimeStatusMenuLines.make(
            data: data,
            damConfig: nil,
            settings: settings,
            damLoadStatus: .success
        )
        #expect(lines.status == "😊 other ja")
    }

    @Test func realtimeStatusMenuLinesUseLoadStateMessagesWithoutData() {
        let settings = AppSettings()
        let lines = RealtimeStatusMenuLines.make(
            data: nil,
            damConfig: nil,
            settings: settings,
            damLoadStatus: .networkUnavailable
        )

        #expect(lines.title == DisplayFormatters.localizedDamName(nil))
        #expect(lines.detail == nil)
        #expect(lines.timeText == nil)
        #expect(lines.percentText == nil)
        #expect(lines.status == settings.networkUnavailableText(isJapanese: AppLocale.isJapanese))
        #expect(lines.trend == .unknown)
    }

    @Test func realtimeStatusMenuLinesHideStatusForPendingLoadStatesWithoutData() {
        let settings = AppSettings()

        for pendingStatus in [DamLoadStatus.initial, .success] {
            let lines = RealtimeStatusMenuLines.make(
                data: nil,
                damConfig: nil,
                settings: settings,
                damLoadStatus: pendingStatus
            )
            #expect(lines.status == nil)
            #expect(lines.detail == nil)
        }

        let failedLines = RealtimeStatusMenuLines.make(
            data: nil,
            damConfig: nil,
            settings: settings,
            damLoadStatus: .loadingFailure
        )
        #expect(failedLines.status == settings.loadingErrorText(isJapanese: AppLocale.isJapanese))
    }

    @Test func summaryCardUnavailableMessageHiddenForPendingLoadStates() {
        let settings = AppSettings()

        #expect(SummaryCard.unavailableMessageText(settings: settings, damLoadStatus: .initial) == nil)
        #expect(SummaryCard.unavailableMessageText(settings: settings, damLoadStatus: .success) == nil)
        #expect(
            SummaryCard.unavailableMessageText(settings: settings, damLoadStatus: .networkUnavailable)
                == settings.networkUnavailableText(isJapanese: AppLocale.isJapanese)
        )
        #expect(
            SummaryCard.unavailableMessageText(settings: settings, damLoadStatus: .loadingFailure)
                == settings.loadingErrorText(isJapanese: AppLocale.isJapanese)
        )
    }

    @Test func realtimeStatusMenuLinesHideStorageMessageWhenDisabled() {
        var settings = AppSettings()
        settings.showStorageRateMessage = false
        let lines = RealtimeStatusMenuLines.make(
            data: damData(storagePercentage: Float(82.345)),
            damConfig: nil,
            settings: settings,
            damLoadStatus: .success
        )

        let expectedTime = DamCoreJSTSupport.appendingJstSuffix("2026/05/25 05:00", isLocalJst: DisplayFormatters.isJST)
        #expect(lines.detail == "\(expectedTime) 82.35%")
        #expect(lines.timeText == expectedTime)
        #expect(lines.percentText == "82.35%")
        #expect(lines.status == nil)
    }

    @Test func damLoadStatusInitialAfterModelCreation() {
        let appModel = DamAppModel()
        #expect(appModel.damLoadStatus == .initial)
    }

    @Test func autoUpdateUserMessageMatchesDisabledAndRunningStates() {
        let appModel = DamAppModel()

        appModel.settings.autoUpdateEnabled = false
        #expect(appModel.autoUpdateUserMessage() == AppText.mainAutorenewDisabled)

        appModel.isAutoUpdateRunning = true
        #expect(appModel.autoUpdateUserMessage() == AppText.mainAutorenewInProgress)
    }

    @Test func autoUpdateUserMessageMatchesAndroidFirstRunAndLastRunFormats() throws {
        let appModel = DamAppModel()
        let next = try jstDateTime(year: 2026, month: 5, day: 26, hour: 5, minute: 15)
        let last = try jstDateTime(year: 2026, month: 5, day: 25, hour: 5, minute: 15)

        appModel.settings.autoUpdateEnabled = true
        appModel.settings.autoUpdateInterval = .oneDay
        appModel.settings.nextRequestedUpdate = next
        appModel.settings.lastAutoUpdate = nil
        #expect(appModel.autoUpdateUserMessage(now: last) == AppText.mainAutorenewEnabledFirst(
            interval: appModel.settings.autoUpdateInterval.localizedLabel,
            next: expectedJSTDateTime(next)
        ))

        appModel.settings.lastAutoUpdate = last
        #expect(appModel.autoUpdateUserMessage(now: next) == AppText.mainAutorenewEnabledWithLast(
            interval: appModel.settings.autoUpdateInterval.localizedLabel,
            last: expectedJSTDateTime(last)
        ))
    }

    @Test func manualUpdateBlockedMessageMatchesAndroidCooldownFormat() throws {
        let appModel = DamAppModel()
        let last = try jstDateTime(year: 2026, month: 5, day: 25, hour: 5, minute: 15)
        let now = try jstDateTime(year: 2026, month: 5, day: 25, hour: 5, minute: 20)
        let next = try #require(Calendar.jst.date(byAdding: .minute, value: 10, to: last))

        appModel.lastFetchTime = last

        #expect(appModel.manualUpdateBlockedMessage(now: now) == AppText.mainRefreshTooEarly(expectedJSTDateTime(next)))
    }

    @Test func manualUpdateBlockedWhenAutoUpdateRunning() throws {
        let appModel = DamAppModel()
        let last = try jstDateTime(year: 2026, month: 5, day: 25, hour: 5, minute: 0)
        let now = try jstDateTime(year: 2026, month: 5, day: 25, hour: 5, minute: 11)
        appModel.lastFetchTime = last
        appModel.isAutoUpdateRunning = true

        #expect(appModel.manualUpdateBlockedMessage(now: now) == AppText.mainAutorenewInProgress)
    }

    @Test func sudmonitorHistoryAutoUpdateUserMessageMatchesRunningStates() {
        let appModel = DamAppModel()
        appModel.settings.autoUpdateEnabled = false

        appModel.isSudmonitorHistoryAutoUpdateRunning = true
        #expect(appModel.sudmonitorHistoryAutoUpdateUserMessage() == AppText.mainAutorenewInProgress)

        appModel.isSudmonitorHistoryAutoUpdateRunning = false
        appModel.isSudmonitorHistoryInitialRunning = true
        #expect(appModel.sudmonitorHistoryAutoUpdateUserMessage() == AppText.mainAutorenewInProgress)

        appModel.isSudmonitorHistoryInitialRunning = false
        appModel.isAutoUpdateRunning = true
        #expect(appModel.sudmonitorHistoryAutoUpdateUserMessage() == AppText.mainAutorenewInProgress)

        appModel.isAutoUpdateRunning = false
        appModel.isSudmonitorHistoryManualRunning = true
        #expect(appModel.sudmonitorHistoryAutoUpdateUserMessage() == AppText.mainManualUpdateInProgress)

        appModel.isSudmonitorHistoryManualRunning = false
        #expect(appModel.sudmonitorHistoryAutoUpdateUserMessage() == AppText.mainAutorenewDisabled)
    }

    @Test func debugCooldownBypassAllowsManualRefreshInDebugMode() throws {
        let appModel = DamAppModel()
        let last = try jstDateTime(year: 2026, month: 5, day: 25, hour: 5, minute: 15)
        let now = try jstDateTime(year: 2026, month: 5, day: 25, hour: 5, minute: 20)
        appModel.lastFetchTime = last
        appModel.settings.debugModeEnabled = true

        #expect(appModel.canRefresh(now: now))
    }

    @Test func canRefreshReturnsTrueWhenCooldownExpired() throws {
        let appModel = DamAppModel()
        let last = try jstDateTime(year: 2026, month: 5, day: 25, hour: 5, minute: 0)
        let now = try jstDateTime(year: 2026, month: 5, day: 25, hour: 5, minute: 11)
        appModel.lastFetchTime = last
        #expect(appModel.canRefresh(now: now))
    }

    @Test func canRefreshReturnsFalseWhenCooldownActive() throws {
        let appModel = DamAppModel()
        let last = try jstDateTime(year: 2026, month: 5, day: 25, hour: 5, minute: 0)
        let now = try jstDateTime(year: 2026, month: 5, day: 25, hour: 5, minute: 9)
        appModel.lastFetchTime = last
        #expect(!appModel.canRefresh(now: now))
    }

    @Test func canRefreshReturnsTrueWhenLastFetchIsDistantPast() throws {
        let appModel = DamAppModel()
        appModel.lastFetchTime = Date.distantPast
        #expect(appModel.canRefresh(now: Date()))
    }

    @Test func canRefreshUsesStoredManualRefreshAvailableAtOverLastFetchFallback() throws {
        let appModel = DamAppModel()
        let last = try jstDateTime(year: 2026, month: 5, day: 25, hour: 5, minute: 0)
        let availableAt = try jstDateTime(year: 2026, month: 5, day: 25, hour: 7, minute: 0)
        appModel.lastFetchTime = last
        appModel.manualRefreshAvailableAt = availableAt

        // lastFetchTime + 10 分(05:10)は過ぎているが、保存済みヘッダー時刻(07:00)が優先される
        #expect(!appModel.canRefresh(now: availableAt.addingTimeInterval(-1)))
        #expect(appModel.canRefresh(now: availableAt))
    }

    @Test func debugCooldownBypassOverridesHeaderBasedCooldownEnd() throws {
        let appModel = DamAppModel()
        let last = try jstDateTime(year: 2026, month: 5, day: 25, hour: 5, minute: 0)
        let availableAt = try jstDateTime(year: 2026, month: 5, day: 25, hour: 7, minute: 0)
        appModel.lastFetchTime = last
        appModel.manualRefreshAvailableAt = availableAt
        appModel.settings.debugModeEnabled = true

        #expect(appModel.canRefresh(now: last))
        #expect(appModel.canRefresh(now: availableAt.addingTimeInterval(-1)))
    }

    @Test func damCoreRawDatBridgeFetchedAtPreserved() throws {
        let archivedFetch = try jstDateTime(year: 2026, month: 5, day: 25, hour: 4, minute: 4)
        let bridge = DamCoreRawDatBridge(stationId: "test", dataUrl: "https://www1.river.go.jp/test", fetchedAt: archivedFetch, rawBytes: Data())
        #expect(bridge.fetchedAt == archivedFetch)
    }

    @Test func statusMessageFormatterSharesWidgetAndNotificationRules() {
        let settings = AppSettings(locale: Locale(identifier: "en"))
        let formatter = DamStatusMessageFormatter(settings: settings, isJapanese: false)
        let data = damData(storagePercentage: Float(82.345))
        let notification = formatter.notificationMessage(data: data, damName: "Sameura Dam")

        #expect(formatter.widgetMessage(data: data) == "\(settings.state80_100) \(settings.msg80_100)")
        #expect(notification.hasPrefix("Sameura Dam"))
        #expect(notification.contains("82.35%"))
        #expect(notification.contains(formatter.widgetMessage(data: data)))
    }

    @Test func notificationRemainsSingleLineAndSnackbarUsesRealtimeSummaryLines() {
        let settings = AppSettings(locale: Locale(identifier: "en"))
        let formatter = DamStatusMessageFormatter(settings: settings, isJapanese: false)
        let data = damData(storagePercentage: Float(82.345))

        let notification = formatter.notificationMessage(data: data, damName: "Sameura Dam")
        #expect(notification.hasPrefix("Sameura Dam"))
        #expect(notification.contains("2026/05/25"))
        #expect(notification.contains("05:00"))
        #expect(notification.contains("82.35%"))
        #expect(notification.contains("→"))
        #expect(!notification.contains("\n"))

        let snackbar = formatter.snackbarMessage(data: data, damName: "Sameura Dam")
        #expect(
            snackbar == [
                "Sameura Dam",
                formatter.dataLine(data: data),
                formatter.widgetMessage(data: data),
            ].joined(separator: "\n")
        )
        #expect(snackbar.split(separator: "\n").count == 3)
    }

    @Test func snackbarOmitsMessageLineWhenStorageRateMessagesAreDisabled() {
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.showStorageRateMessage = false
        let formatter = DamStatusMessageFormatter(settings: settings, isJapanese: false)
        let data = damData(storagePercentage: Float(82.345))

        let snackbar = formatter.snackbarMessage(data: data, damName: "Sameura Dam")

        #expect(
            snackbar == [
                "Sameura Dam",
                formatter.dataLine(data: data),
            ].joined(separator: "\n")
        )
        #expect(snackbar.split(separator: "\n").count == 2)
        #expect(!snackbar.hasSuffix("\n"))
    }

    @Test func snackbarUsesLocalizedJapaneseStateMessageOnThirdLine() {
        let settings = AppSettings(locale: Locale(identifier: "ja"))
        let formatter = DamStatusMessageFormatter(settings: settings, isJapanese: true)
        let data = damData(storagePercentage: Float(82.345))

        let snackbar = formatter.snackbarMessage(data: data, damName: "早明浦ダム")

        #expect(
            snackbar == [
                "早明浦ダム",
                formatter.dataLine(data: data),
                formatter.widgetMessage(data: data),
            ].joined(separator: "\n")
        )
    }

    @Test func notificationAndSnackbarUseOverrideMessage() {
        let settings = AppSettings(locale: Locale(identifier: "en"))
        let formatter = DamStatusMessageFormatter(settings: settings, isJapanese: false)
        let data = damData(storagePercentage: nil)

        #expect(formatter.notificationMessage(data: data, damName: "Dam", overrideMessage: "🥱 resumed") == "Dam 🥱 resumed")
        #expect(formatter.snackbarMessage(data: data, damName: "Dam", overrideMessage: "🥱 resumed") == "Dam 🥱 resumed")
    }

    @Test func notificationAndSnackbarHandleMissingPercentage() {
        let settings = AppSettings(locale: Locale(identifier: "en"))
        let formatter = DamStatusMessageFormatter(settings: settings, isJapanese: false)
        let data = damData(storagePercentage: nil)

        let notification = formatter.notificationMessage(data: data, damName: "Sameura Dam")
        #expect(notification.hasPrefix("Sameura Dam"))
        #expect(notification.contains("-- %"))

        let snackbar = formatter.snackbarMessage(data: data, damName: "Sameura Dam")
        #expect(snackbar.split(separator: "\n").count == 3)
        #expect(snackbar.split(separator: "\n")[0] == "Sameura Dam")
        #expect(snackbar.split(separator: "\n")[1].contains("-- %"))
        #expect(snackbar.split(separator: "\n")[2] == Substring(formatter.widgetMessage(data: data)))
    }

    @Test func snackbarFallbackToUpdatedAtWhenStoragePercentageTimeIsNil() {
        let settings = AppSettings(locale: Locale(identifier: "en"))
        let formatter = DamStatusMessageFormatter(settings: settings, isJapanese: false)
        let data = damData(storagePercentage: Float(50))
        let noStorageTime = DamData(
            observationStationId: data.observationStationId,
            observationStationName: data.observationStationName,
            riverSystemName: data.riverSystemName,
            riverName: data.riverName,
            updatedAt: "2026/05/24 12:30",
            catchmentAverageRainfall: data.catchmentAverageRainfall,
            storageVolume: data.storageVolume,
            storageVolumeForMessage: data.storageVolumeForMessage,
            storageVolumeTrend: data.storageVolumeTrend,
            inflow: data.inflow,
            inflowTrend: data.inflowTrend,
            outflow: data.outflow,
            outflowTrend: data.outflowTrend,
            storagePercentage: data.storagePercentage,
            storagePercentageTrend: data.storagePercentageTrend,
            storagePercentageTime: nil,
            storagePercentageDayChange: data.storagePercentageDayChange,
            storagePercentageDayChangeTrend: data.storagePercentageDayChangeTrend,
            storagePercentageWeekChange: data.storagePercentageWeekChange,
            storagePercentageWeekChangeTrend: data.storagePercentageWeekChangeTrend,
            historicalData: data.historicalData
        )

        let snackbar = formatter.snackbarMessage(data: noStorageTime, damName: "Sameura Dam")
        #expect(snackbar.contains("2026/05/24"))
        #expect(snackbar.contains("12:30"))
    }

    @Test("Trend text maps app trend states to compact symbols",
        arguments: [
            (Trend.up, "↗"),
            (Trend.down, "↘"),
            (Trend.flat, "→"),
            (Trend.unknown, ""),
        ])
    func trendTextMapsCorrectly(trend: Trend, expected: String) {
        #expect(DamStatusMessageFormatter.trendText(trend) == expected)
    }

    @Test func snackbarMessageExcludesMissingTrendWhenUnknown() {
        let settings = AppSettings(locale: Locale(identifier: "en"))
        let formatter = DamStatusMessageFormatter(settings: settings, isJapanese: false)
        let data = damData(storagePercentage: Float(60))
        let unknownTrend = DamData(
            observationStationId: data.observationStationId,
            observationStationName: data.observationStationName,
            riverSystemName: data.riverSystemName,
            riverName: data.riverName,
            updatedAt: data.updatedAt,
            catchmentAverageRainfall: data.catchmentAverageRainfall,
            storageVolume: data.storageVolume,
            storageVolumeForMessage: data.storageVolumeForMessage,
            storageVolumeTrend: data.storageVolumeTrend,
            inflow: data.inflow,
            inflowTrend: data.inflowTrend,
            outflow: data.outflow,
            outflowTrend: data.outflowTrend,
            storagePercentage: data.storagePercentage,
            storagePercentageTrend: .unknown,
            storagePercentageTime: data.storagePercentageTime,
            storagePercentageDayChange: data.storagePercentageDayChange,
            storagePercentageDayChangeTrend: data.storagePercentageDayChangeTrend,
            storagePercentageWeekChange: data.storagePercentageWeekChange,
            storagePercentageWeekChangeTrend: data.storagePercentageWeekChangeTrend,
            historicalData: data.historicalData
        )

        let snackbar = formatter.snackbarMessage(data: unknownTrend, damName: "Sameura Dam")
        #expect(!snackbar.contains(" 60.00%  "))
    }

    @Test("Status formatter uses semantic no-storage states and explicit override messages")
    func statusMessageFormatterUsesAllInvalidAndOverrides() {
        let settings = AppSettings(locale: Locale(identifier: "en"))
        let formatter = DamStatusMessageFormatter(settings: settings, isJapanese: false)
        let allInvalid = damData(storagePercentage: nil)
        let noStorage = damData(storagePercentage: nil, storageVolume: Float(1))

        #expect(formatter.widgetMessage(data: allInvalid) == "\(settings.stateAllDataInvalid) \(settings.msgAllDataInvalid)")
        #expect(formatter.widgetMessage(data: noStorage) == "\(settings.stateAllAbnormal) \(settings.msgAllAbnormal)")
        #expect(formatter.widgetMessage(data: noStorage, overrideMessage: "😪 stopped") == "😪 stopped")
        #expect(formatter.notificationMessage(data: noStorage, damName: "Dam", overrideMessage: "🥱 resumed") == "Dam 🥱 resumed")
    }

    @Test func widgetSnapshotRoundtripsWithDayWeekChangeFields() throws {
        let snapshot = DamCoreWidgetSnapshot(
            damName: "Test Dam",
            updatedAt: "2026/02/22 05:20",
            observedAt: "",
            storagePercentage: Float(82.34),
            trend: "up",
            storageVolume: Float(12345),
            storageVolumeTrend: "flat",
            storagePercentageDayChange: Float(2.3),
            dayChangeTrend: "up",
            storagePercentageWeekChange: Float(17.2),
            weekChangeTrend: "up",
            message: "",
            isNetworkError: false,
            isAllDataInvalid: false,
            lastUpdatedAt: Date()
        )
        let encoded = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(DamCoreWidgetSnapshot.self, from: encoded)
        #expect(decoded.storageVolume == Float(12345))
        #expect(decoded.storageVolumeTrend == "flat")
        #expect(decoded.storagePercentageDayChange == Float(2.3))
        #expect(decoded.dayChangeTrend == "up")
        #expect(decoded.storagePercentageWeekChange == Float(17.2))
        #expect(decoded.weekChangeTrend == "up")
    }

    @Test func manualNextTimingPreservesAnchorForIntervalChange() throws {
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.autoUpdateEnabled = true
        settings.autoUpdateInterval = .oneWeek
        let now = try jstDateTime(year: 2026, month: 6, day: 3, hour: 12, minute: 0)
        let manualNext = try jstDateTime(year: 2026, month: 6, day: 4, hour: 20, minute: 30)
        settings.nextRequestedUpdate = manualNext
        let jstComponents = Calendar.jst.dateComponents([.hour, .minute], from: manualNext)
        if let hour = jstComponents.hour, let minute = jstComponents.minute {
            settings.initialAutoUpdateAnchorMinuteOfDay = hour * 60 + minute
        }

        #expect(settings.initialAutoUpdateAnchorMinuteOfDay == 20 * 60 + 30)

        settings.autoUpdateInterval = .oneDay
        settings.recalculateNextRequestedUpdate(after: now)
        let components = Calendar.jst.dateComponents([.hour, .minute], from: settings.nextRequestedUpdate)
        #expect(components.hour == 20)
        #expect(components.minute == 30)
    }

    @Test func intervalChangeWithoutAnchorDefaultsToFiveFifteenJST() throws {
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.autoUpdateEnabled = true
        let now = try jstDateTime(year: 2026, month: 6, day: 3, hour: 12, minute: 0)
        settings.initialAutoUpdateAnchorMinuteOfDay = nil
        settings.recalculateNextRequestedUpdate(after: now)
        let components = Calendar.jst.dateComponents([.hour, .minute], from: settings.nextRequestedUpdate)
        #expect(components.hour == 5)
        #expect(components.minute == 15)
    }
}

@Suite("Debug data period selection")
@MainActor
struct DebugDataPeriodSelectionTests {
    private let availableDates: [Date]
    private let minDate: Date
    private let maxDate: Date

    init() throws {
        let dates = try [
            jstDateTime(year: 2026, month: 2, day: 22, hour: 1, minute: 0),
            jstDateTime(year: 2026, month: 2, day: 22, hour: 5, minute: 10),
            jstDateTime(year: 2026, month: 2, day: 22, hour: 12, minute: 0),
            jstDateTime(year: 2026, month: 2, day: 23, hour: 0, minute: 0),
        ]
        availableDates = dates
        minDate = dates[0]
        maxDate = dates[3]
    }

    @Test func clampedDateBeforeStartClampsToStart() throws {
        let before = try jstDateTime(year: 2026, month: 2, day: 21, hour: 23, minute: 0)
        #expect(DebugDataPeriodSelection.clampedDate(before, in: availableDates) == minDate)
    }

    @Test func clampedDateAfterEndClampsToEnd() throws {
        let after = try jstDateTime(year: 2026, month: 2, day: 23, hour: 1, minute: 0)
        #expect(DebugDataPeriodSelection.clampedDate(after, in: availableDates) == maxDate)
    }

    @Test func clampedDateOnStartDayBeforeStartTimeClampsToStartTime() throws {
        let candidate = try jstDateTime(year: 2026, month: 2, day: 22, hour: 0, minute: 30)
        #expect(DebugDataPeriodSelection.clampedDate(candidate, in: availableDates) == minDate)
    }

    @Test func clampedDateOnEndDayAfterEndTimeClampsToEndTime() throws {
        let candidate = try jstDateTime(year: 2026, month: 2, day: 23, hour: 0, minute: 30)
        #expect(DebugDataPeriodSelection.clampedDate(candidate, in: availableDates) == maxDate)
    }

    @Test func clampedDateMiddleDayWithinRangeRemainsUnchanged() throws {
        let candidate = try jstDateTime(year: 2026, month: 2, day: 22, hour: 5, minute: 20)
        #expect(DebugDataPeriodSelection.clampedDate(candidate, in: availableDates) == candidate)
    }

    @Test func roundedDateMiddleDayNonObservationTimeRoundsToPreviousObservation() throws {
        let candidate = try jstDateTime(year: 2026, month: 2, day: 22, hour: 8, minute: 30)
        #expect(DebugDataPeriodSelection.roundedDate(candidate, in: availableDates) == availableDates[1])
    }

    @Test func roundedDateExactObservationTimeReturnsSame() {
        let candidate = availableDates[2]
        #expect(DebugDataPeriodSelection.roundedDate(candidate, in: availableDates) == candidate)
    }

    @Test func roundedDateBeforeAllReturnsFirst() throws {
        let candidate = try jstDateTime(year: 2026, month: 2, day: 22, hour: 0, minute: 0)
        #expect(DebugDataPeriodSelection.roundedDate(candidate, in: availableDates) == minDate)
    }

    @Test func roundedDateAfterAllReturnsLast() throws {
        let candidate = try jstDateTime(year: 2026, month: 2, day: 24, hour: 0, minute: 0)
        #expect(DebugDataPeriodSelection.roundedDate(candidate, in: availableDates) == maxDate)
    }

    @Test func periodLabelShowsRangeFormatForMiddleEndDate() {
        let label = DebugDataPeriodSelection.periodLabel(
            start: minDate,
            end: availableDates[1],
            max: maxDate,
            allPeriodLabel: "All"
        )
        let expectedStart = TimeFormatters.jstDisplay.string(from: minDate)
        let expectedEnd = DamCoreJSTSupport.appendingJstSuffix(TimeFormatters.jstDisplay.string(from: availableDates[1]), isLocalJst: DisplayFormatters.isJST)
        #expect(label == "\(expectedStart) - \(expectedEnd)")
    }

    @Test func periodLabelShowsAllWhenEndEqualsMax() {
        let label = DebugDataPeriodSelection.periodLabel(
            start: minDate,
            end: maxDate,
            max: maxDate,
            allPeriodLabel: "All"
        )
        #expect(label == "All")
    }

    @Test func periodLabelShowsAllWhenEndAfterMax() throws {
        let after = try jstDateTime(year: 2026, month: 2, day: 23, hour: 1, minute: 0)
        let label = DebugDataPeriodSelection.periodLabel(
            start: minDate,
            end: after,
            max: maxDate,
            allPeriodLabel: "All"
        )
        #expect(label == "All")
    }

    @Test func periodLabelShowsAllForNilValues() {
        #expect(DebugDataPeriodSelection.periodLabel(start: nil, end: minDate, max: maxDate, allPeriodLabel: "All") == "All")
        #expect(DebugDataPeriodSelection.periodLabel(start: minDate, end: nil, max: maxDate, allPeriodLabel: "All") == "All")
        #expect(DebugDataPeriodSelection.periodLabel(start: minDate, end: minDate, max: nil, allPeriodLabel: "All") == "All")
    }

    @Test func replacingDateKeepsTimeAndUsesNewDatePortion() throws {
        let original = try jstDateTime(year: 2026, month: 2, day: 22, hour: 12, minute: 30)
        let newDate = try jstDateTime(year: 2026, month: 3, day: 1, hour: 5, minute: 0)
        let result = DebugDataPeriodSelection.replacingDate(of: original, with: newDate)
        let expected = try jstDateTime(year: 2026, month: 3, day: 1, hour: 12, minute: 30)
        #expect(result == expected)
    }

    @Test func replacingTimeKeepsDateAndUsesNewTimePortion() throws {
        let original = try jstDateTime(year: 2026, month: 2, day: 22, hour: 12, minute: 30)
        let newTime = try jstDateTime(year: 2026, month: 3, day: 1, hour: 5, minute: 45)
        let result = DebugDataPeriodSelection.replacingTime(of: original, with: newTime)
        let expected = try jstDateTime(year: 2026, month: 2, day: 22, hour: 5, minute: 45)
        #expect(result == expected)
    }
}

@Suite("SwiftData persistence rules", .serialized)
@MainActor
struct SwiftDataPersistenceRuleTests {
    @Test func debugLogsKeepOnlyLatest128Entries() throws {
        let context = try inMemoryModelContext()
        let appModel = DamAppModel()
        appModel.configure(modelContext: context, launchContext: .background)

        let baseTime = Date(timeIntervalSince1970: 10000)
        for index in 0..<130 {
            appModel.addDebugLog(message: "log \(index)", timestamp: baseTime.addingTimeInterval(Double(index)))
        }

        #expect(appModel.debugLogs.count == DamAppModel.maxDebugLogCount)
        #expect(appModel.debugLogs.first?.message == "log 129")
        #expect(!appModel.debugLogs.contains { $0.message == "log 0" })
        #expect(!appModel.debugLogs.contains { $0.message == "log 1" })
    }

    @Test func manualUpdateDebugLogSuccessMatchesAndroid() throws {
        let context = try inMemoryModelContext()
        let appModel = DamAppModel()
        appModel.configure(modelContext: context, launchContext: .background)

        let details = "Dam name: SameuraDam, Data time: 2026-05-25T05:00:00+09:00, Data time (Storage): 2026-05-25T04:50:00+09:00"
        appModel.addDebugLog(message: "Manual update succeeded.", details: details)

        #expect(appModel.debugLogs.count == 1)
        let entry = try #require(appModel.debugLogs.first)
        #expect(entry.message == "Manual update succeeded.")
        #expect(entry.details == details)
    }

    @Test func manualUpdateDebugLogFailureMatchesAndroid() throws {
        let context = try inMemoryModelContext()
        let appModel = DamAppModel()
        appModel.configure(modelContext: context, launchContext: .background)

        appModel.addDebugLog(message: "Manual update failed.", details: "Reason: Network unavailable")

        #expect(appModel.debugLogs.count == 1)
        let entry = try #require(appModel.debugLogs.first)
        #expect(entry.message == "Manual update failed.")
        #expect(entry.details == "Reason: Network unavailable")
    }

    @Test func manualUpdateDebugLogSuccessWithoutStorageTime() throws {
        let context = try inMemoryModelContext()
        let appModel = DamAppModel()
        appModel.configure(modelContext: context, launchContext: .background)

        let details = "Dam name: SameuraDam, Data time: 2026-05-25T05:00:00+09:00"
        appModel.addDebugLog(message: "Manual update succeeded.", details: details)

        let entry = try #require(appModel.debugLogs.first)
        #expect(entry.message == "Manual update succeeded.")
        #expect(entry.details == details)
    }

    @Test func autoUpdateDebugLogSuccessMatchesAndroid() throws {
        let context = try inMemoryModelContext()
        let appModel = DamAppModel()
        appModel.configure(modelContext: context, launchContext: .background)

        let details = "Dam name: Sameura Dam, Data time: 2026-05-25T05:00:00+09:00, Data time (Storage): 2026-05-25T04:50:00+09:00"
        appModel.addDebugLog(message: "Auto update succeeded.", details: details)

        let entry = try #require(appModel.debugLogs.first)
        #expect(entry.message == "Auto update succeeded.")
        #expect(entry.details == details)
    }

    @Test func autoUpdateDebugLogFailureMatchesAndroid() throws {
        let context = try inMemoryModelContext()
        let appModel = DamAppModel()
        appModel.configure(modelContext: context, launchContext: .background)

        appModel.addDebugLog(message: "Auto update failed.", details: "Reason: Network unavailable")

        let entry = try #require(appModel.debugLogs.first)
        #expect(entry.message == "Auto update failed.")
        #expect(entry.details == "Reason: Network unavailable")
    }

    @Test func historicalSearchRejectsDuplicateBeforeFetch() async throws {
        let context = try inMemoryModelContext()
        let dam = try #require(DamListData.dam(id: "1368080700010"))
        context.insert(HistoricalSearchMetaRecord(meta: historicalMeta(dam: dam, start: "20260501", end: "20260502", sortOrder: 0)))
        try context.save()

        let appModel = DamAppModel()
        appModel.configure(modelContext: context, launchContext: .background)
        await appModel.searchHistorical(
            damConfig: dam,
            startDate: try jstDate(year: 2026, month: 5, day: 1),
            endDate: try jstDate(year: 2026, month: 5, day: 2)
        )

        #expect(appModel.errorMessage == AppError.duplicateHistoricalSearch.localizedDescription)
    }

    @Test func historicalSearchRejectsSeventeenthSavedSearchBeforeFetch() async throws {
        let context = try inMemoryModelContext()
        let dam = try #require(DamListData.dam(id: "1368080700010"))
        for index in 0..<DamAppModel.maxHistoricalSearchCount {
            context.insert(HistoricalSearchMetaRecord(meta: historicalMeta(dam: dam, start: "202604\(String(format: "%02d", index + 1))", end: "202604\(String(format: "%02d", index + 1))", sortOrder: index)))
        }
        try context.save()

        let appModel = DamAppModel()
        appModel.configure(modelContext: context, launchContext: .background)
        await appModel.searchHistorical(
            damConfig: dam,
            startDate: try jstDate(year: 2026, month: 5, day: 1),
            endDate: try jstDate(year: 2026, month: 5, day: 2)
        )

        #expect(appModel.errorMessage == AppError.historicalSearchLimitExceeded.localizedDescription)
    }

    @Test func deleteHistoricalRemovesTargetMetaRowsAndClearsSelection() throws {
        let context = try inMemoryModelContext()
        let dam = try #require(DamListData.dam(id: "1368080700010"))
        let deleted = historicalMeta(dam: dam, start: "20260501", end: "20260502", sortOrder: 0)
        let kept = historicalMeta(dam: dam, start: "20260503", end: "20260504", sortOrder: 1)
        context.insert(HistoricalSearchMetaRecord(meta: deleted))
        context.insert(HistoricalSearchMetaRecord(meta: kept))
        context.insert(HistoricalDamDataRecord(searchMetaId: deleted.id, data: historicalRow(time: "2026/05/01 01:00"), timeMillis: 0))
        context.insert(HistoricalDamDataRecord(searchMetaId: kept.id, data: historicalRow(time: "2026/05/03 01:00"), timeMillis: 1))
        try context.save()

        let appModel = DamAppModel()
        appModel.configure(modelContext: context, launchContext: .background)
        appModel.selectedHistoricalMeta = deleted
        appModel.historicalRows = [historicalRow(time: "2026/05/01 01:00")]
        appModel.selectedDetail = .historical(deleted.id)

        appModel.deleteHistorical(metaId: deleted.id)

        let metaIds = try context.fetch(FetchDescriptor<HistoricalSearchMetaRecord>()).map(\.id)
        let rowMetaIds = try context.fetch(FetchDescriptor<HistoricalDamDataRecord>()).map(\.searchMetaId)
        #expect(metaIds == [kept.id])
        #expect(rowMetaIds == [kept.id])
        #expect(appModel.selectedHistoricalMeta == nil)
        #expect(appModel.historicalRows.isEmpty)
        #expect(appModel.selectedDetail == .realtime)
        #expect(appModel.historicalMetaList.map(\.id) == [kept.id])
    }

    @Test func deleteAllHistoricalRemovesAllMetaRowsAndClearsSelection() throws {
        let context = try inMemoryModelContext()
        let dam = try #require(DamListData.dam(id: "1368080700010"))
        let first = historicalMeta(dam: dam, start: "20260501", end: "20260502", sortOrder: 0)
        let second = historicalMeta(dam: dam, start: "20260503", end: "20260504", sortOrder: 1)
        for (index, meta) in [first, second].enumerated() {
            context.insert(HistoricalSearchMetaRecord(meta: meta))
            context.insert(HistoricalDamDataRecord(searchMetaId: meta.id, data: historicalRow(time: "2026/05/0\(index + 1) 01:00"), timeMillis: Double(index)))
        }
        try context.save()

        let appModel = DamAppModel()
        appModel.configure(modelContext: context, launchContext: .background)
        appModel.selectedHistoricalMeta = first
        appModel.historicalRows = [historicalRow(time: "2026/05/01 01:00")]
        appModel.selectedDetail = .historical(first.id)

        appModel.deleteAllHistorical()

        #expect(try context.fetch(FetchDescriptor<HistoricalSearchMetaRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HistoricalDamDataRecord>()).isEmpty)
        #expect(appModel.selectedHistoricalMeta == nil)
        #expect(appModel.historicalRows.isEmpty)
        #expect(appModel.selectedDetail == .realtime)
        #expect(appModel.historicalMetaList.isEmpty)
    }

    @Test func moveHistoricalPersistsSortOrderAndReloadsList() throws {
        let context = try inMemoryModelContext()
        let dam = try #require(DamListData.dam(id: "1368080700010"))
        let first = historicalMeta(dam: dam, start: "20260501", end: "20260501", sortOrder: 0)
        let second = historicalMeta(dam: dam, start: "20260502", end: "20260502", sortOrder: 1)
        let third = historicalMeta(dam: dam, start: "20260503", end: "20260503", sortOrder: 2)
        [first, second, third].forEach { context.insert(HistoricalSearchMetaRecord(meta: $0)) }
        try context.save()

        let appModel = DamAppModel()
        appModel.configure(modelContext: context, launchContext: .background)

        appModel.moveHistorical(from: IndexSet(integer: 0), to: 3)

        #expect(appModel.historicalMetaList.map(\.id) == [second.id, third.id, first.id])
        let records = try context.fetch(FetchDescriptor<HistoricalSearchMetaRecord>())
        #expect(records.first { $0.id == second.id }?.sortOrder == 0)
        #expect(records.first { $0.id == third.id }?.sortOrder == 1)
        #expect(records.first { $0.id == first.id }?.sortOrder == 2)
    }

    @Test func damChangeClearsRealtimeDataAndKeepsHistoricalSearches() throws {
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()
        let oldDam = try #require(DamListData.dam(id: AppSettings.defaultDamId))
        let newDam = try #require(DamListData.allDams.first { $0.id != oldDam.id })
        let realtimeRecord = DamDataRecord(
            encodedData: try JSONEncoder().encode(damData(storagePercentage: Float(55))),
            lastFetchTime: Date(timeIntervalSince1970: 10),
            rawDatBytes: Data("old-dat".utf8)
        )
        context.insert(realtimeRecord)
        let meta = historicalMeta(dam: oldDam, start: "20260501", end: "20260502", sortOrder: 0)
        context.insert(HistoricalSearchMetaRecord(meta: meta))
        context.insert(HistoricalDamDataRecord(searchMetaId: meta.id, data: historicalRow(time: "2026/05/01 01:00"), timeMillis: 0))
        try context.save()

        defaults.set(Data("snapshot".utf8), forKey: WidgetDefaultsKey.snapshotV1)
        defaults.set(Data("app-snapshot".utf8), forKey: WidgetDefaultsKey.appSnapshot)
        defaults.set(Date(timeIntervalSince1970: 20).timeIntervalSinceReferenceDate, forKey: WidgetDefaultsKey.widgetLastFetchAt)

        let appModel = DamAppModel(widgetGroupDefaults: defaults, widgetStandardDefaults: defaults)
        appModel.settings = AppSettings(locale: Locale(identifier: "en"))
        appModel.configure(modelContext: context, launchContext: .background)
        appModel.selectedHistoricalMeta = meta
        appModel.historicalRows = [historicalRow(time: "2026/05/01 01:00")]
        appModel.selectedDetail = .historical(meta.id)

        let didChange = appModel.confirmTargetDamId(newDam.id)

        #expect(didChange)
        #expect(appModel.settings.targetDamId == newDam.id)
        #expect(appModel.settings.lastLoadResultMessage == "")
        #expect(appModel.settings.wasLastDataAllInvalid == false)
        #expect(appModel.damData == nil)
        #expect(appModel.lastFetchTime == nil)
        #expect(appModel.selectedHistoricalMeta == nil)
        #expect(appModel.historicalRows.isEmpty)
        #expect(appModel.selectedDetail == .realtime)
        #expect(try context.fetch(FetchDescriptor<DamDataRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HistoricalSearchMetaRecord>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<HistoricalDamDataRecord>()).count == 1)
        #expect(defaults.string(forKey: WidgetDefaultsKey.stationId) == newDam.id)
        #expect(defaults.string(forKey: WidgetDefaultsKey.dataUrl) == newDam.dataUrl)
        #expect(defaults.data(forKey: WidgetDefaultsKey.snapshotV1) == nil)
        #expect(defaults.data(forKey: WidgetDefaultsKey.appSnapshot) == nil)
        #expect(defaults.object(forKey: WidgetDefaultsKey.widgetLastFetchAt) == nil)
    }

    @Test func damChangeNoopsWhenDamIdIsUnchanged() throws {
        clearSettingsAndWidgetDefaults()
        defer { clearSettingsAndWidgetDefaults() }

        let context = try inMemoryModelContext()
        context.insert(DamDataRecord(
            encodedData: try JSONEncoder().encode(damData(storagePercentage: Float(55))),
            lastFetchTime: Date(timeIntervalSince1970: 10),
            rawDatBytes: Data("old-dat".utf8)
        ))
        try context.save()

        let appModel = DamAppModel()
        appModel.settings = AppSettings(locale: Locale(identifier: "en"))
        appModel.configure(modelContext: context, launchContext: .background)

        let didChange = appModel.confirmTargetDamId(AppSettings.defaultDamId)

        #expect(!didChange)
        #expect(appModel.settings.targetDamId == AppSettings.defaultDamId)
        #expect(try context.fetch(FetchDescriptor<DamDataRecord>()).count == 1)
    }

    @Test func realtimeDatExportFilenameUsesStoredRealtimeDatFileName() throws {
        let context = try inMemoryModelContext()
        context.insert(DamDataRecord(
            encodedData: try JSONEncoder().encode(damData(storagePercentage: Float(55))),
            lastFetchTime: Date(timeIntervalSince1970: 10),
            rawDatBytes: Data("dat".utf8),
            rawDatFileName: "1368080700010_202602220520.dat"
        ))
        try context.save()

        let appModel = DamAppModel()
        appModel.configure(modelContext: context, launchContext: .background)

        #expect(appModel.realtimeDatExportFilename(variant: .raw) == "1368080700010_202602220520.dat")
        #expect(appModel.realtimeDatExportFilename(variant: .utf8) == "1368080700010_202602220520_utf8.dat")
    }

    @Test func historicalDisplayRangeFilterReturnsAllRowsWhenNoFilter() throws {
        let context = try inMemoryModelContext()
        let dam = try #require(DamListData.dam(id: "1368080700010"))
        let meta = historicalMeta(dam: dam, start: "20260501", end: "20260503", sortOrder: 0)
        context.insert(HistoricalSearchMetaRecord(meta: meta))
        let rows = [
            historicalRow(time: "2026/05/01 01:00"),
            historicalRow(time: "2026/05/02 01:00"),
            historicalRow(time: "2026/05/03 01:00"),
        ]
        for row in rows {
            context.insert(HistoricalDamDataRecord(searchMetaId: meta.id, data: row, timeMillis: TimeFormatters.millis(fromDamTime: row.time)))
        }
        try context.save()

        let appModel = DamAppModel()
        appModel.configure(modelContext: context, launchContext: .background)
        appModel.selectedHistoricalMeta = meta
        appModel.historicalRows = rows

        #expect(appModel.visibleHistoricalRows.count == 3)
        #expect(!appModel.isHistoricalDisplayRangeFiltered)
    }

    @Test func historicalDisplayRangeFilterExcludesRowsOutsideRange() throws {
        let context = try inMemoryModelContext()
        let dam = try #require(DamListData.dam(id: "1368080700010"))
        let meta = historicalMeta(dam: dam, start: "20260501", end: "20260503", sortOrder: 0)
        context.insert(HistoricalSearchMetaRecord(meta: meta))
        let rows = [
            historicalRow(time: "2026/05/01 01:00"),
            historicalRow(time: "2026/05/02 01:00"),
            historicalRow(time: "2026/05/03 01:00"),
        ]
        for row in rows {
            context.insert(HistoricalDamDataRecord(searchMetaId: meta.id, data: row, timeMillis: TimeFormatters.millis(fromDamTime: row.time)))
        }
        try context.save()

        let appModel = DamAppModel()
        appModel.configure(modelContext: context, launchContext: .background)
        appModel.selectedHistoricalMeta = meta
        appModel.historicalRows = rows

        appModel.applyHistoricalDisplayRange(startDate: "20260501", endDate: "20260502")

        #expect(appModel.isHistoricalDisplayRangeFiltered)
        #expect(appModel.visibleHistoricalRows.count == 2)
        #expect(appModel.visibleHistoricalRows.contains { $0.time == "2026/05/01 01:00" })
        #expect(appModel.visibleHistoricalRows.contains { $0.time == "2026/05/02 01:00" })
        #expect(!appModel.visibleHistoricalRows.contains { $0.time == "2026/05/03 01:00" })
    }

    @Test func historicalDisplayRangeFilterFullRangeResets() throws {
        let context = try inMemoryModelContext()
        let dam = try #require(DamListData.dam(id: "1368080700010"))
        let meta = historicalMeta(dam: dam, start: "20260501", end: "20260503", sortOrder: 0)
        context.insert(HistoricalSearchMetaRecord(meta: meta))
        let rows = [
            historicalRow(time: "2026/05/01 01:00"),
            historicalRow(time: "2026/05/03 01:00"),
        ]
        for row in rows {
            context.insert(HistoricalDamDataRecord(searchMetaId: meta.id, data: row, timeMillis: TimeFormatters.millis(fromDamTime: row.time)))
        }
        try context.save()

        let appModel = DamAppModel()
        appModel.configure(modelContext: context, launchContext: .background)
        appModel.selectedHistoricalMeta = meta
        appModel.historicalRows = rows

        appModel.applyHistoricalDisplayRange(startDate: "20260502", endDate: "20260503")
        #expect(appModel.isHistoricalDisplayRangeFiltered)

        appModel.applyHistoricalDisplayRange(startDate: "20260501", endDate: "20260503")

        #expect(!appModel.isHistoricalDisplayRangeFiltered)
        #expect(appModel.visibleHistoricalRows.count == 2)
    }

    @Test func historicalDisplayRangeFilterResetRestoresAllRows() throws {
        let context = try inMemoryModelContext()
        let dam = try #require(DamListData.dam(id: "1368080700010"))
        let meta = historicalMeta(dam: dam, start: "20260501", end: "20260503", sortOrder: 0)
        context.insert(HistoricalSearchMetaRecord(meta: meta))
        let rows = [
            historicalRow(time: "2026/05/01 01:00"),
            historicalRow(time: "2026/05/02 01:00"),
            historicalRow(time: "2026/05/03 01:00"),
        ]
        for row in rows {
            context.insert(HistoricalDamDataRecord(searchMetaId: meta.id, data: row, timeMillis: TimeFormatters.millis(fromDamTime: row.time)))
        }
        try context.save()

        let appModel = DamAppModel()
        appModel.configure(modelContext: context, launchContext: .background)
        appModel.selectedHistoricalMeta = meta
        appModel.historicalRows = rows

        appModel.applyHistoricalDisplayRange(startDate: "20260501", endDate: "20260502")
        #expect(appModel.visibleHistoricalRows.count == 2)

        appModel.resetHistoricalDisplayRange()

        #expect(!appModel.isHistoricalDisplayRangeFiltered)
        #expect(appModel.visibleHistoricalRows.count == 3)
    }

    @Test func historicalDisplayRangeFilterIncludesDataAtBoundary() throws {
        let context = try inMemoryModelContext()
        let dam = try #require(DamListData.dam(id: "1368080700010"))
        let meta = historicalMeta(dam: dam, start: "20260501", end: "20260503", sortOrder: 0)
        context.insert(HistoricalSearchMetaRecord(meta: meta))
        let rows = [
            historicalRow(time: "2026/05/01 01:00"),
            historicalRow(time: "2026/05/02 01:00"),
            historicalRow(time: "2026/05/02 24:00"),
            historicalRow(time: "2026/05/03 01:00"),
        ]
        for row in rows {
            context.insert(HistoricalDamDataRecord(searchMetaId: meta.id, data: row, timeMillis: TimeFormatters.millis(fromDamTime: row.time)))
        }
        try context.save()

        let appModel = DamAppModel()
        appModel.configure(modelContext: context, launchContext: .background)
        appModel.selectedHistoricalMeta = meta
        appModel.historicalRows = rows

        appModel.applyHistoricalDisplayRange(startDate: "20260502", endDate: "20260502")

        #expect(appModel.visibleHistoricalRows.count == 2)
        #expect(appModel.visibleHistoricalRows.contains { $0.time == "2026/05/02 01:00" })
        #expect(appModel.visibleHistoricalRows.contains { $0.time == "2026/05/02 24:00" })
        #expect(!appModel.visibleHistoricalRows.contains { $0.time == "2026/05/01 01:00" })
        #expect(!appModel.visibleHistoricalRows.contains { $0.time == "2026/05/03 01:00" })
    }

    @Test func damChangeClearsHistoricalDisplayRangeFilter() throws {
        clearSettingsAndWidgetDefaults()
        defer { clearSettingsAndWidgetDefaults() }

        let context = try inMemoryModelContext()
        let oldDam = try #require(DamListData.dam(id: AppSettings.defaultDamId))
        let newDam = try #require(DamListData.allDams.first { $0.id != oldDam.id })
        let meta = historicalMeta(dam: oldDam, start: "20260501", end: "20260503", sortOrder: 0)
        context.insert(HistoricalSearchMetaRecord(meta: meta))
        try context.save()

        let appModel = DamAppModel()
        appModel.settings = AppSettings(locale: Locale(identifier: "en"))
        appModel.configure(modelContext: context, launchContext: .background)
        appModel.selectedHistoricalMeta = meta
        appModel.historicalRows = [historicalRow(time: "2026/05/01 01:00")]
        appModel.applyHistoricalDisplayRange(startDate: "20260501", endDate: "20260502")
        #expect(appModel.isHistoricalDisplayRangeFiltered)

        appModel.confirmTargetDamId(newDam.id)

        #expect(appModel.selectedHistoricalMeta == nil)
        #expect(appModel.historicalRows.isEmpty)
        #expect(!appModel.isHistoricalDisplayRangeFiltered)
    }
}

@Suite("P2 utility behavior")
@MainActor
struct P2UtilityTests {
    @Test func datExportConvertsShiftJISToUTF8Text() throws {
        let text = "水系名,吉野川\n観測所名,早明浦ダム\n"
        let shiftJIS: Data = try #require(text.data(using: DamCoreTextDecoder.shiftJIS))

        let converted = try DatExportConverter.utf8Data(from: shiftJIS)

        #expect(String(data: converted, encoding: .utf8) == text)
    }

    @Test func datExportThrowsWhenEncodingCannotBeDecoded() {
        #expect(throws: DamCoreTextDecoderError.unsupportedEncoding) {
            _ = try DatExportConverter.utf8Data(from: Data([0x80, 0x81, 0x82]))
        }
    }

    @Test("DAT export filenames preserve Android raw and UTF-8 naming",
        arguments: [
            (DatExportVariant.raw, Optional("1368080700010_202602220520.dat"), "1368080700010_202602220520.dat"),
            (DatExportVariant.utf8, Optional("1368080700010_202602220520.dat"), "1368080700010_202602220520_utf8.dat"),
            (DatExportVariant.raw, Optional<String>.none, "export.dat"),
            (DatExportVariant.utf8, Optional<String>.none, "export_utf8.dat"),
        ])
    func datExportFilenameMatchesAndroidNaming(variant: DatExportVariant, baseName: String?, expected: String) {
        #expect(variant.exportFilename(baseName: baseName) == expected)
    }

    @Test func debugLogExportFilenameMatchesAndroidNaming() {
        let appModel = DamAppModel()
        let filename = appModel.generateDebugLogFileName()
        let range = NSRange(location: 0, length: filename.utf16.count)
        let regex = try! NSRegularExpression(pattern: "^TCSameuraDamMonitor-DebugLog-\\d{8}T\\d{6}_0900\\.csv$")
        #expect(regex.firstMatch(in: filename, options: [], range: range) != nil)
    }

    @Test func chartZoomClampsVisibleLength() {
        let fullLength = ChartZoomCalculator.visibleLength(totalLength: 1_000, rowCount: 100, scale: CGFloat(1))
        let clampedLength = ChartZoomCalculator.visibleLength(totalLength: 1_000, rowCount: 100, scale: CGFloat(100))
        let clampedScale = ChartZoomCalculator.nextScale(currentScale: CGFloat(2), magnification: CGFloat(10))
        #expect(fullLength == 1_000)
        #expect(clampedLength == 120)
        #expect(clampedScale == CGFloat(16))
    }

    @Test func realtimeStorageGraphPast24HoursAddsStartPointFromPreviousHourlyValue() {
        let rows = [
            graphRow("2026/05/18 05:00", storagePercentage: 70),
            graphRow("2026/05/18 05:20"),
            graphRow("2026/05/18 06:00", storagePercentage: 71),
            graphRow("2026/05/19 05:00", storagePercentage: 80),
            graphRow("2026/05/19 05:15"),
        ]

        let result = ObservationGraphCalculator.buildRealtimeStorageGraphDisplayData(rows: rows, range: .past24Hours)

        #expect(result.rows.first?.time == "2026/05/18 05:15")
        #expect(result.rows.first?.storagePercentage == 70)
    }

    @Test func realtimeStorageGraphFillsTrailingPartialHourOnlyWithOtherObservationValues() {
        let rows = [
            graphRow("2026/05/18 05:00", storagePercentage: 70),
            graphRow("2026/05/18 06:00", storagePercentage: 71),
            graphRow("2026/05/19 05:00", storagePercentage: 80),
            graphRow("2026/05/19 05:10", rainfall: 0),
        ]

        let result = ObservationGraphCalculator.buildRealtimeStorageGraphDisplayData(rows: rows, range: .past24Hours)

        #expect(result.rows.last?.time == "2026/05/19 05:10")
        #expect(result.rows.last?.storagePercentage == 80)
    }

    @Test func realtimeStorageGraphKeepsAllMissingMaintenanceRowsMissing() {
        let rows = [
            graphRow("2026/05/18 05:00", rainfall: 0, storagePercentage: 70),
            graphRow("2026/05/19 05:00", rainfall: 0, storagePercentage: 80),
            graphRow("2026/05/19 05:10"),
            graphRow("2026/05/19 05:20"),
        ]

        let result = ObservationGraphCalculator.buildRealtimeStorageGraphDisplayData(rows: rows, range: .past24Hours)

        #expect(result.rows[result.rows.count - 2].storagePercentage == nil)
        #expect(result.rows.last?.storagePercentage == nil)
    }

    @Test func realtimeStorageGraphPast72HoursAddsStartPointFromPreviousHourlyValue() {
        let rows = [
            graphRow("2026/05/15 05:00", storagePercentage: 60),
            graphRow("2026/05/15 05:20"),
            graphRow("2026/05/15 06:00", storagePercentage: 61),
            graphRow("2026/05/18 05:00", storagePercentage: 80),
            graphRow("2026/05/18 05:15"),
        ]

        let result = ObservationGraphCalculator.buildRealtimeStorageGraphDisplayData(rows: rows, range: .past72Hours)

        #expect(result.rows.first?.time == "2026/05/15 05:15")
        #expect(result.rows.first?.storagePercentage == 60)
    }

    @Test func realtimeVolumeFlowGraphPast72HoursFiltersCorrectWindow() {
        let rows = [
            graphRow("2026/05/15 05:20", storageVolume: 100000, inflow: 10, outflow: 9),
            graphRow("2026/05/18 05:00", storageVolume: 100100, inflow: 11, outflow: 10),
            graphRow("2026/05/18 05:20", storageVolume: 100200, inflow: 12, outflow: 11),
        ]

        let result = ObservationGraphCalculator.buildRealtimeGraphDisplayData(rows: rows, range: .past72Hours)

        #expect(result.rows.count == 3)
        #expect(result.rows.first?.time == "2026/05/15 05:20")
    }

    @Test func realtimeGraphScaleValuesUseAllRangeOutsideHistoricalMode() {
        let realtime = ObservationGraphCalculator.realtimeGraphScaleValues(
            allRangeValues: [1, 100],
            selectedRangeValues: [20, 30],
            isHistorical: false
        )
        let historical = ObservationGraphCalculator.realtimeGraphScaleValues(
            allRangeValues: [1, 100],
            selectedRangeValues: [20, 30],
            isHistorical: true
        )

        #expect(realtime == [1, 100])
        #expect(historical == [20, 30])
    }

    @Test func realtimeGraphRangeOptionsRequireEnoughDataPeriod() {
        let shortRows = [
            graphRow("2026/05/19 05:00"),
            graphRow("2026/05/20 05:00"),
        ]
        let longRows = [
            graphRow("2026/05/16 04:50"),
            graphRow("2026/05/20 05:00"),
        ]

        #expect(ObservationGraphCalculator.realtimeGraphRangeOptions(rows: shortRows) == [.all])
        #expect(ObservationGraphCalculator.realtimeGraphRangeOptions(rows: longRows) == [.all, .past72Hours, .past48Hours, .past24Hours])
    }

    @Test func xAxisTickLabelsUseDailyLabelsAndFilterOverlap() throws {
        let start = try jstDateTime(year: 2026, month: 5, day: 20, hour: 0, minute: 10)
        let end = try jstDateTime(year: 2026, month: 5, day: 27, hour: 10, minute: 50)
        let wide = ObservationGraphCalculator.xAxisTickData(start: start, end: end, plotWidth: 800)
        let narrow = ObservationGraphCalculator.xAxisTickData(start: start, end: end, plotWidth: 80)

        #expect(wide.labels.values.contains("05/21"))
        #expect(narrow.labels.count < wide.labels.count)
        #expect(!wide.labels.values.contains { $0.contains("...") || $0.contains("…") })
        #expect(!narrow.labels.values.contains { $0.contains("...") || $0.contains("…") })
        #expect(Set(wide.labels.keys).isSubset(of: Set(wide.tickDates)))
    }

    @Test func xAxisTickLabelsKeepEdgeDateWhenItDoesNotOverlap() throws {
        let start = try jstDateTime(year: 2026, month: 5, day: 20, hour: 0, minute: 0)
        let end = try jstDateTime(year: 2026, month: 5, day: 21, hour: 0, minute: 0)
        let ticks = ObservationGraphCalculator.xAxisTickData(start: start, end: end, plotWidth: 400)

        #expect(ticks.labels[start] == "05/20")
    }

    @Test func xAxisGridLineSegmentsStayInsidePlotArea() throws {
        let start = try jstDateTime(year: 2026, month: 5, day: 20, hour: 0, minute: 10)
        let end = try jstDateTime(year: 2026, month: 5, day: 27, hour: 10, minute: 50)
        let plotFrame = CGRect(x: 20, y: 40, width: 320, height: 180)
        let labelAreaY = plotFrame.maxY + 24

        let segments = ObservationGraphCalculator.xAxisGridLineSegments(
            start: start,
            end: end,
            plotFrame: plotFrame,
            plotWidth: plotFrame.width
        )

        #expect(!segments.isEmpty)
        #expect(segments.allSatisfy { $0.x >= plotFrame.minX && $0.x <= plotFrame.maxX })
        #expect(segments.allSatisfy { $0.minY == plotFrame.minY })
        #expect(segments.allSatisfy { $0.maxY == plotFrame.maxY })
        #expect(segments.allSatisfy { $0.maxY < labelAreaY })
    }

    @Test func verticalPlotLineSegmentStaysInsidePlotArea() throws {
        let start = try jstDateTime(year: 2026, month: 5, day: 20, hour: 0, minute: 0)
        let selected = try jstDateTime(year: 2026, month: 5, day: 20, hour: 12, minute: 0)
        let end = try jstDateTime(year: 2026, month: 5, day: 21, hour: 0, minute: 0)
        let plotFrame = CGRect(x: 10, y: 30, width: 240, height: 160)

        let segment = try #require(ObservationGraphCalculator.verticalPlotLineSegment(
            for: selected,
            start: start,
            end: end,
            plotFrame: plotFrame
        ))

        #expect(segment.x == plotFrame.midX)
        #expect(segment.minY == plotFrame.minY)
        #expect(segment.maxY == plotFrame.maxY)
    }

    @Test func axisTickValuesDoNotExceedPaddedMaximum() {
        let ticks = ObservationGraphCalculator.axisTickValues(maxValue: 209_000)

        #expect(ticks == [0, 50_000, 100_000, 150_000, 200_000])
        #expect(ticks.last ?? 0 <= 209_000)
    }

    @Test("Axis tick labels use rounded nice values",
        arguments: [
            (49_999.999999, 0, "50000"),
            (150_000, 0, "150000"),
            (12.34, 1, "12.3"),
        ])
    func axisTickLabelsUseRoundedNiceValues(value: Double, fractionDigits: Int, expected: String) {
        #expect(ObservationGraphCalculator.axisTickLabel(value, fractionDigits: fractionDigits) == expected)
    }

    @Test func observationHistoryWindowUsesExpectedStep() throws {
        let latest = try #require(Calendar.jst.date(from: DateComponents(year: 2026, month: 5, day: 25, hour: 12, minute: 34)))
        let realtimeInitial = ObservationHistoryWindow.initialDisplayFrom(latest: latest, isHistorical: false)
        let historicalInitial = ObservationHistoryWindow.initialDisplayFrom(latest: latest, isHistorical: true)

        #expect(Calendar.jst.dateComponents([.hour], from: realtimeInitial).hour == 11)
        #expect(Calendar.jst.dateComponents([.hour], from: historicalInitial).hour == 6)
        #expect(Calendar.jst.dateComponents([.minute], from: historicalInitial).minute == 34)

        let searchStart = try #require(Calendar.jst.date(from: DateComponents(year: 2026, month: 5, day: 1)))
        let next = ObservationHistoryWindow.nextDisplayFrom(currentFrom: latest, searchStart: searchStart, isHistorical: true)
        #expect(Calendar.jst.dateComponents([.day], from: next).day == 18)
    }

    @Test func observationHistoryWindowClampsSearchStartAndNextDisplay() throws {
        let oldest = try #require(Calendar.jst.date(from: DateComponents(year: 2026, month: 5, day: 3, hour: 1)))
        let searchStart = ObservationHistoryWindow.searchStartDate(oldest: oldest, searchBgnDate: "20260501")
        #expect(searchStart == oldest)

        let laterSearchStart = ObservationHistoryWindow.searchStartDate(oldest: oldest, searchBgnDate: "20260505")
        #expect(Calendar.jst.dateComponents([.day], from: laterSearchStart).day == 5)

        let current = try #require(Calendar.jst.date(from: DateComponents(year: 2026, month: 5, day: 5, hour: 10)))
        let realtimeNext = ObservationHistoryWindow.nextDisplayFrom(currentFrom: current, searchStart: oldest, isHistorical: false)
        #expect(Calendar.jst.dateComponents([.day], from: realtimeNext).day == 4)

        let clamped = ObservationHistoryWindow.nextDisplayFrom(currentFrom: current, searchStart: oldest, isHistorical: true)
        #expect(clamped == oldest)
    }

    @Test func dashboardRowsSortByJSTDate() {
        let rows = [
            historicalRow(time: "bad-time"),
            historicalRow(time: "2026/05/25 00:30"),
            historicalRow(time: "2026/05/25 01:30")
        ]

        let descending = DashboardRowCache.descending(rows)

        #expect(descending.map(\.row.time) == ["2026/05/25 01:30", "2026/05/25 00:30", "bad-time"])
    }

    @Test func observationHistoryTableRowModelFormatsValues() {
        let row = DamHistoricalData(
            time: "2026/05/25 01:30",
            catchmentAverageRainfall: Float(1.25),
            storagePercentage: Float(51.4),
            storageVolume: Float(85970),
            inflow: Float(33.141),
            outflow: nil
        )
        let model = ObservationHistoryTableRowModel(DatedHistoricalRow(row: row, date: DisplayFormatters.rowDate(row)))

        #expect(model.datetime == "05/25 01:30")
        #expect(model.rainfall == "1.2")
        #expect(model.volume == "85970")
        #expect(model.inflow == "33.14")
        #expect(model.outflow == "--")
        #expect(model.storage == "51.40")
    }

    @Test func observationHistoryTableColumnWidthsExpandToAvailableWidth() {
        let base = ObservationHistoryTableColumnWidths()
        let expanded = base.expanded(to: 900)

        #expect(base.expanded(to: 300) == base)
        #expect(abs(expanded.tableWidth - 900) < 0.001)
        #expect(expanded.datetime > base.datetime)
        #expect(expanded.storage > base.storage)
    }

    @Test func observationHistoryTableColumnWidthsAdjustForFullDisplayWithinFittingRange() {
        let base = ObservationHistoryTableColumnWidths()
        let compact = base.adjustedForFullDisplay(to: 390, minimumFittingTableWidth: 560, maximumTableWidth: 760)
        let portrait = base.adjustedForFullDisplay(to: 600, minimumFittingTableWidth: 560, maximumTableWidth: 760)
        let landscape = base.adjustedForFullDisplay(to: 900, minimumFittingTableWidth: 560, maximumTableWidth: .infinity)

        #expect(compact == base)
        #expect(abs(portrait.tableWidth - 600) < 0.001)
        #expect(portrait.datetime < base.datetime)
        #expect(abs(landscape.tableWidth - 900) < 0.001)
        #expect(landscape.datetime > base.datetime)
        #expect(landscape.storage > base.storage)
    }

    @Test func observationHistoryTableFullDisplayScrollbarReserveIsMacOnly() {
        let base = ObservationHistoryTableColumnWidths()
        let reserve = ObservationHistoryTable.fullDisplayTrailingScrollbarReserve
        let previewSpacing = ObservationHistoryTable.previewBottomControlSpacing
        let bottomScrollbarHeight = ObservationHistoryTable.fullDisplayBottomScrollbarHeight

        #if os(macOS)
        #expect(reserve >= 16)
        #expect(previewSpacing > 0)
        #expect(bottomScrollbarHeight >= 16)
        #expect(base.scrollableWidth(trailingReserve: reserve) == base.scrollableWidth + reserve)
        #expect(base.tableWidth(trailingReserve: reserve) == base.tableWidth + reserve)
        #else
        #expect(reserve == 0)
        #expect(previewSpacing == 0)
        #expect(bottomScrollbarHeight == 0)
        #expect(base.scrollableWidth(trailingReserve: reserve) == base.scrollableWidth)
        #expect(base.tableWidth(trailingReserve: reserve) == base.tableWidth)
        #endif
    }

    @Test func urlPolicyExposesTypedValidationError() throws {
        #expect(try MlitURLPolicy.validatedCoreMLITURL(from: "https://www1.river.go.jp/path").host == "www1.river.go.jp")
        #expect(throws: MlitURLPolicyError.invalidMLITURL) {
            try MlitURLPolicy.validatedCoreMLITURL(from: "https://example.com/path")
        }
    }
}

@Suite("Boot update behavior", .serialized)
struct BootUpdateBehaviorTests {
    @Test("Detects new boot when saved uptime exceeds current uptime")
    func systemUptimeBootDetection() {
        #expect(BootDetector.isNewBoot(currentUptime: 10000, savedUptime: 20000))
    }

    @Test("No boot detected on first launch when saved uptime is zero")
    func systemUptimeNoBootDetectionWhenFirstLaunch() {
        #expect(!BootDetector.isNewBoot(currentUptime: 10000, savedUptime: 0))
    }

    @Test("No boot detected when uptime has increased since last save")
    func systemUptimeNoBootDetectionWhenUptimeIncreases() {
        #expect(!BootDetector.isNewBoot(currentUptime: 30000, savedUptime: 20000))
    }

    @Test("Foreground startup records current uptime in injected widget defaults")
    @MainActor
    func configureWritesCurrentUptimeToInjectedDefaults() throws {
        let defaults = try testDefaults()
        let appModel = DamAppModel(
            networkAvailability: FixedNetworkAvailability(isNetworkAvailable: false),
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults
        )

        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .foreground)

        #expect(defaults.double(forKey: WidgetDefaultsKey.lastKnownSystemUptime) > 0)
    }

    @Test("Foreground configure performs a boot update after a detected reboot")
    @MainActor
    func configureRunsBootUpdateAndWritesWidgetBridgeState() async throws {
        let datURL = "https://www1.river.go.jp/dat/1368080700010_202602220530.dat"
        let datBytes = realtimeDatData(rows: [
            realtimeDatRow("2026/02/22", "05:10", storageVolume: 74000, storagePercentage: 74),
            realtimeDatRow("2026/02/22", "05:20", storageVolume: 75000, storagePercentage: 75),
            realtimeDatRow("2026/02/22", "05:30", storageVolume: 76000, storagePercentage: 76.5),
        ])
        let fetcher = FixtureFetcher(responses: [
            "https://www1.river.go.jp/cgi-bin/DspDamData.exe?ID=1368080700010&KIND=3&PAGE=0": Data(#"<html><body><a href="/dat/1368080700010_202602220530.dat">dat</a></body></html>"#.utf8),
            datURL: datBytes,
        ])
        let defaults = try testDefaults()
        defaults.set(ProcessInfo.processInfo.systemUptime + 1000, forKey: "lastKnownSystemUptime")

        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.updateOnBoot = true
        settings.realtimeDataSource = .mlitDirect
        settings.general.historicalDataSource = .mlitDirect
        SettingsRepository(defaults: defaults).save(settings)

        let context = try inMemoryModelContext()
        let cached = damData(storagePercentage: Float(70))
        context.insert(DamDataRecord(
            encodedData: try JSONEncoder().encode(cached),
            lastFetchTime: Date(timeIntervalSinceNow: -DamAppModel.manualRefreshCooldown - 60),
            rawDatBytes: Data("cached".utf8),
            rawDatFileName: "cached.dat"
        ))
        try context.save()

        let appModel = DamAppModel(
            network: MlitNetworkDataSource(fetcher: fetcher.fetch),
            networkAvailability: FixedNetworkAvailability(isNetworkAvailable: true),
            settingsRepository: SettingsRepository(defaults: defaults),
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults
        )

        appModel.configure(modelContext: context, launchContext: .foreground)
        try await waitUntil {
            appModel.debugLogs.first?.message == "Boot update succeeded."
        }

        #expect(appModel.damData?.updatedAt == "2026/02/22 05:30")
        #expect(appModel.damData?.storagePercentage == Float(76.5))
        #expect(defaults.double(forKey: WidgetDefaultsKey.appBootUpdateDoneAt) > 0)
        #expect(defaults.data(forKey: WidgetDefaultsKey.snapshotV1) != nil)
        let bridgeData = try #require(defaults.data(forKey: WidgetDefaultsKey.rawDatBridgeV1))
        let bridge = try JSONDecoder().decode(DamCoreRawDatBridge.self, from: bridgeData)
        #expect(bridge.rawBytes == datBytes)
        #expect(bridge.rawDatFileName == "1368080700010_202602220530.dat")
        #expect(fetcher.requestedURLs == [
            "https://www1.river.go.jp/cgi-bin/DspDamData.exe?ID=1368080700010&KIND=3&PAGE=0",
            datURL,
        ])
    }
}

@Suite("Fetch latest integration", .serialized)
@MainActor
struct FetchLatestIntegrationTests {
    @Test("fetchLatest success stores parsed data, raw DAT bridge, widget snapshot, and debug log")
    func fetchLatestSuccessStoresDownstreamState() async throws {
        let datURL = "https://www1.river.go.jp/dat/1368080700010_202602220520.dat"
        let datBytes = realtimeDatData(rows: [
            realtimeDatRow("2026/02/22", "05:00", storageVolume: 73000, storagePercentage: 73),
            realtimeDatRow("2026/02/22", "05:10", storageVolume: 74000, storagePercentage: 74),
            realtimeDatRow("2026/02/22", "05:20", storageVolume: 75000, storagePercentage: 75.25),
        ])
        let fetcher = FixtureFetcher(responses: [
            "https://www1.river.go.jp/cgi-bin/DspDamData.exe?ID=1368080700010&KIND=3&PAGE=0": Data(#"<html><body><a href="/dat/1368080700010_202602220520.dat">dat</a></body></html>"#.utf8),
            datURL: datBytes,
        ])
        let defaults = try testDefaults()
        let settingsRepository = SettingsRepository(defaults: defaults)
        let appModel = DamAppModel(
            network: MlitNetworkDataSource(fetcher: fetcher.fetch),
            networkAvailability: FixedNetworkAvailability(isNetworkAvailable: true),
            settingsRepository: settingsRepository,
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults
        )
        let context = try inMemoryModelContext()
        appModel.configure(modelContext: context, launchContext: .background)

        appModel.settings.realtimeDataSource = .mlitDirect
        await appModel.fetchLatest(workType: "Manual update")

        #expect(appModel.damLoadStatus == .success)
        #expect(appModel.errorMessage == nil)
        #expect(appModel.damData?.updatedAt == "2026/02/22 05:20")
        #expect(appModel.damData?.storagePercentage == Float(75.25))
        #expect(appModel.debugLogs.first?.message == "Manual update succeeded.")

        let records = try context.fetch(FetchDescriptor<DamDataRecord>())
        let latest = try #require(records.first)
        #expect(latest.rawDatBytes == datBytes)
        #expect(latest.rawDatFileName == "1368080700010_202602220520.dat")

        let snapshotData = try #require(defaults.data(forKey: WidgetDefaultsKey.snapshotV1))
        let snapshot = try JSONDecoder().decode(DamCoreWidgetSnapshot.self, from: snapshotData)
        #expect(snapshot.damName.contains("早明浦ダム"))
        #expect(snapshot.storagePercentage == Float(75.25))
        #expect(!snapshot.isNetworkError)

        let bridgeData = try #require(defaults.data(forKey: WidgetDefaultsKey.rawDatBridgeV1))
        let bridge = try JSONDecoder().decode(DamCoreRawDatBridge.self, from: bridgeData)
        #expect(bridge.stationId == "1368080700010")
        #expect(bridge.rawBytes == datBytes)
        #expect(bridge.rawDatFileName == "1368080700010_202602220520.dat")
        #expect(fetcher.requestedURLs == [
            "https://www1.river.go.jp/cgi-bin/DspDamData.exe?ID=1368080700010&KIND=3&PAGE=0",
            datURL,
        ])
    }

    @Test("fetchLatest reports network unavailable without performing a fetch")
    func fetchLatestNetworkUnavailableUsesInjectedAvailability() async throws {
        let fetcher = FixtureFetcher(responses: [:])
        let defaults = try testDefaults()
        let appModel = DamAppModel(
            network: MlitNetworkDataSource(fetcher: fetcher.fetch),
            networkAvailability: FixedNetworkAvailability(isNetworkAvailable: false),
            settingsRepository: SettingsRepository(defaults: defaults),
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults
        )
        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)

        await appModel.fetchLatest(workType: "Manual update")

        #expect(appModel.damLoadStatus == .networkUnavailable)
        #expect(
            appModel.updateSnackbarMessage?.contains(
                appModel.settings.networkUnavailableText(isJapanese: AppLocale.isJapanese)
            ) == true
        )
        #expect(appModel.errorMessage == nil)
        #expect(appModel.debugLogs.first?.message == "Manual update failed.")
        #expect(fetcher.requestedURLs.isEmpty)
        #expect(defaults.data(forKey: WidgetDefaultsKey.snapshotV1) != nil)
    }

    @Test("fetchLatest reports loading failure for HTML without DAT link")
    func fetchLatestMalformedHTMLRecordsFailure() async throws {
        let fetcher = FixtureFetcher(responses: [
            "https://www1.river.go.jp/cgi-bin/DspDamData.exe?ID=1368080700010&KIND=3&PAGE=0": Data("<html><body>no dat</body></html>".utf8),
        ])
        let defaults = try testDefaults()
        let appModel = DamAppModel(
            network: MlitNetworkDataSource(fetcher: fetcher.fetch),
            networkAvailability: FixedNetworkAvailability(isNetworkAvailable: true),
            settingsRepository: SettingsRepository(defaults: defaults),
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults
        )
        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)

        appModel.settings.realtimeDataSource = .mlitDirect
        await appModel.fetchLatest(workType: "Manual update")

        #expect(appModel.damLoadStatus == .loadingFailure)
        #expect(
            appModel.updateSnackbarMessage?.contains(
                appModel.settings.loadingErrorText(isJapanese: AppLocale.isJapanese)
            ) == true
        )
        #expect(appModel.errorMessage == nil)
        #expect(appModel.debugLogs.first?.message == "Manual update failed.")
        #expect(fetcher.requestedURLs == [
            "https://www1.river.go.jp/cgi-bin/DspDamData.exe?ID=1368080700010&KIND=3&PAGE=0",
        ])
    }

    @Test("HTTP failure after an available-network check reports a loading failure")
    func fetchLatestHTTPFailureAfterAvailableNetworkUsesLoadingError() async throws {
        let defaults = try testDefaults()
        let appModel = DamAppModel(
            network: MlitNetworkDataSource { _ in
                throw DamCoreMlitURLPolicyError.badHTTPStatus(503)
            },
            networkAvailability: FixedNetworkAvailability(isNetworkAvailable: true),
            settingsRepository: SettingsRepository(defaults: defaults),
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults
        )
        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)

        appModel.settings.realtimeDataSource = .mlitDirect
        await appModel.fetchLatest(workType: "Initial load")

        #expect(appModel.damLoadStatus == .loadingFailure)
        #expect(
            appModel.updateSnackbarMessage?.contains(
                appModel.settings.loadingErrorText(isJapanese: AppLocale.isJapanese)
            ) == true
        )
        #expect(appModel.errorMessage == nil)
        #expect(appModel.debugLogs.first?.message == "Initial load failed.")
    }

    @Test("Timeout after an available-network check reports a loading failure")
    func fetchLatestTimeoutAfterAvailableNetworkUsesLoadingError() async throws {
        let defaults = try testDefaults()
        let appModel = DamAppModel(
            network: MlitNetworkDataSource { _ in
                throw URLError(.timedOut)
            },
            networkAvailability: FixedNetworkAvailability(isNetworkAvailable: true),
            settingsRepository: SettingsRepository(defaults: defaults),
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults
        )
        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)

        appModel.settings.realtimeDataSource = .mlitDirect
        await appModel.fetchLatest(workType: "Manual update")

        #expect(appModel.damLoadStatus == .loadingFailure)
        #expect(
            appModel.updateSnackbarMessage?.contains(
                appModel.settings.loadingErrorText(isJapanese: AppLocale.isJapanese)
            ) == true
        )
        #expect(appModel.errorMessage == nil)
        #expect(appModel.debugLogs.first?.message == "Manual update failed.")
    }

    @Test(
        "Automatic and boot update failures do not emit a Snackbar",
        arguments: ["Auto update (app)", "Boot update"]
    )
    func backgroundStyleFailureDoesNotEmitSnackbar(workType: String) async throws {
        let defaults = try testDefaults()
        let appModel = DamAppModel(
            network: MlitNetworkDataSource { _ in
                throw URLError(.timedOut)
            },
            networkAvailability: FixedNetworkAvailability(isNetworkAvailable: true),
            settingsRepository: SettingsRepository(defaults: defaults),
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults
        )
        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)

        appModel.settings.realtimeDataSource = .mlitDirect
        await appModel.fetchLatest(workType: workType)

        #expect(appModel.damLoadStatus == .loadingFailure)
        #expect(appModel.updateSnackbarMessage == nil)
        #expect(appModel.errorMessage == nil)
        #expect(appModel.settings.lastLoadResultMessage.isEmpty)
        #expect(appModel.debugLogs.first?.message == "\(workType.hasPrefix("Auto update") ? "Auto update" : workType) failed.")
    }

    @Test("sudmonitor fetch uses a single GET, records origin fetched time, and never requests MLIT")
    func sudmonitorSuccessSingleGETRecordsOriginFetchedAt() async throws {
        let sudmonitorURL = "https://sudmonitor.kusugami-lab.net/v1/realtime/1368080700010/latest.dat"
        let datBytes = realtimeDatData(rows: [
            realtimeDatRow("2026/02/22", "05:00", storageVolume: 73000, storagePercentage: 73),
            realtimeDatRow("2026/02/22", "05:10", storageVolume: 74000, storagePercentage: 74),
            realtimeDatRow("2026/02/22", "05:20", storageVolume: 75000, storagePercentage: 75.25),
        ])
        let sudFetcher = HeaderFixtureFetcher(responses: [
            sudmonitorURL: (datBytes, ["X-TCS-Dam-Id": "1368080700010", "X-TCS-Fetched-At": "2026-02-22T05:25:00Z"]),
        ])
        let mlitFetcher = FixtureFetcher(responses: [:])
        let defaults = try testDefaults()
        let appModel = DamAppModel(
            network: MlitNetworkDataSource(fetcher: mlitFetcher.fetch, headerFetcher: sudFetcher.fetch),
            networkAvailability: FixedNetworkAvailability(isNetworkAvailable: true),
            settingsRepository: SettingsRepository(defaults: defaults),
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults
        )
        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)
        appModel.settings.realtimeDataSource = .sudmonitor

        await appModel.fetchLatest(workType: "Manual update")

        #expect(appModel.damLoadStatus == .success)
        #expect(appModel.errorMessage == nil)
        #expect(appModel.damData?.storagePercentage == Float(75.25))
        #expect(sudFetcher.requestedURLs == [sudmonitorURL])
        #expect(mlitFetcher.requestedURLs.isEmpty)
        #expect(appModel.settings.originFetchedAt != nil)
    }

    @Test("sudmonitor response with mismatched X-TCS-Dam-Id is rejected without MLIT fallback")
    func sudmonitorDamIdMismatchRejectedWithoutMlitFallback() async throws {
        let sudmonitorURL = "https://sudmonitor.kusugami-lab.net/v1/realtime/1368080700010/latest.dat"
        let datBytes = realtimeDatData(rows: [
            realtimeDatRow("2026/02/22", "05:20", storageVolume: 75000, storagePercentage: 75.25),
        ])
        let sudFetcher = HeaderFixtureFetcher(responses: [
            sudmonitorURL: (datBytes, ["X-TCS-Dam-Id": "9999999999999"]),
        ])
        let mlitFetcher = FixtureFetcher(responses: [:])
        let defaults = try testDefaults()
        let appModel = DamAppModel(
            network: MlitNetworkDataSource(fetcher: mlitFetcher.fetch, headerFetcher: sudFetcher.fetch),
            networkAvailability: FixedNetworkAvailability(isNetworkAvailable: true),
            settingsRepository: SettingsRepository(defaults: defaults),
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults
        )
        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)
        appModel.settings.realtimeDataSource = .sudmonitor

        await appModel.fetchLatest(workType: "Manual update")

        #expect(appModel.damLoadStatus == .loadingFailure)
        #expect(sudFetcher.requestedURLs == [sudmonitorURL])
        #expect(mlitFetcher.requestedURLs.isEmpty)
    }

    @Test("sudmonitor HTTP failure reports a loading failure and never requests MLIT")
    func sudmonitorHTTPFailureNoMlitFallback() async throws {
        let mlitFetcher = FixtureFetcher(responses: [:])
        let defaults = try testDefaults()
        let appModel = DamAppModel(
            network: MlitNetworkDataSource(fetcher: mlitFetcher.fetch, headerFetcher: { _ in
                throw DamCoreMlitURLPolicyError.badHTTPStatus(404)
            }),
            networkAvailability: FixedNetworkAvailability(isNetworkAvailable: true),
            settingsRepository: SettingsRepository(defaults: defaults),
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults
        )
        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)
        appModel.settings.realtimeDataSource = .sudmonitor

        await appModel.fetchLatest(workType: "Manual update")

        #expect(appModel.damLoadStatus == .loadingFailure)
        #expect(
            appModel.updateSnackbarMessage?.contains(
                appModel.settings.loadingErrorText(isJapanese: AppLocale.isJapanese)
            ) == true
        )
        #expect(mlitFetcher.requestedURLs.isEmpty)
        #expect(!mlitFetcher.requestedURLs.contains { $0.contains("www1.river.go.jp") })
    }

    @Test("sudmonitor transport failure reports a loading failure and never requests MLIT")
    func sudmonitorTransportFailureNoMlitFallback() async throws {
        let sudFetcher = HeaderFixtureFetcher(responses: [:])
        let mlitFetcher = FixtureFetcher(responses: [:])
        let defaults = try testDefaults()
        let appModel = DamAppModel(
            network: MlitNetworkDataSource(fetcher: mlitFetcher.fetch, headerFetcher: sudFetcher.fetch),
            networkAvailability: FixedNetworkAvailability(isNetworkAvailable: true),
            settingsRepository: SettingsRepository(defaults: defaults),
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults
        )
        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)
        appModel.settings.realtimeDataSource = .sudmonitor

        await appModel.fetchLatest(workType: "Manual update")

        #expect(appModel.damLoadStatus == .loadingFailure)
        #expect(!sudFetcher.requestedURLs.contains { $0.contains("www1.river.go.jp") })
        #expect(mlitFetcher.requestedURLs.isEmpty)
    }

    // MARK: - リアルタイム cooldown(X-TCS-Next-Update-At 優先、欠落・MLIT 直接は +10 分)

    @Test("sudmonitor fetch with X-TCS-Next-Update-At uses the header time as the manual refresh cooldown end")
    func sudmonitorFetchStoresHeaderTimeAsManualRefreshCooldownEnd() async throws {
        let sudmonitorURL = "https://sudmonitor.kusugami-lab.net/v1/realtime/1368080700010/latest.dat"
        let datBytes = realtimeDatData(rows: [
            realtimeDatRow("2026/02/22", "05:00", storageVolume: 73000, storagePercentage: 73),
            realtimeDatRow("2026/02/22", "05:10", storageVolume: 74000, storagePercentage: 74),
        ])
        let headerNext = try jstDateTime(year: 2026, month: 2, day: 22, hour: 14, minute: 35)
        let sudFetcher = HeaderFixtureFetcher(responses: [
            sudmonitorURL: (datBytes, [
                "X-TCS-Dam-Id": "1368080700010",
                "X-TCS-Next-Update-At": "2026-02-22T05:35:00Z",
            ]),
        ])
        let mlitFetcher = FixtureFetcher(responses: [:])
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()
        let appModel = DamAppModel(
            network: MlitNetworkDataSource(fetcher: mlitFetcher.fetch, headerFetcher: sudFetcher.fetch),
            networkAvailability: FixedNetworkAvailability(isNetworkAvailable: true),
            settingsRepository: SettingsRepository(defaults: defaults),
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults
        )
        appModel.configure(modelContext: context, launchContext: .background)
        appModel.settings.realtimeDataSource = .sudmonitor

        await appModel.fetchLatest(workType: "Manual update")

        #expect(appModel.damLoadStatus == .success)
        #expect(appModel.manualRefreshAvailableAt == headerNext)
        #expect(!appModel.canRefresh(now: headerNext.addingTimeInterval(-1)))
        #expect(appModel.canRefresh(now: headerNext))
        let record = try #require(try context.fetch(FetchDescriptor<DamDataRecord>()).first)
        #expect(record.manualRefreshAvailableAt == headerNext)
    }

    @Test("sudmonitor fetch without X-TCS-Next-Update-At falls back to fetchedAt + 10 minutes")
    func sudmonitorFetchWithoutHeaderFallsBackToTenMinutes() async throws {
        let sudmonitorURL = "https://sudmonitor.kusugami-lab.net/v1/realtime/1368080700010/latest.dat"
        let datBytes = realtimeDatData(rows: [
            realtimeDatRow("2026/02/22", "05:00", storageVolume: 73000, storagePercentage: 73),
            realtimeDatRow("2026/02/22", "05:10", storageVolume: 74000, storagePercentage: 74),
        ])
        let sudFetcher = HeaderFixtureFetcher(responses: [
            sudmonitorURL: (datBytes, ["X-TCS-Dam-Id": "1368080700010"]),
        ])
        let mlitFetcher = FixtureFetcher(responses: [:])
        let defaults = try testDefaults()
        let appModel = DamAppModel(
            network: MlitNetworkDataSource(fetcher: mlitFetcher.fetch, headerFetcher: sudFetcher.fetch),
            networkAvailability: FixedNetworkAvailability(isNetworkAvailable: true),
            settingsRepository: SettingsRepository(defaults: defaults),
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults
        )
        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)
        appModel.settings.realtimeDataSource = .sudmonitor

        await appModel.fetchLatest(workType: "Manual update")

        #expect(appModel.damLoadStatus == .success)
        let availableAt = try #require(appModel.manualRefreshAvailableAt)
        #expect(abs(availableAt.timeIntervalSinceNow - 600) < 10)
        #expect(!appModel.canRefresh(now: availableAt.addingTimeInterval(-1)))
        #expect(appModel.canRefresh(now: availableAt))
    }

    @Test("MLIT direct fetch keeps the 10-minute cooldown fallback")
    func mlitDirectFetchKeepsTenMinuteCooldownFallback() async throws {
        let datURL = "https://www1.river.go.jp/dat/1368080700010_202602220520.dat"
        let datBytes = realtimeDatData(rows: [
            realtimeDatRow("2026/02/22", "05:00", storageVolume: 73000, storagePercentage: 73),
            realtimeDatRow("2026/02/22", "05:10", storageVolume: 74000, storagePercentage: 74),
        ])
        let fetcher = FixtureFetcher(responses: [
            "https://www1.river.go.jp/cgi-bin/DspDamData.exe?ID=1368080700010&KIND=3&PAGE=0": Data(#"<html><body><a href="/dat/1368080700010_202602220520.dat">dat</a></body></html>"#.utf8),
            datURL: datBytes,
        ])
        let defaults = try testDefaults()
        let appModel = DamAppModel(
            network: MlitNetworkDataSource(fetcher: fetcher.fetch),
            networkAvailability: FixedNetworkAvailability(isNetworkAvailable: true),
            settingsRepository: SettingsRepository(defaults: defaults),
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults
        )
        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)
        appModel.settings.realtimeDataSource = .mlitDirect

        await appModel.fetchLatest(workType: "Manual update")

        #expect(appModel.damLoadStatus == .success)
        let availableAt = try #require(appModel.manualRefreshAvailableAt)
        #expect(abs(availableAt.timeIntervalSinceNow - 600) < 10)
    }
}

@Suite("Widget bridge", .serialized)
@MainActor
struct WidgetBridgeTests {
    @Test func configureSetsAppConfiguredFlagInWidgetDefaults() throws {
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()
        let appModel = DamAppModel(widgetGroupDefaults: defaults, widgetStandardDefaults: defaults)
        appModel.configure(modelContext: context, launchContext: .background)

        #expect(defaults.bool(forKey: WidgetDefaultsKey.appConfigured) == true)
    }

    @Test func configureBridgesDebugSettingsToWidgetDefaults() throws {
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()
        let appModel = DamAppModel(widgetGroupDefaults: defaults, widgetStandardDefaults: defaults)
        appModel.settings.debugModeEnabled = true
        appModel.settings.debugSimulateMode = .networkUnavailable
        appModel.configure(modelContext: context, launchContext: .background)

        #expect(defaults.bool(forKey: WidgetDefaultsKey.debugModeEnabled) == true)
        #expect(defaults.string(forKey: WidgetDefaultsKey.debugSimulateMode) == "networkUnavailable")
    }

    @Test func saveSettingsBridgeWritesRealtimeSourceKeysWithSudmonitorDefault() throws {
        let defaults = try testDefaults()
        let appModel = DamAppModel(
            settingsRepository: SettingsRepository(defaults: defaults),
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults
        )
        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)

        #expect(defaults.string(forKey: WidgetDefaultsKey.realtimeSource) == WidgetDefaultsKey.realtimeSourceSudmonitor)
        #expect(defaults.string(forKey: WidgetDefaultsKey.realtimeDatUrl) == "https://sudmonitor.kusugami-lab.net/v1/realtime/1368080700010/latest.dat")
    }

    @Test func setRealtimeDataSourceSudmonitorForcesSameuraDamAndBridgesSource() throws {
        let defaults = try testDefaults()
        let appModel = DamAppModel(
            settingsRepository: SettingsRepository(defaults: defaults),
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults
        )
        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)
        let alternateDamId = try #require(DamListData.allDams.first(where: { $0.id != AppSettings.defaultDamId })?.id)
        appModel.confirmTargetDamId(alternateDamId)
        #expect(appModel.settings.targetDamId == alternateDamId)
        #expect(appModel.realtimeDataSourceSwitchNeedsDamConfirmation(.sudmonitor))

        appModel.setRealtimeDataSource(.sudmonitor)

        #expect(appModel.settings.realtimeDataSource == .sudmonitor)
        #expect(appModel.settings.targetDamId == AppSettings.defaultDamId)
        #expect(defaults.string(forKey: WidgetDefaultsKey.realtimeSource) == WidgetDefaultsKey.realtimeSourceSudmonitor)
        #expect(defaults.string(forKey: WidgetDefaultsKey.stationId) == AppSettings.defaultDamId)
    }

    @Test func setRealtimeDataSourceMlitDirectKeepsDam() throws {
        let defaults = try testDefaults()
        let appModel = DamAppModel(
            settingsRepository: SettingsRepository(defaults: defaults),
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults
        )
        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)
        appModel.setRealtimeDataSource(.sudmonitor)
        #expect(appModel.settings.targetDamId == AppSettings.defaultDamId)

        appModel.setRealtimeDataSource(.mlitDirect)

        #expect(appModel.settings.realtimeDataSource == .mlitDirect)
        #expect(appModel.settings.targetDamId == AppSettings.defaultDamId)
        #expect(defaults.string(forKey: WidgetDefaultsKey.realtimeSource) == WidgetDefaultsKey.realtimeSourceMlitDirect)
    }

    @Test func widgetLogImportDeduplicatesAndClearsGroupAndStandardQueues() throws {
        let groupDefaults = try testDefaults()
        let standardDefaults = try testDefaults()
        let context = try inMemoryModelContext()
        let appModel = DamAppModel(widgetGroupDefaults: groupDefaults, widgetStandardDefaults: standardDefaults)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000).timeIntervalSinceReferenceDate
        let entry = "\(timestamp);a;Sameura Dam;2026/06/22 01:00;2026/06/22 01:00"
        groupDefaults.set([entry, entry], forKey: WidgetDefaultsKey.fetchLog)
        standardDefaults.set([entry], forKey: WidgetDefaultsKey.fetchLog)

        appModel.configure(modelContext: context, launchContext: .background)

        #expect(groupDefaults.stringArray(forKey: WidgetDefaultsKey.fetchLog) == nil)
        #expect(standardDefaults.stringArray(forKey: WidgetDefaultsKey.fetchLog) == nil)
        let logs = try context.fetch(FetchDescriptor<DebugLogRecord>())
        #expect(logs.count == 1)
        #expect(logs.first?.message == "Auto update (widget) succeeded.")
    }

    @Test func widgetBridgeImportUsesWidgetFetchTimeAndPreservesWidgetNextRequest() async throws {
        let defaults = try testDefaults()
        let settingsRepository = SettingsRepository(defaults: defaults)
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.autoUpdateEnabled = true
        settings.updateOnBoot = false
        settings.autoUpdateInterval = .oneHour
        let fetchTime = try jstDateTime(year: 2030, month: 6, day: 22, hour: 1, minute: 11)
        let widgetNext = try jstDateTime(year: 2030, month: 6, day: 22, hour: 2, minute: 11)
        settings.nextRequestedUpdate = widgetNext
        settingsRepository.save(settings)

        let context = try inMemoryModelContext()
        let oldData = damData(storagePercentage: Float(70))
        context.insert(DamDataRecord(
            encodedData: try JSONEncoder().encode(oldData),
            lastFetchTime: try jstDateTime(year: 2030, month: 6, day: 22, hour: 0, minute: 30),
            rawDatBytes: Data("old".utf8)
        ))
        try context.save()

        let appModel = DamAppModel(
            network: MlitNetworkDataSource(fetcher: FixtureFetcher(responses: [:]).fetch),
            networkAvailability: FixedNetworkAvailability(isNetworkAvailable: true),
            settingsRepository: settingsRepository,
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults
        )
        appModel.configure(modelContext: context, launchContext: .background)

        let datBytes = realtimeDatData(rows: [
            realtimeDatRow("2030/06/22", "01:00", storageVolume: 76000, storagePercentage: 76),
            realtimeDatRow("2030/06/22", "01:10", storageVolume: 77000, storagePercentage: 77),
        ])
        let bridge = DamCoreRawDatBridge(
            stationId: "1368080700010",
            dataUrl: "https://www1.river.go.jp/cgi-bin/DspDamData.exe?ID=1368080700010&KIND=3&PAGE=0",
            fetchedAt: fetchTime,
            rawBytes: datBytes,
            rawDatFileName: "1368080700010_203006220110.dat"
        )
        defaults.set(try JSONEncoder().encode(bridge), forKey: WidgetDefaultsKey.rawDatBridgeV1)
        defaults.set(fetchTime.timeIntervalSinceReferenceDate, forKey: WidgetDefaultsKey.widgetLastFetchAt)
        defaults.set(widgetNext.timeIntervalSinceReferenceDate, forKey: WidgetDefaultsKey.nextRequestedUpdate)

        appModel.completeForegroundStartupIfNeeded(reason: "sceneActive")
        try await waitUntil {
            appModel.lastFetchTime == fetchTime
        }

        #expect(appModel.damData?.updatedAt == "2030/06/22 01:10")
        #expect(appModel.settings.lastAutoUpdate == fetchTime)
        #expect(appModel.settings.nextRequestedUpdate == widgetNext)
        let records = try context.fetch(FetchDescriptor<DamDataRecord>())
        #expect(records.count == 1)
        #expect(records.first?.lastFetchTime == fetchTime)
        let log = try #require(appModel.debugLogs.first)
        #expect(log.message == "Auto update (from widget) succeeded.")
        #expect(log.timestamp == fetchTime)
    }

    @Test func widgetBridgeImportAcceptsSudmonitorDataUrl() async throws {
        let defaults = try testDefaults()
        let settingsRepository = SettingsRepository(defaults: defaults)
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.autoUpdateEnabled = true
        settings.updateOnBoot = false
        settings.realtimeDataSource = .sudmonitor
        let fetchTime = try jstDateTime(year: 2030, month: 6, day: 22, hour: 1, minute: 11)
        let widgetNext = try jstDateTime(year: 2030, month: 6, day: 22, hour: 2, minute: 11)
        settings.nextRequestedUpdate = widgetNext
        settingsRepository.save(settings)

        let context = try inMemoryModelContext()
        let oldData = damData(storagePercentage: Float(70))
        context.insert(DamDataRecord(
            encodedData: try JSONEncoder().encode(oldData),
            lastFetchTime: try jstDateTime(year: 2030, month: 6, day: 22, hour: 0, minute: 30),
            rawDatBytes: Data("old".utf8)
        ))
        try context.save()

        let appModel = DamAppModel(
            network: MlitNetworkDataSource(fetcher: FixtureFetcher(responses: [:]).fetch),
            networkAvailability: FixedNetworkAvailability(isNetworkAvailable: true),
            settingsRepository: settingsRepository,
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults
        )
        appModel.configure(modelContext: context, launchContext: .background)

        let datBytes = realtimeDatData(rows: [
            realtimeDatRow("2030/06/22", "01:00", storageVolume: 76000, storagePercentage: 76),
            realtimeDatRow("2030/06/22", "01:10", storageVolume: 77000, storagePercentage: 77),
        ])
        let bridge = DamCoreRawDatBridge(
            stationId: "1368080700010",
            dataUrl: RealtimeDataSource.sudmonitorLatestDatURL(damId: "1368080700010"),
            fetchedAt: fetchTime,
            nextUpdateAt: widgetNext,
            rawBytes: datBytes,
            rawDatFileName: "latest.dat"
        )
        defaults.set(try JSONEncoder().encode(bridge), forKey: WidgetDefaultsKey.rawDatBridgeV1)
        defaults.set(fetchTime.timeIntervalSinceReferenceDate, forKey: WidgetDefaultsKey.widgetLastFetchAt)
        defaults.set(widgetNext.timeIntervalSinceReferenceDate, forKey: WidgetDefaultsKey.nextRequestedUpdate)

        appModel.completeForegroundStartupIfNeeded(reason: "sceneActive")
        try await waitUntil {
            appModel.lastFetchTime == fetchTime
        }

        #expect(appModel.damData?.updatedAt == "2030/06/22 01:10")
        #expect(appModel.damData?.storagePercentage == Float(77))
        #expect(appModel.settings.lastAutoUpdate == fetchTime)
        #expect(appModel.settings.nextRequestedUpdate == widgetNext)
        let records = try context.fetch(FetchDescriptor<DamDataRecord>())
        #expect(records.count == 1)
        #expect(records.first?.lastFetchTime == fetchTime)
        let log = try #require(appModel.debugLogs.first)
        #expect(log.message == "Auto update (from widget) succeeded.")
    }

    @Test func rawDatBridgeAcceptsBothRealtimeSourceDataUrls() throws {
        let config = try #require(DamListData.dam(id: AppSettings.defaultDamId))
        let otherDam = try #require(DamListData.allDams.first { $0.id != config.id })
        let defaults = try testDefaults()
        let service = WidgetBridgeService(defaults: WidgetBridgeDefaults(
            groupDefaults: defaults,
            standardDefaults: defaults
        ))
        func encodedBridge(dataUrl: String) throws -> Data {
            try JSONEncoder().encode(DamCoreRawDatBridge(
                stationId: config.id,
                dataUrl: dataUrl,
                fetchedAt: Date(timeIntervalSince1970: 100),
                rawBytes: Data("dat".utf8)
            ))
        }

        defaults.set(try encodedBridge(dataUrl: config.dataUrl), forKey: WidgetDefaultsKey.rawDatBridgeV1)
        #expect(service.rawDatBridge(for: config) != nil)

        defaults.set(try encodedBridge(dataUrl: RealtimeDataSource.sudmonitorLatestDatURL(damId: config.id)), forKey: WidgetDefaultsKey.rawDatBridgeV1)
        #expect(service.rawDatBridge(for: config) != nil)

        defaults.set(try encodedBridge(dataUrl: "https://example.com/latest.dat"), forKey: WidgetDefaultsKey.rawDatBridgeV1)
        #expect(service.rawDatBridge(for: config) == nil)

        defaults.set(try encodedBridge(dataUrl: RealtimeDataSource.sudmonitorLatestDatURL(damId: otherDam.id)), forKey: WidgetDefaultsKey.rawDatBridgeV1)
        #expect(service.rawDatBridge(for: config) == nil)
    }

    @Test func widgetBridgeImportSkipsAlreadyImportedBridge() async throws {
        let defaults = try testDefaults()
        let settingsRepository = SettingsRepository(defaults: defaults)
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.autoUpdateEnabled = true
        settings.updateOnBoot = false
        settings.nextRequestedUpdate = try jstDateTime(year: 2030, month: 6, day: 22, hour: 2, minute: 11)
        settingsRepository.save(settings)

        let fetchTime = try jstDateTime(year: 2030, month: 6, day: 22, hour: 1, minute: 11)
        let datBytes = realtimeDatData(rows: [
            realtimeDatRow("2030/06/22", "01:10", storageVolume: 77000, storagePercentage: 77),
        ])
        let context = try inMemoryModelContext()
        context.insert(DamDataRecord(
            encodedData: try JSONEncoder().encode(damData(storagePercentage: Float(77))),
            lastFetchTime: fetchTime,
            rawDatBytes: datBytes
        ))
        context.insert(SudmonitorHistoryRecord(
            damId: "1368080700010",
            periodStartDay: "20260601",
            periodEndDay: "20260630",
            fetchedAt: fetchTime,
            nextUpdateAt: nil,
            rawDatBytes: Data("sample".utf8)
        ))
        try context.save()

        let bridge = DamCoreRawDatBridge(
            stationId: "1368080700010",
            dataUrl: "https://www1.river.go.jp/cgi-bin/DspDamData.exe?ID=1368080700010&KIND=3&PAGE=0",
            fetchedAt: fetchTime,
            rawBytes: datBytes
        )
        defaults.set(try JSONEncoder().encode(bridge), forKey: WidgetDefaultsKey.rawDatBridgeV1)
        defaults.set(fetchTime.timeIntervalSinceReferenceDate, forKey: WidgetDefaultsKey.widgetLastFetchAt)

        let appModel = DamAppModel(
            network: MlitNetworkDataSource(fetcher: FixtureFetcher(responses: [:]).fetch),
            networkAvailability: FixedNetworkAvailability(isNetworkAvailable: true),
            settingsRepository: settingsRepository,
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults
        )
        appModel.configure(modelContext: context, launchContext: .background)
        let logCount = appModel.debugLogs.count

        appModel.completeForegroundStartupIfNeeded(reason: "sceneActive")
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(appModel.debugLogs.count == logCount)
        #expect(try context.fetch(FetchDescriptor<DamDataRecord>()).count == 1)
    }

    @Test("Network unavailable text is composed from configured state and message")
    func networkUnavailableTextContainsStateAndMessage() {
        let settings = AppSettings(locale: Locale(identifier: "en"))
        let text = settings.networkUnavailableText(isJapanese: false)
        #expect(text.hasPrefix(settings.stateNetworkUnavailable))
        #expect(text.contains(settings.msgNetworkUnavailable))
    }

    @Test("Loading error text is composed from configured state and message")
    func loadingErrorTextContainsStateAndMessage() {
        let settings = AppSettings(locale: Locale(identifier: "en"))
        let text = settings.loadingErrorText(isJapanese: false)
        #expect(text.hasPrefix(settings.stateLoadingError))
        #expect(text.contains(settings.msgLoadingError))
    }

    @Test func errorSnapshotDoesNotOverwriteValidExistingSnapshot() async throws {
        let defaults = try testDefaults()
        let validSnapshot = DamCoreWidgetSnapshot(
            damName: "Sameura Dam",
            updatedAt: "2025/01/01 12:00",
            observedAt: "2025/01/01 12:00",
            storagePercentage: Float(82.5),
            trend: "up",
            storageVolume: Float(12345),
            storageVolumeTrend: "flat",
            storagePercentageDayChange: Float(2.3),
            dayChangeTrend: "up",
            storagePercentageWeekChange: Float(17.2),
            weekChangeTrend: "up",
            message: "😊 Plenty of water",
            isNetworkError: false,
            isAllDataInvalid: false,
            lastUpdatedAt: Date()
        )
        let encoded = try JSONEncoder().encode(validSnapshot)
        defaults.set(encoded, forKey: WidgetDefaultsKey.snapshotV1)

        let context = try inMemoryModelContext()
        let appModel = DamAppModel(
            networkAvailability: FixedNetworkAvailability(isNetworkAvailable: false),
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults
        )
        appModel.configure(modelContext: context, launchContext: .background)

        await appModel.fetchLatest(workType: "Manual update")
        #expect(appModel.damLoadStatus == .networkUnavailable)

        let storedData = defaults.data(forKey: WidgetDefaultsKey.snapshotV1)
        let stored = try JSONDecoder().decode(DamCoreWidgetSnapshot.self, from: try #require(storedData))
        #expect(stored.storagePercentage == Float(82.5))
        #expect(stored.isNetworkError == false)
        #expect(stored.damName == "Sameura Dam")
    }

    @Test func errorSnapshotOverwritesExistingErrorSnapshot() async throws {
        let defaults = try testDefaults()
        let oldErrorSnapshot = DamCoreWidgetSnapshot(
            damName: "Sameura Dam",
            updatedAt: "",
            observedAt: "",
            storagePercentage: nil,
            trend: "unknown",
            storageVolume: nil,
            storageVolumeTrend: nil,
            storagePercentageDayChange: nil,
            dayChangeTrend: nil,
            storagePercentageWeekChange: nil,
            weekChangeTrend: nil,
            message: "😢 Old error",
            isNetworkError: true,
            isAllDataInvalid: false,
            lastUpdatedAt: Date()
        )
        let encoded = try JSONEncoder().encode(oldErrorSnapshot)
        defaults.set(encoded, forKey: WidgetDefaultsKey.snapshotV1)

        let context = try inMemoryModelContext()
        let appModel = DamAppModel(
            networkAvailability: FixedNetworkAvailability(isNetworkAvailable: false),
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults
        )
        appModel.configure(modelContext: context, launchContext: .background)

        await appModel.fetchLatest(workType: "Manual update")
        #expect(appModel.damLoadStatus == .networkUnavailable)

        let storedData = defaults.data(forKey: WidgetDefaultsKey.snapshotV1)
        let stored = try JSONDecoder().decode(DamCoreWidgetSnapshot.self, from: try #require(storedData))
        #expect(stored.isNetworkError == true)
    }

    @Test func errorSnapshotSavesWhenNoSnapshotExists() async throws {
        let defaults = try testDefaults()
        let context = try inMemoryModelContext()
        let appModel = DamAppModel(
            networkAvailability: FixedNetworkAvailability(isNetworkAvailable: false),
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults
        )
        appModel.configure(modelContext: context, launchContext: .background)

        await appModel.fetchLatest(workType: "Manual update")
        #expect(appModel.damLoadStatus == .networkUnavailable)

        #expect(defaults.data(forKey: WidgetDefaultsKey.snapshotV1) != nil)
        #expect(defaults.data(forKey: WidgetDefaultsKey.appSnapshot) != nil)
    }

    @Test func widgetMessageFirstWordIsStateEmoji() {
        let settings = AppSettings(locale: Locale(identifier: "en"))
        let formatter = DamStatusMessageFormatter(settings: settings, isJapanese: false)
        let data = damData(storagePercentage: Float(82.345))

        let message = formatter.widgetMessage(data: data)
        let firstWord = message.components(separatedBy: " ").first

        #expect(firstWord == "😊")
        #expect(message.hasPrefix("😊 "))
        #expect(!message.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    @Test func widgetMessageForNilPercentageContainsStateEmoji() {
        let settings = AppSettings(locale: Locale(identifier: "en"))
        let formatter = DamStatusMessageFormatter(settings: settings, isJapanese: false)
        let allInvalid = damData(storagePercentage: nil)

        let message = formatter.widgetMessage(data: allInvalid)
        let firstWord = message.components(separatedBy: " ").first

        #expect(firstWord == "😴")
        #expect(message.hasPrefix("😴 "))
    }

    @Test func initialMessageHasStateEmojiPrefix() {
        let settings = AppSettings(locale: Locale(identifier: "en"))

        let enMessage = settings.initialMessageText(isJapanese: false)
        #expect(enMessage.hasPrefix("🥺 "))
        #expect(enMessage.components(separatedBy: " ").first == "🥺")

        let jaMessage = settings.initialMessageText(isJapanese: true)
        #expect(jaMessage.hasPrefix("🥺 "))
        #expect(jaMessage.components(separatedBy: " ").first == "🥺")
    }

    @Test func accessoryWidgetMessageFormatMatchesSpec() {
        let settings = AppSettings(locale: Locale(identifier: "en"))
        let formatter = DamStatusMessageFormatter(settings: settings, isJapanese: false)
        let data = damData(storagePercentage: Float(74.5))

        let message = formatter.widgetMessage(data: data)
        let stateEmoji = message.components(separatedBy: " ").first ?? ""
        let trendChar = DamStatusMessageFormatter.trendText(data.storagePercentageTrend)

        #expect(!stateEmoji.isEmpty)
        #expect(trendChar == "→")
    }

}

@Suite("Time formatters")
@MainActor
struct TimeFormattersTests {
    @Test("24:00 normalizes to next day 00:00")
    func normalizeDamTimeConverts2400ToNextDay() {
        #expect(TimeFormatters.normalizeDamTime("2026/05/15 24:00") == "2026/05/16 00:00")
    }

    @Test("Normal times are preserved as-is")
    func normalizeDamTimePreservesNormalTimes() {
        #expect(TimeFormatters.normalizeDamTime("2026/05/15 12:30") == "2026/05/15 12:30")
        #expect(TimeFormatters.normalizeDamTime("2026/05/15 00:00") == "2026/05/15 00:00")
        #expect(TimeFormatters.normalizeDamTime("2026/02/21 24:00") == "2026/02/22 00:00")
    }

    @Test("Milliseconds from valid dam time returns positive value")
    func millisFromDamTimeReturnsEpochMillis() {
        let millis = TimeFormatters.millis(fromDamTime: "2026/05/15 00:00")
        #expect(millis > 0)
    }

    @Test("Milliseconds from dam time with 24:00 normalizes correctly")
    func millisFromDamTimeNormalizes2400() {
        let millis = TimeFormatters.millis(fromDamTime: "2026/05/15 24:00")
        #expect(millis > 0)
    }

    @Test("Milliseconds from invalid time returns NaN")
    func millisFromDamTimeReturnsNaNForInvalidTime() {
        let millis = TimeFormatters.millis(fromDamTime: "invalid")
        #expect(millis.isNaN)
    }

    @Test("Milliseconds from empty string returns NaN")
    func millisFromDamTimeReturnsNaNForEmptyString() {
        let millis = TimeFormatters.millis(fromDamTime: "")
        #expect(millis.isNaN)
    }

    @Test("ISO 8601 conversion formats dam time correctly")
    func toIso8601ConvertsDamTime() {
        let iso = TimeFormatters.toIso8601("2026/05/15 12:30")
        #expect(iso == "2026-05-15T12:30:00+09:00")
    }

    @Test("ISO 8601 conversion returns original for invalid time")
    func toIso8601ReturnsOriginalForInvalidTime() {
        #expect(TimeFormatters.toIso8601("invalid") == "invalid")
    }

    @Test("millisIfValid returns nil for invalid time")
    func millisIfValidReturnsNilForInvalidTime() {
        #expect(TimeFormatters.millisIfValid(fromDamTime: "invalid") == nil)
    }
}

@Suite("Chart zoom calculator boundary")
@MainActor
struct ChartZoomCalculatorBoundaryTests {
    @Test("Visible length returns total when row count is below 12-row threshold")
    func visibleLengthReturnsTotalWhenRowCountBelowThreshold() {
        let result = ChartZoomCalculator.visibleLength(totalLength: 1_000, rowCount: 10, scale: CGFloat(2))
        #expect(result == 1_000)
    }

    @Test("Visible length returns total when row count equals threshold")
    func visibleLengthReturnsTotalWhenRowCountEqualsThreshold() {
        let result = ChartZoomCalculator.visibleLength(totalLength: 1_000, rowCount: 12, scale: CGFloat(2))
        #expect(result == 1_000)
    }

    @Test("Visible length returns total when scale is zero")
    func visibleLengthReturnsTotalWhenScaleIsZero() {
        let result = ChartZoomCalculator.visibleLength(totalLength: 1_000, rowCount: 100, scale: CGFloat(0))
        #expect(result == 1_000)
    }

    @Test("Visible length returns total when total length is zero")
    func visibleLengthReturnsTotalWhenTotalLengthIsZero() {
        let result = ChartZoomCalculator.visibleLength(totalLength: 0, rowCount: 100, scale: CGFloat(2))
        #expect(result == 0)
    }

    @Test("Visible length returns total when total length is negative")
    func visibleLengthReturnsTotalWhenTotalLengthIsNegative() {
        let result = ChartZoomCalculator.visibleLength(totalLength: -1, rowCount: 100, scale: CGFloat(2))
        #expect(result == 0)
    }

    @Test("Next scale clamps between 1 and 16")
    func nextScaleClampsBetween1And16() {
        #expect(ChartZoomCalculator.nextScale(currentScale: CGFloat(0.5), magnification: CGFloat(10)) == 5)
        #expect(ChartZoomCalculator.nextScale(currentScale: CGFloat(2), magnification: CGFloat(10)) == 16)
        #expect(ChartZoomCalculator.nextScale(currentScale: CGFloat(2), magnification: CGFloat(0.1)) == 1)
    }

    @Test("Next scale handles zero current scale")
    func nextScaleHandlesZeroCurrentScale() {
        #expect(ChartZoomCalculator.nextScale(currentScale: CGFloat(0), magnification: CGFloat(2)) == 1)
    }
}

@Suite("Observation graph calculator edge cases")
@MainActor
struct ObservationGraphCalculatorEdgeCaseTests {
    @Test("Realtime storage graph handles empty rows")
    func realtimeStorageGraphHandlesEmptyRows() {
        let result = ObservationGraphCalculator.buildRealtimeStorageGraphDisplayData(rows: [], range: .past24Hours)
        #expect(result.rows.isEmpty)
    }

    @Test("Realtime graph display handles empty rows")
    func realtimeGraphDisplayHandlesEmptyRows() {
        let result = ObservationGraphCalculator.buildRealtimeGraphDisplayData(rows: [], range: .past24Hours)
        #expect(result.rows.isEmpty)
    }

    @Test("Range options returns only all for empty rows")
    func realtimeGraphRangeOptionsReturnsOnlyAllForEmptyRows() {
        let result = ObservationGraphCalculator.realtimeGraphRangeOptions(rows: [])
        #expect(result == [.all])
    }

    @Test("Realtime storage graph handles single row")
    func realtimeStorageGraphHandlesSingleRow() {
        let rows = [graphRow("2026/05/19 05:00", storagePercentage: 80)]
        let result = ObservationGraphCalculator.buildRealtimeStorageGraphDisplayData(rows: rows, range: .all)
        #expect(result.rows.count == 1)
        #expect(result.rows.first?.storagePercentage == 80)
    }

    @Test("Realtime storage graph handles all-nil storage percentage rows")
    func realtimeStorageGraphHandlesAllNilStoragePercentage() {
        let rows = [
            graphRow("2026/05/18 05:00"),
            graphRow("2026/05/19 05:00"),
            graphRow("2026/05/19 05:20"),
        ]
        let result = ObservationGraphCalculator.buildRealtimeStorageGraphDisplayData(rows: rows, range: .all)
        #expect(result.rows.allSatisfy { $0.storagePercentage == nil })
    }

    @Test("Rainfall axis max uses default 10 for small values")
    func rainfallAxisMaxUsesDefaultWhenValuesAreSmall() {
        let result = ObservationGraphCalculator.rainfallAxisMax(values: [1, 2, 3])
        #expect(result == 10)
    }

    @Test("Rainfall axis max uses default for empty array")
    func rainfallAxisMaxHandlesEmptyArray() {
        let result = ObservationGraphCalculator.rainfallAxisMax(values: [])
        #expect(result == 10)
    }

    @Test("Padded max returns 1 for empty values")
    func paddedMaxHandlesEmptyValues() {
        let result = ObservationGraphCalculator.paddedMax(values: [])
        #expect(result == 1)
    }

    @Test("Padded max returns 1 for zero values")
    func paddedMaxHandlesZeroValues() {
        let result = ObservationGraphCalculator.paddedMax(values: [0, 0])
        #expect(result > 0)
    }

    @Test("Compute nice step returns 1 for zero range")
    func computeNiceStepHandlesZeroRange() {
        #expect(ObservationGraphCalculator.computeNiceStep(range: 0) == 1)
    }

    @Test("Axis tick values returns 0 and 1 for zero max")
    func axisTickValuesHandlesZeroMax() {
        #expect(ObservationGraphCalculator.axisTickValues(maxValue: 0) == [0, 1])
    }

    @Test("Axis tick values returns 0 and 1 for negative max")
    func axisTickValuesHandlesNegativeMax() {
        #expect(ObservationGraphCalculator.axisTickValues(maxValue: -5) == [0, 1])
    }

    @Test("Chart height satisfies minimum")
    func chartHeightSatisfiesMinimum() {
        #expect(ObservationGraphCalculator.chartHeight(for: 100) == 250)
    }

    @Test("Chart height scales proportionally for wide views")
    func chartHeightScalesProportionally() {
        #expect(ObservationGraphCalculator.chartHeight(for: 600) == 300)
    }

    @Test("Chart height limits extra-wide views")
    func chartHeightLimitsExtraWideViews() {
        #expect(ObservationGraphCalculator.chartHeight(for: 1_200) == 420)
    }

    @Test("Chart layout width prefers measured plot width")
    func chartLayoutWidthPrefersMeasuredPlotWidth() {
        #expect(ObservationGraphCalculator.chartLayoutWidth(plotWidth: 800, containerWidth: 1_000) == 800)
    }

    @Test("Chart layout width falls back to container width")
    func chartLayoutWidthFallsBackToContainerWidth() {
        #expect(ObservationGraphCalculator.chartLayoutWidth(plotWidth: 0, containerWidth: 700) == 700)
    }

    @Test("Chart height uses measured plot width")
    func chartHeightUsesMeasuredPlotWidth() {
        #expect(ObservationGraphCalculator.chartHeight(plotWidth: 800, containerWidth: 1_000) == 400)
    }

    @Test("Chart height caps measured plot width")
    func chartHeightCapsMeasuredPlotWidth() {
        #expect(ObservationGraphCalculator.chartHeight(plotWidth: 1_200, containerWidth: 1_400) == 420)
    }

    @Test("Chart height uses container width before plot width is measured")
    func chartHeightUsesContainerWidthBeforePlotWidthIsMeasured() {
        #expect(ObservationGraphCalculator.chartHeight(plotWidth: 0, containerWidth: 700) == 350)
    }

    @Test("Chart height caps container fallback width")
    func chartHeightCapsContainerFallbackWidth() {
        #expect(ObservationGraphCalculator.chartHeight(plotWidth: 0, containerWidth: 1_200) == 420)
    }

    @Test("Chart Y scale upper bound keeps macOS top-edge values inside the plot area")
    func chartYScaleUpperBoundMatchesPlatformBehavior() {
        #if os(macOS)
        #expect(ObservationGraphCalculator.chartYScaleUpperBound == ObservationGraphCalculator.chartScaleMaximum + ObservationGraphCalculator.macOSChartScaleTopPadding)
        #else
        #expect(ObservationGraphCalculator.chartYScaleUpperBound == ObservationGraphCalculator.chartScaleMaximum)
        #endif
    }

    @Test("Y position calculation follows the platform chart scale upper bound")
    func yPositionUsesPlatformChartScaleUpperBound() {
        let plotFrame = CGRect(x: 0, y: 10, width: 100, height: 100)
        let y = ObservationGraphCalculator.yPosition(forScaledValue: ObservationGraphCalculator.chartScaleMaximum, in: plotFrame)

        #if os(macOS)
        #expect(y > plotFrame.minY)
        #else
        #expect(y == plotFrame.minY)
        #endif
    }

    @Test("Graph domain prefers the window range when both bounds are present")
    func graphDomainPrefersWindowRange() throws {
        let start = try #require(Calendar.jst.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 1)))
        let end = try #require(Calendar.jst.date(from: DateComponents(year: 2026, month: 6, day: 9, hour: 1)))
        let domain = ObservationGraphCalculator.graphDomain(
            start: start,
            end: end,
            firstDate: start.addingTimeInterval(60),
            lastDate: end.addingTimeInterval(-60)
        )
        #expect(domain == start...end)
    }

    @Test("Graph domain falls back to the row range when the window is nil")
    func graphDomainFallsBackToRowRange() throws {
        let first = try #require(Calendar.jst.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 1)))
        let last = try #require(Calendar.jst.date(from: DateComponents(year: 2026, month: 6, day: 9, hour: 1)))
        let domain = ObservationGraphCalculator.graphDomain(start: nil, end: nil, firstDate: first, lastDate: last)
        #expect(domain == first...last)
    }

    @Test("Graph domain returns nil when the row range is empty or reversed")
    func graphDomainReturnsNilForInvalidRowRange() throws {
        let first = try #require(Calendar.jst.date(from: DateComponents(year: 2026, month: 6, day: 9, hour: 1)))
        let last = try #require(Calendar.jst.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 1)))
        #expect(ObservationGraphCalculator.graphDomain(start: nil, end: nil, firstDate: first, lastDate: last) == nil)
        #expect(ObservationGraphCalculator.graphDomain(start: nil, end: nil, firstDate: first, lastDate: first) == nil)
    }

    @Test("Graph domain returns nil when no bound is available")
    func graphDomainReturnsNilForEmptyInputs() {
        #expect(ObservationGraphCalculator.graphDomain(start: nil, end: nil, firstDate: nil, lastDate: nil) == nil)
    }

    @Test("Graph domain resolves the 24:00-derived date as next day 00:00")
    func graphDomainHandles2400DerivedDates() throws {
        let midnightDate = try #require(ObservationGraphCalculator.date(fromDamTime: "2026/06/08 24:00"))
        let expected = try #require(Calendar.jst.date(from: DateComponents(year: 2026, month: 6, day: 9, hour: 0, minute: 0)))
        #expect(midnightDate == expected)
        let first = try #require(ObservationGraphCalculator.date(fromDamTime: "2026/06/07 24:00"))
        let domain = ObservationGraphCalculator.graphDomain(start: nil, end: nil, firstDate: first, lastDate: midnightDate)
        #expect(domain == first...midnightDate)
    }

    @Test("Graph domain reproduces the previous axisRange rule from display data")
    func graphDomainReproducesPreviousAxisRangeRule() {
        let rows = [
            graphRow("2026/06/07 24:00", rainfall: 0, storagePercentage: 80),
            graphRow("2026/06/08 01:00", rainfall: 1, storagePercentage: 79),
            graphRow("2026/06/08 04:00"),
            graphRow("2026/06/08 05:00", rainfall: 0, storagePercentage: 78),
        ]
        for range in [RealtimeGraphRange.past24Hours, .all] {
            let display = ObservationGraphCalculator.buildRealtimeStorageGraphDisplayData(rows: rows, range: range)
            let firstDate = display.rows.first.flatMap { ObservationGraphCalculator.date(fromDamTime: $0.time) }
            let lastDate = display.rows.last.flatMap { ObservationGraphCalculator.date(fromDamTime: $0.time) }
            let domain = ObservationGraphCalculator.graphDomain(
                start: display.windowStart,
                end: display.windowEnd,
                firstDate: firstDate,
                lastDate: lastDate
            )
            let previous: ClosedRange<Date>?
            if let start = display.windowStart, let end = display.windowEnd {
                previous = start...end
            } else if let first = firstDate, let last = lastDate, last > first {
                previous = first...last
            } else {
                previous = nil
            }
            #expect(domain == previous)
        }
    }

    @Test("Graph domain stays nil for empty display data under the previous axisRange rule")
    func graphDomainStaysNilForEmptyDisplayData() {
        let display = ObservationGraphCalculator.buildRealtimeStorageGraphDisplayData(rows: [], range: .all)
        let firstDate = display.rows.first.flatMap { ObservationGraphCalculator.date(fromDamTime: $0.time) }
        let lastDate = display.rows.last.flatMap { ObservationGraphCalculator.date(fromDamTime: $0.time) }
        let domain = ObservationGraphCalculator.graphDomain(
            start: display.windowStart,
            end: display.windowEnd,
            firstDate: firstDate,
            lastDate: lastDate
        )
        let previous: ClosedRange<Date>?
        if let start = display.windowStart, let end = display.windowEnd {
            previous = start...end
        } else if let first = firstDate, let last = lastDate, last > first {
            previous = first...last
        } else {
            previous = nil
        }
        #expect(domain == nil)
        #expect(domain == previous)
    }
}

@Suite("Observation graph nearest index")
@MainActor
struct ObservationGraphNearestIndexTests {
    /// 指定件数の1時間刻みの日時配列を生成します。
    private func hourlyTimestamps(_ count: Int) throws -> [Date] {
        let start = try jstDateTime(year: 2026, month: 6, day: 1, hour: 0, minute: 0)
        return (0..<count).map { start.addingTimeInterval(TimeInterval($0 * 3600)) }
    }

    @Test("Nearest index returns nil for an empty array")
    func nearestIndexEmpty() throws {
        #expect(ObservationGraphCalculator.nearestIndex(in: [], to: Date()) == nil)
    }

    @Test("Nearest index clamps to the first element before the first timestamp")
    func nearestIndexBeforeFirst() throws {
        let timestamps = try hourlyTimestamps(3)
        let before = try jstDateTime(year: 2026, month: 6, day: 1, hour: 0, minute: 0)
            .addingTimeInterval(-3600)
        #expect(ObservationGraphCalculator.nearestIndex(in: timestamps, to: before) == 0)
    }

    @Test("Nearest index clamps to the last element after the last timestamp")
    func nearestIndexAfterLast() throws {
        let timestamps = try hourlyTimestamps(3)
        let after = try jstDateTime(year: 2026, month: 6, day: 1, hour: 2, minute: 0)
            .addingTimeInterval(3600)
        #expect(ObservationGraphCalculator.nearestIndex(in: timestamps, to: after) == timestamps.count - 1)
    }

    @Test("Nearest index finds an exact hit")
    func nearestIndexExactHit() throws {
        let timestamps = try hourlyTimestamps(5)
        let target = try jstDateTime(year: 2026, month: 6, day: 1, hour: 2, minute: 0)
        #expect(ObservationGraphCalculator.nearestIndex(in: timestamps, to: target) == 2)
    }

    @Test("Nearest index prefers the earlier element on an equidistant tie")
    func nearestIndexEquidistantTiePrefersEarlier() throws {
        let timestamps = try hourlyTimestamps(2)
        let between = try jstDateTime(year: 2026, month: 6, day: 1, hour: 0, minute: 30)
        #expect(ObservationGraphCalculator.nearestIndex(in: timestamps, to: between) == 0)
    }

    @Test("Nearest index prefers the earliest occurrence for duplicate timestamps")
    func nearestIndexDuplicateTimestampsPreferEarliest() throws {
        let first = try jstDateTime(year: 2026, month: 6, day: 1, hour: 0, minute: 0)
        let next = try jstDateTime(year: 2026, month: 6, day: 1, hour: 1, minute: 0)
        let timestamps = [first, first, next]
        #expect(ObservationGraphCalculator.nearestIndex(in: timestamps, to: first) == 0)
    }

    @Test("Same-index guard limits state writes to distinct index transitions over 10,000 pointer inputs")
    func sameIndexGuardLimitsStateWrites() throws {
        let timestamps = try hourlyTimestamps(600)
        var inputs: [Date] = []
        for index in 0..<10_000 {
            // 同一hourへ7回ずつ留まりながら循環するwalk(分オフセットは30分未満でhour内に収まる)。
            let hour = (index / 7) % 600
            inputs.append(timestamps[hour].addingTimeInterval(TimeInterval(index % 30) * 60))
        }
        var selectedIndex: Int?
        var stateChangeCount = 0
        var indexChangeCount = 0
        var previousIndex: Int?
        for date in inputs {
            let index = ObservationGraphCalculator.nearestIndex(in: timestamps, to: date)
            if index != previousIndex { indexChangeCount += 1 }
            previousIndex = index
            if index != selectedIndex {
                selectedIndex = index
                stateChangeCount += 1
            }
        }
        #expect(stateChangeCount <= indexChangeCount)
        #expect(stateChangeCount == indexChangeCount)
        #expect(stateChangeCount < 10_000)
    }

    @Test("Repeated identical pointer dates produce zero state writes once selected")
    func repeatedIdenticalDatesProduceZeroWrites() throws {
        let timestamps = try hourlyTimestamps(24)
        let target = try jstDateTime(year: 2026, month: 6, day: 1, hour: 5, minute: 0)
        let index = try #require(ObservationGraphCalculator.nearestIndex(in: timestamps, to: target))
        var selectedIndex: Int? = index
        var stateChangeCount = 0
        for _ in 0..<10_000 {
            let resolved = ObservationGraphCalculator.nearestIndex(in: timestamps, to: target)
            if resolved != selectedIndex {
                selectedIndex = resolved
                stateChangeCount += 1
            }
        }
        #expect(stateChangeCount == 0)
    }
}

@Suite("Settings repository")
@MainActor
struct SettingsRepositoryTests {
    @Test("Load returns new settings when no stored data exists")
    func loadReturnsNewSettingsWhenNoData() {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = SettingsRepository(defaults: defaults)
        let settings = repository.load()
        #expect(!settings.debugSettingsVisible)
        #expect(!settings.targetDamId.isEmpty)
    }

    @Test("Save and load roundtrip preserves settings")
    func saveAndLoadRoundtrip() {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = SettingsRepository(defaults: defaults)
        var settings = repository.load()
        settings.debugSettingsVisible = true
        settings.msg80_100 = "custom message"
        repository.save(settings)
        let loaded = repository.load()
        #expect(loaded.debugSettingsVisible == true)
        #expect(loaded.msg80_100 == "custom message")
    }

    @Test("Save writes nested v2 settings and ignores v1 data")
    func saveWritesNestedV2SettingsAndIgnoresV1Data() throws {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data(#"{"targetDamId":"old","debugSettingsVisible":true}"#.utf8), forKey: "app.settings.v1")
        let repository = SettingsRepository(defaults: defaults)
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.targetDamId = "1368080700100"
        settings.debugSettingsVisible = true
        settings.msg80_100 = "custom nested"

        repository.save(settings)

        #expect(defaults.data(forKey: "app.settings.v1") != nil)
        let v2Data = try #require(defaults.data(forKey: "app.settings.v2"))
        let object = try #require(JSONSerialization.jsonObject(with: v2Data) as? [String: Any])
        #expect(object["general"] != nil)
        #expect(object["messages"] != nil)
        #expect(object["targetDamId"] == nil)
        let loaded = repository.load()
        #expect(loaded.targetDamId == "1368080700100")
        #expect(loaded.msg80_100 == "custom nested")
    }

    @Test("Load returns fresh settings for outdated data")
    func loadReturnsFreshSettingsForOutdatedData() {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let oldData = """
        {"targetDamId":"1368080700010","autoUpdateEnabled":false,"showStorageRateMessage":true,"debugSettingsVisible":false,"debugModeEnabled":false}
        """.data(using: .utf8)!
        defaults.set(oldData, forKey: "app.settings.v1")
        let repository = SettingsRepository(defaults: defaults)
        let settings = repository.load()
        #expect(settings.state80_100 == "😊")
        #expect(settings.targetDamId == AppSettings.defaultDamId)
    }

    @Test("Load returns fresh settings for corrupted stored data")
    func loadReturnsFreshSettingsForCorruptedData() {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data("not json".utf8), forKey: "app.settings.v1")
        let repository = SettingsRepository(defaults: defaults)

        let settings = repository.load()

        #expect(settings.targetDamId == AppSettings.defaultDamId)
        #expect(!settings.debugSettingsVisible)
    }

    @Test("Load returns fresh settings for missing required keys")
    func loadReturnsFreshSettingsForMissingRequiredKeys() throws {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.msg80_100 = "Plenty of water"
        settings.msg60_80 = "Stable"
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any])
        object.removeValue(forKey: "showNotification")
        object.removeValue(forKey: "stateAllDataInvalid")
        defaults.set(try JSONSerialization.data(withJSONObject: object), forKey: "app.settings.v1")
        let repository = SettingsRepository(defaults: defaults)

        let loaded = repository.load()

        #expect(!loaded.showNotification)
        #expect(loaded.stateAllDataInvalid == "😴")
        #expect(loaded.msg80_100 == AppSettings(locale: Locale(identifier: "en")).msg80_100)
    }

    @Test("Legacy v2 payload without realtimeDataSource decodes to sudmonitor default and preserves values")
    func legacyV2WithoutRealtimeDataSourceDecodesToSudmonitorDefault() throws {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.targetDamId = "1368080700100"
        settings.msg80_100 = "legacy custom"
        settings.showNotification = true
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any])
        var general = try #require(object["general"] as? [String: Any])
        general.removeValue(forKey: "realtimeDataSource")
        object["general"] = general
        defaults.set(try JSONSerialization.data(withJSONObject: object), forKey: "app.settings.v2")

        let loaded = SettingsRepository(defaults: defaults).load()

        #expect(loaded.realtimeDataSource == .sudmonitor)
        #expect(loaded.general.realtimeDataSource == nil)
        #expect(loaded.targetDamId == "1368080700100")
        #expect(loaded.msg80_100 == "legacy custom")
        #expect(loaded.showNotification == true)
    }

    @Test("realtimeDataSource sudmonitor survives save/load roundtrip")
    func realtimeDataSourceSudmonitorRoundtrip() {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = SettingsRepository(defaults: defaults)
        var settings = repository.load()
        settings.realtimeDataSource = .sudmonitor
        repository.save(settings)

        let loaded = repository.load()

        #expect(loaded.realtimeDataSource == .sudmonitor)
        #expect(loaded.general.realtimeDataSource == .sudmonitor)
    }

    @Test("historicalDataSource defaults to sudmonitor")
    func historicalDataSourceDefaultIsSudmonitor() {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = SettingsRepository(defaults: defaults)

        let settings = repository.load()

        #expect(settings.historicalDataSource == .sudmonitor)
        #expect(settings.general.historicalDataSource == nil)
    }

    @Test("historicalDataSource mlitDirect survives save/load roundtrip")
    func historicalDataSourceRoundtrip() {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = SettingsRepository(defaults: defaults)
        var settings = repository.load()
        settings.general.historicalDataSource = .mlitDirect
        repository.save(settings)

        let loaded = repository.load()

        #expect(loaded.historicalDataSource == .mlitDirect)
        #expect(loaded.general.historicalDataSource == .mlitDirect)
    }

    @Test("Legacy v2 payload without menuBarResidencyMode decodes to notResident default and preserves values")
    func legacyV2WithoutMenuBarResidencyModeDecodesToNotResidentDefault() throws {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var settings = AppSettings(locale: Locale(identifier: "en"))
        settings.targetDamId = "1368080700100"
        settings.msg80_100 = "legacy custom"
        settings.showNotification = true
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any])
        var general = try #require(object["general"] as? [String: Any])
        general.removeValue(forKey: "menuBarResidencyMode")
        object["general"] = general
        defaults.set(try JSONSerialization.data(withJSONObject: object), forKey: "app.settings.v2")

        let loaded = SettingsRepository(defaults: defaults).load()

        #expect(loaded.menuBarResidencyMode == .notResident)
        #expect(loaded.general.menuBarResidencyMode == nil)
        #expect(loaded.general.effectiveMenuBarResidencyMode == .notResident)
        #expect(loaded.targetDamId == "1368080700100")
        #expect(loaded.msg80_100 == "legacy custom")
        #expect(loaded.showNotification == true)
    }

    @Test("menuBarResidencyMode 3 values survive save/load roundtrip")
    func menuBarResidencyModeRoundtrip() {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = SettingsRepository(defaults: defaults)
        for mode in MenuBarResidencyMode.allCases {
            var settings = repository.load()
            settings.menuBarResidencyMode = mode
            repository.save(settings)

            let loaded = repository.load()

            #expect(loaded.menuBarResidencyMode == mode)
            #expect(loaded.general.menuBarResidencyMode == mode)
        }
    }

    @Test("effectiveMenuBarResidencyMode resolves nil to notResident")
    func effectiveMenuBarResidencyModeResolvesNilToNotResident() {
        var general = AppSettingsGeneral(
            theme: .system,
            showNotification: false,
            targetDamId: AppSettings.defaultDamId,
            realtimeDataSource: nil
        )
        #expect(general.menuBarResidencyMode == nil)
        #expect(general.effectiveMenuBarResidencyMode == .notResident)
        for mode in MenuBarResidencyMode.allCases {
            general.menuBarResidencyMode = mode
            #expect(general.effectiveMenuBarResidencyMode == mode)
        }
    }

    @Test("AppSettings menuBarResidencyMode accessor delegates to general")
    func appSettingsMenuBarResidencyModeDelegatesToGeneral() {
        var settings = AppSettings(locale: Locale(identifier: "en"))
        #expect(settings.menuBarResidencyMode == .notResident)
        #expect(settings.general.menuBarResidencyMode == nil)

        settings.menuBarResidencyMode = .residentHidden
        #expect(settings.general.menuBarResidencyMode == .residentHidden)
        #expect(settings.menuBarResidencyMode == .residentHidden)

        settings.general.menuBarResidencyMode = .residentVisible
        #expect(settings.menuBarResidencyMode == .residentVisible)

        settings.general.menuBarResidencyMode = nil
        #expect(settings.menuBarResidencyMode == .notResident)
    }

    @Test("MenuBarResidencyMode localizedLabel is non-empty")
    func menuBarResidencyModeLocalizedLabelIsNonEmpty() {
        for mode in MenuBarResidencyMode.allCases {
            #expect(!mode.localizedLabel.isEmpty)
        }
    }
}

@Suite("Historical asset store")
@MainActor
struct HistoricalAssetStoreTests {
    @Test("canCover requires continuous local historical asset coverage")
    func canCoverRequiresContinuousCoverage() {
        let store = HistoricalAssetStore(entries: [
            historicalEntry(start: "202601010100", end: "202601012400", filePath: "day1.dat"),
            historicalEntry(start: "202601020100", end: "202601022400", filePath: "day2.dat"),
            historicalEntry(start: "202601040100", end: "202601042400", filePath: "day4.dat"),
        ])

        #expect(store.canCover(stationId: "1368080700010", startDate: "20260101", endDate: "20260102"))
        #expect(!store.canCover(stationId: "1368080700010", startDate: "20260101", endDate: "20260104"))
        #expect(!store.canCover(stationId: "other", startDate: "20260101", endDate: "20260102"))
    }

    @Test("load merges overlapping files, filters requested range, and deduplicates by time")
    func loadMergesFiltersAndDeduplicatesRows() throws {
        let first = historicalEntry(start: "202601010100", end: "202601022400", filePath: "first.dat")
        let second = historicalEntry(start: "202601020100", end: "202601032400", filePath: "second.dat")
        let dataByPath: [String: Data] = [
            first.filePath: historicalDatData(rows: [
                realtimeDatRow("2026/01/01", "23:50", storageVolume: 10100, storagePercentage: 11),
                realtimeDatRow("2026/01/02", "00:10", storageVolume: 10200, storagePercentage: 12),
                realtimeDatRow("2026/01/02", "00:20", storageVolume: 10300, storagePercentage: 13),
            ]),
            second.filePath: historicalDatData(rows: [
                realtimeDatRow("2026/01/02", "00:20", storageVolume: 20300, storagePercentage: 23),
                realtimeDatRow("2026/01/03", "00:10", storageVolume: 30400, storagePercentage: 34),
                realtimeDatRow("2026/01/04", "00:10", storageVolume: 40500, storagePercentage: 45),
            ]),
        ]
        let store = HistoricalAssetStore(entries: [first, second]) { entry in
            dataByPath[entry.filePath]
        }
        let dam = try #require(DamListData.dam(id: "1368080700010"))

        let (meta, rows) = try store.load(damConfig: dam, startDate: "20260102", endDate: "20260103")

        #expect(meta.searchBgnDate == "20260102")
        #expect(meta.searchEndDate == "20260103")
        #expect(meta.dataStartTimeStr == "2026/01/02 00:10")
        #expect(meta.dataEndTimeStr == "2026/01/03 00:10")
        #expect(meta.dataMinStoragePct == Float(12))
        #expect(meta.dataMaxStoragePct == Float(34))
        #expect(rows.map(\.time) == [
            "2026/01/02 00:10",
            "2026/01/02 00:20",
            "2026/01/03 00:10",
        ])
        #expect(rows.first(where: { $0.time == "2026/01/02 00:20" })?.storagePercentage == Float(23))
    }
}

@MainActor
@Suite("Auto update next selection policy")
struct AutoUpdateNextSelectionPolicyTests {
    @Test func minimumValidDateIs15MinutesFromNow() {
        let now = Date(timeIntervalSince1970: 1000000)
        let minDate = AutoUpdateNextSelectionPolicy.minimumValidDate(now: now)
        #expect(minDate.timeIntervalSince(now) >= 15 * 60)
    }

    @Test func isInvalidWhenSelectedDateEqualsMinimum() {
        let now = Date(timeIntervalSince1970: 1000000)
        let selected = AutoUpdateNextSelectionPolicy.minimumValidDate(now: now)
        #expect(AutoUpdateNextSelectionPolicy.isInvalidSelection(selectedDate: selected, now: now))
    }

    @Test func isInvalidWhenSelectedDateBeforeMinimum() {
        let now = Date(timeIntervalSince1970: 1000000)
        let selected = Date(timeIntervalSince1970: 1000000)
        #expect(AutoUpdateNextSelectionPolicy.isInvalidSelection(selectedDate: selected, now: now))
    }

    @Test func isValidWhenSelectedDateAfterMinimum() {
        let now = Date(timeIntervalSince1970: 1000000)
        let selected = Date(timeIntervalSince1970: 1000000 + 16 * 60)
        #expect(!AutoUpdateNextSelectionPolicy.isInvalidSelection(selectedDate: selected, now: now))
    }
}

@MainActor
@Suite("Historical search date policy")
struct HistoricalSearchDatePolicyTests {
    @Test func tooOldWhenStartBefore20020601() {
        let start = Calendar.jst.date(from: DateComponents(year: 2002, month: 5, day: 31))!
        let end = Calendar.jst.date(from: DateComponents(year: 2002, month: 6, day: 10))!
        let now = Calendar.jst.date(from: DateComponents(year: 2026, month: 6, day: 10))!
        let error = HistoricalSearchDatePolicy.validate(start: start, end: end, existingSearches: [], damId: "test", now: now)
        #expect(error == .tooOld)
    }

    @Test func dateRangeWhenStartAfterEnd() {
        let start = Calendar.jst.date(from: DateComponents(year: 2026, month: 5, day: 20))!
        let end = Calendar.jst.date(from: DateComponents(year: 2026, month: 5, day: 10))!
        let error = HistoricalSearchDatePolicy.validate(start: start, end: end, existingSearches: [], damId: "test", now: Date())
        #expect(error == .dateRange)
    }

    @Test func todayWhenEndEqualsToday() {
        let now = Date()
        let start = Calendar.jst.date(byAdding: .day, value: -5, to: now)!
        let today = Calendar.jst.startOfDay(for: now)
        let error = HistoricalSearchDatePolicy.validate(start: start, end: today, existingSearches: [], damId: "test", now: now)
        #expect(error == .today)
    }

    @Test func tooLongWhenRangeExceedsMaxDays() {
        let start = Calendar.jst.date(from: DateComponents(year: 2026, month: 5, day: 1))!
        let end = Calendar.jst.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        let now = Calendar.jst.date(from: DateComponents(year: 2026, month: 6, day: 10))!
        let error = HistoricalSearchDatePolicy.validate(start: start, end: end, existingSearches: [], damId: "test", now: now)
        #expect(error == .tooLong)
    }

    @Test func duplicateWhenSameRangeExists() {
        let start = Calendar.jst.date(from: DateComponents(year: 2026, month: 5, day: 10))!
        let end = Calendar.jst.date(from: DateComponents(year: 2026, month: 5, day: 15))!
        let now = Calendar.jst.date(from: DateComponents(year: 2026, month: 6, day: 10))!
        let existing = [(damConfigId: "test", searchBgnDate: "20260510", searchEndDate: "20260515")]
        let error = HistoricalSearchDatePolicy.validate(start: start, end: end, existingSearches: existing, damId: "test", now: now)
        #expect(error == .duplicate)
    }

    @Test func validWhenAllConditionsMet() {
        let start = Calendar.jst.date(from: DateComponents(year: 2026, month: 5, day: 10))!
        let end = Calendar.jst.date(from: DateComponents(year: 2026, month: 5, day: 15))!
        let now = Calendar.jst.date(from: DateComponents(year: 2026, month: 6, day: 10))!
        let error = HistoricalSearchDatePolicy.validate(start: start, end: end, existingSearches: [], damId: "test", now: now)
        #expect(error == nil)
    }

    @Test func sudmonitorHistoryLoadedWhenIdenticalToLoadedDailyRange() {
        let start = Calendar.jst.date(from: DateComponents(year: 2026, month: 7, day: 1))!
        let end = Calendar.jst.date(from: DateComponents(year: 2026, month: 7, day: 31))!
        let now = Calendar.jst.date(from: DateComponents(year: 2026, month: 8, day: 10))!
        let loaded = (start: "20260701", end: "20260731")
        let error = HistoricalSearchDatePolicy.validate(
            start: start, end: end, existingSearches: [], damId: "test", now: now,
            loadedDailyHistory: loaded
        )
        #expect(error == .sudmonitorHistoryLoaded)
    }

    @Test func subsetSupersetAndPartialOverlapOfLoadedDailyRangeAreAllowed() {
        let now = Calendar.jst.date(from: DateComponents(year: 2026, month: 8, day: 10))!
        let loaded = (start: "20260710", end: "20260720")

        // 真部分集合
        let subsetStart = Calendar.jst.date(from: DateComponents(year: 2026, month: 7, day: 12))!
        let subsetEnd = Calendar.jst.date(from: DateComponents(year: 2026, month: 7, day: 18))!
        #expect(HistoricalSearchDatePolicy.validate(
            start: subsetStart, end: subsetEnd, existingSearches: [], damId: "test", now: now,
            loadedDailyHistory: loaded
        ) == nil)

        // 上位集合
        let supersetStart = Calendar.jst.date(from: DateComponents(year: 2026, month: 7, day: 1))!
        let supersetEnd = Calendar.jst.date(from: DateComponents(year: 2026, month: 7, day: 31))!
        #expect(HistoricalSearchDatePolicy.validate(
            start: supersetStart, end: supersetEnd, existingSearches: [], damId: "test", now: now,
            loadedDailyHistory: loaded
        ) == nil)

        // 部分重複
        let overlapStart = Calendar.jst.date(from: DateComponents(year: 2026, month: 7, day: 15))!
        let overlapEnd = Calendar.jst.date(from: DateComponents(year: 2026, month: 7, day: 25))!
        #expect(HistoricalSearchDatePolicy.validate(
            start: overlapStart, end: overlapEnd, existingSearches: [], damId: "test", now: now,
            loadedDailyHistory: loaded
        ) == nil)
    }

    @Test func mlitDirectGateIgnoresLoadedDailyRange() {
        let start = Calendar.jst.date(from: DateComponents(year: 2026, month: 7, day: 1))!
        let end = Calendar.jst.date(from: DateComponents(year: 2026, month: 7, day: 31))!
        let now = Calendar.jst.date(from: DateComponents(year: 2026, month: 8, day: 10))!
        let loaded = (start: "20260701", end: "20260731")
        let error = HistoricalSearchDatePolicy.validate(
            start: start, end: end, existingSearches: [], damId: "test", now: now,
            historicalDataSource: .mlitDirect, loadedDailyHistory: loaded
        )
        #expect(error == nil)
    }

    @Test("Start-date change moves end to start when start exceeds end")
    func startChangeMovesEndToStartWhenRangeIsInverted() throws {
        let start = try jstDateTime(year: 2026, month: 5, day: 20, hour: 10, minute: 30)
        let end = try jstDateTime(year: 2026, month: 5, day: 10, hour: 5, minute: 0)

        let adjusted = HistoricalSearchDatePolicy.adjustedRangeAfterStartChange(start: start, end: end)

        #expect(DisplayFormatters.searchDate(adjusted.start) == "20260520")
        #expect(DisplayFormatters.searchDate(adjusted.end) == "20260520")
    }

    @Test("Start-date change clamps end to 30 days after start")
    func startChangeClampsEndToThirtyDays() throws {
        let start = try jstDate(year: 2026, month: 5, day: 1)
        let end = try jstDate(year: 2026, month: 6, day: 15)

        let adjusted = HistoricalSearchDatePolicy.adjustedRangeAfterStartChange(start: start, end: end)

        #expect(DisplayFormatters.searchDate(adjusted.end) == "20260531")
    }

    @Test("End-date change moves start to end when range is inverted")
    func endChangeMovesStartToEndWhenRangeIsInverted() throws {
        let start = try jstDate(year: 2026, month: 5, day: 20)
        let end = try jstDate(year: 2026, month: 5, day: 10)

        let adjusted = HistoricalSearchDatePolicy.adjustedRangeAfterEndChange(start: start, end: end)

        #expect(DisplayFormatters.searchDate(adjusted.start) == "20260510")
        #expect(DisplayFormatters.searchDate(adjusted.end) == "20260510")
    }

    @Test("End-date change clamps start to 30 days before end")
    func endChangeClampsStartToThirtyDays() throws {
        let start = try jstDate(year: 2026, month: 5, day: 1)
        let end = try jstDate(year: 2026, month: 6, day: 15)

        let adjusted = HistoricalSearchDatePolicy.adjustedRangeAfterEndChange(start: start, end: end)

        #expect(DisplayFormatters.searchDate(adjusted.start) == "20260516")
    }
}

@Suite("Network data source with fixtures")
struct NetworkDataSourceFixtureTests {
    @Test func fetcherInjectionWorksWithFixtureData() async throws {
        let fixtureData = Data("test fixture".utf8)
        let dataSource = MlitNetworkDataSource { urlString in
            #expect(urlString == "https://www1.river.go.jp/dat/test.dat")
            return fixtureData
        }
        let result = try await dataSource.fetchBytes("https://www1.river.go.jp/dat/test.dat")
        #expect(result == fixtureData)
    }

    @Test func fetcherThrowsSimulatesNetworkError() async {
        let dataSource = MlitNetworkDataSource { _ in
            throw URLError(.notConnectedToInternet)
        }
        await #expect(throws: MlitNetworkError.transport) {
            _ = try await dataSource.fetchBytes("https://www1.river.go.jp/dat/test.dat")
        }
    }
}

private struct FixedNetworkAvailability: NetworkAvailabilityProviding {
    private let available: Bool

    init(isNetworkAvailable: Bool) {
        available = isNetworkAvailable
    }

    nonisolated var isNetworkAvailable: Bool {
        available
    }
}

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

private final class HeaderFixtureFetcher: @unchecked Sendable {
    private let responses: [String: (Data, [String: String])]
    private nonisolated(unsafe) var urls: [String] = []

    init(responses: [String: (Data, [String: String])]) {
        self.responses = responses
    }

    var requestedURLs: [String] {
        urls
    }

    func fetch(urlString: String) async throws -> (Data, [String: String]) {
        urls.append(urlString)
        guard let entry = responses[urlString] else {
            throw URLError(.fileDoesNotExist)
        }
        return entry
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

private func tenMinuteRealtimeRows(start: Date, count: Int, storagePercentage: (Int) -> Float) throws -> [String] {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
    dateFormatter.dateFormat = "yyyy/MM/dd"
    let timeFormatter = DateFormatter()
    timeFormatter.locale = Locale(identifier: "en_US_POSIX")
    timeFormatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
    timeFormatter.dateFormat = "HH:mm"
    return try (0..<count).map { index in
        let date = try #require(Calendar.jst.date(byAdding: .minute, value: index * 10, to: start))
        let percentage = storagePercentage(index)
        return realtimeDatRow(
            dateFormatter.string(from: date),
            timeFormatter.string(from: date),
            storageVolume: 10000 + Float(index),
            storagePercentage: percentage
        )
    }
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

private func clearSettingsAndWidgetDefaults() {
    let keys: [String] = [
        "app.settings.v1",
        WidgetDefaultsKey.autoUpdateEnabled,
        WidgetDefaultsKey.showNotification,
        WidgetDefaultsKey.nextRequestedUpdate,
        WidgetDefaultsKey.autoUpdateIntervalSeconds,
        WidgetDefaultsKey.damDisplayName,
        WidgetDefaultsKey.dataUrl,
        WidgetDefaultsKey.stationId,
        WidgetDefaultsKey.stationName,
        WidgetDefaultsKey.messages,
        WidgetDefaultsKey.appSnapshot,
        WidgetDefaultsKey.snapshotV1,
        WidgetDefaultsKey.rawDatBridgeV1,
        WidgetDefaultsKey.fetchLog,
        WidgetDefaultsKey.fetchFailLog,
        WidgetDefaultsKey.appLastFetchAt,
        WidgetDefaultsKey.widgetLastFetchAt,
        WidgetDefaultsKey.appConfigured,
        WidgetDefaultsKey.debugModeEnabled,
        WidgetDefaultsKey.debugSimulateMode,
        WidgetDefaultsKey.initialLoadDone,
        WidgetDefaultsKey.appBootUpdateDoneAt,
        WidgetDefaultsKey.widgetBootUpdateDoneAt,
        WidgetDefaultsKey.lastKnownSystemUptime,
        "widget.currentBootMarker",
        "widget.lastKnownBootMarker",
        "widget.bootUpdateDoneAt",
        "lastKnownSystemUptime"
    ]
    keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    if let groupDefaults = UserDefaults(suiteName: "group.net.tecogonaz.TCSameuraDamMonitor") {
        keys.forEach { groupDefaults.removeObject(forKey: $0) }
    }
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

private func jstDateTime(year: Int, month: Int, day: Int, hour: Int, minute: Int) throws -> Date {
    try #require(Calendar.jst.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)))
}

@Suite("Dashboard navigation")
@MainActor
struct DashboardNavigationTests {
    @Test func resetsDashboardPathWhenDetailSelectionChanges() {
        let firstMetaId = UUID()
        let secondMetaId = UUID()

        #expect(DashboardNavigation.shouldResetPath(oldSelection: .realtime, newSelection: .historical(firstMetaId)))
        #expect(DashboardNavigation.shouldResetPath(oldSelection: .historical(firstMetaId), newSelection: .realtime))
        #expect(DashboardNavigation.shouldResetPath(oldSelection: .historical(firstMetaId), newSelection: .historical(secondMetaId)))
        #expect(DashboardNavigation.shouldResetPath(oldSelection: .historical(firstMetaId), newSelection: .historicalManage))
        #expect(DashboardNavigation.shouldResetPath(oldSelection: .historical(firstMetaId), newSelection: .settings))
    }

    @Test func keepsDashboardPathWhenDetailSelectionIsUnchanged() {
        let metaId = UUID()

        #expect(!DashboardNavigation.shouldResetPath(oldSelection: .realtime, newSelection: .realtime))
        #expect(!DashboardNavigation.shouldResetPath(oldSelection: .historical(metaId), newSelection: .historical(metaId)))
        #expect(!DashboardNavigation.shouldResetPath(oldSelection: .settings, newSelection: .settings))
    }
}

@MainActor
private func expectedJSTDateTime(_ date: Date) -> String {
    TimeFormatters.jstDisplay.string(from: date)
}

@MainActor
private func historicalMeta(dam: DamConfig, start: String, end: String, sortOrder: Int) -> HistoricalSearchMeta {
    HistoricalSearchMeta(
        id: UUID(),
        observationStationId: dam.id,
        observationStationName: dam.nameJa,
        riverSystemName: "",
        riverName: "",
        damConfigId: dam.id,
        searchBgnDate: start,
        searchEndDate: end,
        fetchedAt: Date(),
        sortOrder: sortOrder,
        isPinned: false,
        dataStartTimeStr: nil,
        dataEndTimeStr: nil,
        dataStartStoragePct: nil,
        dataEndStoragePct: nil,
        dataMinStoragePct: nil,
        dataMaxStoragePct: nil
    )
}

private func damData(storagePercentage: Float?, storageVolume: Float? = nil, observationStationId: String = "1368080700010") -> DamData {
    DamData(
        observationStationId: observationStationId,
        observationStationName: "早明浦ダム",
        riverSystemName: "吉野川",
        riverName: "吉野川",
        updatedAt: "2026/05/25 05:00",
        catchmentAverageRainfall: nil,
        storageVolume: storageVolume,
        storageVolumeForMessage: nil,
        storageVolumeTrend: .unknown,
        inflow: nil,
        inflowTrend: .unknown,
        outflow: nil,
        outflowTrend: .unknown,
        storagePercentage: storagePercentage,
        storagePercentageTrend: .flat,
        storagePercentageTime: "2026/05/25 05:00",
        storagePercentageDayChange: nil,
        storagePercentageDayChangeTrend: .unknown,
        storagePercentageWeekChange: nil,
        storagePercentageWeekChangeTrend: .unknown,
        historicalData: []
    )
}

@MainActor
private func storageRateMessageBodies(_ settings: AppSettings) -> [String] {
    [
        settings.msg80_100,
        settings.msg80_100Ja,
        settings.msg60_80,
        settings.msg60_80Ja,
        settings.msg40_60,
        settings.msg40_60Ja,
        settings.msg20_40,
        settings.msg20_40Ja,
        settings.msg0_20,
        settings.msg0_20Ja,
        settings.msg0,
        settings.msg0Ja,
        settings.msgAllAbnormal,
        settings.msgAllAbnormalJa,
        settings.msgAllDataInvalid,
        settings.msgAllDataInvalidJa
    ]
}

private func historicalRow(time: String) -> DamHistoricalData {
    DamHistoricalData(
        time: time,
        catchmentAverageRainfall: Float(1),
        storagePercentage: Float(2),
        storageVolume: Float(3),
        inflow: Float(4),
        outflow: Float(5)
    )
}

private func graphRow(
    _ time: String,
    rainfall: Float? = nil,
    storagePercentage: Float? = nil,
    storageVolume: Float? = nil,
    inflow: Float? = nil,
    outflow: Float? = nil
) -> DamHistoricalData {
    DamHistoricalData(
        time: time,
        catchmentAverageRainfall: rainfall,
        storagePercentage: storagePercentage,
        storageVolume: storageVolume,
        inflow: inflow,
        outflow: outflow
    )
}

@Suite("Geo URI coordinate parsing")
struct GeoURICoordinateTests {
    @Test("parseGeoCoordinate extracts lat/lng from valid geo URI")
    func validGeoURI() {
        let url = URL(string: "geo:33.755833,133.548056")!
        let coordinate = GeoLinkRow.parseGeoCoordinate(from: url)
        #expect(coordinate != nil)
        #expect(abs(coordinate!.latitude - 33.755833) < 0.0001)
        #expect(abs(coordinate!.longitude - 133.548056) < 0.0001)
    }

    @Test("parseGeoCoordinate returns nil for non-geo scheme")
    func nonGeoScheme() {
        let url = URL(string: "https://example.com")!
        let coordinate = GeoLinkRow.parseGeoCoordinate(from: url)
        #expect(coordinate == nil)
    }

    @Test("parseGeoCoordinate returns nil for malformed geo URI")
    func malformedGeoURI() {
        let url = URL(string: "geo:invalid")!
        let coordinate = GeoLinkRow.parseGeoCoordinate(from: url)
        #expect(coordinate == nil)
    }

    @Test("parseGeoCoordinate handles geo URI with query parameters")
    func geoURIWithQuery() {
        let url = URL(string: "geo:35.6895,139.6917?z=15")!
        let coordinate = GeoLinkRow.parseGeoCoordinate(from: url)
        #expect(coordinate != nil)
        #expect(abs(coordinate!.latitude - 35.6895) < 0.0001)
        #expect(abs(coordinate!.longitude - 139.6917) < 0.0001)
    }
}

// MARK: - Phase 2: PreparedGraphData

/// 変更前のCard body内計算（per-body）をそのまま再現するレガシー計算の結果。
private struct LegacyGraphDisplay {
    let rows: [DatedHistoricalRow]
    let domain: ClosedRange<Date>
    let summary: String
    let rainfallScaleValues: [Float]
    let rainfallAxisMax: Double?
    let volumeScaleValues: [Float]
    let inflowScaleValues: [Float]
    let outflowScaleValues: [Float]
    let volumeMax: Double?
    let flowMax: Double?
    let hasFlowScaleData: Bool
    let volumeTickValues: [Double]
    let flowTickValues: [Double]
    let storageSegments: [DamChartSegment]
    let rainfallSegments: [DamChartSegment]
    let volumeSegments: [DamChartSegment]
    let inflowSegments: [DamChartSegment]
    let outflowSegments: [DamChartSegment]
}

/// Phase 1のGraphSection bodyが行っていた計算を、そのままの手順で再現します。
@MainActor
private func legacyGraphDisplay(
    allRows: [DamHistoricalData],
    kind: ObservationGraphDisplayKind,
    range: RealtimeGraphRange,
    isHistorical: Bool,
    rangeStartDate: String? = nil,
    rangeEndDate: String? = nil,
    meta: HistoricalSearchMeta? = nil,
    selectedYears: Set<Int> = [],
    comparisonPayload: HistoricalComparisonPayload? = nil
) -> LegacyGraphDisplay {
    let baseRows = DashboardRowCache.ascending(allRows)
    let (rows, chartRange): ([DatedHistoricalRow], ClosedRange<Date>?)
    if isHistorical {
        let range = legacyHistoricalAxisRange(meta: meta, rangeStartDate: rangeStartDate, rangeEndDate: rangeEndDate)
        chartRange = range
        if let range {
            rows = baseRows.filter { $0.date >= range.lowerBound && $0.date <= range.upperBound }
        } else {
            rows = baseRows
        }
    } else {
        switch kind {
        case .rainfallStorage, .rainfallStorageHistory:
            let data = ObservationGraphCalculator.buildRealtimeStorageGraphDisplayData(rows: baseRows.map(\.row), range: range)
            rows = data.rows.map { DatedHistoricalRow(row: $0, date: ObservationGraphCalculator.date(fromDamTime: $0.time) ?? .distantPast) }
            chartRange = ObservationGraphCalculator.graphDomain(
                start: data.windowStart, end: data.windowEnd,
                firstDate: rows.first?.date, lastDate: rows.last?.date
            )
        case .volumeFlow, .volumeFlowHistory:
            let data = ObservationGraphCalculator.buildRealtimeGraphDisplayData(rows: baseRows.map(\.row), range: range)
            rows = data.rows.map { DatedHistoricalRow(row: $0, date: ObservationGraphCalculator.date(fromDamTime: $0.time) ?? .distantPast) }
            chartRange = ObservationGraphCalculator.graphDomain(
                start: data.windowStart, end: data.windowEnd,
                firstDate: rows.first?.date, lastDate: rows.last?.date
            )
        }
    }
    let domain = legacyChartDomain(rows, range: chartRange)
    let summary: String
    switch kind {
    case .rainfallStorage, .rainfallStorageHistory:
        summary = legacyRainfallSummary(rows: rows, range: chartRange, isHistorical: isHistorical, rangeStartDate: rangeStartDate, rangeEndDate: rangeEndDate, meta: meta)
    case .volumeFlow, .volumeFlowHistory:
        summary = legacyVolumeSummary(rows: rows, range: chartRange, isHistorical: isHistorical, rangeStartDate: rangeStartDate, rangeEndDate: rangeEndDate, meta: meta)
    }
    let isRainfallKind = kind == .rainfallStorage || kind == .rainfallStorageHistory
    let rainfallScaleValues = isRainfallKind
        ? ObservationGraphCalculator.realtimeGraphScaleValues(
            allRangeValues: baseRows.compactMap(\.row.catchmentAverageRainfall),
            selectedRangeValues: rows.compactMap(\.row.catchmentAverageRainfall),
            isHistorical: isHistorical
        )
        : []
    let rainfallAxisMax = isRainfallKind ? ObservationGraphCalculator.rainfallAxisMax(values: rainfallScaleValues) : nil
    let volumeScaleValues = !isRainfallKind
        ? ObservationGraphCalculator.realtimeGraphScaleValues(
            allRangeValues: baseRows.compactMap(\.row.storageVolume),
            selectedRangeValues: rows.compactMap(\.row.storageVolume),
            isHistorical: isHistorical
        )
        : []
    let displayedPastSeries = comparisonPayload.map {
        $0.pastSeries.filter { selectedYears.contains($0.year) }
    } ?? []
    let volumeMax = !isRainfallKind
        ? ObservationGraphCalculator.paddedMax(
            values: volumeScaleValues + displayedPastSeries.flatMap(\.points).compactMap(\.value)
        )
        : nil
    let inflowScaleValues = !isRainfallKind
        ? ObservationGraphCalculator.realtimeGraphScaleValues(
            allRangeValues: baseRows.compactMap(\.row.inflow),
            selectedRangeValues: rows.compactMap(\.row.inflow),
            isHistorical: isHistorical
        )
        : []
    let outflowScaleValues = !isRainfallKind
        ? ObservationGraphCalculator.realtimeGraphScaleValues(
            allRangeValues: baseRows.compactMap(\.row.outflow),
            selectedRangeValues: rows.compactMap(\.row.outflow),
            isHistorical: isHistorical
        )
        : []
    let flowScaleValues = inflowScaleValues + outflowScaleValues
    let hasFlowScaleData = !isRainfallKind && !flowScaleValues.isEmpty
    let flowMax = !isRainfallKind ? ObservationGraphCalculator.paddedMax(values: flowScaleValues) : nil
    let volumeTickValues = volumeMax.map { vmax in
        ObservationGraphCalculator.axisTickValues(maxValue: vmax).map { legacyScaled($0, max: vmax) }
    } ?? []
    let flowTickValues = hasFlowScaleData
        ? flowMax.map { fmax in
            ObservationGraphCalculator.axisTickValues(maxValue: fmax).map { legacyScaled($0, max: fmax) }
        } ?? []
        : []
    return LegacyGraphDisplay(
        rows: rows,
        domain: domain,
        summary: summary,
        rainfallScaleValues: rainfallScaleValues,
        rainfallAxisMax: rainfallAxisMax,
        volumeScaleValues: volumeScaleValues,
        inflowScaleValues: inflowScaleValues,
        outflowScaleValues: outflowScaleValues,
        volumeMax: volumeMax,
        flowMax: flowMax,
        hasFlowScaleData: hasFlowScaleData,
        volumeTickValues: volumeTickValues,
        flowTickValues: flowTickValues,
        storageSegments: isRainfallKind ? legacySegments(rows: rows, idPrefix: "storage") { $0.row.storagePercentage.map(Double.init) } : [],
        rainfallSegments: isRainfallKind ? legacySegments(rows: rows, idPrefix: "rainfall") { $0.row.catchmentAverageRainfall.map { legacyScaled(Double($0), max: rainfallAxisMax ?? 0) } } : [],
        volumeSegments: !isRainfallKind ? legacySegments(rows: rows, idPrefix: "volume") { $0.row.storageVolume.map { legacyScaled(Double($0), max: volumeMax ?? 0) } } : [],
        inflowSegments: !isRainfallKind ? legacySegments(rows: rows, idPrefix: "inflow") { $0.row.inflow.map { legacyScaled(Double($0), max: flowMax ?? 0) } } : [],
        outflowSegments: !isRainfallKind ? legacySegments(rows: rows, idPrefix: "outflow") { $0.row.outflow.map { legacyScaled(Double($0), max: flowMax ?? 0) } } : []
    )
}

/// 変更前の `chartDomain` フォールバックを再現します。
@MainActor
private func legacyChartDomain(_ rows: [DatedHistoricalRow], range: ClosedRange<Date>?) -> ClosedRange<Date> {
    if let range { return range }
    let start = rows.first?.date ?? Date()
    let end = rows.last?.date ?? start.addingTimeInterval(1)
    return start < end ? start...end : start...start.addingTimeInterval(1)
}

/// 変更前の `scaled` を再現します。
private func legacyScaled(_ value: Double, max maxValue: Double) -> Double {
    guard maxValue > 0 else { return 0 }
    return min(max(value / maxValue * 100, 0), 100)
}

/// 変更前の `lineSegments` を再現します。
@MainActor
private func legacySegments(
    rows: [DatedHistoricalRow],
    idPrefix: String,
    value: (DatedHistoricalRow) -> Double?
) -> [DamChartSegment] {
    var segments: [DamChartSegment] = []
    var current: [DamChartPoint] = []
    var lastDate: Date?
    var segmentIndex = 0

    func flush() {
        if !current.isEmpty {
            segments.append(DamChartSegment(id: "\(idPrefix)-segment-\(segmentIndex)", points: current))
            segmentIndex += 1
            current = []
        }
    }

    for item in rows {
        guard let pointValue = value(item) else {
            flush()
            lastDate = nil
            continue
        }
        if let lastDate, item.date.timeIntervalSince(lastDate) > damChartLineBreakGap {
            flush()
        }
        current.append(DamChartPoint(id: "\(item.id)-\(idPrefix)", date: item.date, value: pointValue))
        lastDate = item.date
    }

    flush()
    return segments
}

/// 変更前の `historicalAxisRange` を再現します。
@MainActor
private func legacyHistoricalAxisRange(meta: HistoricalSearchMeta?, rangeStartDate: String?, rangeEndDate: String?) -> ClosedRange<Date>? {
    if let startDate = rangeStartDate, let endDate = rangeEndDate,
       let start = legacyHistoricalStartDate(from: startDate),
       let end = legacyHistoricalEndDate(from: endDate) {
        return start...end
    }
    if let meta,
       let start = legacyHistoricalStartDate(meta),
       let end = legacyHistoricalEndDate(meta) {
        return start...end
    }
    return nil
}

@MainActor
private func legacyHistoricalStartDate(_ meta: HistoricalSearchMeta) -> Date? {
    legacyHistoricalStartDate(from: meta.searchBgnDate)
}

@MainActor
private func legacyHistoricalEndDate(_ meta: HistoricalSearchMeta) -> Date? {
    legacyHistoricalEndDate(from: meta.searchEndDate)
}

@MainActor
private func legacyHistoricalStartDate(from yyyymmdd: String) -> Date? {
    guard let day = TimeFormatters.jstDay.date(from: yyyymmdd) else { return nil }
    return Calendar.jst.date(byAdding: .hour, value: 1, to: day)
}

@MainActor
private func legacyHistoricalEndDate(from yyyymmdd: String) -> Date? {
    guard let day = TimeFormatters.jstDay.date(from: yyyymmdd),
          let nextDay = Calendar.jst.date(byAdding: .day, value: 1, to: day) else {
        return nil
    }
    return nextDay
}

/// 変更前の `periodText` を再現します。
@MainActor
private func legacyPeriodText(
    rows: [DatedHistoricalRow],
    range: ClosedRange<Date>?,
    isHistorical: Bool,
    rangeStartDate: String?,
    rangeEndDate: String?,
    meta: HistoricalSearchMeta?
) -> String {
    let isLocalJst = DisplayFormatters.isJST
    if isHistorical {
        if let startDate = rangeStartDate, let endDate = rangeEndDate {
            return DamCoreJSTSupport.appendingJstSuffix("\(DisplayFormatters.slashDate(startDate)) 01:00 - \(DisplayFormatters.nextDaySlashDate(endDate)) 00:00", isLocalJst: isLocalJst)
        }
        if let meta {
            return DamCoreJSTSupport.appendingJstSuffix("\(DisplayFormatters.slashDate(meta.searchBgnDate)) 01:00 - \(DisplayFormatters.nextDaySlashDate(meta.searchEndDate)) 00:00", isLocalJst: isLocalJst)
        }
    }
    if let range, !isHistorical {
        return "\(TimeFormatters.jstDisplay.string(from: range.lowerBound)) - \(DamCoreJSTSupport.appendingJstSuffix(TimeFormatters.jstDisplay.string(from: range.upperBound), isLocalJst: isLocalJst))"
    }
    guard let first = rows.first?.row, let last = rows.last?.row else { return "--" }
    return "\(DisplayFormatters.damDateTime(first.time, withJSTSuffix: false)) - \(DamCoreJSTSupport.appendingJstSuffix(DisplayFormatters.damDateTime(last.time, withJSTSuffix: false), isLocalJst: isLocalJst))"
}

/// 変更前の雨量・貯水率サマリーを再現します(Phase 5の行順: 期間 → 貯水率最大 → 貯水率最小 →
/// 流域平均雨量(合計) → 流域平均雨量 最大)。
@MainActor
private func legacyRainfallSummary(
    rows: [DatedHistoricalRow],
    range: ClosedRange<Date>?,
    isHistorical: Bool,
    rangeStartDate: String?,
    rangeEndDate: String?,
    meta: HistoricalSearchMeta?
) -> String {
    var lines = ["\(AppText.graphLabelPeriod) \(legacyPeriodText(rows: rows, range: range, isHistorical: isHistorical, rangeStartDate: rangeStartDate, rangeEndDate: rangeEndDate, meta: meta))"]
    let storageRows = rows.filter { $0.row.storagePercentage != nil }
    if let maxItem = storageRows.max(by: { ($0.row.storagePercentage ?? 0) < ($1.row.storagePercentage ?? 0) }),
       let minItem = storageRows.min(by: { ($0.row.storagePercentage ?? 0) < ($1.row.storagePercentage ?? 0) }),
       let maxValue = maxItem.row.storagePercentage,
       let minValue = minItem.row.storagePercentage {
        lines.append("\(AppText.graphLabelStorageRateMax) \(DisplayFormatters.damDateTime(maxItem.row.time)) \(String(format: "%.2f", maxValue))%")
        lines.append("\(AppText.graphLabelStorageRateMin) \(DisplayFormatters.damDateTime(minItem.row.time)) \(String(format: "%.2f", minValue))%")
    }
    let rainfalls = rows.compactMap(\.row.catchmentAverageRainfall)
    if !rainfalls.isEmpty {
        lines.append("\(AppText.graphLabelRainfallTotal) \(String(format: "%.1f", rainfalls.reduce(0, +)))mm")
        if let maxRainfall = rainfalls.max(), maxRainfall != 0 {
            let unit = isHistorical ? AppText.graphUnitRainfallPerHour : AppText.graphUnitRainfall
            lines.append("\(AppText.graphLabelRainfallMax) \(String(format: "%.1f", maxRainfall))\(unit.trimmedUnit)")
        }
    }
    return lines.joined(separator: "\n")
}

/// 変更前の貯水量・流量サマリーを再現します。
@MainActor
private func legacyVolumeSummary(
    rows: [DatedHistoricalRow],
    range: ClosedRange<Date>?,
    isHistorical: Bool,
    rangeStartDate: String?,
    rangeEndDate: String?,
    meta: HistoricalSearchMeta?
) -> String {
    var lines = ["\(AppText.graphLabelPeriod) \(legacyPeriodText(rows: rows, range: range, isHistorical: isHistorical, rangeStartDate: rangeStartDate, rangeEndDate: rangeEndDate, meta: meta))"]
    legacyAppendSummary(to: &lines, rows: rows, value: \.storageVolume, maxLabel: AppText.graphLabelStorageVolumeMax, minLabel: AppText.graphLabelStorageVolumeMin, unit: AppText.graphUnitStorageVolume, decimals: 0)
    legacyAppendSummary(to: &lines, rows: rows, value: \.inflow, maxLabel: AppText.graphLabelInflowMax, minLabel: AppText.graphLabelInflowMin, unit: AppText.graphUnitFlow, decimals: 2)
    legacyAppendSummary(to: &lines, rows: rows, value: \.outflow, maxLabel: AppText.graphLabelOutflowMax, minLabel: AppText.graphLabelOutflowMin, unit: AppText.graphUnitFlow, decimals: 2)
    return lines.joined(separator: "\n")
}

@MainActor
private func legacyAppendSummary(
    to lines: inout [String],
    rows: [DatedHistoricalRow],
    value: KeyPath<DamHistoricalData, Float?>,
    maxLabel: String,
    minLabel: String,
    unit: String,
    decimals: Int
) {
    let validRows = rows.filter { $0.row[keyPath: value] != nil }
    guard let maxItem = validRows.max(by: { ($0.row[keyPath: value] ?? 0) < ($1.row[keyPath: value] ?? 0) }),
          let minItem = validRows.min(by: { ($0.row[keyPath: value] ?? 0) < ($1.row[keyPath: value] ?? 0) }),
          let maxValue = maxItem.row[keyPath: value],
          let minValue = minItem.row[keyPath: value] else {
        return
    }
    if maxValue != 0 {
        lines.append("\(maxLabel) \(DisplayFormatters.damDateTime(maxItem.row.time)) \(legacyFormatValue(maxValue, decimals: decimals))\(unit.trimmedUnit)")
    }
    if minValue != 0 {
        lines.append("\(minLabel) \(DisplayFormatters.damDateTime(minItem.row.time)) \(legacyFormatValue(minValue, decimals: decimals))\(unit.trimmedUnit)")
    }
}

private func legacyFormatValue(_ value: Float, decimals: Int) -> String {
    decimals == 0 ? "\(Int(value))" : String(format: "%.\(decimals)f", value)
}

@Suite("Graph period JST suffix")
@MainActor
struct GraphPeriodJstSuffixTests {
    private func datedRows(_ rows: [DamHistoricalData]) -> [DatedHistoricalRow] {
        rows.map { DatedHistoricalRow(row: $0, date: ObservationGraphCalculator.date(fromDamTime: $0.time) ?? .distantPast) }
    }

    @Test("Realtime range period appends the suffix only to the end when not JST")
    func realtimeRangePeriodAppendsSuffixToEndOnly() throws {
        let start = try jstDateTime(year: 2026, month: 6, day: 8, hour: 1, minute: 0)
        let end = try jstDateTime(year: 2026, month: 6, day: 8, hour: 6, minute: 0)
        let range = start...end

        let text = PreparedGraphDataBuilder.periodText(
            rows: datedRows(fixtureGraphRows()), range: range, isHistorical: false,
            rangeStartDate: nil, rangeEndDate: nil, meta: nil, isLocalJst: false
        )
        #expect(text == "2026/06/08 01:00 - 2026/06/08 06:00 (JST)")
        #expect(!text.contains("(JST) - "))

        let jstText = PreparedGraphDataBuilder.periodText(
            rows: datedRows(fixtureGraphRows()), range: range, isHistorical: false,
            rangeStartDate: nil, rangeEndDate: nil, meta: nil, isLocalJst: true
        )
        #expect(jstText == "2026/06/08 01:00 - 2026/06/08 06:00")
    }

    @Test("Realtime all-period falls back to first/last rows with end-only suffix")
    func realtimeAllPeriodAppendsSuffixToEndRowOnly() {
        let text = PreparedGraphDataBuilder.periodText(
            rows: datedRows(fixtureGraphRows()), range: nil, isHistorical: false,
            rangeStartDate: nil, rangeEndDate: nil, meta: nil, isLocalJst: false
        )
        #expect(text == "2026/06/07 23:50 - 2026/06/09 00:00 (JST)")
        #expect(!text.contains("(JST) - "))

        let jstText = PreparedGraphDataBuilder.periodText(
            rows: datedRows(fixtureGraphRows()), range: nil, isHistorical: false,
            rangeStartDate: nil, rangeEndDate: nil, meta: nil, isLocalJst: true
        )
        #expect(jstText == "2026/06/07 23:50 - 2026/06/09 00:00")
    }

    @Test("Historical period appends the suffix to the end boundary only")
    func historicalPeriodAppendsSuffixToEndOnly() {
        let text = PreparedGraphDataBuilder.periodText(
            rows: datedRows(fixtureGraphRows()), range: nil, isHistorical: true,
            rangeStartDate: "20260607", rangeEndDate: "20260608", meta: nil, isLocalJst: false
        )
        #expect(text == "2026/06/07 01:00 - 2026/06/09 00:00 (JST)")
        #expect(!text.contains("(JST) - "))

        let jstText = PreparedGraphDataBuilder.periodText(
            rows: datedRows(fixtureGraphRows()), range: nil, isHistorical: true,
            rangeStartDate: "20260607", rangeEndDate: "20260608", meta: nil, isLocalJst: true
        )
        #expect(jstText == "2026/06/07 01:00 - 2026/06/09 00:00")
    }
}

/// builderのdisplay snapshotが変更前のper-body計算と一致することを確認します。
/// 空行のdomainだけは `Date()` フォールバックのため一致検証を行いません。
@MainActor
private func assertLegacyEquivalence(_ snapshot: GraphDisplaySnapshot, _ legacy: LegacyGraphDisplay) {
    #expect(snapshot.rows.map(\.row.time) == legacy.rows.map(\.row.time))
    #expect(snapshot.rows.map(\.date) == legacy.rows.map(\.date))
    if !snapshot.rows.isEmpty {
        #expect(snapshot.domain == legacy.domain)
    }
    #expect(snapshot.summary == legacy.summary)
    #expect(snapshot.rainfallScaleValues == legacy.rainfallScaleValues.map(Double.init))
    #expect(snapshot.volumeScaleValues == legacy.volumeScaleValues.map(Double.init))
    #expect(snapshot.inflowScaleValues == legacy.inflowScaleValues.map(Double.init))
    #expect(snapshot.outflowScaleValues == legacy.outflowScaleValues.map(Double.init))
    #expect(snapshot.rainfallAxisMax == legacy.rainfallAxisMax)
    #expect(snapshot.volumeMax == legacy.volumeMax)
    #expect(snapshot.flowMax == legacy.flowMax)
    #expect(snapshot.hasFlowScaleData == legacy.hasFlowScaleData)
    #expect(snapshot.volumeTickValues == legacy.volumeTickValues)
    #expect(snapshot.flowTickValues == legacy.flowTickValues)
    #expect(snapshot.storageSegments == legacy.storageSegments)
    #expect(snapshot.rainfallSegments == legacy.rainfallSegments)
    #expect(snapshot.volumeSegments == legacy.volumeSegments)
    #expect(snapshot.inflowSegments == legacy.inflowSegments)
    #expect(snapshot.outflowSegments == legacy.outflowSegments)
}

/// 欠測・3時間超gap・24:00・複数値を持つ等価性検証用の行フィクスチャ。
private func fixtureGraphRows() -> [DamHistoricalData] {
    [
        graphRow("2026/06/07 23:50", rainfall: 1.5, storagePercentage: 80, storageVolume: 80000, inflow: 10, outflow: 8),
        graphRow("2026/06/08 00:00", rainfall: 2, storagePercentage: 79.5, storageVolume: 79500, inflow: 12, outflow: 9),
        graphRow("2026/06/08 01:00", storagePercentage: 79, storageVolume: 79000),
        graphRow("2026/06/08 02:00", rainfall: 0, storageVolume: 78900, inflow: 11, outflow: 10),
        graphRow("2026/06/08 05:30", rainfall: 3, storagePercentage: 78, storageVolume: 78000, inflow: 13, outflow: 11),
        graphRow("2026/06/08 06:00", rainfall: 0.5, storagePercentage: 78.2, storageVolume: 78200, inflow: 12, outflow: 10),
        graphRow("2026/06/08 24:00", storagePercentage: 78.5, storageVolume: 78500),
    ]
}

/// 過去比較の等価性検証用のペイロードフィクスチャ（2024/2025年・年ごとに値が異なる）。
@MainActor
private func fixtureComparisonPayload() throws -> HistoricalComparisonPayload {
    let points2024 = try (0..<24).map { index in
        let date = try jstDateTime(year: 2025, month: 6, day: 8, hour: index, minute: 0)
        return HistoricalComparisonSeriesPoint(
            id: "2024-\(index)",
            date: date,
            value: Float(90000 + index * 100),
            rawTime: "2024/06/08 \(String(format: "%02d", index)):00"
        )
    }
    let points2025 = try (0..<24).map { index in
        let date = try jstDateTime(year: 2025, month: 6, day: 8, hour: index, minute: 0)
        return HistoricalComparisonSeriesPoint(
            id: "2025-\(index)",
            date: date,
            value: Float(95000 + index * 100),
            rawTime: "2025/06/08 \(String(format: "%02d", index)):00"
        )
    }
    return HistoricalComparisonPayload(
        metric: .storageVolume,
        currentYear: 2026,
        mainYear: 2026,
        availablePastYears: [2024, 2025],
        periodStart: points2024.first?.date,
        periodEnd: points2024.last?.date,
        pastSeries: [
            HistoricalComparisonSeries(year: 2024, points: points2024),
            HistoricalComparisonSeries(year: 2025, points: points2025),
        ]
    )
}

@Suite("Prepared graph data builder equivalence")
@MainActor
struct PreparedGraphDataBuilderEquivalenceTests {
    @Test("Realtime rainfall display matches the per-body computation for edge fixtures")
    func rainfallRealtimeEquivalence() {
        let fixtures = [fixtureGraphRows(), [graphRow("2026/06/08 05:00", storagePercentage: 80)], []]
        for fixture in fixtures {
            for range in [RealtimeGraphRange.all, .past24Hours] {
                let base = PreparedGraphDataBuilder.base(from: fixture, rangeOptions: [range])
                let snapshot = PreparedGraphDataBuilder.display(
                    base: base, kind: .rainfallStorage, range: range,
                    selectedYears: [], isHistorical: false,
                    comparisonPayload: nil, rangeStartDate: nil, rangeEndDate: nil,
                    meta: nil, localeFingerprint: "true-Asia/Tokyo"
                )
                let legacy = legacyGraphDisplay(allRows: fixture, kind: .rainfallStorage, range: range, isHistorical: false)
                assertLegacyEquivalence(snapshot, legacy)
            }
        }
    }

    @Test("Realtime volume/flow display matches the per-body computation for edge fixtures")
    func volumeFlowRealtimeEquivalence() {
        let fixtures = [fixtureGraphRows(), [graphRow("2026/06/08 05:00", storageVolume: 70000, inflow: 10, outflow: 9)], []]
        for fixture in fixtures {
            for range in [RealtimeGraphRange.all, .past24Hours] {
                let base = PreparedGraphDataBuilder.base(from: fixture, rangeOptions: [range])
                let snapshot = PreparedGraphDataBuilder.display(
                    base: base, kind: .volumeFlow, range: range,
                    selectedYears: [], isHistorical: false,
                    comparisonPayload: nil, rangeStartDate: nil, rangeEndDate: nil,
                    meta: nil, localeFingerprint: "true-Asia/Tokyo"
                )
                let legacy = legacyGraphDisplay(allRows: fixture, kind: .volumeFlow, range: range, isHistorical: false)
                assertLegacyEquivalence(snapshot, legacy)
            }
        }
    }

    @Test("Historical display uses base rows and the meta/range domain")
    func historicalDisplayEquivalence() throws {
        let fixture = fixtureGraphRows()
        let dam = try #require(DamListData.dam(id: "1368080700010"))
        let meta = historicalMeta(dam: dam, start: "20260608", end: "20260609", sortOrder: 0)
        let base = PreparedGraphDataBuilder.base(from: fixture, rangeOptions: [.all])

        let metaSnapshot = PreparedGraphDataBuilder.display(
            base: base, kind: .rainfallStorage, range: .all,
            selectedYears: [], isHistorical: true,
            comparisonPayload: nil, rangeStartDate: nil, rangeEndDate: nil,
            meta: meta, localeFingerprint: "true-Asia/Tokyo"
        )
        let metaLegacy = legacyGraphDisplay(allRows: fixture, kind: .rainfallStorage, range: .all, isHistorical: true, meta: meta)
        assertLegacyEquivalence(metaSnapshot, metaLegacy)
        #expect(metaSnapshot.rows.map(\.row.time) == base.rows.filter { $0.date >= metaSnapshot.domain.lowerBound && $0.date <= metaSnapshot.domain.upperBound }.map(\.row.time))

        let filterSnapshot = PreparedGraphDataBuilder.display(
            base: base, kind: .rainfallStorage, range: .all,
            selectedYears: [], isHistorical: true,
            comparisonPayload: nil, rangeStartDate: "20260608", rangeEndDate: "20260609",
            meta: meta, localeFingerprint: "true-Asia/Tokyo"
        )
        let filterLegacy = legacyGraphDisplay(allRows: fixture, kind: .rainfallStorage, range: .all, isHistorical: true, rangeStartDate: "20260608", rangeEndDate: "20260609", meta: meta)
        assertLegacyEquivalence(filterSnapshot, filterLegacy)
    }

    @Test("Volume display includes displayed past series values in volumeMax")
    func volumeMaxIncludesDisplayedPastSeries() throws {
        let fixture = fixtureGraphRows()
        let payload = try fixtureComparisonPayload()
        let base = PreparedGraphDataBuilder.base(from: fixture, rangeOptions: [.all])

        let bothYears: Set<Int> = [2024, 2025]
        let snapshot = PreparedGraphDataBuilder.display(
            base: base, kind: .volumeFlowHistory, range: .all,
            selectedYears: bothYears, isHistorical: false,
            comparisonPayload: payload, rangeStartDate: nil, rangeEndDate: nil,
            meta: nil, localeFingerprint: "true-Asia/Tokyo"
        )
        let legacy = legacyGraphDisplay(allRows: fixture, kind: .volumeFlowHistory, range: .all, isHistorical: false, selectedYears: bothYears, comparisonPayload: payload)
        assertLegacyEquivalence(snapshot, legacy)

        let oneYear: Set<Int> = [2024]
        let oneSnapshot = PreparedGraphDataBuilder.display(
            base: base, kind: .volumeFlowHistory, range: .all,
            selectedYears: oneYear, isHistorical: false,
            comparisonPayload: payload, rangeStartDate: nil, rangeEndDate: nil,
            meta: nil, localeFingerprint: "true-Asia/Tokyo"
        )
        let oneLegacy = legacyGraphDisplay(allRows: fixture, kind: .volumeFlowHistory, range: .all, isHistorical: false, selectedYears: oneYear, comparisonPayload: payload)
        assertLegacyEquivalence(oneSnapshot, oneLegacy)
        #expect(oneSnapshot.volumeMax != snapshot.volumeMax)
    }

    @Test("Base building normalizes 24:00, rejects 24:01/25:00, and keeps pre-existing 2/29 rollover boundary")
    func baseBuildingNormalizesAndRejectsEdgeTimes() throws {
        // 非うるう年の2/29は既存のDamCoreDamTime境界が3/1へrolloverする（pre-Phase-2から不変）。
        // timestampsは行をdedupしない（行数と一致）。
        let rows = [
            graphRow("2026/06/07 24:00", storagePercentage: 80),
            graphRow("2026/06/08 01:00", storagePercentage: 79),
            graphRow("2026/06/08 24:01", storagePercentage: 78),
            graphRow("2026/06/09 25:00", storagePercentage: 77),
            graphRow("2026/02/29 10:00", storagePercentage: 76),
            graphRow("2024/02/29 10:00", storagePercentage: 75),
        ]
        let base = PreparedGraphDataBuilder.base(from: rows, rangeOptions: [.all])

        #expect(base.rows.filter { $0.date == .distantPast }.count == 2)
        #expect(base.timestamps.contains(try jstDateTime(year: 2026, month: 6, day: 8, hour: 0, minute: 0)))
        #expect(base.timestamps.contains(try jstDateTime(year: 2026, month: 6, day: 8, hour: 1, minute: 0)))
        #expect(base.timestamps.contains(try jstDateTime(year: 2024, month: 2, day: 29, hour: 10, minute: 0)))
        #expect(base.timestamps.contains(try jstDateTime(year: 2026, month: 3, day: 1, hour: 10, minute: 0)))
        #expect(base.timestamps.sorted() == base.timestamps)
        #expect(base.timestamps.count == 6)
    }

    @Test("Benchmark fixture builds base for 1,151 rows and display for a 24-year payload")
    func benchmarkFixtureBuildsCountsOnly() throws {
        let start = try jstDateTime(year: 2026, month: 4, day: 1, hour: 0, minute: 0)
        let rows = try (0..<1151).map { index in
            let date = try #require(Calendar.jst.date(byAdding: .minute, value: index * 10, to: start))
            return graphRow(
                TimeFormatters.jstDisplay.string(from: date),
                rainfall: 0.5, storagePercentage: 70,
                storageVolume: 70000, inflow: 10, outflow: 9
            )
        }
        let payload = try fixture24YearPayload()
        let identity = GraphInputSnapshot.SourceIdentity.realtime(damID: "1368080700010")
        let stamp = GraphInputSnapshot.ComparisonStamp(generation: 1, metric: .storageVolume, isReady: true)
        let input = GraphInputSnapshot(identity: identity, rawRows: rows, dataRevision: 0, comparison: stamp)
        let loader = PreparedGraphLoader()

        let base = loader.baseSnapshot(for: input)
        #expect(base.rows.count == 1151)
        #expect(base.timestamps.count == 1151)
        let allYears = Set(payload.availablePastYears)
        let display = loader.displaySnapshot(
            base: input, kind: .volumeFlowHistory, range: .all,
            selectedYears: allYears, isHistorical: false,
            comparisonPayload: payload, rangeStartDate: nil, rangeEndDate: nil,
            meta: nil, localeFingerprint: "true-Asia/Tokyo"
        )
        #expect(display.rows.count == 1151)
        #expect(display.timestamps.count == 1151)
        #expect(display.volumeSegments.count == 1)
        // 線系列はdamChartMaxLinePoints超でmin/maxデシメーションされ、先頭・末尾は保持される。
        // 主系列(貯水量70000の定値)はバケットごとに代表点のみ残る。
        for segments in [display.volumeSegments, display.inflowSegments, display.outflowSegments] {
            let points = segments.first?.points ?? []
            #expect(points.count <= damChartMaxLinePoints + 2)
            #expect(Set(points.map(\.id)).count == points.count)
            #expect(points.first?.date == base.rows.first?.date)
            #expect(points.last?.date == base.rows.last?.date)
        }
        // 過去年系列(48点×24年、全選択)もデシメーションされずに事前計算される。
        #expect(display.pastVolumeSeries.count == 24)
        for series in display.pastVolumeSeries {
            #expect(series.segments.first?.points.count == 48)
            #expect(series.axisLabel == HistoricalComparisonDisplay.yearLabel(series.year, isJapanese: AppLocale.isJapanese))
        }
        #expect(display.drawnPastYears == allYears)
        #expect(loader.baseBuildCount == 1)
        #expect(loader.displayBuildCount == 1)

        _ = loader.baseSnapshot(for: input)
        _ = loader.displaySnapshot(
            base: input, kind: .volumeFlowHistory, range: .all,
            selectedYears: allYears, isHistorical: false,
            comparisonPayload: payload, rangeStartDate: nil, rangeEndDate: nil,
            meta: nil, localeFingerprint: "true-Asia/Tokyo"
        )
        #expect(loader.baseBuildCount == 1)
        #expect(loader.displayBuildCount == 1)
    }

    @Test("Decimation caps points per line while keeping shape and endpoints")
    func decimationCapsPointsAndKeepsExtremes() {
        let start = Date(timeIntervalSince1970: 0)
        // 山と谷を含む単調増加幅の锯歯状系列。
        let points = (0..<3000).map { index -> DamChartPoint in
            let value = Double(index % 100 == 0 ? 100 : (index % 50 == 0 ? -100 : index % 7))
            return DamChartPoint(id: "p\(index)", date: start.addingTimeInterval(Double(index)), value: value)
        }
        let decimated = decimatedChartPoints(points)
        #expect(decimated.count <= damChartMaxLinePoints + 2)
        #expect(decimated.count >= damChartMaxLinePoints / 2)
        #expect(decimated.first?.id == "p0")
        #expect(decimated.last?.id == "p\(2999)")
        // 極値(±100)が保持される。
        #expect(decimated.contains { $0.value == 100 })
        #expect(decimated.contains { $0.value == -100 })
        // 日時昇順かつID重複なし。
        #expect(decimated.map(\.date) == decimated.map(\.date).sorted())
        #expect(Set(decimated.map(\.id)).count == decimated.count)
        // 上限以下の系列はそのまま返る。
        let small = Array(points.prefix(600))
        #expect(decimatedChartPoints(small).map(\.id) == small.map(\.id))
    }

    @Test("Descending row cache returns identical order and refreshes on input change")
    func descendingCacheSemantics() {
        let rows = [
            graphRow("2026/06/08 01:00", storagePercentage: 79),
            graphRow("2026/06/08 02:00", storagePercentage: 78),
            graphRow("2026/06/08 03:00", storagePercentage: 77),
        ]
        let first = DashboardRowCache.descending(rows)
        #expect(first.map(\.row.time) == ["2026/06/08 03:00", "2026/06/08 02:00", "2026/06/08 01:00"])
        // 同一入力の再呼び出しも同じ結果(キャッシュヒット)。
        #expect(DashboardRowCache.descending(rows).map(\.row.id) == first.map(\.row.id))
        // 入力が変われば結果も追従する。
        let changed = [graphRow("2026/06/08 04:00", storagePercentage: 80)] + rows
        let second = DashboardRowCache.descending(changed)
        #expect(second.first?.row.time == "2026/06/08 04:00")
        #expect(second.count == 4)
    }
}

/// 24年分（2002...2025）の過去年を持つペイロードフィクスチャ。
/// 系列点は主系列fixtureのdomain(2026/04/01〜)内に30分間隔で配置する
/// (3時間超のgapでセグメントが分断されないようにする)。
@MainActor
private func fixture24YearPayload() throws -> HistoricalComparisonPayload {
    let series = try (2002...2025).map { year in
        let dayStart = try jstDateTime(year: 2026, month: 4, day: 2, hour: 0, minute: 0)
        let points = try (0..<48).map { index in
            let date = try #require(Calendar.jst.date(byAdding: .minute, value: index * 30, to: dayStart))
            return HistoricalComparisonSeriesPoint(
                id: "\(year)-\(index)",
                date: date,
                value: Float(70000 + index * 100),
                rawTime: ""
            )
        }
        return HistoricalComparisonSeries(year: year, points: points)
    }
    return HistoricalComparisonPayload(
        metric: .storageVolume,
        currentYear: 2026,
        mainYear: 2026,
        availablePastYears: Array(2002...2025),
        periodStart: series.first?.points.first?.date,
        periodEnd: series.first?.points.last?.date,
        pastSeries: series
    )
}

@Suite("Prepared graph loader cache semantics")
@MainActor
struct PreparedGraphLoaderCacheTests {
    private func makeInput(
        identity: GraphInputSnapshot.SourceIdentity = .realtime(damID: "1368080700010"),
        rows: [DamHistoricalData] = fixtureGraphRows(),
        revision: Int = 0,
        generation: Int = 1,
        metric: HistoricalComparisonMetric? = nil,
        isReady: Bool = false
    ) -> GraphInputSnapshot {
        GraphInputSnapshot(
            identity: identity,
            rawRows: rows,
            dataRevision: revision,
            comparison: GraphInputSnapshot.ComparisonStamp(generation: generation, metric: metric, isReady: isReady)
        )
    }

    @Test("Base cache hit keeps build count at one for identical inputs")
    func baseCacheHitsForIdenticalInputs() {
        let loader = PreparedGraphLoader()
        let input = makeInput()
        _ = loader.baseSnapshot(for: input)
        _ = loader.baseSnapshot(for: input)
        #expect(loader.baseBuildCount == 1)
    }

    @Test("Base cache rebuilds on revision, identity, and comparison stamp changes")
    func baseCacheInvalidatesOnRevisionIdentityAndComparison() {
        let loader = PreparedGraphLoader()
        _ = loader.baseSnapshot(for: makeInput(revision: 0))
        #expect(loader.baseBuildCount == 1)
        _ = loader.baseSnapshot(for: makeInput(revision: 1))
        #expect(loader.baseBuildCount == 2)

        _ = loader.baseSnapshot(for: makeInput(identity: .realtime(damID: "other-dam"), revision: 1))
        #expect(loader.baseBuildCount == 3)

        _ = loader.baseSnapshot(for: makeInput(revision: 1, generation: 2))
        #expect(loader.baseBuildCount == 4)

        _ = loader.baseSnapshot(for: makeInput(revision: 1, generation: 2, metric: .storageRate))
        #expect(loader.baseBuildCount == 5)

        _ = loader.baseSnapshot(for: makeInput(revision: 1, generation: 2, metric: .storageRate, isReady: true))
        #expect(loader.baseBuildCount == 6)

        _ = loader.baseSnapshot(for: makeInput(revision: 1, generation: 2, metric: .storageRate, isReady: true))
        #expect(loader.baseBuildCount == 6)
    }

    @Test("Display cache invalidates on display inputs without rebuilding base")
    func displayCacheInvalidatesOnDisplayInputs() throws {
        let loader = PreparedGraphLoader()
        let payload = try fixtureComparisonPayload()
        let input = makeInput(metric: .storageVolume, isReady: true)
        func snapshot(
            kind: ObservationGraphDisplayKind = .volumeFlowHistory,
            range: RealtimeGraphRange = .all,
            selectedYears: Set<Int> = [2024],
            localeFingerprint: String = "true-Asia/Tokyo"
        ) -> GraphDisplaySnapshot {
            loader.displaySnapshot(
                base: input, kind: kind, range: range,
                selectedYears: selectedYears, isHistorical: false,
                comparisonPayload: payload, rangeStartDate: nil, rangeEndDate: nil,
                meta: nil, localeFingerprint: localeFingerprint
            )
        }
        _ = snapshot()
        _ = snapshot()
        #expect(loader.baseBuildCount == 1)
        #expect(loader.displayBuildCount == 1)

        _ = snapshot(range: .past24Hours)
        #expect(loader.baseBuildCount == 1)
        #expect(loader.displayBuildCount == 2)

        _ = snapshot(kind: .rainfallStorageHistory)
        #expect(loader.baseBuildCount == 1)
        #expect(loader.displayBuildCount == 3)

        _ = snapshot(selectedYears: [2025])
        #expect(loader.baseBuildCount == 1)
        #expect(loader.displayBuildCount == 4)

        _ = snapshot(localeFingerprint: "false-America/Los_Angeles")
        #expect(loader.baseBuildCount == 1)
        #expect(loader.displayBuildCount == 5)
    }

    @Test("Display cache invalidates when the payload readiness changes")
    func displayCacheInvalidatesOnPayloadReadiness() {
        let loader = PreparedGraphLoader()
        let loading = makeInput(metric: .storageRate, isReady: false)
        let ready = makeInput(metric: .storageRate, isReady: true)
        func snapshot(_ input: GraphInputSnapshot) -> GraphDisplaySnapshot {
            loader.displaySnapshot(
                base: input, kind: .rainfallStorageHistory, range: .all,
                selectedYears: [2024], isHistorical: false,
                comparisonPayload: nil, rangeStartDate: nil, rangeEndDate: nil,
                meta: nil, localeFingerprint: "true-Asia/Tokyo"
            )
        }
        _ = snapshot(loading)
        _ = snapshot(ready)
        #expect(loader.baseBuildCount == 2)
        #expect(loader.displayBuildCount == 2)
        _ = snapshot(ready)
        #expect(loader.baseBuildCount == 2)
        #expect(loader.displayBuildCount == 2)
    }

    @Test("Display cache evicts the least recently used entry beyond capacity")
    func displayCacheEvictsOldestEntry() {
        let loader = PreparedGraphLoader()
        let input = makeInput()
        for index in 0...(PreparedGraphLoader.displayCacheCapacity) {
            _ = loader.displaySnapshot(
                base: input, kind: .rainfallStorage, range: .all,
                selectedYears: [], isHistorical: false,
                comparisonPayload: nil, rangeStartDate: nil, rangeEndDate: nil,
                meta: nil, localeFingerprint: "fp-\(index)"
            )
        }
        #expect(loader.displayBuildCount == PreparedGraphLoader.displayCacheCapacity + 1)
        _ = loader.displaySnapshot(
            base: input, kind: .rainfallStorage, range: .all,
            selectedYears: [], isHistorical: false,
            comparisonPayload: nil, rangeStartDate: nil, rangeEndDate: nil,
            meta: nil, localeFingerprint: "fp-0"
        )
        #expect(loader.displayBuildCount == PreparedGraphLoader.displayCacheCapacity + 2)
        _ = loader.displaySnapshot(
            base: input, kind: .rainfallStorage, range: .all,
            selectedYears: [], isHistorical: false,
            comparisonPayload: nil, rangeStartDate: nil, rangeEndDate: nil,
            meta: nil, localeFingerprint: "fp-\(PreparedGraphLoader.displayCacheCapacity - 1)"
        )
        #expect(loader.displayBuildCount == PreparedGraphLoader.displayCacheCapacity + 2)
    }

    @Test("Base cache evicts the least recently used identity beyond capacity")
    func baseCacheEvictsOldestIdentity() {
        let loader = PreparedGraphLoader()
        let rows = fixtureGraphRows()
        for index in 0...(PreparedGraphLoader.baseCacheCapacity) {
            _ = loader.baseSnapshot(for: makeInput(identity: .realtime(damID: "dam-\(index)"), rows: rows))
        }
        #expect(loader.baseBuildCount == PreparedGraphLoader.baseCacheCapacity + 1)
        _ = loader.baseSnapshot(for: makeInput(identity: .realtime(damID: "dam-0"), rows: rows))
        #expect(loader.baseBuildCount == PreparedGraphLoader.baseCacheCapacity + 2)
        _ = loader.baseSnapshot(for: makeInput(identity: .realtime(damID: "dam-\(PreparedGraphLoader.baseCacheCapacity - 1)"), rows: rows))
        #expect(loader.baseBuildCount == PreparedGraphLoader.baseCacheCapacity + 2)
    }
}

@Suite("Graph data revision")
@MainActor
struct GraphDataRevisionTests {
    @Test("Realtime fetch parse bumps the graph data revision")
    func realtimeFetchBumpsRevision() async throws {
        let datURL = "https://www1.river.go.jp/dat/1368080700010_202602220520.dat"
        let datBytes = realtimeDatData(rows: [
            realtimeDatRow("2026/02/22", "05:00", storageVolume: 73000, storagePercentage: 73),
            realtimeDatRow("2026/02/22", "05:10", storageVolume: 74000, storagePercentage: 74),
            realtimeDatRow("2026/02/22", "05:20", storageVolume: 75000, storagePercentage: 75.25),
        ])
        let fetcher = FixtureFetcher(responses: [
            "https://www1.river.go.jp/cgi-bin/DspDamData.exe?ID=1368080700010&KIND=3&PAGE=0": Data(#"<html><body><a href="/dat/1368080700010_202602220520.dat">dat</a></body></html>"#.utf8),
            datURL: datBytes,
        ])
        let defaults = try testDefaults()
        let appModel = DamAppModel(
            network: MlitNetworkDataSource(fetcher: fetcher.fetch),
            networkAvailability: FixedNetworkAvailability(isNetworkAvailable: true),
            settingsRepository: SettingsRepository(defaults: defaults),
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults
        )
        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)
        appModel.settings.realtimeDataSource = .mlitDirect
        let before = appModel.graphDataRevision

        await appModel.fetchLatest(workType: "Manual update")

        #expect(appModel.damLoadStatus == .success)
        #expect(appModel.graphDataRevision == before + 1)
    }

    @Test("Opening and filtering a historical search bumps the graph data revision")
    func historicalOpenAndRangeFilterBumpRevision() async throws {
        let context = try inMemoryModelContext()
        let dam = try #require(DamListData.dam(id: "1368080700010"))
        let meta = historicalMeta(dam: dam, start: "20260501", end: "20260502", sortOrder: 0)
        context.insert(HistoricalSearchMetaRecord(meta: meta))
        context.insert(HistoricalDamDataRecord(searchMetaId: meta.id, data: historicalRow(time: "2026/05/01 01:00"), timeMillis: 0))
        context.insert(HistoricalDamDataRecord(searchMetaId: meta.id, data: historicalRow(time: "2026/05/02 01:00"), timeMillis: 1))
        try context.save()

        let appModel = DamAppModel()
        appModel.configure(modelContext: context, launchContext: .background)
        let beforeOpen = appModel.graphDataRevision

        await appModel.openHistorical(metaId: meta.id)
        #expect(appModel.graphDataRevision == beforeOpen + 1)

        let beforeFilter = appModel.graphDataRevision
        appModel.applyHistoricalDisplayRange(startDate: "20260501", endDate: "20260501")
        #expect(appModel.graphDataRevision == beforeFilter + 1)
        #expect(appModel.visibleHistoricalRows.count == 1)

        let beforeReset = appModel.graphDataRevision
        appModel.resetHistoricalDisplayRange()
        #expect(appModel.graphDataRevision == beforeReset + 1)
    }

    @Test("Unrelated settings changes do not bump the graph data revision")
    func unrelatedSettingsDoNotBumpRevision() throws {
        let defaults = try testDefaults()
        let appModel = DamAppModel(
            settingsRepository: SettingsRepository(defaults: defaults),
            widgetGroupDefaults: defaults,
            widgetStandardDefaults: defaults
        )
        appModel.configure(modelContext: try inMemoryModelContext(), launchContext: .background)
        let before = appModel.graphDataRevision

        appModel.updateSettings { settings in
            settings.autoUpdateEnabled = true
        }

        #expect(appModel.graphDataRevision == before)
    }
}
