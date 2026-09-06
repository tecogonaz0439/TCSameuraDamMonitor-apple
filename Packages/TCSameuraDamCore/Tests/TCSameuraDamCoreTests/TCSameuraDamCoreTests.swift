// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Testing
import Foundation
@testable import TCSameuraDamCore

@Suite("DamCoreDamTime date parsing")
struct DamCoreDamTimeTests {
    @Test(arguments: [
        ("2026/05/15 00:00", "2026/05/15 00:00"),
        ("2026/05/15 12:30", "2026/05/15 12:30"),
        ("2026/05/15 23:59", "2026/05/15 23:59"),
        ("2026/05/15 24:00", "2026/05/16 00:00"),
    ])
    func validTimesNormalizeCorrectly(input: String, expected: String) {
        #expect(DamCoreDamTime.normalizedString(input) == expected)
    }

    @Test(arguments: [
        "2026/05/15 24:01",
        "2026/05/15 25:00",
        "2026/05/15 99:99",
        "abc def",
        "",
    ])
    func invalidTimesReturnNil(input: String) {
        #expect(DamCoreDamTime.date(from: input) == nil)
    }

    @Test func validDateMillisecondsRoundtrip() throws {
        #expect(DamCoreDamTime.millis(from: "2026/05/15 05:00") != nil)
    }

    @Test func hourKeyProducesCorrectNormalizedBoundary() {
        #expect(DamCoreDamTime.hourKey(date: "2026/05/15", time: "23:59") == "2026/05/15 23")
        #expect(DamCoreDamTime.hourKey(date: "2026/05/15", time: "24:00") == "2026/05/16 00")
    }

    @Test func hourKeyReturnsNilForInvalidInput() {
        #expect(DamCoreDamTime.hourKey(date: "2026/05/15", time: "25:00") == nil)
    }
}

@Suite("DamCoreTextDecoder")
struct DamCoreTextDecoderTests {
    @Test func decodesUTF8BOMData() {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data("水系名,test\n".utf8))
        let result = DamCoreTextDecoder.decodeMLITText(data)
        #expect(result?.contains("水系名") == true)
    }

    @Test func emptyDataDecodesAsEmptyString() {
        #expect(DamCoreTextDecoder.decodeMLITText(Data()) == "")
    }

    @Test func decodesShiftJISContent() throws {
        let text = "水系名,吉野川"
        let shiftJIS = try #require(text.data(using: DamCoreTextDecoder.shiftJIS))
        let result = DamCoreTextDecoder.decodeMLITText(shiftJIS)
        #expect(result?.contains("水系名") == true)
    }

    @Test func utf8DataConvertsShiftJIS() throws {
        let text = "水系名,吉野川\n観測所名,早明浦ダム\n"
        let shiftJIS: Data = try #require(text.data(using: DamCoreTextDecoder.shiftJIS))
        let converted = try DamCoreTextDecoder.utf8Data(from: shiftJIS)
        #expect(String(data: converted, encoding: .utf8) == text)
    }

    @Test func utf8DataThrowsUnsupportedEncoding() {
        #expect(throws: DamCoreTextDecoderError.unsupportedEncoding) {
            _ = try DamCoreTextDecoder.utf8Data(from: Data([0x80, 0x81, 0x82]))
        }
    }
}

@Suite("DamCoreWidgetMessageKey")
struct DamCoreWidgetMessageKeyTests {
    @Test(arguments: [
        (Float(80), DamCoreWidgetMessageKey.storage80_100),
        (Float(60), DamCoreWidgetMessageKey.storage60_80),
        (Float(40), DamCoreWidgetMessageKey.storage40_60),
        (Float(20), DamCoreWidgetMessageKey.storage20_40),
        (Float(0.01), DamCoreWidgetMessageKey.storage0_20),
        (Float(0), DamCoreWidgetMessageKey.storage0),
        (Float(-0.1), DamCoreWidgetMessageKey.abnormal),
    ])
    func storageKeyMatchesSharedThresholds(percentage: Float, expected: DamCoreWidgetMessageKey) {
        #expect(DamCoreWidgetMessageKey.storageKey(for: percentage) == expected)
    }

    @Test(arguments: [
        (Float(120), DamCoreWidgetMessageKey.storage80_100),
        (Float(80), DamCoreWidgetMessageKey.storage80_100),
        (Float(79.99), DamCoreWidgetMessageKey.storage60_80),
        (Float(60), DamCoreWidgetMessageKey.storage60_80),
        (Float(59.99), DamCoreWidgetMessageKey.storage40_60),
        (Float(40), DamCoreWidgetMessageKey.storage40_60),
        (Float(39.99), DamCoreWidgetMessageKey.storage20_40),
        (Float(20), DamCoreWidgetMessageKey.storage20_40),
        (Float(19.99), DamCoreWidgetMessageKey.storage0_20),
        (Float(0.01), DamCoreWidgetMessageKey.storage0_20),
        (Float(0), DamCoreWidgetMessageKey.storage0),
        (Float(-0.1), DamCoreWidgetMessageKey.storage0),
    ])
    func sameuraStorageKeyMatchesRateOnlyClassification(percentage: Float, expected: DamCoreWidgetMessageKey) {
        #expect(DamCoreWidgetMessageKey.sameuraStorageKey(for: percentage, storageVolumeForMessage: nil) == expected)
    }

    @Test(arguments: [
        (Float(50), Float(80_000), DamCoreWidgetMessageKey.storage60_80),
        (Float(50), Float(90_000), DamCoreWidgetMessageKey.storage60_80),
        (Float(50), Float(79_999), DamCoreWidgetMessageKey.storage40_60),
        (Float(50), Float(60_000), DamCoreWidgetMessageKey.storage40_60),
        (Float(50), Float(59_999), DamCoreWidgetMessageKey.storage20_40),
        (Float(50), Float(40_000), DamCoreWidgetMessageKey.storage20_40),
        (Float(50), Float(39_999), DamCoreWidgetMessageKey.storage0_20),
        (Float(50), Float(0), DamCoreWidgetMessageKey.storage0_20),
        (Float(50), Float(-1), DamCoreWidgetMessageKey.storage0_20),
    ])
    func sameuraStorageKeyUsesVolumeThresholds(
        percentage: Float,
        volume: Float?,
        expected: DamCoreWidgetMessageKey
    ) {
        #expect(DamCoreWidgetMessageKey.sameuraStorageKey(for: percentage, storageVolumeForMessage: volume) == expected)
    }
}

