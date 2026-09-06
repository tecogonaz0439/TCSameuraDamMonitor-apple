// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// ウィジェットとメインアプリ間で共有される UserDefaults (App Group) のキーを定義する列挙型。
public enum WidgetDefaultsKey {
    /// アプリのスナップショットデータを格納するキー。
    public static let appSnapshot = "widget.appSnapshot"
    /// バージョン1のスナップショットデータを格納するキー。
    public static let snapshotV1 = "widget.snapshot.v1"
    /// バージョン1の rawDatBridge データを格納するキー。
    public static let rawDatBridgeV1 = "widget.rawDatBridge.v1"
    public static let dailyHistoryBridgeV1 = "widget.dailyHistoryBridge.v1"
    /// 設定されたメッセージ辞書データを格納するキー。
    public static let messages = "widget.messages"
    /// データ取得ログを格納するキー。
    public static let fetchLog = "widget.fetchLog"
    /// データ取得失敗ログを格納するキー。
    public static let fetchFailLog = "widget.fetchFailLog"
    /// タイムラインコールログを格納するキー。
    public static let timelineCallLog = "widget.timelineCallLog"
    /// データ取得可否の判定ログを格納するキー。
    public static let fetchDecisionLog = "widget.fetchDecisionLog"
    /// リロードコールログを格納するキー。
    public static let reloadCallLog = "widget.reloadCallLog"
    /// アプリが設定済み（セットアップ完了）かどうかを示すフラグのキー。
    public static let appConfigured = "widget.appConfigured"
    /// 自動更新が有効かどうかを示すフラグのキー。
    public static let autoUpdateEnabled = "widget.autoUpdateEnabled"
    /// 通知を表示するかどうかを示すフラグのキー。
    public static let showNotification = "widget.showNotification"
    /// 次回要求される更新日時のキー。
    public static let nextRequestedUpdate = "widget.nextRequestedUpdate"
    /// 自動更新の間隔（秒数）を格納するキー。
    public static let autoUpdateIntervalSeconds = "widget.autoUpdateIntervalSeconds"
    /// ダムの表示名を格納するキー。
    public static let damDisplayName = "widget.damDisplayName"
    /// データソースとなるURLのキー。
    public static let dataUrl = "widget.dataUrl"
    /// 観測所のIDのキー。
    public static let stationId = "widget.stationId"
    /// 観測所の名前のキー。
    public static let stationName = "widget.stationName"
    /// デバッグモードが有効かどうかを示すフラグ의キー。
    public static let debugModeEnabled = "widget.debugModeEnabled"
    /// デバッグシミュレーションのモードを格納するキー。
    public static let debugSimulateMode = "widget.debugSimulateMode"
    /// 初回データ取得が完了しているかどうかを示すフラグのキー。
    public static let initialLoadDone = "widget.initialLoadDone"
    /// アプリ側の最終データ取得日時を格納するキー。
    public static let appLastFetchAt = "widget.appLastFetchAt"
    /// ウィジェット側の最終データ取得日時を格納するキー。
    public static let widgetLastFetchAt = "widget.widgetLastFetchAt"
    /// アプリ起動時の更新が完了した日時を格納するキー。
    public static let appBootUpdateDoneAt = "widget.appBootUpdateDoneAt"
    /// ウィジェット起動時の更新が完了した日時を格納するキー。
    public static let widgetBootUpdateDoneAt = "widget.widgetBootUpdateDoneAt"
    /// 最後に記録されたシステムアップタイムを格納するキー。
    public static let lastKnownSystemUptime = "widget.lastKnownSystemUptime"
    /// リアルタイムデータの取得ソース（`realtimeSourceSudmonitor` / `realtimeSourceMlitDirect`）を格納するキー。
    public static let realtimeSource = "widget.realtimeSource"
    /// sudmonitor 中継取得用の完全な `.dat` URL を格納するキー。
    public static let realtimeDatUrl = "widget.realtimeDatUrl"
    /// リアルタイムデータ取得ソース: sudmonitor 中継。
    public static let realtimeSourceSudmonitor = "sudmonitor"
    /// リアルタイムデータ取得ソース: 国土交通省 (MLIT) 直接取得。
    public static let realtimeSourceMlitDirect = "mlitDirect"
    public static let historicalDataSource = "widget.historicalDataSource"
    public static let historicalDataSourceSudmonitor = "sudmonitor"
    public static let historicalDataSourceMlitDirect = "mlitDirect"
}
