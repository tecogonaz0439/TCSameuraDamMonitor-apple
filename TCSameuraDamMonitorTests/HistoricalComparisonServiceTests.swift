// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Testing
import Foundation
@testable import TCSameuraDamMonitor

/// 過去比較グラフサービスの年写像・毎時axis・月次エントリ選択・月次asset読込のテスト。
@Suite("Historical comparison service")
struct HistoricalComparisonServiceTests {
    private let sameuraId = "1368080700010"

    // MARK: - availablePastYears

    @Test("availablePastYears returns 2002...2025 for the JST year 2026")
    func availablePastYearsIn2026() throws {
        let now2026 = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let service = HistoricalComparisonService(now: { now2026 })
        #expect(service.availablePastYears() == Array(2002...2025))
    }

    @Test("availablePastYears uses the JST year independent of the device timezone")
    func availablePastYearsUsesJSTYear() throws {
        let boundaryJST2026 = try utcDate(year: 2025, month: 12, day: 31, hour: 15, minute: 0)
        #expect(HistoricalComparisonService(now: { boundaryJST2026 }).availablePastYears() == Array(2002...2025))
        let boundaryJST2025 = try utcDate(year: 2025, month: 12, day: 31, hour: 14, minute: 59)
        #expect(HistoricalComparisonService(now: { boundaryJST2025 }).availablePastYears() == Array(2002...2024))
        let in2002 = try jstDate(year: 2002, month: 6, day: 27, hour: 0, minute: 0)
        #expect(HistoricalComparisonService(now: { in2002 }).availablePastYears() == [])
    }

    @Test("currentJstYear returns the JST year independent of the device timezone")
    func currentJstYearUsesJST() throws {
        let boundaryJST2026 = try utcDate(year: 2025, month: 12, day: 31, hour: 15, minute: 0)
        #expect(HistoricalComparisonService(now: { boundaryJST2026 }).currentJstYear() == 2026)
        let boundaryJST2025 = try utcDate(year: 2025, month: 12, day: 31, hour: 14, minute: 59)
        #expect(HistoricalComparisonService(now: { boundaryJST2025 }).currentJstYear() == 2025)
        let in2002 = try jstDate(year: 2002, month: 6, day: 27, hour: 0, minute: 0)
        #expect(HistoricalComparisonService(now: { in2002 }).currentJstYear() == 2002)
    }

    @Test("availablePastYears is the current JST year exclusive while currentJstYear includes it")
    func availablePastYearsExcludesCurrentYear() throws {
        let now2026 = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let service = HistoricalComparisonService(now: { now2026 })
        #expect(service.currentJstYear() == 2026)
        #expect(!service.availablePastYears().contains(service.currentJstYear()))
    }

    // MARK: - mapDate

    @Test("mapDate maps to the target year keeping month/day/hour/minute")
    func mapDateNormal() throws {
        let source = try jstDate(year: 2026, month: 6, day: 27, hour: 13, minute: 45)
        let expected = try jstDate(year: 2002, month: 6, day: 27, hour: 13, minute: 45)
        #expect(HistoricalComparisonService.mapDate(source, from: 2026, to: 2002, calendar: .jst) == expected)
    }

    @Test("mapDate crosses year boundaries by the relative year difference")
    func mapDateAcrossYearBoundary() throws {
        let source = try jstDate(year: 2025, month: 12, day: 31, hour: 12, minute: 0)
        let expected = try jstDate(year: 2001, month: 12, day: 31, hour: 12, minute: 0)
        #expect(HistoricalComparisonService.mapDate(source, from: 2026, to: 2002, calendar: .jst) == expected)
    }

    @Test("mapDate returns nil for Feb 29 in a non-leap target year")
    func mapDateLeapDayNil() throws {
        let source = try jstDate(year: 2024, month: 2, day: 29, hour: 10, minute: 0)
        #expect(HistoricalComparisonService.mapDate(source, from: 2024, to: 2025, calendar: .jst) == nil)
        let leapExpected = try jstDate(year: 2004, month: 2, day: 29, hour: 10, minute: 0)
        #expect(HistoricalComparisonService.mapDate(source, from: 2024, to: 2004, calendar: .jst) == leapExpected)
    }

    // MARK: - hourlyAxis

