// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Testing
import Foundation
@testable import TCSameuraDamMonitor

/// 過去比較グラフの年選択状態遷移(Allトグル・個別トグル・全選択導出)のテスト。
/// 対象年は過去年(2002...前年)+今年(JST現在年)を含み、Allチップは「今年含む全対象年」を
/// 一括切替します(全選択中に押すと全解除、未選択中に押すと全選択)。
@Suite("Historical year selection")
struct HistoricalYearSelectionTests {
    @Test("toggling all switches from all selected to empty and back")
    func togglingAllCycles() {
        let allYears = Set(2002...2026)
        let none = HistoricalYearSelection.togglingAll(allYears, allYears: allYears)
        #expect(none == [])
        let all = HistoricalYearSelection.togglingAll(none, allYears: allYears)
        #expect(all == allYears)
    }

    @Test("toggling a year removes it and re-selecting restores the full selection")
    func togglingYearRemovesAndRestores() {
        let allYears = Set(2002...2026)
        let without2026 = HistoricalYearSelection.togglingYear(2026, current: allYears)
        #expect(!without2026.contains(2026))
        #expect(!HistoricalYearSelection.isAllSelected(without2026, allYears: allYears))
        let restored = HistoricalYearSelection.togglingYear(2026, current: without2026)
        #expect(restored == allYears)
        #expect(HistoricalYearSelection.isAllSelected(restored, allYears: allYears))
    }

    @Test("toggling an unselected year adds it")
    func togglingYearAdds() {
        let current: Set<Int> = [2002, 2003]
        let next = HistoricalYearSelection.togglingYear(2004, current: current)
        #expect(next == [2002, 2003, 2004])
    }

    @Test("isAllSelected is derived from the set rather than independent state")
    func isAllSelectedDerived() {
        let allYears = Set(2002...2026)
        #expect(HistoricalYearSelection.isAllSelected(allYears, allYears: allYears))
        #expect(!HistoricalYearSelection.isAllSelected(Set(), allYears: allYears))
        var missing = allYears
        missing.remove(2010)
        #expect(!HistoricalYearSelection.isAllSelected(missing, allYears: allYears))
        #expect(!HistoricalYearSelection.isAllSelected(Set(), allYears: Set()))
    }

    @Test("the all toggle covers the current year together with the past years")
    func togglingAllCoversCurrentYear() {
        let pastYears = Set(2002...2025)
        let allYears = pastYears.union([2026])
        let deselected = HistoricalYearSelection.togglingAll(allYears, allYears: allYears)
        #expect(deselected == [])
        let reselected = HistoricalYearSelection.togglingAll(deselected, allYears: allYears)
        #expect(reselected == allYears)
        #expect(reselected.contains(2026))
    }
}
