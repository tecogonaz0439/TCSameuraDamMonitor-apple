// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Charts
import SwiftUI

/// 操作中に表示する現行系列の交点marker定義。
struct GraphInteractionMarker: Identifiable {
    /// 対応するグラフ系列。
    let line: GraphLine
    /// 系列色。
    let color: Color
    /// 対応する線が現在表示されているかどうか。
    let isVisible: Bool
    /// 選択行からmarkerのY値を返すresolver。欠測時は`nil`を返します。
    let yValue: (DatedHistoricalRow) -> Double?

    var id: GraphLine { line }
}

/// 十字線・マーカー・ツールチップと選択状態を所有する、チャート上のインタラクションオーバーレイ。
///
/// 選択indexは本ビューが専有し、静的Chart subtreeは選択状態を参照しない。ドラッグ中の
/// pointer eventは`nearestIndex`の二分探索と同index書き込み抑止により、表示条件が
/// 変わらない限り選択indexが変化した場合のみ状態を更新する。
struct GraphInteractionOverlay: View {
    /// 表示行（昇順ソート済み）。
    let rows: [DatedHistoricalRow]
    /// 表示行の日時配列（昇順、二分探索対象）。
    let timestamps: [Date]
    /// X軸の表示domain。
    let xDomain: ClosedRange<Date>
    /// チャートの座標変換プロキシ。
    let proxy: ChartProxy
    /// 十字線が有効であるかどうかを示す真偽値フラグ。
    let isEnabled: Bool
    /// X軸目盛りの密度計算に使うプロット幅。
    let xAxisPlotWidth: CGFloat
    /// 左側Y軸の目盛り値。
    let leftYTickValues: [Double]
    /// 右側Y軸の目盛り値。
    let rightYTickValues: [Double]
    /// ツールチップ行のビルダー。
    let tooltip: (DamHistoricalData) -> [String]
    /// 操作中に表示する現行系列のmarker定義。
    let markers: [GraphInteractionMarker]
    /// 表示keyの変更に応じて選択状態をリセットするための識別子。
    let displayResetKey: String
    /// 十字線トラッキングによって現在選択されている行のindex。
    @State private var selectedIndex: Int?

    /// 十字線オーバーレイのコンテンツとレイアウト。
    var body: some View {
        GeometryReader { geometry in
            let plotFrame = proxy.plotFrame.map { geometry[$0] } ?? .zero
            ZStack(alignment: .topLeading) {
                chartAxisDecoration(
                    plotFrame: plotFrame,
                    xDomain: xDomain,
                    xAxisPlotWidth: xAxisPlotWidth,
                    leftYTickValues: leftYTickValues,
                    rightYTickValues: rightYTickValues
                )

                Color.clear.preference(key: ChartPlotWidthPreferenceKey.self, value: plotFrame.width)

                if isEnabled, let selectedIndex, let row = displayRow(at: selectedIndex),
                   let segment = ObservationGraphCalculator.verticalPlotLineSegment(
                       for: row.date,
                       start: xDomain.lowerBound,
                       end: xDomain.upperBound,
                       plotFrame: plotFrame
                   ) {
                    Path { path in
                        path.move(to: CGPoint(x: segment.x, y: segment.minY))
                        path.addLine(to: CGPoint(x: segment.x, y: segment.maxY))
                    }
                    .stroke(.secondary.opacity(0.65), style: StrokeStyle(lineWidth: 1, lineCap: .butt, dash: [4, 4]))
                }

                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .allowsHitTesting(isEnabled)
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in updateSelection(location: value.location, plotFrame: plotFrame) }
                        .onEnded { _ in selectedIndex = nil })

                if isEnabled, let selectedIndex, let row = displayRow(at: selectedIndex) {
                    ForEach(markers.filter { $0.isVisible }) { marker in
                        if let yValue = marker.yValue(row),
                           let point = proxy.position(for: (x: row.date, y: yValue)) {
                            Circle()
                                .fill(marker.color)
                                .frame(width: graphMarkerDiameter, height: graphMarkerDiameter)
                                .position(x: point.x + plotFrame.minX, y: point.y + plotFrame.minY)
                                .allowsHitTesting(false)
                        }
                    }
                }

                if isEnabled, let selectedIndex, let row = displayRow(at: selectedIndex),
                   let x = proxy.position(forX: row.date) {
                    ChartTooltipOverlay(
                        lines: tooltip(row.row),
                        anchorX: x + plotFrame.minX,
                        plotFrame: plotFrame
                    )
                }
            }
        }
        .onChange(of: isEnabled) { _, newValue in
            if !newValue { selectedIndex = nil }
        }
    }

    /// 指定されたindexに対応する表示行を返します。
    /// - Parameter index: 表示行のindex。
    /// - Returns: 表示行。範囲外の場合は `nil`。
    private func displayRow(at index: Int) -> DatedHistoricalRow? {
        guard rows.indices.contains(index) else { return nil }
        return rows[index]
    }

    /// タッチ位置座標に一致するように選択indexを調整します。
    ///
    /// 前回と同じindexへは書き込まず、pointer eventの連続到着による不要な状態更新を抑止します。
    private func updateSelection(location: CGPoint, plotFrame: CGRect) {
        guard isEnabled else {
            if selectedIndex != nil { selectedIndex = nil }
            return
        }
        let index = ObservationGraphCalculator.nearestIndex(
            atX: location.x,
            plotFrame: plotFrame,
            start: xDomain.lowerBound,
            end: xDomain.upperBound,
            timestamps: timestamps
        )
        if index != selectedIndex {
            selectedIndex = index
        }
    }
}

/// 十字線マーカー（今年系列の値点）の描画直径。
private let graphMarkerDiameter: CGFloat = 9