@Suite("DamCoreWidgetMessageLookup")
struct DamCoreWidgetMessageLookupTests {
    private func makeLookup(
        messages: [String: String]?,
        sameuraFallback: @escaping @Sendable (DamCoreWidgetMessageKey) -> String,
        otherFallback: @escaping @Sendable (DamCoreWidgetMessageKey) -> String
    ) -> DamCoreWidgetMessageLookup {
        DamCoreWidgetMessageLookup(
            messages: messages,
            storageFallback: { _ in "legacy storage fallback" },
            specialFallback: { key in key == .allDataInvalid ? "all invalid" : "abnormal" },
            sameuraStorageFallback: sameuraFallback,
            otherStorageFallback: otherFallback
        )
    }

    @Test func sameuraMessageResolvesSameuraDictionaryKeys() {
        let lookup = makeLookup(
            messages: ["60_80": "sameura custom"],
            sameuraFallback: { _ in "sameura fallback" },
            otherFallback: { _ in "other fallback" }
        )
        #expect(lookup.sameuraMessage(for: 50, storageVolumeForMessage: 90_000) == "sameura custom")
        #expect(lookup.sameuraMessage(for: 50, storageVolumeForMessage: 70_000) == "sameura fallback")
    }

    @Test func sameuraMessageUsesRateKeysWithoutVolume() {
        let lookup = makeLookup(
            messages: ["80_100": "full", "0": "empty"],
            sameuraFallback: { key in "sameura \(key.rawValue)" },
            otherFallback: { _ in "other fallback" }
        )
        #expect(lookup.sameuraMessage(for: 81, storageVolumeForMessage: nil) == "full")
        #expect(lookup.sameuraMessage(for: 0, storageVolumeForMessage: nil) == "empty")
        #expect(lookup.sameuraMessage(for: 79, storageVolumeForMessage: nil) == "sameura 60_80")
        #expect(lookup.sameuraMessage(for: -1, storageVolumeForMessage: 90_000) == "empty")
    }

    @Test func sameuraMessageReturnsEmptyForEmptyDictionary() {
        let lookup = makeLookup(
            messages: [:],
            sameuraFallback: { _ in "sameura fallback" },
            otherFallback: { _ in "other fallback" }
        )
        #expect(lookup.sameuraMessage(for: 50, storageVolumeForMessage: 70_000) == "")
    }

    @Test func otherMessageResolvesPrefixedDictionaryKeys() {
        let lookup = makeLookup(
            messages: ["other_80_100": "other custom"],
            sameuraFallback: { _ in "sameura fallback" },
            otherFallback: { _ in "other fallback" }
        )
        #expect(lookup.otherMessage(for: 85) == "other custom")
        #expect(lookup.otherMessage(for: 55) == "other fallback")
    }

    @Test func otherMessageUsesOtherPrefixedKeysPerThreshold() {
        var messages: [String: String] = [:]
        for key in [DamCoreWidgetMessageKey.storage80_100, .storage60_80, .storage40_60, .storage20_40, .storage0_20, .storage0, .abnormal] {
            messages["other_\(key.rawValue)"] = "other \(key.rawValue)"
        }
        let lookup = makeLookup(
            messages: messages,
            sameuraFallback: { _ in "sameura fallback" },
            otherFallback: { _ in "other fallback" }
        )
        #expect(lookup.otherMessage(for: 81) == "other 80_100")
        #expect(lookup.otherMessage(for: 70) == "other 60_80")
        #expect(lookup.otherMessage(for: 50) == "other 40_60")
        #expect(lookup.otherMessage(for: 30) == "other 20_40")
        #expect(lookup.otherMessage(for: 10) == "other 0_20")
        #expect(lookup.otherMessage(for: 0) == "other 0")
        #expect(lookup.otherMessage(for: -1) == "other 0")
    }

    @Test func legacyInitKeepsMessageAndSpecialMessageBehavior() {
        let lookup = DamCoreWidgetMessageLookup(
            messages: ["80_100": "custom high"],
            storageFallback: { _ in "fallback storage" },
            specialFallback: { key in key == .allDataInvalid ? "all invalid" : "abnormal" }
        )
        #expect(lookup.message(for: 81) == "custom high")
        #expect(lookup.message(for: 50) == "fallback storage")
        #expect(lookup.specialMessage(for: .allDataInvalid) == "all invalid")
        #expect(lookup.sameuraMessage(for: 81, storageVolumeForMessage: nil) == "custom high")
        #expect(lookup.otherMessage(for: 81) == "")
    }
}

@Suite("DamCoreWidgetPresentation")
struct DamCoreWidgetPresentationTests {
    @Test func formatsWidgetValuesAndTrends() {
        #expect(DamCoreWidgetPresentation.percent(75.256) == "75.26%")
        #expect(DamCoreWidgetPresentation.percent(nil) == "-- %")
        #expect(DamCoreWidgetPresentation.volume(12_345.6) == "12346")
        #expect(DamCoreWidgetPresentation.trendGlyph("up") == "↗")
        #expect(DamCoreWidgetPresentation.trendGlyph("down") == "↘")
        #expect(DamCoreWidgetPresentation.trendGlyph("flat") == "→")
        #expect(DamCoreWidgetPresentation.trendGlyph("unknown") == "")
    }

    @Test func notificationMessageUsesObservedTimePercentageTrendAndMessage() throws {
        let snapshot = DamCoreWidgetSnapshot(
            damName: "Sameura Dam",
            updatedAt: "2026/05/15 24:00",
            observedAt: "2026/05/15 24:00",
            storagePercentage: 75.25,
            trend: "up",
            storageVolume: 75_000,
            storageVolumeTrend: "up",
            storagePercentageDayChange: 1.2,
            dayChangeTrend: "up",
            storagePercentageWeekChange: -3.4,
            weekChangeTrend: "down",
            message: "Stable",
            isNetworkError: false,
            isAllDataInvalid: false,
            lastUpdatedAt: try #require(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 5, day: 16)))
        )

        #expect(DamCoreWidgetPresentation.notificationMessage(snapshot: snapshot, currentTimeZoneIdentifier: "Asia/Tokyo") == "Sameura Dam 2026/05/16 00:00 75.25% ↗ Stable")
        #expect(DamCoreWidgetPresentation.notificationMessage(snapshot: snapshot, currentTimeZoneIdentifier: "Etc/GMT-9") == "Sameura Dam 2026/05/16 00:00 75.25% ↗ Stable")
        #expect(DamCoreWidgetPresentation.notificationMessage(snapshot: snapshot, currentTimeZoneIdentifier: "UTC").contains("00:00 (JST)"))
    }

    @Test func accessoryInlineTextUsesInitialPlaceholderAndSnapshotStates() {
        let snapshot = DamCoreWidgetSnapshot(
            damName: "Sameura Dam",
            updatedAt: "2026/05/15 10:00",
            observedAt: "2026/05/15 10:00",
            storagePercentage: 62.5,
            trend: "flat",
            storageVolume: nil,
            storageVolumeTrend: nil,
            storagePercentageDayChange: nil,
            dayChangeTrend: nil,
            storagePercentageWeekChange: nil,
            weekChangeTrend: nil,
            message: "😌 Stable",
            isNetworkError: false,
            isAllDataInvalid: false,
            lastUpdatedAt: Date(timeIntervalSinceReferenceDate: 0)
        )

        #expect(DamCoreWidgetPresentation.accessoryInlineText(snapshot: nil, placeholderMessage: "No data", initialMessage: "Open app") == "Open app")
        #expect(DamCoreWidgetPresentation.accessoryInlineText(snapshot: snapshot, placeholderMessage: "No data", initialMessage: "Open app") == "😌 62.50% →")
    }
}

