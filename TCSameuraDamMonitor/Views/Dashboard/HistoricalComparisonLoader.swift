// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Observation

/// 過去比較グラフのデータ読み込み状態をMetricごとに管理し、画面ライフタイムのキャッシュと古い完了結果の無視を行うローダー。
///
/// metric非依存の`HistoricalComparisonBase`を画面ライフタイムで1回だけ構築し、metric切替は
/// asset読込なしでbaseからpayloadを同期派生します。baseの無効化条件は「ソース行の同一性
/// (rowsの時刻文字列列)の変化」と「generation進み(cancel・再読み込み)」です。baseは単一保持で、
/// 大きさは約24年×axis長の軽量データ(年別写像・年別lookup)です。
@MainActor
@Observable
final class HistoricalComparisonLoader {
    /// 過去比較データを読み込むサービス。
    private let service: HistoricalComparisonService
    /// Metricごとの読み込み状態。
    private(set) var states: [HistoricalComparisonMetric: HistoricalComparisonLoadState] = [:]
    /// 実行中の読み込みタスク。
    private var loadTask: Task<Void, Never>?
    /// 読み込み世代トークン。キャンセルや再読み込みで進み、古い完了結果を無視するために使う。
    /// `GraphInputSnapshot`の比較stamp（base/display cacheの失効条件）が読み取れるよう公開します。
    private(set) var generation = 0
    /// 画面ライフタイムのmetric非依存比較基底。有効ならmetric切替をasset読込なしで派生できます。
    private var base: HistoricalComparisonBase?
    /// base構築時のソース行の同一性(時刻文字列列)。rowsが変わるとbaseを再構築します。
    private var baseRowsTimes: [String]?
    /// base構築時の日次過去データ行の同一性(時刻文字列列)。dailyRowsが変わるとbaseを再構築します。
    private var baseDailyRowsTimes: [String]?
    /// base構築時の主系列年。mainYearが変わるとbaseを再構築します。
    private var baseMainYear: Int?

    /// ローダーを初期化します。
    /// - Parameter service: 過去比較データを読み込むサービス。
    init(service: HistoricalComparisonService) {
        self.service = service
    }

    /// 指定したMetricの読み込み状態を返します。
    /// - Parameter metric: 測定値の種類。
    /// - Returns: 読み込み状態。未登録の場合は `.idle`。
    func state(for metric: HistoricalComparisonMetric) -> HistoricalComparisonLoadState {
        states[metric] ?? .idle
    }

    /// 指定したMetricの過去比較データを読み込みます。
    ///
    /// 既に `.ready` または `.loading` の場合は何もしません(metric別の画面ライフタイムキャッシュ)。
    /// baseが未構築、またはrowsの時刻文字列列・日次行の時刻文字列列・主系列年がbase構築時と
    /// 異なる場合は、metric非依存の比較baseを再構築します。実行中タスクがある場合はキャンセルし、
    /// 世代トークンを進めて古い完了結果が反映されないようにします。baseが有効で入力が不変なら、
    /// TaskやI/Oなしにbaseから該当Metricのpayloadを同期派生します(世代を進めず `.loading` を経由しません)。
    /// - Parameters:
    ///   - metric: 測定値の種類。
    ///   - damConfigId: 対象のダム構成設定ID。
    ///   - rows: 現在の観測行。
    ///   - mainYear: 主系列の年。未指定時はJST現在年(リアルタイム・日次の従来挙動)。
    ///   - dailyRows: 読込済み日次過去データの行(通常の過去データ表示で最新年の比較系列へ合成する)。
    func load(metric: HistoricalComparisonMetric, damConfigId: String, rows: [DamHistoricalData],
              mainYear: Int? = nil, dailyRows: [DamHistoricalData] = []) {
        switch states[metric] {
        case .ready, .loading:
            return
        default:
            break
        }
        let rowTimes = rows.map(\.time)
        let dailyRowTimes = dailyRows.map(\.time)
        guard base == nil || baseRowsTimes != rowTimes || baseDailyRowsTimes != dailyRowTimes
                || baseMainYear != mainYear else {
            states[metric] = .ready(service.payload(from: base!, metric: metric))
            return
        }
        loadTask?.cancel()
        for key in states.keys where states[key] == .loading {
            states[key] = .idle
        }
        generation += 1
        states[metric] = .loading
        let currentGeneration = generation
        loadTask = Task { [service] in
            do {
                let newBase = try await service.loadBase(damConfigId: damConfigId, rows: rows,
                                                         mainYear: mainYear, dailyRows: dailyRows)
                guard !Task.isCancelled, currentGeneration == generation else { return }
                self.base = newBase
                self.baseRowsTimes = rowTimes
                self.baseDailyRowsTimes = dailyRowTimes
                self.baseMainYear = mainYear
                states[metric] = .ready(service.payload(from: newBase, metric: metric))
            } catch {
                guard !Task.isCancelled, currentGeneration == generation else { return }
                states[metric] = .failed
            }
        }
    }

    /// 読み込みタスクをキャンセルし、すべての状態と画面ライフタイムの比較基底を初期化します。
    ///
    /// 基底を破棄するため、次の読み込みは入力が不変でもbaseを再構築します。
    func cancel() {
        generation += 1
        loadTask?.cancel()
        loadTask = nil
        states = [:]
        base = nil
        baseRowsTimes = nil
        baseDailyRowsTimes = nil
        baseMainYear = nil
    }
}