    @Test("hourlyAxis floors both ends and includes them")
    func hourlyAxisFloorsEnds() throws {
        let start = try jstDate(year: 2026, month: 6, day: 27, hour: 13, minute: 47)
        let end = try jstDate(year: 2026, month: 6, day: 27, hour: 16, minute: 20)
        #expect(HistoricalComparisonService.hourlyAxis(from: start, to: end, calendar: .jst) == [
            try jstDate(year: 2026, month: 6, day: 27, hour: 13, minute: 0),
            try jstDate(year: 2026, month: 6, day: 27, hour: 14, minute: 0),
            try jstDate(year: 2026, month: 6, day: 27, hour: 15, minute: 0),
            try jstDate(year: 2026, month: 6, day: 27, hour: 16, minute: 0),
        ])
    }

    @Test("hourlyAxis returns an empty array when the end precedes the start")
    func hourlyAxisEndBeforeStart() throws {
        let start = try jstDate(year: 2026, month: 6, day: 27, hour: 16, minute: 0)
        let end = try jstDate(year: 2026, month: 6, day: 27, hour: 15, minute: 0)
        #expect(HistoricalComparisonService.hourlyAxis(from: start, to: end, calendar: .jst) == [])
    }

    @Test("hourlyAxis builds one-hour steps")
    func hourlyAxisSteps() throws {
        let start = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 59)
        let end = try jstDate(year: 2026, month: 6, day: 27, hour: 13, minute: 1)
        #expect(HistoricalComparisonService.hourlyAxis(from: start, to: end, calendar: .jst) == [
            try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0),
            try jstDate(year: 2026, month: 6, day: 27, hour: 13, minute: 0),
        ])
    }

    // MARK: - monthEntries

    @Test("monthEntries includes the previous-month file for a start on the 1st")
    func monthEntriesIncludesPreviousDayFile() throws {
        let may = monthlyEntry(year: 2002, month: 5, filePath: "may.dat")
        let june = monthlyEntry(year: 2002, month: 6, filePath: "june.dat")
        let start = try jstDate(year: 2002, month: 6, day: 1, hour: 0, minute: 0)
        #expect(HistoricalComparisonService.monthEntries(entries: [may, june], stationId: sameuraId,
                                                        start: start, end: start, calendar: .jst) == [may, june])
    }

    @Test("monthEntries excludes months outside the extended range")
    func monthEntriesExcludesNonIntersecting() throws {
        let may = monthlyEntry(year: 2002, month: 5, filePath: "may.dat")
        let june = monthlyEntry(year: 2002, month: 6, filePath: "june.dat")
        let start = try jstDate(year: 2002, month: 6, day: 15, hour: 0, minute: 0)
        let end = try jstDate(year: 2002, month: 6, day: 15, hour: 23, minute: 0)
        #expect(HistoricalComparisonService.monthEntries(entries: [may, june], stationId: sameuraId,
                                                        start: start, end: end, calendar: .jst) == [june])
    }

    @Test("monthEntries returns an empty array for January 2002 without an entry")
    func monthEntriesEmptyForJanuary2002() throws {
        let june = monthlyEntry(year: 2002, month: 6, filePath: "june.dat")
        let start = try jstDate(year: 2002, month: 1, day: 15, hour: 0, minute: 0)
        let end = try jstDate(year: 2002, month: 1, day: 15, hour: 23, minute: 0)
        #expect(HistoricalComparisonService.monthEntries(entries: [june], stationId: sameuraId,
                                                        start: start, end: end, calendar: .jst) == [])
    }

    // MARK: - load errors

    @Test("load rejects an unsupported dam without touching the dataLoader")
    func loadUnsupportedDam() async throws {
        let now2026 = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let counter = LoadCounter()
        let store = HistoricalComparisonAssetStore(entries: [monthlyEntry(year: 2002, month: 6, filePath: "june.dat")]) { _ in
            counter.increment()
            return nil
        }
        let service = HistoricalComparisonService(now: { now2026 }, assetStore: store)
        await #expect(throws: HistoricalComparisonServiceError.unsupportedDam) {
            _ = try await service.load(damConfigId: "other", rows: [comparisonRow("2026/6/27 12:00")], metric: .storageRate)
        }
        #expect(counter.count == 0)
    }

    @Test("load rejects empty rows without touching the dataLoader")
    func loadEmptyRows() async throws {
        let now2026 = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let counter = LoadCounter()
        let store = HistoricalComparisonAssetStore(entries: []) { _ in
            counter.increment()
            return nil
        }
        let service = HistoricalComparisonService(now: { now2026 }, assetStore: store)
        await #expect(throws: HistoricalComparisonServiceError.noRows) {
            _ = try await service.load(damConfigId: sameuraId, rows: [], metric: .storageRate)
        }
        #expect(counter.count == 0)
    }

    // MARK: - load integration

    @Test("load builds the payload with all 24 past years from monthly assets")
    func loadIntegration() async throws {
        let now2026 = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let entries = juneEntries(2002...2025)
        let store = HistoricalComparisonAssetStore(entries: entries, dataLoader: june27DataLoader())
        let service = HistoricalComparisonService(now: { now2026 }, assetStore: store)
        let payload = try await service.load(damConfigId: sameuraId, rows: [
            comparisonRow("2026/6/27 12:00"),
            comparisonRow("2026/6/27 13:00"),
        ], metric: .storageRate)
        #expect(payload.metric == .storageRate)
        #expect(payload.currentYear == 2026)
        #expect(payload.mainYear == 2026)
        #expect(payload.availablePastYears == Array(2002...2025))
        let expectedStart = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let expectedEnd = try jstDate(year: 2026, month: 6, day: 27, hour: 13, minute: 0)
        #expect(payload.periodStart == expectedStart)
        #expect(payload.periodEnd == expectedEnd)
        #expect(payload.pastSeries.count == 24)
        for (index, series) in payload.pastSeries.enumerated() {
            let year = 2002 + index
            #expect(series.year == year)
            #expect(series.id == year)
            #expect(series.points.count == 2)
            #expect(series.points[0].value == 50.0)
            #expect(series.points[1].value == 51.0)
            #expect(series.points[0].rawTime == "\(year)/6/27 12:00")
            #expect(series.points[1].rawTime == "\(year)/6/27 13:00")
            #expect(series.points[0].id == "\(year)-0")
            #expect(series.points[1].id == "\(year)-1")
        }
    }

    @Test("load reads storage volume values for the volume metric")
    func loadStorageVolumeMetric() async throws {
        let now2026 = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let store = HistoricalComparisonAssetStore(entries: juneEntries(2002...2025), dataLoader: june27DataLoader())
        let service = HistoricalComparisonService(now: { now2026 }, assetStore: store)
        let payload = try await service.load(damConfigId: sameuraId, rows: [
            comparisonRow("2026/6/27 12:00"),
            comparisonRow("2026/6/27 13:00"),
        ], metric: .storageVolume)
        let series2002 = payload.pastSeries.first { $0.year == 2002 }
        #expect(series2002?.points[0].value == 200000.0)
        #expect(series2002?.points[1].value == 201000.0)
    }

    @Test("a January span leaves 2002 nil while 2003 loads from its January asset")
    func loadJanuary2002Span() async throws {
        let now2026 = try jstDate(year: 2026, month: 1, day: 27, hour: 12, minute: 0)
        let january2003 = HistoricalDatFileEntry(stationId: sameuraId, startDatetime: "200301010100",
                                                 endDatetime: "200301312400", filePath: "2003-jan.dat")
        let store = HistoricalComparisonAssetStore(entries: [january2003]) { entry in
            guard let year = Int(entry.startDatetime.prefix(4)) else { return nil }
            return historicalDatData(rows: [
                historicalDatRow("\(year)/1/27", "12:00", storageVolume: 300000, storagePercentage: 30.0),
            ])
        }
        let service = HistoricalComparisonService(now: { now2026 }, assetStore: store)
        let payload = try await service.load(damConfigId: sameuraId, rows: [comparisonRow("2026/1/27 12:00")],
                                            metric: .storageRate)
        #expect(payload.pastSeries.count == 24)
        let series2002 = payload.pastSeries.first { $0.year == 2002 }
        #expect(series2002?.points.count == 1)
        #expect(series2002?.points[0].value == nil)
        let series2003 = payload.pastSeries.first { $0.year == 2003 }
        #expect(series2003?.points[0].value == 30.0)
    }

    @Test("24:00 rows normalize to the next day 00:00 and month-boundary points deduplicate first-wins")
    func loadNormalizes2400AndDeduplicates() async throws {
        let now2026 = try jstDate(year: 2026, month: 6, day: 30, hour: 23, minute: 0)
        let entries = (2002...2025).flatMap { year in
            [
                HistoricalDatFileEntry(stationId: sameuraId, startDatetime: "\(year)06010100",
                                       endDatetime: "\(year)06302400", filePath: "\(year)-june.dat"),
                HistoricalDatFileEntry(stationId: sameuraId, startDatetime: "\(year)07010100",
                                       endDatetime: "\(year)07312400", filePath: "\(year)-july.dat"),
            ]
        }
        let store = HistoricalComparisonAssetStore(entries: entries) { entry in
            guard let year = Int(entry.startDatetime.prefix(4)),
                  let month = Int(entry.startDatetime.prefix(6).suffix(2)) else { return nil }
            if month == 6 {
                return historicalDatData(rows: [
                    historicalDatRow("\(year)/6/30", "23:00", storageVolume: 60000, storagePercentage: 60.0),
                    historicalDatRow("\(year)/6/30", "24:00", storageVolume: 61000, storagePercentage: 61.0),
                ])
            }
            return historicalDatData(rows: [
                historicalDatRow("\(year)/7/1", "00:00", storageVolume: 62000, storagePercentage: 62.0),
            ])
        }
        let service = HistoricalComparisonService(now: { now2026 }, assetStore: store)
        let payload = try await service.load(damConfigId: sameuraId, rows: [
            comparisonRow("2026/6/30 23:00"),
            comparisonRow("2026/7/1 00:00"),
        ], metric: .storageRate)
        let series2002 = payload.pastSeries.first { $0.year == 2002 }
        #expect(series2002?.points.count == 2)
        #expect(series2002?.points[0].value == 60.0)
        #expect(series2002?.points[1].value == 61.0)
        #expect(series2002?.points[1].rawTime == "2002/6/30 24:00")
        let june30Axis = try jstDate(year: 2026, month: 6, day: 30, hour: 23, minute: 0)
        let july1Axis = try jstDate(year: 2026, month: 7, day: 1, hour: 0, minute: 0)
        #expect(series2002?.points[0].date == june30Axis)
        #expect(series2002?.points[1].date == july1Axis)
    }

    @Test("quality-missing hourly points map to nil values")
    func loadQualityMissingNil() async throws {
        let now2026 = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let store = HistoricalComparisonAssetStore(entries: juneEntries(2002...2025)) { entry in
            guard let year = Int(entry.startDatetime.prefix(4)) else { return nil }
            return historicalDatData(rows: [
                historicalDatRow("\(year)/6/27", "12:00", storageVolume: 200000, storagePercentage: 50.0),
                historicalDatRow("\(year)/6/27", "13:00", storageVolume: 201000, storagePercentage: 51.0, pctQuality: "$"),
            ])
        }
        let service = HistoricalComparisonService(now: { now2026 }, assetStore: store)
        let payload = try await service.load(damConfigId: sameuraId, rows: [
            comparisonRow("2026/6/27 12:00"),
            comparisonRow("2026/6/27 13:00"),
        ], metric: .storageRate)
        let series2002 = payload.pastSeries.first { $0.year == 2002 }
        #expect(series2002?.points[0].value == 50.0)
        #expect(series2002?.points[1].value == nil)
    }

    @Test("a missing asset fails the whole load with assetLoadFailed")
    func loadMissingAssetFailsWholeLoad() async throws {
        let now2026 = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let entry = HistoricalDatFileEntry(stationId: sameuraId, startDatetime: "200206010100",
                                           endDatetime: "200206302400", filePath: "missing.dat")
        let store = HistoricalComparisonAssetStore(entries: [entry]) { _ in nil }
        let service = HistoricalComparisonService(now: { now2026 }, assetStore: store)
        await #expect(throws: HistoricalComparisonServiceError.assetLoadFailed("missing.dat")) {
            _ = try await service.load(damConfigId: sameuraId, rows: [
                comparisonRow("2026/6/27 12:00"),
                comparisonRow("2026/6/27 13:00"),
            ], metric: .storageRate)
        }
    }

    @Test("a single parse failure fails the whole load without partial success")
    func loadPartialSuccessForbidden() async throws {
        let now2026 = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let entries = juneEntries(2002...2025)
        let store = HistoricalComparisonAssetStore(entries: entries) { entry in
            guard let year = Int(entry.startDatetime.prefix(4)) else { return nil }
            if year == 2010 { return historicalDatData(rows: []) }
            return june27Bytes(year: year)
        }
        let service = HistoricalComparisonService(now: { now2026 }, assetStore: store)
        do {
            _ = try await service.load(damConfigId: sameuraId, rows: [
                comparisonRow("2026/6/27 12:00"),
                comparisonRow("2026/6/27 13:00"),
            ], metric: .storageRate)
            Issue.record("load must fail for the broken 2010 asset")
        } catch HistoricalComparisonServiceError.assetLoadFailed(let path) {
            #expect(path.contains("2010"))
        }
    }

    @Test("load reads each monthly asset exactly once via the injected dataLoader")
    func loadDataLoaderCallCount() async throws {
        let now2026 = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let counter = LoadCounter()
        let store = HistoricalComparisonAssetStore(entries: juneEntries(2002...2025)) { entry in
            counter.increment()
            guard let year = Int(entry.startDatetime.prefix(4)) else { return nil }
            return june27Bytes(year: year)
        }
        let service = HistoricalComparisonService(now: { now2026 }, assetStore: store)
        _ = try await service.load(damConfigId: sameuraId, rows: [
            comparisonRow("2026/6/27 12:00"),
            comparisonRow("2026/6/27 13:00"),
        ], metric: .storageRate)
        #expect(counter.count == 24)
    }

    // MARK: - loadBase

    @Test("loadBase plus payload derivation equals load for both metrics")
    func loadBaseAndPayloadEquivalenceForBothMetrics() async throws {
        let now2026 = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let store = HistoricalComparisonAssetStore(entries: juneEntries(2002...2025), dataLoader: june27DataLoader())
        let service = HistoricalComparisonService(now: { now2026 }, assetStore: store)
        let rows = [
            comparisonRow("2026/6/27 12:00"),
            comparisonRow("2026/6/27 13:00"),
        ]
        let base = try await service.loadBase(damConfigId: sameuraId, rows: rows)
        for metric in [HistoricalComparisonMetric.storageRate, .storageVolume] {
            let expected = try await service.load(damConfigId: sameuraId, rows: rows, metric: metric)
            let derived = service.payload(from: base, metric: metric)
            #expect(derived == expected)
            for (derivedSeries, expectedSeries) in zip(derived.pastSeries, expected.pastSeries) {
                #expect(derivedSeries.year == expectedSeries.year)
                for (derivedPoint, expectedPoint) in zip(derivedSeries.points, expectedSeries.points) {
                    #expect(derivedPoint.id == expectedPoint.id)
                    #expect(derivedPoint.date == expectedPoint.date)
                    #expect(derivedPoint.value == expectedPoint.value)
                    #expect(derivedPoint.rawTime == expectedPoint.rawTime)
                }
            }
        }
    }

    @Test("loadBase loads the deduplicated union of month entries with bounded concurrency")
    func loadBaseLoadsUnionEntriesOnceAcrossAllYears() async throws {
        let now2026 = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let counter = ConcurrencyCounter()
        let store = HistoricalComparisonAssetStore(entries: juneEntries(2002...2025)) { entry in
            counter.enter()
            defer { counter.exit() }
            guard let year = Int(entry.startDatetime.prefix(4)) else { return nil }
            return june27Bytes(year: year)
        }
        let service = HistoricalComparisonService(now: { now2026 }, assetStore: store)
        _ = try await service.loadBase(damConfigId: sameuraId, rows: [
            comparisonRow("2026/6/27 12:00"),
            comparisonRow("2026/6/27 13:00"),
        ])
        #expect(counter.loadCount == 24)
        #expect(counter.maxConcurrent <= 4)
    }

    @Test("payload derivation performs no additional asset loads")
    func payloadDerivationDoesNotTouchAssets() async throws {
        let now2026 = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let counter = LoadCounter()
        let store = HistoricalComparisonAssetStore(entries: juneEntries(2002...2025)) { entry in
            counter.increment()
            guard let year = Int(entry.startDatetime.prefix(4)) else { return nil }
            return june27Bytes(year: year)
        }
        let service = HistoricalComparisonService(now: { now2026 }, assetStore: store)
        let rows = [
            comparisonRow("2026/6/27 12:00"),
            comparisonRow("2026/6/27 13:00"),
        ]
        let base = try await service.loadBase(damConfigId: sameuraId, rows: rows)
        let loadCountAfterBase = counter.count
        #expect(loadCountAfterBase == 24)
        let rate = service.payload(from: base, metric: .storageRate)
        _ = service.payload(from: base, metric: .storageVolume)
        #expect(counter.count == loadCountAfterBase)
        #expect(rate.pastSeries[0].points[0].value == 50.0)
        #expect(rate.pastSeries[0].points[1].value == 51.0)
    }

    @Test("a year without entries yields an empty series from the base")
    func emptyYearProducesEmptySeriesFromBase() async throws {
        let now2026 = try jstDate(year: 2026, month: 1, day: 27, hour: 12, minute: 0)
        let january2003 = HistoricalDatFileEntry(stationId: sameuraId, startDatetime: "200301010100",
                                                 endDatetime: "200301312400", filePath: "2003-jan.dat")
        let store = HistoricalComparisonAssetStore(entries: [january2003]) { entry in
            guard let year = Int(entry.startDatetime.prefix(4)) else { return nil }
            return historicalDatData(rows: [
                historicalDatRow("\(year)/1/27", "12:00", storageVolume: 300000, storagePercentage: 30.0),
            ])
        }
        let service = HistoricalComparisonService(now: { now2026 }, assetStore: store)
        let base = try await service.loadBase(damConfigId: sameuraId, rows: [comparisonRow("2026/1/27 12:00")])
        let payload = service.payload(from: base, metric: .storageRate)
        let series2002 = payload.pastSeries.first { $0.year == 2002 }
        #expect(series2002?.points.count == 1)
        #expect(series2002?.points[0].id == "2002-0")
        #expect(series2002?.points[0].value == nil)
        #expect(series2002?.points[0].rawTime == "")
        let series2003 = payload.pastSeries.first { $0.year == 2003 }
        #expect(series2003?.points[0].value == 30.0)
        #expect(series2003?.points[0].rawTime == "2003/1/27 12:00")
    }

    @Test("loadBase respects cooperative cancellation")
    func loadBaseRespectsCancellation() async throws {
        let now2026 = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let store = HistoricalComparisonAssetStore(entries: juneEntries(2002...2025)) { entry in
            Thread.sleep(forTimeInterval: 0.02)
            guard let year = Int(entry.startDatetime.prefix(4)) else { return nil }
            return june27Bytes(year: year)
        }
        let service = HistoricalComparisonService(now: { now2026 }, assetStore: store)
        let task = Task {
            try await service.loadBase(damConfigId: sameuraId, rows: [comparisonRow("2026/6/27 12:00")])
        }
        task.cancel()
        do {
            _ = try await task.value
        } catch {
            #expect(error is CancellationError)
        }
    }

    // MARK: - mainYear (normal historical display)

    @Test("comparisonYears excludes the base year from 2002...clockYear and is empty below 2002")
    func comparisonYearsExcludesBaseYear() {
        #expect(HistoricalComparisonService.comparisonYears(forBaseYear: 2026, clockYear: 2026) == Array(2002...2025))
        #expect(HistoricalComparisonService.comparisonYears(forBaseYear: 2018, clockYear: 2026)
                == Array(2002...2026).filter { $0 != 2018 })
        #expect(HistoricalComparisonService.comparisonYears(forBaseYear: 2001, clockYear: 2001) == [])
        #expect(HistoricalComparisonService.comparisonYears(forBaseYear: 2002, clockYear: 2002) == [])
    }

    @Test("mainYear mode compares through the JST current year and reports the displayed year as the main series")
    func loadWithMainYear() async throws {
        let now2026 = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let store = HistoricalComparisonAssetStore(entries: juneEntries(2002...2026), dataLoader: june27DataLoader())
        let service = HistoricalComparisonService(now: { now2026 }, assetStore: store)
        let rows = [
            comparisonRow("2018/6/27 12:00"),
            comparisonRow("2018/6/27 13:00"),
        ]
        let payload = try await service.load(damConfigId: sameuraId, rows: rows,
                                             metric: .storageRate, mainYear: 2018)
        #expect(payload.mainYear == 2018)
        #expect(payload.currentYear == 2026)
        #expect(payload.availablePastYears == Array(2002...2026).filter { $0 != 2018 })
        #expect(payload.availablePastYears.contains(2026))
        #expect(payload.pastSeries.count == 24)
        let series2026 = payload.pastSeries.first { $0.year == 2026 }
        #expect(series2026?.points.count == 2)
        #expect(series2026?.points[0].value == 50.0)
        #expect(series2026?.points[1].value == 51.0)
        #expect(series2026?.points[0].rawTime == "2026/6/27 12:00")
        let series2002 = payload.pastSeries.first { $0.year == 2002 }
        #expect(series2002?.points[0].value == 50.0)
        #expect(series2002?.points[0].rawTime == "2002/6/27 12:00")
        #expect(!payload.pastSeries.contains { $0.year == 2018 })

        let base = try await service.loadBase(damConfigId: sameuraId, rows: rows, mainYear: 2018)
        #expect(base.mainYear == 2018)
        #expect(base.currentYear == 2026)
        #expect(service.payload(from: base, metric: .storageRate) == payload)
    }

    @Test("the latest-year series merges bundled points with daily rows and stays nil beyond coverage")
    func loadMergesDailyRowsIntoLatestYearSeries() async throws {
        let now2026 = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let store = HistoricalComparisonAssetStore(entries: juneEntries(2002...2026), dataLoader: june27DataLoader())
        let service = HistoricalComparisonService(now: { now2026 }, assetStore: store)
        let rows = [
            comparisonRow("2018/6/27 12:00"),
            comparisonRow("2018/6/27 13:00"),
            comparisonRow("2018/6/27 14:00"),
        ]
        let dailyRows = [
            DamHistoricalData(time: "2026/6/27 12:00", catchmentAverageRainfall: nil,
                              storagePercentage: nil, storageVolume: 199000, inflow: nil, outflow: nil),
            DamHistoricalData(time: "2026/6/27 13:00", catchmentAverageRainfall: nil,
                              storagePercentage: 55.0, storageVolume: 205000, inflow: nil, outflow: nil),
            DamHistoricalData(time: "2026/6/27 14:00", catchmentAverageRainfall: nil,
                              storagePercentage: 56.0, storageVolume: nil, inflow: nil, outflow: nil),
        ]
        let rate = try await service.load(damConfigId: sameuraId, rows: rows,
                                          metric: .storageRate, mainYear: 2018, dailyRows: dailyRows)
        let series2026 = rate.pastSeries.first { $0.year == 2026 }
        #expect(series2026?.points.count == 3)
        // 12:00: 日次の貯水率はnil(異常)のためバンドル値のまま。貯水率のみ上書き対象。
        #expect(series2026?.points[0].value == 50.0)
        // 13:00: 日次がバンドル(51.0)を上書き。
        #expect(series2026?.points[1].value == 55.0)
        #expect(series2026?.points[1].rawTime == "2026/6/27 13:00")
        // 14:00: バンドルに無く日次のみ。
        #expect(series2026?.points[2].value == 56.0)
        #expect(series2026?.points[2].rawTime == "2026/6/27 14:00")

        let volume = try await service.load(damConfigId: sameuraId, rows: rows,
                                            metric: .storageVolume, mainYear: 2018, dailyRows: dailyRows)
        let volume2026 = volume.pastSeries.first { $0.year == 2026 }
        #expect(volume2026?.points[0].value == 199000)
        #expect(volume2026?.points[1].value == 205000)
        // 14:00: 日次の貯水量はnilかつバンドルに無いため欠測のまま。
        #expect(volume2026?.points[2].value == nil)

        // カバレッジ外はバンドル由来の値が無い年と同様にnull。
        let series2025 = rate.pastSeries.first { $0.year == 2025 }
        #expect(series2025?.points[2].value == nil)
    }

    @Test("the latest-year series uses only daily rows when the bundled latest-year asset is absent")
    func loadMergesDailyRowsWithoutBundledLatestYearAsset() async throws {
        let now2026 = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let store = HistoricalComparisonAssetStore(entries: juneEntries(2002...2025), dataLoader: june27DataLoader())
        let service = HistoricalComparisonService(now: { now2026 }, assetStore: store)
        let rows = [
            comparisonRow("2018/6/27 12:00"),
            comparisonRow("2018/6/27 13:00"),
        ]
        let dailyRows = [
            DamHistoricalData(time: "2026/6/27 13:00", catchmentAverageRainfall: nil,
                              storagePercentage: 55.0, storageVolume: 205000, inflow: nil, outflow: nil),
        ]
        let payload = try await service.load(damConfigId: sameuraId, rows: rows,
                                             metric: .storageRate, mainYear: 2018, dailyRows: dailyRows)
        let series2026 = payload.pastSeries.first { $0.year == 2026 }
        #expect(series2026?.points.count == 2)
        #expect(series2026?.points[0].value == nil)
        #expect(series2026?.points[1].value == 55.0)
    }

    @Test("mainYear nil keeps the realtime-style behavior and ignores daily rows")
    func loadWithoutMainYearKeepsLegacyBehavior() async throws {
        let now2026 = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let store = HistoricalComparisonAssetStore(entries: juneEntries(2002...2025), dataLoader: june27DataLoader())
        let service = HistoricalComparisonService(now: { now2026 }, assetStore: store)
        let payload = try await service.load(damConfigId: sameuraId, rows: [
            comparisonRow("2026/6/27 12:00"),
            comparisonRow("2026/6/27 13:00"),
        ], metric: .storageRate, dailyRows: [
            DamHistoricalData(time: "2026/6/27 13:00", catchmentAverageRainfall: nil,
                              storagePercentage: 99.0, storageVolume: nil, inflow: nil, outflow: nil),
        ])
        #expect(payload.mainYear == 2026)
        #expect(payload.currentYear == 2026)
        #expect(payload.availablePastYears == Array(2002...2025))
        #expect(payload.pastSeries.map(\.year) == Array(2002...2025))
        let series2025 = payload.pastSeries.first { $0.year == 2025 }
        #expect(series2025?.points[1].value == 51.0)
    }

    // MARK: - fixture helpers

    private func juneEntries(_ years: ClosedRange<Int>) -> [HistoricalDatFileEntry] {
        years.map { year in
            HistoricalDatFileEntry(stationId: sameuraId, startDatetime: "\(year)06010100",
                                   endDatetime: "\(year)06302400",
                                   filePath: "1368080700010_\(year)06010100_\(year)06302400.dat")
        }
    }

    private func monthlyEntry(year: Int, month: Int, filePath: String) -> HistoricalDatFileEntry {
        HistoricalDatFileEntry(stationId: sameuraId, startDatetime: "\(year)\(String(format: "%02d", month))010100",
                               endDatetime: "\(year)\(String(format: "%02d", month))302400", filePath: filePath)
    }

    private func june27DataLoader() -> @Sendable (HistoricalDatFileEntry) throws -> Data? {
        { entry in
            guard let year = Int(entry.startDatetime.prefix(4)) else { return nil }
            return june27Bytes(year: year)
        }
    }

    private func june27Bytes(year: Int) -> Data {
        historicalDatData(rows: [
            historicalDatRow("\(year)/6/27", "12:00", storageVolume: 200000, storagePercentage: 50.0),
            historicalDatRow("\(year)/6/27", "13:00", storageVolume: 201000, storagePercentage: 51.0),
        ])
    }
}