@Suite("DamCoreWidgetSnapshotFactory")
struct DamCoreWidgetSnapshotFactoryTests {
    @Test func makeSnapshotUsesConfiguredStorageMessage() {
        let fields = DamCoreWidgetParser.SnapshotFields(
            updatedAt: "2026/05/15 10:00",
            observedAt: "2026/05/15 10:00",
            storagePercentage: 81,
            trend: "up",
            storageVolume: 70_000,
            storageVolumeTrend: "up",
            storagePercentageDayChange: 1,
            dayChangeTrend: "up",
            storagePercentageWeekChange: 2,
            weekChangeTrend: "up",
            isAllDataInvalid: false
        )
        let lookup = DamCoreWidgetMessageLookup(
            messages: [DamCoreWidgetMessageKey.storage80_100.rawValue: "custom high"],
            storageFallback: { _ in "fallback storage" },
            specialFallback: { _ in "fallback special" }
        )

        let snapshot = DamCoreWidgetSnapshotFactory.makeSnapshot(
            damName: "Sameura Dam",
            fields: fields,
            messageLookup: lookup,
            isSameura: true,
            lastUpdatedAt: Date(timeIntervalSinceReferenceDate: 1)
        )

        #expect(snapshot.message == "custom high")
        #expect(snapshot.storagePercentage == 81)
        #expect(snapshot.trend == "up")
        #expect(snapshot.isNetworkError == false)
        #expect(snapshot.isSameura == true)
        #expect(snapshot.storageVolumeForMessage == nil)
    }

    @Test func makeSnapshotUsesSameuraVolumeClassificationMessage() {
        let fields = DamCoreWidgetParser.SnapshotFields(
            updatedAt: "2026/05/15 10:00",
            observedAt: "2026/05/15 10:00",
            storagePercentage: 55,
            trend: "flat",
            storageVolume: 70_000,
            storageVolumeTrend: nil,
            storagePercentageDayChange: nil,
            dayChangeTrend: nil,
            storagePercentageWeekChange: nil,
            weekChangeTrend: nil,
            isAllDataInvalid: false
        )
        let lookup = DamCoreWidgetMessageLookup(
            messages: [
                DamCoreWidgetMessageKey.storage60_80.rawValue: "sameura 60-80",
                "other_80_100": "other 80-100",
            ],
            storageFallback: { _ in "fallback storage" },
            specialFallback: { _ in "fallback special" },
            sameuraStorageFallback: { key in "sameura fallback \(key.rawValue)" },
            otherStorageFallback: { key in "other fallback \(key.rawValue)" }
        )

        let snapshot = DamCoreWidgetSnapshotFactory.makeSnapshot(
            damName: "Sameura Dam",
            fields: fields,
            messageLookup: lookup,
            isSameura: true,
            storageVolumeForMessage: 90_000,
            lastUpdatedAt: Date(timeIntervalSinceReferenceDate: 1)
        )

        #expect(snapshot.message == "sameura 60-80")
        #expect(snapshot.isSameura == true)
        #expect(snapshot.storageVolumeForMessage == 90_000)
    }

    @Test func makeSnapshotUsesOtherPrefixedMessageWhenNotSameura() {
        let fields = DamCoreWidgetParser.SnapshotFields(
            updatedAt: "2026/05/15 10:00",
            observedAt: "2026/05/15 10:00",
            storagePercentage: 85,
            trend: "up",
            storageVolume: 90_000,
            storageVolumeTrend: nil,
            storagePercentageDayChange: nil,
            dayChangeTrend: nil,
            storagePercentageWeekChange: nil,
            weekChangeTrend: nil,
            isAllDataInvalid: false
        )
        let lookup = DamCoreWidgetMessageLookup(
            messages: [
                DamCoreWidgetMessageKey.storage80_100.rawValue: "sameura 80-100",
                "other_80_100": "other 80-100",
            ],
            storageFallback: { _ in "fallback storage" },
            specialFallback: { _ in "fallback special" },
            sameuraStorageFallback: { key in "sameura fallback \(key.rawValue)" },
            otherStorageFallback: { key in "other fallback \(key.rawValue)" }
        )

        let snapshot = DamCoreWidgetSnapshotFactory.makeSnapshot(
            damName: "Other Dam",
            fields: fields,
            messageLookup: lookup,
            isSameura: false,
            storageVolumeForMessage: 90_000,
            lastUpdatedAt: Date(timeIntervalSinceReferenceDate: 1)
        )

        #expect(snapshot.message == "other 80-100")
        #expect(snapshot.isSameura == false)
        #expect(snapshot.storageVolumeForMessage == 90_000)
    }

    @Test func makeSnapshotFallsBackToOtherFallbackForMissingOtherKey() {
        let fields = DamCoreWidgetParser.SnapshotFields(
            updatedAt: "2026/05/15 10:00",
            observedAt: "2026/05/15 10:00",
            storagePercentage: 55,
            trend: "flat",
            storageVolume: nil,
            storageVolumeTrend: nil,
            storagePercentageDayChange: nil,
            dayChangeTrend: nil,
            storagePercentageWeekChange: nil,
            weekChangeTrend: nil,
            isAllDataInvalid: false
        )
        let lookup = DamCoreWidgetMessageLookup(
            messages: ["80_100": "sameura high"],
            storageFallback: { _ in "fallback storage" },
            specialFallback: { _ in "fallback special" },
            sameuraStorageFallback: { key in "sameura fallback \(key.rawValue)" },
            otherStorageFallback: { key in "other fallback \(key.rawValue)" }
        )

        let snapshot = DamCoreWidgetSnapshotFactory.makeSnapshot(
            damName: "Other Dam",
            fields: fields,
            messageLookup: lookup,
            isSameura: false,
            lastUpdatedAt: Date(timeIntervalSinceReferenceDate: 1)
        )

        #expect(snapshot.message == "other fallback 40_60")
    }

