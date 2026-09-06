// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// グラフのライン(表示/非表示を切り替えられる系列)を表す列挙型。
nonisolated enum GraphLine: String, CaseIterable, Sendable, Hashable {
    /// 貯水率 (%)
    case storageRate
    /// 流域平均雨量 (mm)
    case rainfall
    /// 貯水量 (万立方メートル)
    case storageVolume
    /// 流入量 (m³/s)
    case inflow
    /// 放流量 (m³/s)
    case outflow
}

/// グラフラインの表示/非表示と主系列(今年のライン)の描画判定を担う純粋関数群。
nonisolated enum GraphLineVisibility {
    /// ラインの表示/非表示トグル遷移を返します。
    /// - Parameters:
    ///   - line: トグル対象のライン。
    ///   - current: 現在の表示中ライン集合。
    /// - Returns: 遷移後の表示中ライン集合。
    static func togglingLine(_ line: GraphLine, current: Set<GraphLine>) -> Set<GraphLine> {
        var next = current
        if next.contains(line) {
            next.remove(line)
        } else {
            next.insert(line)
        }
        return next
    }

    /// 主系列(主系列年のライン)を描画するかを判定します。
    ///
    /// 非比較モード(mode 1/2)ではメトリックラインの選択状態(`visibleLines`)に従い、
    /// 主系列のチップ(「貯水率」「貯水量」)を外すと主線が描画されなくなります。
    /// 比較モード(mode 3/4)では主系列年チップの選択状態(`selectedYears`)に従います。
    /// 比較データ非ロード時は年チップが無いためfalse(読み込みオーバーレイで覆われる)。
    /// - Parameters:
    ///   - isComparisonMode: 比較モード(mode 3/4)であるかどうか。
    ///   - mainLine: 主系列のライン(貯水率または貯水量)。
    ///   - visibleLines: 選択中のメトリックラインの集合。
    ///   - comparisonMainYear: 比較データが保持する主系列の年(通常の過去データ表示では表示対象データの年)。比較データ非ロード時は `nil`。
    ///   - selectedYears: 選択中の年の集合(比較年+主系列年)。
    /// - Returns: 主系列を描画する場合は `true`。
    static func isCurrentYearLineVisible(
        isComparisonMode: Bool,
        mainLine: GraphLine,
        visibleLines: Set<GraphLine>,
        comparisonMainYear: Int?,
        selectedYears: Set<Int>
    ) -> Bool {
        if isComparisonMode {
            guard let comparisonMainYear else { return false }
            return selectedYears.contains(comparisonMainYear)
        }
        return visibleLines.contains(mainLine)
    }

    /// 指定した現行系列を描画するかを判定します。
    ///
    /// 主系列は`isCurrentYearLineVisible`と同じく比較モードでは主系列年チップ、
    /// 非比較モードでは主系列ラインチップに従います。副系列はラインチップの
    /// 選択状態に従います。LineMarkと操作中markerの両方からこの判定を利用して、
    /// 系列ごとの表示条件を一致させます。
    static func isLineVisible(
        _ line: GraphLine,
        isComparisonMode: Bool,
        mainLine: GraphLine,
        visibleLines: Set<GraphLine>,
        comparisonMainYear: Int?,
        selectedYears: Set<Int>
    ) -> Bool {
        if line == mainLine {
            return isCurrentYearLineVisible(
                isComparisonMode: isComparisonMode,
                mainLine: mainLine,
                visibleLines: visibleLines,
                comparisonMainYear: comparisonMainYear,
                selectedYears: selectedYears
            )
        }
        return visibleLines.contains(line)
    }
}
