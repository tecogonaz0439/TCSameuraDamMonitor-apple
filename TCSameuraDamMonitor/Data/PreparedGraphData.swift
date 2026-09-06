// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// 連続するデータポイントを分割するための最大時間間隔（3時間超で線分を分断）。
internal let damChartLineBreakGap: TimeInterval = 3 * 60 * 60

/// 線描画に使う1系列あたりの最大点数。
///
/// Swift Chartsは1点1マークとして展開されるため、これを超える系列は
/// 視覚形状（極大・極小）を保ったまま間引く。ツールチップ・十字線の当たり判定は
/// 元の全行に対して行われるため、表示精度には影響しない。
internal let damChartMaxLinePoints = 600

/// ダムチャート用のデータポイント表現。
struct DamChartPoint: Identifiable, Equatable, Sendable {
    /// データポイントの一意の識別子。
    let id: String
    /// データポイントに関連付けられた日時。
    let date: Date
    /// このデータポイントの数値。
    let value: Double
}

/// 過去年比較グラフの1年分の描画セグメント。
struct PastYearChartSeries: Identifiable, Equatable, Sendable {
    /// 年。
    let year: Int
    /// Y軸の系列名（年ラベル）。
    let axisLabel: String
    /// 欠測・大きなギャップで分割された線分。
    let segments: [DamChartSegment]

    var id: Int { year }
}

/// 昇順点列を視覚形状（極大・極小）を保ちつつ最大`maxPoints`点へ間引きます。
///
/// 内部区間（先頭・末尾以外）を重なりのないバケットへ等分割し、バケットごとに
/// 最小値点と最大値点を保持するmin/maxデシメーションです。先頭点と末尾点は常に保持し、
/// 同一バケット内で最小値点と最大値点が同一点になる場合は1点のみ追加します。
/// `points.count <= maxPoints`の場合はそのまま返します。
/// - Parameters:
///   - points: 日時昇順の点列。
///   - maxPoints: 最大点数。
/// - Returns: 間引かれた点列。
func decimatedChartPoints(_ points: [DamChartPoint], maxPoints: Int = damChartMaxLinePoints) -> [DamChartPoint] {
    let count = points.count
    guard count > maxPoints, maxPoints >= 4 else { return points }
    let pairCount = maxPoints / 2
    var result: [DamChartPoint] = []
    result.reserveCapacity(maxPoints + 2)
    result.append(points[0])
    let innerCount = count - 2
    let bucketWidth = Double(innerCount) / Double(pairCount)
    var cursor = 1
    for bucket in 0..<pairCount {
        let rawEnd = 1 + Int((Double(bucket + 1) * bucketWidth).rounded(.up))
        let end = min(count - 1, max(cursor + 1, rawEnd))
        let start = cursor
        guard start < end else { continue }
        var minValue = points[start]
        var maxValue = points[start]
        for point in points[start..<end] {
            if point.value < minValue.value { minValue = point }
            if point.value > maxValue.value { maxValue = point }
        }
        // 定値バケットではmin/maxが同一点になるため、ForEachのID重複を避けて1点のみ追加する。
        if minValue.date <= maxValue.date {
            result.append(minValue)
            if maxValue.id != minValue.id { result.append(maxValue) }
        } else {
            result.append(maxValue)
            if minValue.id != maxValue.id { result.append(minValue) }
        }
        cursor = end
    }
    result.append(points[count - 1])
    return result
}

/// 複数のチャートデータポイントをグループ化する線分表現。
struct DamChartSegment: Identifiable, Equatable, Sendable {
    /// セグメントの一意の識別子。
    let id: String
    /// このセグメントのデータポイント of 配列。
    let points: [DamChartPoint]
}

/// metric・locale・plot幅に依存しない、グラフ表示の基底となるsnapshot。
///
/// 同一のsource identity + data revision + 比較stampに対しては一度だけ構築され、
/// 表示条件（mode・range・選択年・locale）の変更では再構築されません。
struct GraphBaseSnapshot: Sendable, Equatable {
    /// 日付変換と昇順ソートを一度だけ行った履歴行。
    let rows: [DatedHistoricalRow]
    /// 昇順ソート済みの日時配列（二分探索用）。
    let timestamps: [Date]
    /// 選択可能なグラフ範囲オプション。
    let rangeOptions: [RealtimeGraphRange]
}

/// metric固有の表示内容を含む、表示層向けsnapshot。
///
/// 表示key（source identity・revision・比較stamp・kind・range・選択年・locale等）ごとに
/// 一度だけ構築され、pointer操作のような表示条件以外の変化では再構築されません。
struct GraphDisplaySnapshot: Sendable, Equatable {
    /// 表示範囲でスライスされた表示行（過去データ検索モードでは全区間の行）。
    let rows: [DatedHistoricalRow]
    /// 表示行の昇順日時配列（オーバーレイの二分探索用。body評価ごとの再生成を回避）。
    let timestamps: [Date]
    /// X軸の表示domain。
    let domain: ClosedRange<Date>
    /// 期間・最大最小のサマリーテキスト（locale依存）。
    let summary: String
    /// 貯水率スケール値（非表示kindでは空）。
    let storageScaleValues: [Double]
    /// 雨量スケール値（非表示kindでは空）。
    let rainfallScaleValues: [Double]
    /// 貯水量スケール値（非表示kindでは空）。
    let volumeScaleValues: [Double]
    /// 流入量スケール値（非表示kindでは空）。
    let inflowScaleValues: [Double]
    /// 放流量スケール値（非表示kindでは空）。
    let outflowScaleValues: [Double]
    /// 貯水量軸の最大値（貯水量系kindのみ設定）。
    let volumeMax: Double?
    /// 流量軸の最大値（貯水量系kindのみ設定）。
    let flowMax: Double?
    /// 雨量軸の最大値（雨量系kindのみ設定）。
    let rainfallAxisMax: Double?
    /// 流量スケール値が存在するかどうか。
    let hasFlowScaleData: Bool
    /// 貯水量軸の目盛り値（スケール済み）。
    let volumeTickValues: [Double]
    /// 流量軸の目盛り値（スケール済み・データなしは空）。
    let flowTickValues: [Double]
    /// 貯水率の線分マーカー（非表示kindでは空）。
    let storageSegments: [DamChartSegment]
    /// 雨量の線分マーカー（非表示kindでは空）。
    let rainfallSegments: [DamChartSegment]
    /// 貯水量の線分マーカー（非表示kindでは空）。
    let volumeSegments: [DamChartSegment]
    /// 流入量の線分マーカー（非表示kindでは空）。
    let inflowSegments: [DamChartSegment]
    /// 放流量の線分マーカー（非表示kindでは空）。
    let outflowSegments: [DamChartSegment]
    /// 過去年比較系列（貯水率kind用・%値、非比較kindでは空）。
    let pastStorageSeries: [PastYearChartSeries]
    /// 過去年比較系列（貯水量kind用・軸maxで%スケール、非比較kindでは空）。
    let pastVolumeSeries: [PastYearChartSeries]
    /// 表示domain内で線が実際に描かれる過去年の集合（tooltip絞り込み用）。
    let drawnPastYears: Set<Int>
}