    @Test func makeSnapshotUsesSpecialMessageForInvalidRows() {
        let fields = DamCoreWidgetParser.SnapshotFields(
            updatedAt: "2026/05/15 10:00",
            observedAt: nil,
            storagePercentage: nil,
            trend: "unknown",
            storageVolume: nil,
            storageVolumeTrend: nil,
            storagePercentageDayChange: nil,
            dayChangeTrend: nil,
            storagePercentageWeekChange: nil,
            weekChangeTrend: nil,
            isAllDataInvalid: true
        )
        let lookup = DamCoreWidgetMessageLookup(
            messages: nil,
            storageFallback: { _ in "fallback storage" },
            specialFallback: { key in key == .allDataInvalid ? "all invalid" : "abnormal" }
        )

        let snapshot = DamCoreWidgetSnapshotFactory.makeSnapshot(
            damName: "Sameura Dam",
            fields: fields,
            messageLookup: lookup,
            lastUpdatedAt: Date(timeIntervalSinceReferenceDate: 1)
        )

        #expect(snapshot.message == "all invalid")
        #expect(snapshot.observedAt == "")
    }
}

@Suite("DamCoreWidgetSnapshot")
struct DamCoreWidgetSnapshotTests {
    private func makeSnapshot(isSameura: Bool = false, storageVolumeForMessage: Float? = nil) throws -> DamCoreWidgetSnapshot {
        DamCoreWidgetSnapshot(
            damName: "Sameura Dam",
            updatedAt: "2026/05/15 10:00",
            observedAt: "2026/05/15 10:00",
            storagePercentage: 55,
            trend: "flat",
            storageVolume: 70_000,
            storageVolumeTrend: nil,
            storagePercentageDayChange: nil,
            dayChangeTrend: nil,
            storagePercentageWeekChange: nil,
            weekChangeTrend: nil,
            message: "custom",
            isNetworkError: false,
            isAllDataInvalid: false,
            isSameura: isSameura,
            storageVolumeForMessage: storageVolumeForMessage,
            lastUpdatedAt: try #require(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 5, day: 15)))
        )
    }

    @Test func codableRoundtripPreservesSameuraFields() throws {
        let snapshot = try makeSnapshot(isSameura: true, storageVolumeForMessage: 70_000)
        let encoded = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(DamCoreWidgetSnapshot.self, from: encoded)
        #expect(decoded.isSameura == true)
        #expect(decoded.storageVolumeForMessage == 70_000)
    }

    @Test func legacySnapshotJSONWithoutSameuraKeysDecodes() throws {
        let snapshot = try makeSnapshot()
        let encoded = try JSONEncoder().encode(snapshot)
        var json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json.removeValue(forKey: "isSameura")
        json.removeValue(forKey: "storageVolumeForMessage")
        let legacyData = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(DamCoreWidgetSnapshot.self, from: legacyData)
        #expect(decoded.isSameura == false)
        #expect(decoded.storageVolumeForMessage == nil)
        #expect(decoded.storagePercentage == 55)
        #expect(decoded.damName == "Sameura Dam")
    }
}

@Suite("DamCoreMlitURLPolicy")
struct DamCoreMlitURLPolicyTests {
    @Test func isAllowedMLITURLAcceptsCorrectHost() throws {
        let url = try #require(URL(string: "https://www1.river.go.jp/cgi-bin/test"))
        #expect(DamCoreMlitURLPolicy.isAllowedMLITURL(url))
    }

    @Test func isAllowedMLITURLAcceptsExplicitHTTPSPort() throws {
        let url = try #require(URL(string: "https://www1.river.go.jp:443/cgi-bin/test"))
        #expect(DamCoreMlitURLPolicy.isAllowedMLITURL(url))
    }

    @Test func isAllowedMLITURLRejectsWrongHost() throws {
        let url = try #require(URL(string: "https://example.com/cgi-bin/test"))
        #expect(!DamCoreMlitURLPolicy.isAllowedMLITURL(url))
    }

    @Test func isAllowedMLITURLRejectsHTTPScheme() throws {
        let url = try #require(URL(string: "http://www1.river.go.jp/cgi-bin/test"))
        #expect(!DamCoreMlitURLPolicy.isAllowedMLITURL(url))
    }

    @Test(arguments: [
        "https://user@www1.river.go.jp/cgi-bin/test",
        "https://user:pass@www1.river.go.jp/cgi-bin/test",
        "https://www1.river.go.jp:444/cgi-bin/test",
        "https://www1.river.go.jp/cgi-bin/test#fragment",
    ])
    func isAllowedMLITURLRejectsUnsafeComponents(input: String) throws {
        let url = try #require(URL(string: input))
        #expect(!DamCoreMlitURLPolicy.isAllowedMLITURL(url))
    }

    @Test func isAllowedDatURLAcceptsDotDatSuffix() throws {
        let url = try #require(URL(string: "https://www1.river.go.jp/dat/1.dat"))
        #expect(DamCoreMlitURLPolicy.isAllowedDatURL(url))
    }

    @Test func isAllowedDatURLRejectsNonDatSuffix() throws {
        let url = try #require(URL(string: "https://www1.river.go.jp/cgi-bin/test"))
        #expect(!DamCoreMlitURLPolicy.isAllowedDatURL(url))
    }

    @Test func resolvedDatURLResolvesRelativePath() {
        let url = DamCoreMlitURLPolicy.resolvedDatURL(from: "/dat/DspDamData_1368080700010.dat")
        #expect(url?.absoluteString == "https://www1.river.go.jp/dat/DspDamData_1368080700010.dat")
    }

    @Test func resolvedDatURLResolvesAbsolutePath() {
        let url = DamCoreMlitURLPolicy.resolvedDatURL(from: "https://www1.river.go.jp/dat/DspDamData_1368080700010.dat")
        #expect(url?.absoluteString == "https://www1.river.go.jp/dat/DspDamData_1368080700010.dat")
    }

    @Test func resolvedDatURLUpgradesHTTPToHTTPS() {
        let url = DamCoreMlitURLPolicy.resolvedDatURL(from: "http://www1.river.go.jp/dat/1.dat")
        #expect(url?.scheme == "https")
    }

    @Test func resolvedDatURLRejectsNonDatPath() {
        #expect(DamCoreMlitURLPolicy.resolvedDatURL(from: "https://www1.river.go.jp/not-dat.txt") == nil)
    }

    @Test func resolvedDatURLRejectsExternalHost() {
        #expect(DamCoreMlitURLPolicy.resolvedDatURL(from: "https://example.com/dat/1.dat") == nil)
    }

    @Test func validatedMLITURLReturnsURLForValidInput() throws {
        let url = try DamCoreMlitURLPolicy.validatedMLITURL(from: "https://www1.river.go.jp/test")
        #expect(url.host == "www1.river.go.jp")
    }

