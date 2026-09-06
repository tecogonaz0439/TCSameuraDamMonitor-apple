// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Testing
import Foundation
@testable import TCSameuraDamMonitor

/// グラフラインの表示/非表示と主系列(主系列年のライン)の描画判定のテスト。
@Suite("Graph line visibility")
struct GraphLineVisibilityTests {
    @Test("toggling a line removes it and re-selecting restores it")
    func togglingLineCycles() {
        let all = Set(GraphLine.allCases)
        let withoutRainfall = GraphLineVisibility.togglingLine(.rainfall, current: all)
        #expect(!withoutRainfall.contains(.rainfall))
        #expect(withoutRainfall.count == all.count - 1)
        let restored = GraphLineVisibility.togglingLine(.rainfall, current: withoutRainfall)
        #expect(restored == all)
    }

    @Test("non-comparison mode draws the main line only when its line chip is selected")
    func nonComparisonFollowsVisibleLines() {
        let visible = Set(GraphLine.allCases)
        #expect(GraphLineVisibility.isCurrentYearLineVisible(
            isComparisonMode: false,
            mainLine: .storageRate,
            visibleLines: visible,
            comparisonMainYear: 2026,
            selectedYears: []
        ))
        let withoutMain = GraphLineVisibility.togglingLine(.storageRate, current: visible)
        #expect(!GraphLineVisibility.isCurrentYearLineVisible(
            isComparisonMode: false,
            mainLine: .storageRate,
            visibleLines: withoutMain,
            comparisonMainYear: 2026,
            selectedYears: []
        ))
        #expect(GraphLineVisibility.isCurrentYearLineVisible(
            isComparisonMode: false,
            mainLine: .storageVolume,
            visibleLines: withoutMain,
            comparisonMainYear: 2026,
            selectedYears: []
        ))
    }

    @Test("comparison mode draws the main line only when the main year is selected")
    func comparisonFollowsSelectedYears() {
        #expect(GraphLineVisibility.isCurrentYearLineVisible(
            isComparisonMode: true,
            mainLine: .storageRate,
            visibleLines: Set(GraphLine.allCases),
            comparisonMainYear: 2026,
            selectedYears: [2026]
        ))
        #expect(!GraphLineVisibility.isCurrentYearLineVisible(
            isComparisonMode: true,
            mainLine: .storageRate,
            visibleLines: Set(GraphLine.allCases),
            comparisonMainYear: 2026,
            selectedYears: [2025]
        ))
        // 比較モードは主系列年チップの選択状態のみに従い、ライン切替チップ(visibleLines)は
        // 無視する(Android isCurrentYearLineVisible と同じ仕様)。
        #expect(GraphLineVisibility.isCurrentYearLineVisible(
            isComparisonMode: true,
            mainLine: .storageRate,
            visibleLines: [],
            comparisonMainYear: 2026,
            selectedYears: [2026]
        ))
        // 通常の過去データ表示では主系列年が表示対象データの年になる。
        #expect(GraphLineVisibility.isCurrentYearLineVisible(
            isComparisonMode: true,
            mainLine: .storageRate,
            visibleLines: Set(GraphLine.allCases),
            comparisonMainYear: 2018,
            selectedYears: [2018, 2026]
        ))
        #expect(!GraphLineVisibility.isCurrentYearLineVisible(
            isComparisonMode: true,
            mainLine: .storageRate,
            visibleLines: Set(GraphLine.allCases),
            comparisonMainYear: 2018,
            selectedYears: [2026]
        ))
    }

    @Test("comparison mode without loaded data never draws the main line")
    func comparisonWithoutDataHidesCurrentYearLine() {
        #expect(!GraphLineVisibility.isCurrentYearLineVisible(
            isComparisonMode: true,
            mainLine: .storageVolume,
            visibleLines: Set(GraphLine.allCases),
            comparisonMainYear: nil,
            selectedYears: [2026]
        ))
    }

    @Test("non-comparison marker visibility follows each line chip")
    func nonComparisonMarkerVisibilityFollowsLineChips() {
        let visible: Set<GraphLine> = [.storageRate, .rainfall, .storageVolume, .inflow, .outflow]
        #expect(GraphLineVisibility.isLineVisible(
            .storageRate,
            isComparisonMode: false,
            mainLine: .storageRate,
            visibleLines: visible,
            comparisonMainYear: nil,
            selectedYears: []
        ))
        #expect(GraphLineVisibility.isLineVisible(
            .rainfall,
            isComparisonMode: false,
            mainLine: .storageRate,
            visibleLines: visible,
            comparisonMainYear: nil,
            selectedYears: []
        ))

        let withoutRainfall = visible.subtracting([.rainfall])
        #expect(!GraphLineVisibility.isLineVisible(
            .rainfall,
            isComparisonMode: false,
            mainLine: .storageRate,
            visibleLines: withoutRainfall,
            comparisonMainYear: nil,
            selectedYears: []
        ))
        #expect(GraphLineVisibility.isLineVisible(
            .storageRate,
            isComparisonMode: false,
            mainLine: .storageRate,
            visibleLines: withoutRainfall,
            comparisonMainYear: nil,
            selectedYears: []
        ))

        let withoutVolume = visible.subtracting([.storageVolume])
        #expect(!GraphLineVisibility.isLineVisible(
            .storageVolume,
            isComparisonMode: false,
            mainLine: .storageVolume,
            visibleLines: withoutVolume,
            comparisonMainYear: nil,
            selectedYears: []
        ))
        #expect(GraphLineVisibility.isLineVisible(
            .inflow,
            isComparisonMode: false,
            mainLine: .storageVolume,
            visibleLines: withoutVolume,
            comparisonMainYear: nil,
            selectedYears: []
        ))
    }

    @Test("comparison marker visibility separates current year and metric chips")
    func comparisonMarkerVisibilitySeparatesCurrentYearAndMetricChips() {
        let visible: Set<GraphLine> = [.storageRate, .rainfall, .storageVolume, .inflow, .outflow]
        #expect(GraphLineVisibility.isLineVisible(
            .storageRate,
            isComparisonMode: true,
            mainLine: .storageRate,
            visibleLines: [],
            comparisonMainYear: 2026,
            selectedYears: [2026]
        ))
        #expect(!GraphLineVisibility.isLineVisible(
            .storageRate,
            isComparisonMode: true,
            mainLine: .storageRate,
            visibleLines: visible,
            comparisonMainYear: 2026,
            selectedYears: [2025]
        ))
        #expect(GraphLineVisibility.isLineVisible(
            .rainfall,
            isComparisonMode: true,
            mainLine: .storageRate,
            visibleLines: visible,
            comparisonMainYear: 2026,
            selectedYears: [2025]
        ))
        #expect(!GraphLineVisibility.isLineVisible(
            .rainfall,
            isComparisonMode: true,
            mainLine: .storageRate,
            visibleLines: visible.subtracting([.rainfall]),
            comparisonMainYear: 2026,
            selectedYears: [2026]
        ))
        #expect(!GraphLineVisibility.isLineVisible(
            .outflow,
            isComparisonMode: true,
            mainLine: .storageVolume,
            visibleLines: visible.subtracting([.outflow]),
            comparisonMainYear: 2026,
            selectedYears: [2026]
        ))
    }
}
