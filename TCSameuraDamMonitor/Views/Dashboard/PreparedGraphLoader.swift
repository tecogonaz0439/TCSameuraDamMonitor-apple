// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// グラフCardのscreen lifetimeでbase/display両snapshotをキャッシュするローダー。
///
/// 同期実装を採用する（非同期Task・generation tokenによる古い結果の破棄は行わない）。
/// 同一revisionでのparse+sortはPhase 0計測で約26msであり、pointer操作やmode・range切替の
/// たびに毎回実行するとMainActorを長時間ブロックするため、cache hit時の追加コストゼロと
/// stale結果の完全排除を優先して同期キャッシュとする。pointer操作（selectedDate変化）では
/// 表示keyが変わらないためcache hitし、RawRowSort/DisplayDataBuildは実行されない。
///
/// `@Observable`にはしない。cacheへの書き込みはCard body評価中に発生するため、
/// 観測対象にするとcache hitのたびにビューがinvalidateされ、無限レンダリングループになる。
/// 本クラスはbodyから命令的に参照されるだけで、viewがプロパティを観測する必要はない。
@MainActor
final class PreparedGraphLoader {
    /// base cacheの最大保持件数。
    internal static let baseCacheCapacity = 4
    /// display cacheの最大保持件数。
    internal static let displayCacheCapacity = 16

    /// display cacheのキー。base identity・revision・比較stampと全表示条件を含める。
    ///
    /// 1要素でも欠けるとstale表示を引き起こすため、変更可能な全入力（表示種類・範囲・
    /// 選択年・履歴モード・locale fingerprint）を明示的に保持する。
    internal struct DisplayCacheKey: Hashable {
        /// データの出所。
        let identity: GraphInputSnapshot.SourceIdentity
        /// データリビジョン。
        let dataRevision: Int
        /// 比較データの同一性stamp。
        let comparison: GraphInputSnapshot.ComparisonStamp
        /// 表示種類。
        let kind: ObservationGraphDisplayKind
        /// 選択されたグラフ範囲。
        let range: RealtimeGraphRange
        /// 過去比較で選択された過去年（昇順ソート済み）。
        let selectedYears: [Int]
        /// 過去データ検索結果を表示しているかどうか。
        let isHistorical: Bool
        /// summary等のlocale依存出力を区別するfingerprint。
        let localeFingerprint: String
    }

    /// base cacheのエントリ。
    private struct BaseEntry {
        let revision: Int
        let comparison: GraphInputSnapshot.ComparisonStamp
        let snapshot: GraphBaseSnapshot
        var lastUsed: Int
    }

    /// display cacheのエントリ。
    private struct DisplayEntry {
        let snapshot: GraphDisplaySnapshot
        var lastUsed: Int
    }

    /// base cache（source identityごとに1件、最大`baseCacheCapacity`件）。
    private var baseCache: [GraphInputSnapshot.SourceIdentity: BaseEntry] = [:]
    /// display cache（表示keyごとに1件、最大`displayCacheCapacity`件）。
    private var displayCache: [DisplayCacheKey: DisplayEntry] = [:]
    /// LRU判定用の使用順カウンタ。
    private var recencyCounter = 0
    /// base snapshotの構築回数（テスト・計測用）。
    private(set) var baseBuildCount = 0
    /// display snapshotの構築回数（テスト・計測用）。
    private(set) var displayBuildCount = 0

    /// 構築回数のカウンタをリセットします（計測用）。
    func resetCounters() {
        baseBuildCount = 0
        displayBuildCount = 0
    }

    /// 入力に対応するbase snapshotを返します。
    ///
    /// 同一（identity・revision・比較stamp）ならキャッシュを返し、それ以外は構築して
    /// 保存します。構築は`BasePrepare`signpostで計測されます。
    /// - Parameter input: グラフ入力snapshot。
    /// - Returns: base snapshot。
    func baseSnapshot(for input: GraphInputSnapshot) -> GraphBaseSnapshot {
        if let entry = baseCache[input.identity],
           entry.revision == input.dataRevision,
           entry.comparison == input.comparison {
            touch(entry: entry, key: input.identity)
            return entry.snapshot
        }
        baseBuildCount += 1
        let rangeOptions: [RealtimeGraphRange]
        switch input.identity {
        case .historicalSearch, .sudmonitorHistory:
            rangeOptions = [.all]
        case .realtime:
            rangeOptions = ObservationGraphCalculator.realtimeGraphRangeOptions(rows: input.rawRows)
        }
        let snapshot = PreparedGraphDataBuilder.base(from: input.rawRows, rangeOptions: rangeOptions)
        recencyCounter += 1
        baseCache[input.identity] = BaseEntry(
            revision: input.dataRevision,
            comparison: input.comparison,
            snapshot: snapshot,
            lastUsed: recencyCounter
        )
        evictBaseIfNeeded()
        return snapshot
    }