    @Test func validatedMLITURLThrowsForInvalidHost() {
        #expect(throws: DamCoreMlitURLPolicyError.invalidMLITURL) {
            try DamCoreMlitURLPolicy.validatedMLITURL(from: "https://example.com/test")
        }
    }

    @Test func validateRejectsOversizedContentLength() {
        let response = URLResponse(
            url: URL(string: "https://www1.river.go.jp/test")!,
            mimeType: "text/plain",
            expectedContentLength: DamCoreMlitURLPolicy.maxResponseBytes + 1,
            textEncodingName: "utf-8"
        )
        #expect(throws: DamCoreMlitURLPolicyError.responseTooLarge) {
            try DamCoreMlitURLPolicy.validate(data: Data(), response: response)
        }
    }

    @Test func validateRejectsBadHTTPStatus() {
        let response = HTTPURLResponse(
            url: URL(string: "https://www1.river.go.jp/test")!,
            statusCode: 503,
            httpVersion: nil,
            headerFields: nil
        )!
        #expect(throws: DamCoreMlitURLPolicyError.badHTTPStatus(503)) {
            try DamCoreMlitURLPolicy.validate(data: Data(), response: response)
        }
    }

    @Test func validateRejectsOversizedBody() {
        let response = URLResponse(
            url: URL(string: "https://www1.river.go.jp/test")!,
            mimeType: "text/plain",
            expectedContentLength: 1,
            textEncodingName: "utf-8"
        )
        let oversizedData = Data(repeating: 0, count: DamCoreMlitURLPolicy.maxResponseBytes + 1)
        #expect(throws: DamCoreMlitURLPolicyError.responseTooLarge) {
            try DamCoreMlitURLPolicy.validate(data: oversizedData, response: response)
        }
    }

    @Test func collectAllowsExactMaximumByteCount() async throws {
        let bytes = byteStream(count: DamCoreMlitURLPolicy.maxResponseBytes)
        let data = try await DamCoreMlitNetwork.collect(bytes: bytes)
        #expect(data.count == DamCoreMlitURLPolicy.maxResponseBytes)
    }

    @Test func collectRejectsAboveMaximumByteCount() async {
        let bytes = byteStream(count: DamCoreMlitURLPolicy.maxResponseBytes + 1)
        await #expect(throws: DamCoreMlitURLPolicyError.responseTooLarge) {
            _ = try await DamCoreMlitNetwork.collect(bytes: bytes)
        }
    }

    @Test func validateRejectsInvalidFinalURL() {
        let response = URLResponse(
            url: URL(string: "https://example.com/test")!,
            mimeType: "text/plain",
            expectedContentLength: 1,
            textEncodingName: "utf-8"
        )
        #expect(throws: DamCoreMlitURLPolicyError.invalidMLITURL) {
            try DamCoreMlitURLPolicy.validate(data: Data(), response: response)
        }
    }

    @Test func makeRequestSetsUserAgentAndTimeout() throws {
        let url = try #require(URL(string: "https://www1.river.go.jp/test"))
        let request = DamCoreMlitURLPolicy.makeRequest(url: url)
        #expect(request.value(forHTTPHeaderField: "User-Agent") == DamCoreMlitURLPolicy.userAgent)
        #expect(request.timeoutInterval == DamCoreMlitURLPolicy.requestTimeout)
    }
}

@Suite("DamCoreURLPolicy")
struct DamCoreURLPolicyTests {
    @Test func mlitPresetMatchesLegacyStaticPolicy() {
        #expect(DamCoreURLPolicy.mlit.allowedHost == DamCoreMlitURLPolicy.allowedHost)
        #expect(DamCoreURLPolicy.mlit.userAgent == DamCoreMlitURLPolicy.userAgent)
        #expect(DamCoreURLPolicy.mlit.maxResponseBytes == DamCoreMlitURLPolicy.maxResponseBytes)
        #expect(DamCoreURLPolicy.mlit.isAllowedURL(URL(string: "https://www1.river.go.jp/cgi-bin/DspDamData.exe")!))
        #expect(!DamCoreURLPolicy.mlit.isAllowedURL(URL(string: "https://sudmonitor.kusugami-lab.net/v1/realtime/1/latest.dat")!))
    }

    @Test func sudmonitorPresetAllowsSudmonitorHostOnly() throws {
        let policy = DamCoreURLPolicy.sudmonitor(userAgent: "TCSameuraDamMonitor-Apple/1.0.0")
        let url = try policy.validatedURL(from: "https://sudmonitor.kusugami-lab.net/v1/realtime/1368080700010/latest.dat")
        #expect(policy.isAllowedURL(url))
        #expect(policy.isAllowedDatURL(url))
        #expect(throws: DamCoreMlitURLPolicyError.invalidMLITURL) {
            _ = try policy.validatedURL(from: "https://www1.river.go.jp/cgi-bin/DspDamData.exe")
        }
        #expect(throws: DamCoreMlitURLPolicyError.invalidMLITURL) {
            _ = try policy.validatedURL(from: "http://sudmonitor.kusugami-lab.net/v1/realtime/1/latest.dat")
        }
    }

    @Test func sudmonitorPresetRequiresDatSuffixForDatURLs() throws {
        let policy = DamCoreURLPolicy.sudmonitor(userAgent: "TCSameuraDamMonitor-Apple/1.0.0")
        let datURL = try #require(URL(string: "https://sudmonitor.kusugami-lab.net/v1/realtime/1/latest.dat"))
        let jsonURL = try #require(URL(string: "https://sudmonitor.kusugami-lab.net/v1/status.json"))
        #expect(policy.isAllowedDatURL(datURL))
        #expect(policy.isAllowedURL(jsonURL))
        #expect(!policy.isAllowedDatURL(jsonURL))
    }

    @Test func sudmonitorPresetUsesProvidedUserAgent() throws {
        let policy = DamCoreURLPolicy.sudmonitor(userAgent: "TCSameuraDamMonitor-Apple/9.9.9")
        let url = try #require(URL(string: "https://sudmonitor.kusugami-lab.net/v1/realtime/1/latest.dat"))
        let request = policy.makeRequest(url: url)
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "TCSameuraDamMonitor-Apple/9.9.9")
    }

    @Test func sudmonitorHistoryPresetAllowsHistoryFiles() throws {
        let policy = DamCoreURLPolicy.sudmonitorHistory(userAgent: "TCSameuraDamMonitor-Apple/1.0.0")
        let latest = try #require(URL(string: "https://sudmonitor.kusugami-lab.net/v1/history/1368080700010/latest.dat"))
        let monthly = try #require(URL(string: "https://sudmonitor.kusugami-lab.net/v1/history/1368080700010/1368080700010_202607010100_202607312400.dat"))
        #expect(policy.isAllowedURL(latest))
        #expect(policy.isAllowedURL(monthly))
        #expect(policy.isAllowedDatURL(latest))
        #expect(policy.isAllowedDatURL(monthly))
    }

    @Test func sudmonitorHistoryPresetRejectsNonHistoryPaths() throws {
        let policy = DamCoreURLPolicy.sudmonitorHistory(userAgent: "TCSameuraDamMonitor-Apple/1.0.0")
        #expect(throws: DamCoreMlitURLPolicyError.invalidMLITURL) {
            _ = try policy.validatedURL(from: "https://sudmonitor.kusugami-lab.net/v1/realtime/1368080700010/latest.dat")
        }
        #expect(throws: DamCoreMlitURLPolicyError.invalidMLITURL) {
            _ = try policy.validatedURL(from: "https://sudmonitor.kusugami-lab.net/v1/dams.json")
        }
        #expect(throws: DamCoreMlitURLPolicyError.invalidMLITURL) {
            _ = try policy.validatedURL(from: "https://sudmonitor.kusugami-lab.net/v1/history_extra/1368080700010/latest.dat")
        }
    }

    @Test func defaultPolicyHasNoPathRestriction() throws {
        let policy = DamCoreURLPolicy.sudmonitor(userAgent: "TCSameuraDamMonitor-Apple/1.0.0")
        let realtimeURL = try #require(URL(string: "https://sudmonitor.kusugami-lab.net/v1/realtime/1/latest.dat"))
        let jsonURL = try #require(URL(string: "https://sudmonitor.kusugami-lab.net/v1/dams.json"))
        #expect(policy.isAllowedURL(realtimeURL))
        #expect(policy.isAllowedURL(jsonURL))
        #expect(policy.allowedPathPrefix == nil)
    }
}

