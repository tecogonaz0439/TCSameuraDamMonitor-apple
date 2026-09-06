// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import CoreGraphics
import Foundation
import Testing
@testable import TCSameuraDamMonitor

/// グラフ全体から開始できるTooltip選択の座標変換を検証します。
@Suite("Graph interaction selection")
@MainActor
struct GraphInteractionSelectionTests {
    private let plotFrame = CGRect(x: 40, y: 20, width: 200, height: 100)
    private let start = Date(timeIntervalSince1970: 0)
    private var end: Date { start.addingTimeInterval(120) }
    private var timestamps: [Date] {
        [0, 60, 120].map { start.addingTimeInterval(TimeInterval($0)) }
    }

    @Test("X selection is clamped to the first and last observation")
    func xOutsidePlotSelectsBoundaryRows() {
        #expect(ObservationGraphCalculator.nearestIndex(
            atX: plotFrame.minX - 100,
            plotFrame: plotFrame,
            start: start,
            end: end,
            timestamps: timestamps
        ) == 0)
        #expect(ObservationGraphCalculator.nearestIndex(
            atX: plotFrame.maxX + 100,
            plotFrame: plotFrame,
            start: start,
            end: end,
            timestamps: timestamps
        ) == 2)
    }

    @Test("Y position does not affect the selected observation")
    func yPositionIsIgnored() {
        let inside = ObservationGraphCalculator.nearestIndex(
            atX: plotFrame.midX,
            plotFrame: plotFrame,
            start: start,
            end: end,
            timestamps: timestamps
        )
        let above = ObservationGraphCalculator.nearestIndex(
            atX: plotFrame.midX,
            plotFrame: CGRect(x: plotFrame.minX, y: -200, width: plotFrame.width, height: 500),
            start: start,
            end: end,
            timestamps: timestamps
        )
        #expect(inside == 1)
        #expect(above == inside)
    }

    @Test("internal X uses nearest observation and invalid input returns nil")
    func internalNearestAndInvalidInputs() {
        #expect(ObservationGraphCalculator.nearestIndex(
            atX: plotFrame.minX + 0.2 * plotFrame.width,
            plotFrame: plotFrame,
            start: start,
            end: end,
            timestamps: timestamps
        ) == 0)
        #expect(ObservationGraphCalculator.nearestIndex(
            atX: plotFrame.minX + 0.7 * plotFrame.width,
            plotFrame: plotFrame,
            start: start,
            end: end,
            timestamps: timestamps
        ) == 1)
        #expect(ObservationGraphCalculator.nearestIndex(
            atX: plotFrame.midX,
            plotFrame: .zero,
            start: start,
            end: end,
            timestamps: timestamps
        ) == nil)
        #expect(ObservationGraphCalculator.nearestIndex(
            atX: plotFrame.midX,
            plotFrame: plotFrame,
            start: start,
            end: start,
            timestamps: timestamps
        ) == nil)
        #expect(ObservationGraphCalculator.nearestIndex(
            atX: plotFrame.midX,
            plotFrame: plotFrame,
            start: start,
            end: end,
            timestamps: []
        ) == nil)
    }
}