    /// 入力と表示条件に対応するdisplay snapshotを返します。
    ///
    /// 表示key（base identity・revision・比較stamp・表示種類・範囲・選択年・履歴モード・
    /// locale fingerprint）が同一ならキャッシュを返し、それ以外は構築して保存します。
    /// 構築は`DisplayDataBuild`signpostで計測されます。
    /// - Parameters:
    ///   - base: グラフ入力snapshot（key判定とbase cache解決に使う）。
    ///   - kind: 表示種類。
    ///   - range: 選択されたグラフ範囲。
    ///   - selectedYears: 過去比較で選択された過去年の集合。
    ///   - isHistorical: 過去データ検索結果を表示しているかどうか。
    ///   - comparisonPayload: 過去比較の読み込み結果ペイロード。
    ///   - rangeStartDate: 表示開始日のフィルター文字列。
    ///   - rangeEndDate: 表示終了日のフィルター文字列。
    ///   - meta: 過去データ検索設定のメタデータ。
    ///   - localeFingerprint: summary等のlocale依存出力を区別するfingerprint。
    /// - Returns: display snapshot。
    func displaySnapshot(
        base input: GraphInputSnapshot,
        kind: ObservationGraphDisplayKind,
        range: RealtimeGraphRange,
        selectedYears: Set<Int>,
        isHistorical: Bool,
        comparisonPayload: HistoricalComparisonPayload?,
        rangeStartDate: String?,
        rangeEndDate: String?,
        meta: HistoricalSearchMeta?,
        localeFingerprint: String
    ) -> GraphDisplaySnapshot {
        let baseSnapshot = baseSnapshot(for: input)
        let key = DisplayCacheKey(
            identity: input.identity,
            dataRevision: input.dataRevision,
            comparison: input.comparison,
            kind: kind,
            range: range,
            selectedYears: selectedYears.sorted(),
            isHistorical: isHistorical,
            localeFingerprint: localeFingerprint
        )
        if let entry = displayCache[key] {
            recencyCounter += 1
            displayCache[key] = DisplayEntry(snapshot: entry.snapshot, lastUsed: recencyCounter)
            return entry.snapshot
        }
        displayBuildCount += 1
        let snapshot = PreparedGraphDataBuilder.display(
            base: baseSnapshot,
            kind: kind,
            range: range,
            selectedYears: selectedYears,
            isHistorical: isHistorical,
            comparisonPayload: comparisonPayload,
            rangeStartDate: rangeStartDate,
            rangeEndDate: rangeEndDate,
            meta: meta,
            localeFingerprint: localeFingerprint
        )
        recencyCounter += 1
        displayCache[key] = DisplayEntry(snapshot: snapshot, lastUsed: recencyCounter)
        evictDisplayIfNeeded()
        return snapshot
    }

    /// base cacheエントリの使用順を更新します。
    /// - Parameters:
    ///   - entry: キャッシュされたエントリ。
    ///   - key: エントリのkey。
    private func touch(entry: BaseEntry, key: GraphInputSnapshot.SourceIdentity) {
        recencyCounter += 1
        baseCache[key] = BaseEntry(
            revision: entry.revision,
            comparison: entry.comparison,
            snapshot: entry.snapshot,
            lastUsed: recencyCounter
        )
    }

    /// base cacheが容量を超えた場合、最も古いエントリを破棄します。
    private func evictBaseIfNeeded() {
        guard baseCache.count > Self.baseCacheCapacity else { return }
        if let key = baseCache.min(by: { $0.value.lastUsed < $1.value.lastUsed })?.key {
            baseCache.removeValue(forKey: key)
        }
    }

    /// display cacheが容量を超えた場合、最も古いエントリを破棄します。
    private func evictDisplayIfNeeded() {
        guard displayCache.count > Self.displayCacheCapacity else { return }
        if let key = displayCache.min(by: { $0.value.lastUsed < $1.value.lastUsed })?.key {
            displayCache.removeValue(forKey: key)
        }
    }
}