@Suite("DamCoreHTTPHeaders")
struct DamCoreHTTPHeadersTests {
    @Test func valueLookupIsCaseInsensitive() {
        let headers = ["X-TCS-Dam-Id": "1368080700010", "Content-Type": "application/octet-stream"]
        #expect(DamCoreHTTPHeaders.value(headers, forField: "X-TCS-Dam-Id") == "1368080700010")
        #expect(DamCoreHTTPHeaders.value(headers, forField: "x-tcs-dam-id") == "1368080700010")
        #expect(DamCoreHTTPHeaders.value(headers, forField: "X-TCS-Fetched-At") == nil)
    }
}

@Suite("DamCoreRawDatBridge")
struct DamCoreRawDatBridgeTests {
    @Test func codableRoundtripPreservesAllFields() throws {
        let original = DamCoreRawDatBridge(
            stationId: "1368080700010",
            dataUrl: "https://www1.river.go.jp/dat/test.dat",
            fetchedAt: Date(timeIntervalSince1970: 1000),
            rawBytes: Data("test raw".utf8),
            rawDatFileName: "test.dat"
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DamCoreRawDatBridge.self, from: encoded)
        #expect(decoded.stationId == "1368080700010")
        #expect(decoded.dataUrl == "https://www1.river.go.jp/dat/test.dat")
        #expect(decoded.fetchedAt == original.fetchedAt)
        #expect(decoded.rawBytes == Data("test raw".utf8))
        #expect(decoded.rawDatFileName == "test.dat")
        #expect(decoded.version == DamCoreRawDatBridge.currentVersion)
    }

    @Test func codableRoundtripPreservesNilFilename() throws {
        let original = DamCoreRawDatBridge(
            stationId: "1368080700010",
            dataUrl: "https://www1.river.go.jp/dat/test.dat",
            fetchedAt: Date(timeIntervalSince1970: 1000),
            rawBytes: Data("test raw".utf8)
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DamCoreRawDatBridge.self, from: encoded)
        #expect(decoded.rawDatFileName == nil)
    }
}

@Suite("DamCoreWidgetFetchGate")
struct DamCoreWidgetFetchGateTests {
    @Test func autoUpdateOffBlocksNoCacheFetch() {
        let now = Date(timeIntervalSince1970: 1000)
        let decision = DamCoreWidgetFetchGate.decision(
            initialLoadDone: true,
            autoUpdateEnabled: false,
            debugSimulationActive: false,
            hasUsableCache: false,
            lastFetchAt: nil,
            nextRefresh: nil,
            now: now
        )

        #expect(decision == DamCoreWidgetFetchDecision(allowed: false, reason: "autoUpdateDisabled"))
    }

    @Test func autoUpdateOnAllowsNoCacheFetchAfterInitialLoad() {
        let now = Date(timeIntervalSince1970: 1000)
        let decision = DamCoreWidgetFetchGate.decision(
            initialLoadDone: true,
            autoUpdateEnabled: true,
            debugSimulationActive: false,
            hasUsableCache: false,
            lastFetchAt: nil,
            nextRefresh: nil,
            now: now
        )

        #expect(decision == DamCoreWidgetFetchDecision(allowed: true, reason: "noUsableCache"))
    }

    @Test func initialLoadBlocksFetchBeforeAutoUpdateState() {
        let now = Date(timeIntervalSince1970: 1000)
        let decision = DamCoreWidgetFetchGate.decision(
            initialLoadDone: false,
            autoUpdateEnabled: true,
            debugSimulationActive: false,
            hasUsableCache: false,
            lastFetchAt: nil,
            nextRefresh: now,
            now: now
        )

        #expect(decision == DamCoreWidgetFetchDecision(allowed: false, reason: "initialLoadNotDone"))
    }

    @Test func throttleBlocksFetchBeforeOtherReasons() {
        let now = Date(timeIntervalSince1970: 1000)
        let decision = DamCoreWidgetFetchGate.decision(
            initialLoadDone: true,
            autoUpdateEnabled: true,
            debugSimulationActive: false,
            hasUsableCache: false,
            lastFetchAt: now.addingTimeInterval(-60),
            nextRefresh: now,
            now: now
        )

        #expect(decision == DamCoreWidgetFetchDecision(allowed: false, reason: "throttled"))
    }
}

@Suite("DamCoreRedirectRejectingDelegate")
struct DamCoreRedirectRejectingDelegateTests {
    @Test func redirectDelegateRejectsRedirect() {
        let delegate = DamCoreRedirectRejectingDelegate()
        let session = URLSession.shared
        let task = session.dataTask(with: URL(string: "https://example.com")!)
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 302,
            httpVersion: nil,
            headerFields: nil
        )!
        let request = URLRequest(url: URL(string: "https://example.com/redirect")!)

        var callbackCalled = false
        delegate.urlSession(session, task: task, willPerformHTTPRedirection: response, newRequest: request) { newRequest in
            #expect(newRequest == nil)
            callbackCalled = true
        }
        #expect(callbackCalled)
    }
}

@Suite("DamCoreWidgetParser")
struct DamCoreWidgetParserTests {
    private static let shiftJISEncoding = DamCoreTextDecoder.shiftJIS

    private static func makeShiftJISData(_ text: String) throws -> Data {
        try #require(text.data(using: shiftJISEncoding))
    }

