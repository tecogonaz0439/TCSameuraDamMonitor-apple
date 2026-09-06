// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// グラフCardの入力となる、source identity・raw rows・data revision・比較stampを同時に固定する不変スナップショット。
///
/// 非同期計算中に別世代の値を混ぜないための入力境界です。MainActor上のCard body評価で
/// 一度だけ構築され、base/display両cacheのkey判定に使われます。
struct GraphInputSnapshot: Sendable, Equatable {
    /// グラフデータの出所を表す識別子。
    enum SourceIdentity: Sendable, Equatable, Hashable {
        /// リアルタイム観測データ（ダムID）。
        case realtime(damID: String)
        /// 保存済み過去データ検索の結果（検索結果meta IDと表示期間フィルタ境界）。
        case historicalSearch(metaID: UUID, filterStart: String?, filterEnd: String?)
        /// sudmonitor 日次過去データ（ダムIDと表示期間フィルタ境界）。
        case sudmonitorHistory(damID: String, filterStart: String?, filterEnd: String?)
    }

    /// 過去比較データの読み込み世代と表示対象metricの同一性を示すstamp。
    ///
    /// raw rowsが不変でも、payloadが`loading`から`ready`へ変わった場合にisReadyが
    /// 反転するため、cacheの失効条件として機能します。
    struct ComparisonStamp: Sendable, Equatable, Hashable {
        /// `HistoricalComparisonLoader.generation`（snapshot取得時点の値）。
        var generation: Int
        /// 表示中の比較metric。過去比較以外は `nil`。
        var metric: HistoricalComparisonMetric?
        /// 表示対象metricのpayloadが `.ready` かどうか。
        var isReady: Bool
    }

    /// データの出所。
    let identity: SourceIdentity
    /// 生の履歴行（未変換・並び順保証なし）。
    let rawRows: [DamHistoricalData]
    /// モデル側で単調増加するデータリビジョン。
    let dataRevision: Int
    /// 比較データの同一性stamp。
    let comparison: ComparisonStamp

    /// 現在のCard入力から入力スナップショットを構築します（MainActor上のCard body評価専用）。
    ///
    /// ローダーのgenerationと表示対象metricの読み込み状態を同時に取り出すことで、
    /// snapshot作成時点の比較データ状態を固定します。
    /// - Parameters:
    ///   - identity: データの出所。
    ///   - rawRows: 生の履歴行。
    ///   - dataRevision: モデル側のデータリビジョン。
    ///   - loader: 過去比較の読み込みローダー。
    ///   - metric: 表示中の比較metric（過去比較以外は `nil`）。
    /// - Returns: 構築された入力スナップショット。
    @MainActor
    static func current(
        identity: SourceIdentity,
        rawRows: [DamHistoricalData],
        dataRevision: Int,
        loader: HistoricalComparisonLoader,
        metric: HistoricalComparisonMetric?
    ) -> GraphInputSnapshot {
        let isReady: Bool
        if let metric {
            if case .ready = loader.state(for: metric) {
                isReady = true
            } else {
                isReady = false
            }
        } else {
            isReady = false
        }
        return GraphInputSnapshot(
            identity: identity,
            rawRows: rawRows,
            dataRevision: dataRevision,
            comparison: ComparisonStamp(generation: loader.generation, metric: metric, isReady: isReady)
        )
    }
}
