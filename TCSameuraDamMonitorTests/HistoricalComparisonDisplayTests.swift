// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Testing
import Foundation
@testable import TCSameuraDamMonitor

/// 過去比較グラフのTooltip行の表示計算(順位・書式・JST hour floor照合)のテスト。
@Suite("Historical comparison display")
struct HistoricalComparisonDisplayTests {
    @Test("formatValue formats storage rate and storage volume")
    func formatValueFormats() {
        #expect(HistoricalComparisonDisplay.formatValue(65.0, metric: .storageRate) == "65.00%")
        #expect(HistoricalComparisonDisplay.formatValue(201000, metric: .storageVolume) == "201000×10³m³")
        #expect(HistoricalComparisonDisplay.missingValueText(metric: .storageRate) == "--%")
        #expect(HistoricalComparisonDisplay.missingValueText(metric: .storageVolume) == "--×10³m³")
    }

    @Test("yearValueLines sorts by value descending, main year first on ties, then year descending, nil rows omitted")
    func sortedRows() throws {
        let selected = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let series = [
            pastSeries(year: 2002, at: selected, value: 50),
            pastSeries(year: 2003, at: selected, value: 60),
            pastSeries(year: 2004, at: selected, value: 60),
            pastSeries(year: 2005, at: selected, value: nil),
        ]
        let lines = HistoricalComparisonDisplay.yearValueLines(
            selectedDate: selected, currentYearValue: 60, pastSeries: series,
            metric: .storageRate, isJapanese: true, calendar: .jst, mainYear: 2026)
        #expect(lines == [
            "2026年: 60.00%",
            "2004年: 60.00%",
            "2003年: 60.00%",
            "2002年: 50.00%",
        ])
    }

    @Test("comparison years without a value at the hovered hour are omitted while the main year always appears")
    func nilRowsOmitted() throws {
        let selected = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let series = [
            pastSeries(year: 2002, at: selected, value: nil),
            pastSeries(year: 2003, at: selected, value: 50),
        ]
        let lines = HistoricalComparisonDisplay.yearValueLines(
            selectedDate: selected, currentYearValue: nil, pastSeries: series,
            metric: .storageRate, isJapanese: true, calendar: .jst, mainYear: 2026)
        #expect(lines == ["2003年: 50.00%", "2026年: --%"])
    }

    @Test("up to 8 past years renders all rows while 9 compresses")
    func boundaryEightNine() throws {
        let selected = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let eightYears = (2002...2009).map { pastSeries(year: $0, at: selected, value: Float($0 - 2000)) }
        let eightLines = HistoricalComparisonDisplay.yearValueLines(
            selectedDate: selected, currentYearValue: 6.5, pastSeries: eightYears,
            metric: .storageRate, isJapanese: true, calendar: .jst, mainYear: 2026)
        #expect(eightLines.count == 9)
        #expect(eightLines.filter { $0 == ":" }.isEmpty)
        #expect(eightLines.first == "2009年: 9.00%")

        let nineYears = (2002...2010).map { pastSeries(year: $0, at: selected, value: Float($0 - 2000)) }
        let nineLines = HistoricalComparisonDisplay.yearValueLines(
            selectedDate: selected, currentYearValue: 6.5, pastSeries: nineYears,
            metric: .storageRate, isJapanese: true, calendar: .jst, mainYear: 2026)
        #expect(nineLines.count == 9)
        #expect(nineLines.filter { $0 == ":" }.count == 2)
        #expect(nineLines[0] == "2010年: 10.00%")
        #expect(nineLines[2] == "2008年: 8.00%")
        #expect(nineLines[4] == "2026年: 6.50%")
        #expect(nineLines[6] == "2004年: 4.00%")
        #expect(nineLines[8] == "2002年: 2.00%")
    }

    @Test("compressed rows put the current year inside the top three")
    func compressedCurrentInTop() throws {
        let selected = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let series = (2002...2010).map { pastSeries(year: $0, at: selected, value: Float($0 - 2000)) }
        let lines = HistoricalComparisonDisplay.yearValueLines(
            selectedDate: selected, currentYearValue: 99, pastSeries: series,
            metric: .storageRate, isJapanese: true, calendar: .jst, mainYear: 2026)
        #expect(lines.count == 7)
        #expect(lines.filter { $0 == ":" }.count == 1)
        #expect(lines[0] == "2026年: 99.00%")
        #expect(lines[1] == "2010年: 10.00%")
        #expect(lines[2] == "2009年: 9.00%")
        #expect(lines[4] == "2004年: 4.00%")
        #expect(lines[6] == "2002年: 2.00%")
    }

    @Test("compressed rows put the current year inside the worst three")
    func compressedCurrentInWorst() throws {
        let selected = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let series = (2002...2010).map { pastSeries(year: $0, at: selected, value: Float(100 - ($0 - 2000))) }
        let lines = HistoricalComparisonDisplay.yearValueLines(
            selectedDate: selected, currentYearValue: 1, pastSeries: series,
            metric: .storageRate, isJapanese: true, calendar: .jst, mainYear: 2026)
        #expect(lines.count == 7)
        #expect(lines.filter { $0 == ":" }.count == 1)
        #expect(lines[0] == "2002年: 98.00%")
        #expect(lines[3] == ":")
        #expect(lines[4] == "2009年: 91.00%")
        #expect(lines[6] == "2026年: 1.00%")
    }

    @Test("compressed rows exclude top years from the worst side")
    func compressedExcludesTopYearsFromWorst() throws {
        let selected = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let series = (2002...2010).map { year -> HistoricalComparisonSeries in
            let value: Float?
            switch year {
            case 2007: value = 50
            case 2008: value = 40
            case 2009: value = 30
            case 2010: value = 20
            default: value = nil
            }
            return pastSeries(year: year, at: selected, value: value)
        }
        let lines = HistoricalComparisonDisplay.yearValueLines(
            selectedDate: selected, currentYearValue: 99, pastSeries: series,
            metric: .storageRate, isJapanese: true, calendar: .jst, mainYear: 2026)
        #expect(lines == [
            "2026年: 99.00%",
            "2007年: 50.00%",
            "2008年: 40.00%",
            ":",
            "2009年: 30.00%",
            "2010年: 20.00%",
        ])
    }

    @Test("a missing current year renders the missing value text between two separators in compressed mode")
    func compressedMissingCurrent() throws {
        let selected = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let series = (2002...2010).map { pastSeries(year: $0, at: selected, value: Float($0 - 2000)) }
        let rateLines = HistoricalComparisonDisplay.yearValueLines(
            selectedDate: selected, currentYearValue: nil, pastSeries: series,
            metric: .storageRate, isJapanese: true, calendar: .jst, mainYear: 2026)
        #expect(rateLines.count == 9)
        #expect(rateLines.filter { $0 == ":" }.count == 2)
        #expect(rateLines[4] == "2026年: --%")
        let volumeLines = HistoricalComparisonDisplay.yearValueLines(
            selectedDate: selected, currentYearValue: nil, pastSeries: series,
            metric: .storageVolume, isJapanese: true, calendar: .jst, mainYear: 2026)
        #expect(volumeLines[4] == "2026年: --×10³m³")
    }

    @Test("yearValueLines matches series points by the JST hour floor of the selected date")
    func floorMatching() throws {
        let pointDate = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let series = [
            pastSeries(year: 2002, at: pointDate, value: 50),
            pastSeries(year: 2003, at: pointDate, value: 60),
        ]
        let aligned = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 45)
        let lines = HistoricalComparisonDisplay.yearValueLines(
            selectedDate: aligned, currentYearValue: 70, pastSeries: series,
            metric: .storageRate, isJapanese: true, calendar: .jst, mainYear: 2026)
        #expect(lines == ["2026年: 70.00%", "2003年: 60.00%", "2002年: 50.00%"])

        let misaligned = try jstDate(year: 2026, month: 6, day: 27, hour: 13, minute: 15)
        let missingLines = HistoricalComparisonDisplay.yearValueLines(
            selectedDate: misaligned, currentYearValue: 70, pastSeries: series,
            metric: .storageRate, isJapanese: true, calendar: .jst, mainYear: 2026)
        #expect(missingLines == ["2026年: 70.00%"])
    }

    @Test("year labels use 年 for Japanese and plain digits otherwise")
    func yearLabels() throws {
        #expect(HistoricalComparisonDisplay.yearLabel(2002, isJapanese: true) == "2002年")
        #expect(HistoricalComparisonDisplay.yearLabel(2002, isJapanese: false) == "2002")
        let selected = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let series = [pastSeries(year: 2002, at: selected, value: 50)]
        let ja = HistoricalComparisonDisplay.yearValueLines(
            selectedDate: selected, currentYearValue: 50, pastSeries: series,
            metric: .storageRate, isJapanese: true, calendar: .jst, mainYear: 2026)
        #expect(ja == ["2026年: 50.00%", "2002年: 50.00%"])
        let en = HistoricalComparisonDisplay.yearValueLines(
            selectedDate: selected, currentYearValue: 50, pastSeries: series,
            metric: .storageRate, isJapanese: false, calendar: .jst, mainYear: 2026)
        #expect(en == ["2026: 50.00%", "2002: 50.00%"])
    }

    @Test("Web fixture: 24 years plus the current year compresses to top3/worst3 with the current in the middle")
    func webFixtureCompressedRows() throws {
        let timestamps = [
            try jstDate(year: 2026, month: 6, day: 28, hour: 0, minute: 0),
            try jstDate(year: 2026, month: 6, day: 28, hour: 1, minute: 0),
            try jstDate(year: 2026, month: 6, day: 28, hour: 2, minute: 0),
        ]
        let series = (2002...2025).map { year -> HistoricalComparisonSeries in
            let value = Float(60 + (year - 2002))
            return HistoricalComparisonSeries(year: year, points: timestamps.enumerated().map { index, date in
                HistoricalComparisonSeriesPoint(
                    id: "\(year)-\(index)",
                    date: date,
                    value: index == 1 && year == 2002 ? nil : value + (index == 1 ? 0.5 : Float(index - 1)),
                    rawTime: ""
                )
            })
        }
        let lines = HistoricalComparisonDisplay.yearValueLines(
            selectedDate: timestamps[2], currentYearValue: 65, pastSeries: series,
            metric: .storageRate, isJapanese: true, calendar: .jst, mainYear: 2026)
        #expect(lines.count == 9)
        #expect(lines.filter { $0 == ":" }.count == 2)
        #expect(lines[0] == "2025年: 84.00%")
        #expect(lines[1] == "2024年: 83.00%")
        #expect(lines[2] == "2023年: 82.00%")
        #expect(lines[3] == ":")
        #expect(lines[4] == "2026年: 65.00%")
        #expect(lines[5] == ":")
        #expect(lines[6] == "2004年: 63.00%")
        #expect(lines[7] == "2003年: 62.00%")
        #expect(lines[8] == "2002年: 61.00%")
    }

    @Test("visiblePoints keeps only points inside the domain including both boundaries")
    func visiblePointsFiltersDomain() throws {
        let domainStart = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let domainEnd = try jstDate(year: 2026, month: 6, day: 27, hour: 14, minute: 0)
        let points = try [
            (0, jstDate(year: 2026, month: 6, day: 27, hour: 10, minute: 0)),
            (1, jstDate(year: 2026, month: 6, day: 27, hour: 11, minute: 0)),
            (2, domainStart),
            (3, try jstDate(year: 2026, month: 6, day: 27, hour: 13, minute: 0)),
            (4, domainEnd),
            (5, try jstDate(year: 2026, month: 6, day: 27, hour: 15, minute: 0)),
        ].map { index, date in
            HistoricalComparisonSeriesPoint(id: "p\(index)", date: date, value: Float(index), rawTime: "")
        }
        let visible = HistoricalComparisonDisplay.visiblePoints(points, in: domainStart...domainEnd)
        #expect(visible.map(\.id) == ["p2", "p3", "p4"])
        #expect(visible.map(\.value) == [2, 3, 4])
    }

    @Test("visiblePoints returns empty when no point falls inside the domain")
    func visiblePointsEmpty() throws {
        let start = try jstDate(year: 2026, month: 6, day: 27, hour: 0, minute: 0)
        let end = try jstDate(year: 2026, month: 6, day: 27, hour: 2, minute: 0)
        let points = try [
            (0, jstDate(year: 2026, month: 6, day: 26, hour: 23, minute: 0)),
            (1, try jstDate(year: 2026, month: 6, day: 27, hour: 3, minute: 0)),
        ].map { index, date in
            HistoricalComparisonSeriesPoint(id: "p\(index)", date: date, value: Float(index), rawTime: "")
        }
        #expect(HistoricalComparisonDisplay.visiblePoints(points, in: start...end).isEmpty)
    }

    @Test("edgeExtendedPoints clamps the boundary points to reach both edges")
    func edgeExtendedClampsBoundaries() throws {
        let domainStart = try jstDate(year: 2026, month: 6, day: 27, hour: 5, minute: 20)
        let domainEnd = try jstDate(year: 2026, month: 6, day: 27, hour: 6, minute: 40)
        let points = try [
            (0, jstDate(year: 2026, month: 6, day: 27, hour: 4, minute: 0), Float(40)),
            (1, try jstDate(year: 2026, month: 6, day: 27, hour: 5, minute: 0), Float(50)),
            (2, try jstDate(year: 2026, month: 6, day: 27, hour: 6, minute: 0), Float(60)),
            (3, try jstDate(year: 2026, month: 6, day: 27, hour: 7, minute: 0), Float(70)),
        ].map { index, date, value in
            HistoricalComparisonSeriesPoint(id: "p\(index)", date: date, value: value, rawTime: "")
        }
        let extended = HistoricalComparisonDisplay.edgeExtendedPoints(points, in: domainStart...domainEnd)
        let inDomainDate = try jstDate(year: 2026, month: 6, day: 27, hour: 6, minute: 0)
        #expect(extended.count == 3)
        #expect(extended[0].date == domainStart)
        #expect(extended[0].value == 50)
        #expect(extended[0].id == "p2-edgeLower")
        #expect(extended[1].date == inDomainDate)
        #expect(extended[1].value == 60)
        #expect(extended[2].date == domainEnd)
        #expect(extended[2].value == 60)
        #expect(extended[2].id == "p2-edgeUpper")
    }

    @Test("edgeExtendedPoints does not extend across a missing observation")
    func edgeExtendedSkipsMissing() throws {
        let domainStart = try jstDate(year: 2026, month: 6, day: 27, hour: 5, minute: 20)
        let firstMissingDomainEnd = try jstDate(year: 2026, month: 6, day: 27, hour: 7, minute: 40)
        let firstMissing = try [
            (0, jstDate(year: 2026, month: 6, day: 27, hour: 4, minute: 0), Float(40)),
            (1, try jstDate(year: 2026, month: 6, day: 27, hour: 5, minute: 0), Float(50)),
            (2, try jstDate(year: 2026, month: 6, day: 27, hour: 6, minute: 0), nil as Float?),
            (3, try jstDate(year: 2026, month: 6, day: 27, hour: 7, minute: 0), Float(70)),
        ].map { index, date, value in
            HistoricalComparisonSeriesPoint(id: "p\(index)", date: date, value: value, rawTime: "")
        }
        let missingFirst = HistoricalComparisonDisplay.edgeExtendedPoints(firstMissing, in: domainStart...firstMissingDomainEnd)
        #expect(missingFirst.map(\.id) == ["p2", "p3", "p3-edgeUpper"])

        let preMissingDomainEnd = try jstDate(year: 2026, month: 6, day: 27, hour: 6, minute: 40)
        let preMissing = try [
            (0, jstDate(year: 2026, month: 6, day: 27, hour: 5, minute: 0), nil as Float?),
            (1, try jstDate(year: 2026, month: 6, day: 27, hour: 6, minute: 0), Float(60)),
        ].map { index, date, value in
            HistoricalComparisonSeriesPoint(id: "p\(index)", date: date, value: value, rawTime: "")
        }
        let missingPre = HistoricalComparisonDisplay.edgeExtendedPoints(preMissing, in: domainStart...preMissingDomainEnd)
        #expect(missingPre.map(\.id) == ["p1", "p1-edgeUpper"])
    }

    @Test("edgeExtendedPoints leaves boundary-aligned points and empty domains unchanged")
    func edgeExtendedAlignedAndEmpty() throws {
        let domainStart = try jstDate(year: 2026, month: 6, day: 27, hour: 5, minute: 0)
        let domainEnd = try jstDate(year: 2026, month: 6, day: 27, hour: 6, minute: 0)
        let aligned = try [
            (0, jstDate(year: 2026, month: 6, day: 27, hour: 5, minute: 0), Float(50)),
            (1, try jstDate(year: 2026, month: 6, day: 27, hour: 6, minute: 0), Float(60)),
        ].map { index, date, value in
            HistoricalComparisonSeriesPoint(id: "p\(index)", date: date, value: value, rawTime: "")
        }
        #expect(HistoricalComparisonDisplay.edgeExtendedPoints(aligned, in: domainStart...domainEnd) == aligned)

        let outside = try [
            (0, jstDate(year: 2026, month: 6, day: 27, hour: 4, minute: 0), Float(40)),
            (1, try jstDate(year: 2026, month: 6, day: 27, hour: 7, minute: 0), Float(70)),
        ].map { index, date, value in
            HistoricalComparisonSeriesPoint(id: "p\(index)", date: date, value: value, rawTime: "")
        }
        #expect(HistoricalComparisonDisplay.edgeExtendedPoints(outside, in: domainStart...domainEnd).isEmpty)
    }

    @Test("drawnPastYears keeps only years with a non-missing observation inside the domain")
    func drawnPastYearsFiltersByDomainAndValues() throws {
        let domainStart = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let domainEnd = try jstDate(year: 2026, month: 6, day: 27, hour: 14, minute: 0)
        let inDomain = try jstDate(year: 2026, month: 6, day: 27, hour: 13, minute: 0)
        let outside = try jstDate(year: 2026, month: 6, day: 27, hour: 11, minute: 0)
        let series = [
            HistoricalComparisonSeries(year: 2002, points: [
                HistoricalComparisonSeriesPoint(id: "2002-0", date: inDomain, value: 50, rawTime: ""),
            ]),
            HistoricalComparisonSeries(year: 2003, points: [
                HistoricalComparisonSeriesPoint(id: "2003-0", date: inDomain, value: nil, rawTime: ""),
            ]),
            HistoricalComparisonSeries(year: 2004, points: [
                HistoricalComparisonSeriesPoint(id: "2004-0", date: outside, value: 60, rawTime: ""),
            ]),
            HistoricalComparisonSeries(year: 2005, points: [
                HistoricalComparisonSeriesPoint(id: "2005-0", date: inDomain, value: 70, rawTime: ""),
                HistoricalComparisonSeriesPoint(id: "2005-1", date: outside, value: nil, rawTime: ""),
            ]),
        ]
        let drawn = HistoricalComparisonDisplay.drawnPastYears(series, in: domainStart...domainEnd)
        #expect(drawn == [2002, 2005])
    }

    @Test("tooltipPastSeries keeps only selected years that are actually drawn")
    func tooltipPastSeriesFiltersSelectedAndDrawn() {
        let series = (2002...2005).map { year in
            HistoricalComparisonSeries(year: year, points: [
                HistoricalComparisonSeriesPoint(id: "\(year)-0", date: .distantPast, value: Float(year), rawTime: ""),
            ])
        }
        let filtered = HistoricalComparisonDisplay.tooltipPastSeries(
            selectedYears: [2002, 2003, 2005],
            drawnYears: [2003, 2004],
            pastSeries: series
        )
        #expect(filtered.map(\.year) == [2003])
    }

    @Test("yearValueLines keeps the current year row when all past lines are hidden")
    func allHiddenKeepsCurrentYearRow() throws {
        let selected = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let lines = HistoricalComparisonDisplay.yearValueLines(
            selectedDate: selected, currentYearValue: 65, pastSeries: [],
            metric: .storageRate, isJapanese: true, calendar: .jst, mainYear: 2026)
        #expect(lines == ["2026年: 65.00%"])
    }

    @Test("yearValueLines with the drawn-only filter excludes undrawn selected years")
    func filteredTooltipExcludesUndrawnYears() throws {
        let selected = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let series = [
            HistoricalComparisonSeries(year: 2002, points: [
                HistoricalComparisonSeriesPoint(id: "2002-0", date: selected, value: nil, rawTime: ""),
            ]),
            HistoricalComparisonSeries(year: 2003, points: [
                HistoricalComparisonSeriesPoint(id: "2003-0", date: selected, value: 60, rawTime: ""),
            ]),
        ]
        let drawnYears = HistoricalComparisonDisplay.drawnPastYears(series, in: selected...selected)
        let tooltipSeries = HistoricalComparisonDisplay.tooltipPastSeries(
            selectedYears: [2002, 2003], drawnYears: drawnYears, pastSeries: series)
        #expect(tooltipSeries.map(\.year) == [2003])
        let lines = HistoricalComparisonDisplay.yearValueLines(
            selectedDate: selected, currentYearValue: 65, pastSeries: tooltipSeries,
            metric: .storageRate, isJapanese: true, calendar: .jst, mainYear: 2026)
        #expect(lines == ["2026年: 65.00%", "2003年: 60.00%"])
    }

    @Test("the main year row uses mainYear while the latest year appears as a comparison row when it has a value")
    func mainYearRowUsesMainYear() throws {
        let selected = try jstDate(year: 2018, month: 6, day: 27, hour: 12, minute: 0)
        let series = [
            pastSeries(year: 2026, at: selected, value: 55),
            pastSeries(year: 2002, at: selected, value: nil),
        ]
        let lines = HistoricalComparisonDisplay.yearValueLines(
            selectedDate: selected, currentYearValue: 50, pastSeries: series,
            metric: .storageRate, isJapanese: true, calendar: .jst, mainYear: 2018)
        #expect(lines == ["2026年: 55.00%", "2018年: 50.00%"])
    }

    // MARK: - fixture helpers

    private func pastSeries(year: Int, at date: Date, value: Float?) -> HistoricalComparisonSeries {
        HistoricalComparisonSeries(year: year, points: [
            HistoricalComparisonSeriesPoint(id: "\(year)-0", date: date, value: value, rawTime: ""),
        ])
    }
}

private func jstDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) throws -> Date {
    try #require(Calendar.jst.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)))
}