    @Test func parseRowsFromValidDataReturnsParsedRows() throws {
        let text = """
        # comment line
        2026/05/15,00:10,0, ,0, ,0, ,0, ,80.5, 
        2026/05/15,00:20,0, ,0, ,0, ,0, ,81.0, 
        """
        let data = try Self.makeShiftJISData(text)
        let rows = try #require(DamCoreWidgetParser.parseRows(from: data))
        #expect(rows.count == 2)
        let first = rows[0]
        #expect(first.date == "2026/05/15")
        #expect(first.time == "00:10")
        #expect(first.columns.count > 5)
    }

    @Test func parseRowsFromEmptyDataReturnsNil() {
        #expect(DamCoreWidgetParser.parseRows(from: Data()) == nil)
    }

    @Test func parseRowsFromCommentOnlyDataReturnsEmptyArray() throws {
        let text = "# only comment\n# another comment\n"
        let data = try Self.makeShiftJISData(text)
        let rows = try #require(DamCoreWidgetParser.parseRows(from: data))
        #expect(rows.isEmpty)
    }

    @Test(arguments: [" ", ""])
    func isAttributeNormalWithSpaceOrEmpty(attr: String) {
        let row = DamCoreWidgetParser.ParsedRow(date: "2026/05/15", time: "00:10", columns: ["2026/05/15", "00:10", "0", attr])
        #expect(DamCoreWidgetParser.isAttributeNormal(row, 2))
    }

    @Test(arguments: ["-", "$", "#"])
    func isAttributeNormalWithAbnormalValue(attr: String) {
        let row = DamCoreWidgetParser.ParsedRow(date: "2026/05/15", time: "00:10", columns: ["2026/05/15", "00:10", "0", attr])
        #expect(!DamCoreWidgetParser.isAttributeNormal(row, 2))
    }

    @Test func floatValueValidExtraction() {
        let row = DamCoreWidgetParser.ParsedRow(date: "2026/05/15", time: "00:10", columns: ["", "", "42.5"])
        #expect(DamCoreWidgetParser.floatValue(row, 2) == 42.5)
    }

    @Test func floatValueNilForMissingColumn() {
        let row = DamCoreWidgetParser.ParsedRow(date: "2026/05/15", time: "00:10", columns: ["a", "b"])
        #expect(DamCoreWidgetParser.floatValue(row, 10) == nil)
    }

    @Test func storagePercentageExtractsFromLastRow() throws {
        let text = """
        2026/05/15,00:10,0, ,0, ,0, ,0, ,80.5, 
        2026/05/15,00:20,0, ,0, ,0, ,0, ,81.0, 
        """
        let data = try Self.makeShiftJISData(text)
        let rows = try #require(DamCoreWidgetParser.parseRows(from: data))
        let result = DamCoreWidgetParser.storagePercentage(from: rows)
        #expect(result.percentage == 81.0)
        #expect(result.observedAt == "2026/05/15 00:20")
        #expect(result.index != nil)
    }

    @Test func trendUpWhenLatestGreater() throws {
        let text = """
        2026/05/15,00:10,0, ,0, ,0, ,0, ,80.5, 
        2026/05/15,00:20,0, ,0, ,0, ,0, ,81.0, 
        """
        let data = try Self.makeShiftJISData(text)
        let rows = try #require(DamCoreWidgetParser.parseRows(from: data))
        let storageResult = DamCoreWidgetParser.storagePercentage(from: rows)
        let index = try #require(storageResult.index)
        let percentage = try #require(storageResult.percentage)
        #expect(DamCoreWidgetParser.trend(from: rows, latestPercentage: percentage, latestIndex: index) == "up")
    }

    @Test func trendDownWhenLatestLess() throws {
        let text = """
        2026/05/15,00:10,0, ,0, ,0, ,0, ,81.0, 
        2026/05/15,00:20,0, ,0, ,0, ,0, ,80.5, 
        """
        let data = try Self.makeShiftJISData(text)
        let rows = try #require(DamCoreWidgetParser.parseRows(from: data))
        let storageResult = DamCoreWidgetParser.storagePercentage(from: rows)
        let index = try #require(storageResult.index)
        let percentage = try #require(storageResult.percentage)
        #expect(DamCoreWidgetParser.trend(from: rows, latestPercentage: percentage, latestIndex: index) == "down")
    }

    @Test func trendFlatWhenEqual() throws {
        let text = """
        2026/05/15,00:10,0, ,0, ,0, ,0, ,80.5, 
        2026/05/15,00:20,0, ,0, ,0, ,0, ,80.5, 
        """
        let data = try Self.makeShiftJISData(text)
        let rows = try #require(DamCoreWidgetParser.parseRows(from: data))
        let storageResult = DamCoreWidgetParser.storagePercentage(from: rows)
        let index = try #require(storageResult.index)
        let percentage = try #require(storageResult.percentage)
        #expect(DamCoreWidgetParser.trend(from: rows, latestPercentage: percentage, latestIndex: index) == "flat")
    }

    @Test func trendUnknownWhenNoPrevious() throws {
        let text = """
        2026/05/15,00:20,0, ,0, ,0, ,0, ,81.0, 
        """
        let data = try Self.makeShiftJISData(text)
        let rows = try #require(DamCoreWidgetParser.parseRows(from: data))
        #expect(DamCoreWidgetParser.trend(from: rows, latestPercentage: 81.0, latestIndex: 0) == "unknown")
    }

    @Test func pctChangeReturnsDiff() throws {
        let text = """
        2026/05/15,00:10,0, ,0, ,0, ,0, ,80.5, 
        2026/05/15,00:20,0, ,0, ,0, ,0, ,81.0, 
        """
        let data = try Self.makeShiftJISData(text)
        let rows = try #require(DamCoreWidgetParser.parseRows(from: data))
        let (diff, compare) = DamCoreWidgetParser.pctChange(rows: rows, column: 10, latestValidRowIndex: 0, offset: nil)
        #expect(diff == 0.5)
        #expect(compare == 80.5)
    }

    @Test(arguments: [(Float(0.5), "up"), (Float(-0.5), "down"), (Float(0.0), "flat"), (Float(0.00005), "flat")])
    func trendStringForDiff(diff: Float, expected: String) {
        #expect(DamCoreWidgetParser.trendString(for: diff) == expected)
    }

    @Test func trendStringUnknownForNil() {
        #expect(DamCoreWidgetParser.trendString(for: nil) == "unknown")
    }

    @Test("Widget realtime snapshot fields are parsed from a known DAT fixture")
    func snapshotFieldsFromKnownRealtimeDatFixture() throws {
        let rows = [
            "2026/05/08,00:00,0, ,78000, ,0, ,0, ,78.0, ",
            "2026/05/15,00:00,0, ,80000, ,0, ,0, ,80.0, ",
            "2026/05/15,00:10,0, ,81000, ,0, ,0, ,81.5, ",
        ]
        let data = try Self.makeShiftJISData(rows.joined(separator: "\n"))

        let fields = try #require(DamCoreWidgetParser.snapshotFields(from: data))

        #expect(fields.updatedAt == "2026/05/15 00:10")
        #expect(fields.observedAt == "2026/05/15 00:10")
        #expect(fields.storagePercentage == Float(81.5))
        #expect(fields.trend == "up")
        #expect(fields.storageVolume == Float(81000))
        #expect(fields.storageVolumeTrend == "up")
        #expect(fields.storagePercentageDayChange == Float(3.5))
        #expect(fields.dayChangeTrend == "up")
        #expect(fields.storagePercentageWeekChange == Float(3.5))
        #expect(fields.weekChangeTrend == "up")
        #expect(!fields.isAllDataInvalid)
    }