/// データローダ呼出回数を数えるためのスレッドセーフなカウンタ。
private final class LoadCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func increment() {
        lock.lock()
        value += 1
        lock.unlock()
    }
}

/// データローダ呼出の回数と同時数を数えるためのスレッドセーフなカウンタ。
private final class ConcurrencyCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var active = 0
    private var maxSeen = 0
    private var total = 0

    /// 呼出の総数。
    var loadCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return total
    }

    /// 同時に呼出中だった最大数。
    var maxConcurrent: Int {
        lock.lock()
        defer { lock.unlock() }
        return maxSeen
    }

    /// 呼出の開始を記録します。
    func enter() {
        lock.lock()
        active += 1
        maxSeen = max(maxSeen, active)
        total += 1
        lock.unlock()
    }

    /// 呼出の終了を記録します。
    func exit() {
        lock.lock()
        active -= 1
        lock.unlock()
    }
}

private func utf8BOMData(_ text: String) -> Data {
    var data = Data([0xEF, 0xBB, 0xBF])
    data.append(Data(text.utf8))
    return data
}

private func historicalDatData(rows: [String]) -> Data {
    utf8BOMData("""
    水系名,吉野川
    河川名,吉野川
    観測所名,早明浦ダム
    観測所記号,1368080700010
    \(rows.joined(separator: "\n"))
    """)
}

private func historicalDatRow(_ date: String, _ time: String,
                              storageVolume: Float, storagePercentage: Float,
                              volumeQuality: String = " ", pctQuality: String = " ") -> String {
    "\(date),\(time),0, ,\(storageVolume),\(volumeQuality),0, ,0, ,\(storagePercentage),\(pctQuality)"
}

private func jstDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) throws -> Date {
    try #require(Calendar.jst.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)))
}

private func utcDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) throws -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)))
}

private func comparisonRow(_ time: String) -> DamHistoricalData {
    DamHistoricalData(time: time, catchmentAverageRainfall: nil, storagePercentage: 50,
                      storageVolume: 200000, inflow: nil, outflow: nil)
}