    @Test func snapshotFieldsStorageVolumeForMessageFallsBackToLatestNormalVolume() throws {
        let rows = [
            "2026/05/15,00:00,0, ,78000, ,0, ,0, ,70.0, ",
            "2026/05/15,00:10,0, ,-, ,0, ,0, ,70.5, ",
            "2026/05/15,00:20,0, ,-, ,0, ,0, ,71.0, ",
        ]
        let data = try Self.makeShiftJISData(rows.joined(separator: "\n"))

        let fields = try #require(DamCoreWidgetParser.snapshotFields(from: data))

        #expect(fields.storageVolume == nil)
        #expect(fields.storageVolumeForMessage == Float(78000))
    }

    @Test func snapshotFieldsStorageVolumeForMessageUsesLatestNormalVolume() throws {
        let rows = [
            "2026/05/15,00:00,0, ,78000, ,0, ,0, ,70.0, ",
            "2026/05/15,00:10,0, ,79000, ,0, ,0, ,70.5, ",
        ]
        let data = try Self.makeShiftJISData(rows.joined(separator: "\n"))

        let fields = try #require(DamCoreWidgetParser.snapshotFields(from: data))

        #expect(fields.storageVolume == Float(79000))
        #expect(fields.storageVolumeForMessage == Float(79000))
    }

    @Test func snapshotFieldsStorageVolumeForMessageIsNilWhenNoNormalVolumeExists() throws {
        let rows = [
            "2026/05/15,00:00,0, ,-, ,0, ,0, ,70.0, ",
            "2026/05/15,00:10,0, ,-, ,0, ,0, ,70.5, ",
        ]
        let data = try Self.makeShiftJISData(rows.joined(separator: "\n"))

        let fields = try #require(DamCoreWidgetParser.snapshotFields(from: data))

        #expect(fields.storageVolume == nil)
        #expect(fields.storageVolumeForMessage == nil)
    }
}

@Suite("DamCoreJSTSupport")
struct DamCoreJSTSupportTests {
    @Test func offsetBasedDetectionTreatsEtcGmtMinus9AsJst() {
        #expect(DamCoreJSTSupport.isJst(TimeZone(identifier: "Asia/Tokyo")))
        #expect(DamCoreJSTSupport.isJst(identifier: "Asia/Tokyo"))
        #expect(DamCoreJSTSupport.isJst(identifier: "Etc/GMT-9"))
        #expect(!DamCoreJSTSupport.isJst(identifier: "UTC"))
        #expect(!DamCoreJSTSupport.isJst(identifier: "America/Los_Angeles"))
        #expect(!DamCoreJSTSupport.isJst(identifier: nil))
        #expect(!DamCoreJSTSupport.isJst(identifier: "NoSuchZone/Invalid"))
    }

    @Test func appendingJstSuffixIsIdempotent() {
        #expect(DamCoreJSTSupport.appendingJstSuffix("05:15", isLocalJst: false) == "05:15 (JST)")
        #expect(DamCoreJSTSupport.appendingJstSuffix("05:15 (JST)", isLocalJst: false) == "05:15 (JST)")
        #expect(DamCoreJSTSupport.appendingJstSuffix("2026/05/16 09:30", isLocalJst: false) == "2026/05/16 09:30 (JST)")
        #expect(DamCoreJSTSupport.appendingJstSuffix("05:15", isLocalJst: true) == "05:15")
        #expect(DamCoreJSTSupport.appendingJstSuffix("05:15 (JST)", isLocalJst: true) == "05:15 (JST)")
    }

    @Test func observedAtUsesOffsetBasedJstDetectionForSuffix() {
        #expect(DamCoreWidgetPresentation.observedAt("2026/05/16 09:30", currentTimeZoneIdentifier: "Etc/GMT-9") == "2026/05/16 09:30")
        #expect(DamCoreWidgetPresentation.observedAt("2026/05/16 09:30", currentTimeZoneIdentifier: "UTC") == "2026/05/16 09:30 (JST)")
        #expect(DamCoreWidgetPresentation.observedAt("2026/05/16 09:30", currentTimeZoneIdentifier: "NoSuchZone/Invalid") == "2026/05/16 09:30 (JST)")

        let etcGmt9 = DamCoreWidgetPresentation.observedAtParts("2026/05/16 09:30", currentTimeZoneIdentifier: "Etc/GMT-9")
        #expect(etcGmt9.date == "2026/05/16")
        #expect(etcGmt9.time == "09:30")
        let utc = DamCoreWidgetPresentation.observedAtParts("2026/05/16 09:30", currentTimeZoneIdentifier: "UTC")
        #expect(utc.time == "09:30 (JST)")
        let invalid = DamCoreWidgetPresentation.observedAtParts("2026/05/16 09:30", currentTimeZoneIdentifier: "NoSuchZone/Invalid")
        #expect(invalid.time == "09:30 (JST)")
    }

    @Test func notificationMessageTreatsEtcGmtMinus9AsJst() throws {
        let snapshot = DamCoreWidgetSnapshot(
            damName: "Sameura Dam",
            updatedAt: "2026/05/15 24:00",
            observedAt: "2026/05/15 24:00",
            storagePercentage: 75.25,
            trend: "up",
            storageVolume: 75_000,
            storageVolumeTrend: "up",
            storagePercentageDayChange: nil,
            dayChangeTrend: nil,
            storagePercentageWeekChange: nil,
            weekChangeTrend: nil,
            message: "Stable",
            isNetworkError: false,
            isAllDataInvalid: false,
            lastUpdatedAt: try #require(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 5, day: 16)))
        )
        #expect(DamCoreWidgetPresentation.notificationMessage(snapshot: snapshot, currentTimeZoneIdentifier: "Etc/GMT-9") == "Sameura Dam 2026/05/16 00:00 75.25% ↗ Stable")
        #expect(DamCoreWidgetPresentation.notificationMessage(snapshot: snapshot, currentTimeZoneIdentifier: "UTC") == "Sameura Dam 2026/05/16 00:00 (JST) 75.25% ↗ Stable")
    }
}

private func byteStream(count: Int) -> AsyncStream<UInt8> {
    AsyncStream { continuation in
        for _ in 0..<count {
            continuation.yield(1)
        }
        continuation.finish()
    }
}
