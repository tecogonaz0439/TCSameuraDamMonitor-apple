// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import WidgetKit
import UserNotifications
import TCSameuraDamCore
import os

/// ウィジェットのロケール固有の情報を解決するユーティリティ。
enum WidgetLocale {
    /// ユーザーの優先設定に基づいて解決された言語コード。
    static var effectiveLanguageCode: String {
        let preferred = Locale.preferredLanguages
            .compactMap { Locale(identifier: $0).language.languageCode?.identifier }
            .first
        return preferred ?? Locale.autoupdatingCurrent.language.languageCode?.identifier ?? "en"
    }

    /// 現在の言語が日本語であるかどうかを示す真偽値。
    static var isJapanese: Bool {
        effectiveLanguageCode == "ja"
    }
}

/// ウィジェットのUI表示用に調整されたローカライズ文字列を提供するヘルパー。
enum WidgetText {
    /// アクティブな言語が日本語であるかどうかを示す真偽値。
    static var isJapanese: Bool {
        WidgetLocale.isJapanese
    }

    private static func t(_ key: String) -> String {
        WidgetLocalized.text(key)
    }

    /// ローカライズされたアプリケーション名。
    static var appName: String { t("widget.appName") }
    /// データが欠落している場合に表示されるプロンプトの1行目。
    static var promptLine1: String { t("widget.promptLine1") }
    /// データが欠落している場合に表示されるプロンプトの2行目。
    static var promptLine2: String { t("widget.promptLine2") }
    /// ウィジェット設定ギャラリーに表示される説明文。
    static var configurationDescription: String { t("widget.configurationDescription") }
    /// ダム名のフォールバック用プレースホルダー。
    static var placeholderDamName: String { t("widget.placeholderDamName") }

    /// 前日比（日変化量）のローカライズされたラベル。
    static var dayChangeLabel: String { t("widget.dayChange") }
    /// 前週比（週変化量）のローカライズされたラベル。
    static var weekChangeLabel: String { t("widget.weekChange") }
    /// 貯水量の単位のローカライズされたラベル。
    static var volumeUnit: String { t("widget.volumeUnit") }
    /// ユーザーに表示される初期セットアップメッセージ。
    static var initialMessage: String { t("widget.initialMessage") }
}

typealias DamWidgetSnapshot = DamCoreWidgetSnapshot

/// 特定の日時における早明浦ダムの状態を表すタイムラインエントリ。
struct DamWidgetEntry: TimelineEntry {
    /// ウィジェットを描画する日時。
    let date: Date
    /// 貯水率と貯水量を表すダムのスナップショット。
    let snapshot: DamWidgetSnapshot?
}

/// タイムライン生成用の完了ハンドラーを内包するスレッドセーフなラッパー。
private struct TimelineCompletion: @unchecked Sendable {
    /// タイムラインの構築が完了したときに実行する完了ハンドラー。
    let complete: (Timeline<DamWidgetEntry>) -> Void
}

private let fetchGate = OSAllocatedUnfairLock(initialState: false)

/// WidgetKitに対して早明浦ダムウィジェットの表示更新タイミングを提示するタイムラインプロバイダー。
struct DamWidgetProvider: TimelineProvider {
    /// ウィジェットを初めて描画するときに使用されるプレースホルダーエントリを返します。
    /// - Parameter context: ウィジェットに関するコンテキスト情報。
    /// - Returns: プレースホルダーデータを含む `DamWidgetEntry`。
    func placeholder(in context: Context) -> DamWidgetEntry {
        DamWidgetEntry(date: Date(), snapshot: Self.makeNoDataSnapshot())
    }

    /// ウィジェットの現在の状態を示す一時的なスナップショットを提供します。
    /// - Parameters:
    ///   - context: ウィジェットに関するコンテキスト情報.
    ///   - completion: 一時的なスナップショットを渡して実行する完了ブロック。
    func getSnapshot(in context: Context, completion: @escaping (DamWidgetEntry) -> Void) {
        let v1 = loadSnapshot()
        let app = loadAppSnapshot()
        if let snapshot = v1 ?? app {
            completion(DamWidgetEntry(date: Date(), snapshot: snapshot))
        } else {
            completion(DamWidgetEntry(date: Date(), snapshot: Self.makeNoDataSnapshot()))
        }
    }

    /// 早明浦ダムのリアルタイム観測データを含むエントリのタイムラインを生成します。
    /// - Parameters:
    ///   - context: ウィジェットに関するコンテキスト情報。
    ///   - completion: 生成されたタイムラインを渡して実行する完了ブロック。
    func getTimeline(in context: Context, completion: @escaping (Timeline<DamWidgetEntry>) -> Void) {
        appendTimelineCallLog()
        let timelineCompletion = TimelineCompletion(complete: completion)
        Task {
            let canFetch = fetchGate.withLock { isFetching -> Bool in
                if isFetching { return false }
                isFetching = true
                return true
            }
            guard canFetch else {
                let fallback = timelinePolicyFallback()
                timelineCompletion.complete(fallback)
                return
            }
            defer {
                fetchGate.withLock { $0 = false }
            }
            var cachedSnapshot = loadSnapshot()
            let appSnapshot = loadAppSnapshot()
            if let appSnapshot, shouldUseAppSnapshot(appSnapshot, cachedSnapshot: cachedSnapshot) {
                saveSnapshot(appSnapshot)
                cachedSnapshot = appSnapshot
            }

            let currentUptime = ProcessInfo.processInfo.systemUptime
            let savedUptime = widgetDouble(forKey: WidgetDefaultsKey.lastKnownSystemUptime)
            let isNewBoot = savedUptime > 0 && currentUptime < savedUptime
            let appBootUpdateDone = widgetDouble(forKey: WidgetDefaultsKey.appBootUpdateDoneAt) > 0

            var nextRefresh = loadNextRequestedUpdate()
            let decision = fetchDecision(cachedSnapshot: cachedSnapshot, nextRefresh: nextRefresh, now: Date())
            if decision.allowed {
                appendFetchDecisionLog(allowed: true, reason: decision.reason)
                let oldSnapshot = cachedSnapshot
                do {
                    let (snapshot, rawDatBridge) = try await WidgetDataFetcher.fetchSnapshot()
                    saveSnapshot(snapshot)
                    saveRawDatBridge(rawDatBridge)
                    saveWidgetLastFetchAt(Date())
                    nextRefresh = advanceNextRequestedUpdate(previous: nextRefresh, now: Date())
                    let isWidgetBootUpdate = isNewBoot && !appBootUpdateDone
                    appendFetchLog(damName: snapshot.damName, updatedAt: snapshot.updatedAt, observedAt: snapshot.observedAt, isBootUpdate: isWidgetBootUpdate, isInitial: oldSnapshot == nil && !isWidgetBootUpdate)
                    setWidgetValue(currentUptime, forKey: WidgetDefaultsKey.lastKnownSystemUptime)
                    if isWidgetBootUpdate {
                        setWidgetValue(Date().timeIntervalSinceReferenceDate, forKey: WidgetDefaultsKey.widgetBootUpdateDoneAt)
                    }
                    if snapshotHasChanged(newSnapshot: snapshot, oldSnapshot: oldSnapshot) {
                        appendReloadCallLog(reason: "snapshotChanged")
                        if loadShowNotification() {
                            await sendWidgetNotification(snapshot: snapshot)
                        }
                    }
                    cachedSnapshot = snapshot
                } catch {
                    appendFetchDecisionLog(allowed: false, reason: "fetchFailed:\((error as NSError).description)")
                    appendFetchFailLog(reason: (error as NSError).description)
                }
            } else {
                appendFetchDecisionLog(allowed: false, reason: decision.reason)
            }

            await fetchDailyHistoryBridgeIfAllowed(now: Date())

            let entry = DamWidgetEntry(date: Date(), snapshot: cachedSnapshot ?? DamWidgetProvider.makeNoDataSnapshot())
            timelineCompletion.complete(Timeline(entries: [entry], policy: timelinePolicy(snapshot: cachedSnapshot, nextRefresh: nextRefresh, now: Date())))
        }
    }

    /// アプリ側のスナップショットがウィジェットのキャッシュされたスナップショットより新しいかどうかを判定します。
    /// - Parameters:
    ///   - appSnapshot: メインアプリからのスナップショット。
    ///   - cachedSnapshot: ウィジェットのキャッシュされたスナップショット。
    /// - Returns: アプリのスナップショットを使用すべきかを示す真偽値。
    private func shouldUseAppSnapshot(_ appSnapshot: DamWidgetSnapshot, cachedSnapshot: DamWidgetSnapshot?) -> Bool {
        guard let cachedSnapshot else { return true }
        return appSnapshot.lastUpdatedAt > cachedSnapshot.lastUpdatedAt
    }

    /// 取得ロックが獲得できなかった場合のために、15分の再ロード間隔を持つフォールバックタイムラインを提供します。
    /// - Returns: フォールバックタイムライン。
    private func timelinePolicyFallback() -> Timeline<DamWidgetEntry> {
        let snapshot = loadSnapshot() ?? DamWidgetProvider.makeNoDataSnapshot()
        let entry = DamWidgetEntry(date: Date(), snapshot: snapshot)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60)))
    }

    /// レート制限、設定、およびキャッシュの有無に基づいて、新しい取得リクエストが許可されるかどうかを評価します。
    /// - Parameters:
    ///   - cachedSnapshot: 現在キャッシュされているスナップショット。
    ///   - nextRefresh: スケジュールされた次回の更新日時。
    ///   - now: 現在の日時。
    /// - Returns: 取得が許可されるかどうかを示す真偽値と、その決定理由を含むタプル。
    private func fetchDecision(cachedSnapshot: DamWidgetSnapshot?, nextRefresh: Date?, now: Date) -> (allowed: Bool, reason: String) {
        #if DEBUG
        if loadDebugModeEnabled() {
            return (false, "debugModeActive")
        }
        #endif
        let decision = DamCoreWidgetFetchGate.decision(
            initialLoadDone: loadInitialLoadDone(),
            autoUpdateEnabled: loadAutoUpdateEnabled(),
            debugSimulationActive: false,
            hasUsableCache: cachedSnapshot?.storagePercentage != nil,
            lastFetchAt: loadWidgetLastFetchAt(),
            nextRefresh: nextRefresh,
            now: now
        )
        return (decision.allowed, decision.reason)
    }

    /// キャッシュの有効性と次回更新スケジュールに基づいて、タイムラインの再ロードポリシーを決定します。
    /// - Parameters:
    ///   - snapshot: 現在のウィジェットスナップショット。
    ///   - nextRefresh: スケジュールされた次回の更新日時。
    ///   - now: 現在の日時。
    /// - Returns: タイムラインの再ロードポリシー。
    private func timelinePolicy(snapshot: DamWidgetSnapshot?, nextRefresh: Date?, now: Date) -> TimelineReloadPolicy {
        if snapshot?.storagePercentage == nil {
            return .after(now.addingTimeInterval(15 * 60))
        }
        if let nextRefresh, nextRefresh > now {
            return .after(nextRefresh)
        }
        return .after(now.addingTimeInterval(30 * 60))
    }

    /// 取得ログに新しいエントリを追加します。
    /// - Parameters:
    ///   - damName: ダムの表示名。
    ///   - updatedAt: データソースからの更新タイムスタンプ。
    ///   - observedAt: 観測タイムスタンプ。
    ///   - isBootUpdate: この取得がシステム起動によってトリガーされたかどうか。
    ///   - isInitial: これが最初の取得かどうか。
    private func appendFetchLog(damName: String, updatedAt: String, observedAt: String, isBootUpdate: Bool = false, isInitial: Bool = false) {
        var entries = WidgetDefaultsStore.shared.stringArray(forKey: WidgetDefaultsKey.fetchLog)
        let type = isBootUpdate ? "b" : (isInitial ? "i" : "a")
        entries.append("\(Date().timeIntervalSinceReferenceDate);\(type);\(damName);\(updatedAt);\(observedAt)")
        if entries.count > 128 {
            entries = Array(entries.suffix(128))
        }
        WidgetDefaultsStore.shared.set(entries, forKey: WidgetDefaultsKey.fetchLog)
    }

    /// 取得失敗ログに失敗エントリを追加します。
    /// - Parameter reason: 失敗の理由。
    private func appendFetchFailLog(reason: String) {
        var entries = WidgetDefaultsStore.shared.stringArray(forKey: WidgetDefaultsKey.fetchFailLog)
        entries.append("\(Date().timeIntervalSinceReferenceDate);\(reason)")
        if entries.count > 128 {
            entries = Array(entries.suffix(128))
        }
        WidgetDefaultsStore.shared.set(entries, forKey: WidgetDefaultsKey.fetchFailLog)
    }

    /// タイムライン呼び出しログに現在時刻を追加します。
    private func appendTimelineCallLog() {
        var entries = WidgetDefaultsStore.shared.stringArray(forKey: WidgetDefaultsKey.timelineCallLog)
        entries.append("\(Date().timeIntervalSinceReferenceDate)")
        if entries.count > 128 {
            entries = Array(entries.suffix(128))
        }
        WidgetDefaultsStore.shared.set(entries, forKey: WidgetDefaultsKey.timelineCallLog)
    }

    /// 取得決定の結果をログに追加します。
    /// - Parameters:
    ///   - allowed: 取得が許可されたかどうか。
    ///   - reason: その決定に至った理由。
    private func appendFetchDecisionLog(allowed: Bool, reason: String) {
        var entries = WidgetDefaultsStore.shared.stringArray(forKey: WidgetDefaultsKey.fetchDecisionLog)
        let status = allowed ? "allowed" : "skipped"
        entries.append("\(Date().timeIntervalSinceReferenceDate);\(status);\(reason)")
        if entries.count > 128 {
            entries = Array(entries.suffix(128))
        }
        WidgetDefaultsStore.shared.set(entries, forKey: WidgetDefaultsKey.fetchDecisionLog)
    }

    /// ウィジェットの再ロード呼び出しログにエントリを追加します。
    /// - Parameter reason: 再ロードをトリガーした理由。
    private func appendReloadCallLog(reason: String) {
        var entries = WidgetDefaultsStore.shared.stringArray(forKey: WidgetDefaultsKey.reloadCallLog)
        entries.append("\(Date().timeIntervalSinceReferenceDate);\(reason)")
        if entries.count > 128 {
            entries = Array(entries.suffix(128))
        }
        WidgetDefaultsStore.shared.set(entries, forKey: WidgetDefaultsKey.reloadCallLog)
    }

    /// 新しいスナップショットが、観測日時または貯水率の点で古いスナップショットと異なるかどうかを確認します。
    /// - Parameters:
    ///   - newSnapshot: 新しく取得されたスナップショット。
    ///   - oldSnapshot: 以前にキャッシュされたスナップショット。
    /// - Returns: スナップショットが変更されたかどうかを示す真偽値。
    private func snapshotHasChanged(newSnapshot: DamWidgetSnapshot, oldSnapshot: DamWidgetSnapshot?) -> Bool {
        guard let old = oldSnapshot else { return true }
        return newSnapshot.observedAt != old.observedAt || newSnapshot.storagePercentage != old.storagePercentage
    }

    /// ローカル通知が有効化されているかどうかを確認します。
    /// - Returns: 通知を表示すべきかどうかを示す真偽値。
    private func loadShowNotification() -> Bool {
        WidgetDefaultsStore.shared.bool(forKey: WidgetDefaultsKey.showNotification)
    }

    /// 早明浦ダムの更新された貯水率を表示するローカル通知を送信します。
    /// - Parameter snapshot: ダムのスナップショット。
    private func sendWidgetNotification(snapshot: DamWidgetSnapshot) async {
        let center = UNUserNotificationCenter.current()
        let notificationSettings = await center.notificationSettings()
        switch notificationSettings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: break
        default: return
        }
        let message = buildNotificationMessage(snapshot: snapshot)
        guard !message.isEmpty else { return }
        let content = UNMutableNotificationContent()
        content.title = WidgetText.appName
        content.body = message
        let request = UNNotificationRequest(identifier: "widget-dam-update", content: content, trigger: nil)
        try? await center.add(request)
    }

    /// スナップショットに基づいて通知の本文メッセージを構築します。
    /// - Parameter snapshot: ダムのスナップショット。
    /// - Returns: フォーマットされた通知メッセージ。
    private func buildNotificationMessage(snapshot: DamWidgetSnapshot) -> String {
        DamCoreWidgetPresentation.notificationMessage(snapshot: snapshot)
    }

    /// デフォルトストアからキャッシュされたスナップショットを読み込みます。
    /// - Returns: キャッシュされたスナップショット。見つからない場合は `nil`。
    private func loadSnapshot() -> DamWidgetSnapshot? {
        let data = WidgetDefaultsStore.shared.data(forKey: WidgetDefaultsKey.snapshotV1)
        guard let data else { return nil }
        return try? JSONDecoder().decode(DamWidgetSnapshot.self, from: data)
    }

    /// スナップショットをデフォルトストアに保存し、メインアプリ用に複製します。
    /// - Parameter snapshot: 保存するスナップショット。
    private func saveSnapshot(_ snapshot: DamWidgetSnapshot) {
        guard let encoded = try? JSONEncoder().encode(snapshot) else { return }
        setWidgetValue(encoded, forKey: WidgetDefaultsKey.snapshotV1)
        setWidgetValue(encoded, forKey: WidgetDefaultsKey.appSnapshot)
    }

    /// スケジュールされた次回の更新日時を読み込みます。
    /// - Returns: 次回の更新日時。
    private func loadNextRequestedUpdate() -> Date? {
        let interval = widgetDouble(forKey: WidgetDefaultsKey.nextRequestedUpdate)
        guard interval > 0 else { return nil }
        return Date(timeIntervalSinceReferenceDate: interval)
    }

    /// 自動更新間隔を加算して、次回の更新日時を進めます。
    /// - Parameters:
    ///   - previous: 以前にスケジュールされた更新日時。
    ///   - now: 現在の日時。
    /// - Returns: 進められた更新日時。
    private func advanceNextRequestedUpdate(previous: Date?, now: Date) -> Date? {
        guard var candidate = previous else { return nil }
        let interval = loadAutoUpdateInterval()
        guard interval > 0 else { return nil }
        while candidate <= now {
            candidate = candidate.addingTimeInterval(interval)
        }
        setWidgetValue(candidate.timeIntervalSinceReferenceDate, forKey: WidgetDefaultsKey.nextRequestedUpdate)
        return candidate
    }

    /// メインアプリによって書き込まれたスナップショットを読み込みます。
    /// - Returns: メインアプリのスナップショット。
    private func loadAppSnapshot() -> DamWidgetSnapshot? {
        guard let data = widgetData(forKey: WidgetDefaultsKey.appSnapshot) else { return nil }
        return try? JSONDecoder().decode(DamWidgetSnapshot.self, from: data)
    }

    /// 生のDATブリッジ情報をデフォルトストアに保存します。
    /// - Parameter bridge: 生のDATブリッジモデル。
    private func saveRawDatBridge(_ bridge: DamCoreRawDatBridge) {
        guard let encoded = try? JSONEncoder().encode(bridge) else { return }
        setWidgetValue(encoded, forKey: WidgetDefaultsKey.rawDatBridgeV1)
    }

    private func fetchDailyHistoryBridgeIfAllowed(now: Date) async {
        guard loadDailyHistoryFetchAllowed(now: now) else { return }
        let stationId = WidgetDefaultsStore.shared.string(forKey: WidgetDefaultsKey.stationId) ?? WidgetDataFetcher.sameuraStationId
        guard stationId == WidgetDataFetcher.sameuraStationId else { return }
        do {
            let bridge = try await WidgetDataFetcher.fetchDailyHistory(damId: stationId)
            saveDailyHistoryBridge(bridge)
        } catch {
        }
    }

    private func loadDailyHistoryFetchAllowed(now: Date) -> Bool {
        #if DEBUG
        guard !loadDebugModeEnabled() else { return false }
        #endif
        let source = WidgetDefaultsStore.shared.string(forKey: WidgetDefaultsKey.historicalDataSource) ?? WidgetDefaultsKey.historicalDataSourceSudmonitor
        guard source == WidgetDefaultsKey.historicalDataSourceSudmonitor else { return false }
        guard loadAutoUpdateEnabled() else { return false }
        let interval = loadAutoUpdateInterval()
        guard interval == 60 * 60 || interval == 12 * 60 * 60 else { return true }
        guard let bridge = loadDailyHistoryBridge() else { return true }
        return bridge.nextUpdateAt <= now
    }

    private func saveDailyHistoryBridge(_ bridge: DamCoreDailyHistoryBridge) {
        guard let encoded = try? JSONEncoder().encode(bridge) else { return }
        setWidgetValue(encoded, forKey: WidgetDefaultsKey.dailyHistoryBridgeV1)
    }

    private func loadDailyHistoryBridge() -> DamCoreDailyHistoryBridge? {
        guard let data = widgetData(forKey: WidgetDefaultsKey.dailyHistoryBridgeV1) else { return nil }
        return try? JSONDecoder().decode(DamCoreDailyHistoryBridge.self, from: data)
    }

    /// 最後に取得を試みたタイムスタンプを保存します。
    /// - Parameter date: 取得日時のタイムスタンプ。
    private func saveWidgetLastFetchAt(_ date: Date) {
        setWidgetValue(date.timeIntervalSinceReferenceDate, forKey: WidgetDefaultsKey.widgetLastFetchAt)
    }

    /// 最後に取得を試みたタイムスタンプを読み込みます。
    /// - Returns: 最後の取得日時のタイムスタンプ。
    private func loadWidgetLastFetchAt() -> Date? {
        let interval = widgetDouble(forKey: WidgetDefaultsKey.widgetLastFetchAt)
        guard interval > 0 else { return nil }
        return Date(timeIntervalSinceReferenceDate: interval)
    }

    /// 自動更新間隔（秒）を読み込みます。
    /// - Returns: 設定されていない場合のデフォルト値は7日間。
    private func loadAutoUpdateInterval() -> TimeInterval {
        let interval = widgetDouble(forKey: WidgetDefaultsKey.autoUpdateIntervalSeconds)
        return interval > 0 ? interval : 7 * 24 * 60 * 60
    }

    /// 自動更新が有効化されているかどうかを確認します。
    /// - Returns: 自動更新が有効な場合は真。
    private func loadAutoUpdateEnabled() -> Bool {
        WidgetDefaultsStore.shared.bool(forKey: WidgetDefaultsKey.autoUpdateEnabled)
    }

    /// 指定されたキーについて、ユーザーデフォルトからデータを取得します。
    /// - Parameter key: 検索するキー。
    /// - Returns: データ。見つからない場合は `nil`。
    private func widgetData(forKey key: String) -> Data? {
        WidgetDefaultsStore.shared.data(forKey: key)
    }

    /// ユーザーデフォルトから実数（Double）を取得します。
    /// - Parameter key: 検索するキー。
    /// - Returns: 実数値。
    private func widgetDouble(forKey key: String) -> Double {
        WidgetDefaultsStore.shared.double(forKey: key)
    }

    /// ユーザーデフォルトに値を書き込みます。
    /// - Parameters:
    ///   - value: 書き込む値。
    ///   - key: 値を関連付けるキー。
    private func setWidgetValue(_ value: Any, forKey key: String) {
        WidgetDefaultsStore.shared.set(value, forKey: key)
    }

    /// ユーザーデフォルトから値を削除します。
    /// - Parameter key: 削除するキー。
    private func removeWidgetValue(forKey key: String) {
        WidgetDefaultsStore.shared.removeObject(forKey: key)
    }

    /// リアルタイム観測データが利用できない場合に、フォールバック用のスナップショットを生成します。
    /// - Returns: フォールバック用の `DamWidgetSnapshot` オブジェクト。
    nonisolated static func makeNoDataSnapshot() -> DamWidgetSnapshot {
        let damName = damDisplayNameForWidget() ?? WidgetText.placeholderDamName
        let msg = initialMessageForWidget() ?? WidgetText.initialMessage
        return DamWidgetSnapshot(
            damName: damName,
            updatedAt: "",
            observedAt: "",
            storagePercentage: nil,
            trend: "unknown",
            storageVolume: nil,
            storageVolumeTrend: nil,
            storagePercentageDayChange: nil,
            dayChangeTrend: nil,
            storagePercentageWeekChange: nil,
            weekChangeTrend: nil,
            message: msg,
            isNetworkError: false,
            isAllDataInvalid: false,
            isSameura: isSameuraDamForWidget(),
            storageVolumeForMessage: nil,
            lastUpdatedAt: Date()
        )
    }

    /// メインアプリが設定済みかどうかを確認します。
    /// - Returns: アプリの設定が完了しているかどうかを示す真偽値。
    private func loadAppConfigured() -> Bool {
        WidgetDefaultsStore.shared.bool(forKey: WidgetDefaultsKey.appConfigured)
    }

    /// 初回のデータ読み込みが完了しているかどうかを確認します。
    /// - Returns: 初回読み込みが完了しているかどうかを示す真偽値。
    private func loadInitialLoadDone() -> Bool {
        if WidgetDefaultsStore.shared.bool(forKey: WidgetDefaultsKey.initialLoadDone) {
            return true
        }
        return loadSnapshot()?.storagePercentage != nil || loadAppSnapshot()?.storagePercentage != nil
    }

    /// デバッグモードが有効化されているかどうかを確認します。
    /// - Returns: デバッグモードがアクティブであるかどうかを示す真偽値。
    private func loadDebugModeEnabled() -> Bool {
        WidgetDefaultsStore.shared.bool(forKey: WidgetDefaultsKey.debugModeEnabled)
    }

}

/// アクティブなウィジェットファミリーと現在のタイムラインエントリに基づいて、早明浦ダムウィジェットを描画する SwiftUI ビュー。
struct TCSameuraDamMonitorWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @ScaledMetric(relativeTo: .body) private var widgetFontSize: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var smallDataFontSize: CGFloat = 12
    @ScaledMetric(relativeTo: .title3) private var mediumTitleFontSize: CGFloat = 20
    @ScaledMetric(relativeTo: .caption) private var accessoryEmojiFontSize: CGFloat = 14
    @ScaledMetric(relativeTo: .caption2) private var accessoryPercentFontSize: CGFloat = 10
    @ScaledMetric(relativeTo: .caption) private var accessoryRectangularFontSize: CGFloat = 12

    /// 早明浦ダムのスナップショットデータを含むタイムラインエントリ。
    let entry: DamWidgetEntry

    /// ビューの本体。
    var body: some View {
        switch family {
        case .accessoryInline:
            accessoryInlineBody
        case .accessoryCircular:
            accessoryCircularBody
        case .accessoryRectangular:
            accessoryRectangularBody
        default:
            let isSmall = family == .systemSmall
            VStack(spacing: 4) {
                Spacer(minLength: 0)
                if let snapshot = entry.snapshot {
                    Group {
                        if isSmall {
                            Text(snapshot.damName)
                                .font(widgetFont)
                        } else {
                            Text(snapshot.damName)
                                .font(.system(size: mediumTitleFontSize))
                        }
                    }
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if snapshot.storagePercentage == nil && snapshot.observedAt.isEmpty {
                        Text(snapshot.message)
                            .font(isSmall ? smallDataFont : widgetFont)
                            .lineLimit(isSmall ? 2 : 1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if isSmall {
                        smallDataRows(snapshot)
                    } else {
                        mediumDataRows(snapshot)
                    }
                } else {
                    Text(damDisplayNameForWidget() ?? WidgetText.placeholderDamName)
                        .font(widgetFont)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(WidgetText.promptLine1)
                        .font(widgetFont)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(WidgetText.promptLine2)
                        .font(widgetFont)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 0)
            }
            .padding(0)
            .containerBackground(.background, for: .widget)
        }
    }

    /// インライン・アクセサリ・ウィジェットファミリー用のビュー本体。
    @ViewBuilder
    private var accessoryInlineBody: some View {
        Text(accessoryInlineText)
            .lineLimit(1)
    }

    /// インライン・アクセサリ用のローカライズされたテキスト文字列。
    private var accessoryInlineText: String {
        guard let snapshot = entry.snapshot else {
            return WidgetText.initialMessage
        }
        return DamCoreWidgetPresentation.accessoryInlineText(
            snapshot: snapshot,
            placeholderMessage: "",
            initialMessage: WidgetText.initialMessage
        )
    }

    /// 貯水率を表示する円形（Circular）アクセサリ・ウィジェットファミリー用のビュー本体。
    @ViewBuilder
    private var accessoryCircularBody: some View {
        ZStack {
            #if os(iOS)
            AccessoryWidgetBackground()
            #endif
            if let snapshot = entry.snapshot, let pct = snapshot.storagePercentage {
                VStack(spacing: -2) {
                    Text(DamCoreWidgetPresentation.stateEmoji(from: snapshot.message))
                        .font(.system(size: accessoryEmojiFontSize))
                        .offset(y: -3)
                    Text("\(DamCoreWidgetPresentation.percentValue(pct))%")
                        .font(.system(size: accessoryPercentFontSize))
                }
            } else {
                Text("--%")
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    /// 貯水率のトレンドを表示する矩形（Rectangular）アクセサリ・ウィジェットファミリー用のビュー本体。
    @ViewBuilder
    private var accessoryRectangularBody: some View {
        ZStack {
            #if os(iOS)
            AccessoryWidgetBackground()
            #endif
            if let snapshot = entry.snapshot {
                if let pct = snapshot.storagePercentage {
                    let emoji = DamCoreWidgetPresentation.stateEmoji(from: snapshot.message)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(snapshot.damName)
                            .font(.system(size: accessoryRectangularFontSize, weight: .bold))
                            .lineLimit(1)
                        HStack {
                            Spacer()
                            Text(DamCoreWidgetPresentation.compactDateTime(snapshot.observedAt))
                                .font(.system(size: accessoryRectangularFontSize))
                        }
                        Text("\(emoji) \(DamCoreWidgetPresentation.percentValue(pct))% \(DamCoreWidgetPresentation.trendGlyph(snapshot.trend))".trimmingCharacters(in: .whitespaces))
                            .font(.system(size: accessoryRectangularFontSize))
                            .foregroundStyle(trendColor(snapshot.trend))
                    }
                    .padding(.horizontal, 4)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(snapshot.damName)
                            .font(.system(size: accessoryRectangularFontSize, weight: .bold))
                            .lineLimit(1)
                        Text(snapshot.message)
                            .font(.system(size: accessoryRectangularFontSize))
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 4)
                }
            } else {
                Text(WidgetText.initialMessage)
                    .font(.system(size: accessoryRectangularFontSize))
                    .padding(.horizontal, 4)
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    /// systemSmall ウィジェット用に最適化されたデータ行を描画します。
    private func smallDataRows(_ snapshot: DamWidgetSnapshot) -> some View {
        ViewThatFits {
            smallDataWithChangeRows(snapshot)
            smallDataWithoutChangeRows(snapshot)
        }
    }

    /// 貯水率と前日比（日変化量）を表示するデータ行を描画します。
    private func smallDataWithChangeRows(_ snapshot: DamWidgetSnapshot) -> some View {
        VStack(spacing: 4) {
            Text(DamCoreWidgetPresentation.observedAt(snapshot.observedAt))
                .font(smallDataFont)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(DamCoreWidgetPresentation.percent(snapshot.storagePercentage)) \(DamCoreWidgetPresentation.trendGlyph(snapshot.trend))".trimmingCharacters(in: .whitespaces))
                .font(smallDataFont)
                .foregroundStyle(trendColor(snapshot.trend))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .trailing)
            dayChangeRow(snapshot: snapshot, font: smallDataFont)
            Text(snapshot.message)
                .font(smallDataFont)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 変化量を含めずに貯水率を表示するデータ行を描画します。
    private func smallDataWithoutChangeRows(_ snapshot: DamWidgetSnapshot) -> some View {
        VStack(spacing: 4) {
            Text(DamCoreWidgetPresentation.observedAt(snapshot.observedAt))
                .font(smallDataFont)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(DamCoreWidgetPresentation.percent(snapshot.storagePercentage)) \(DamCoreWidgetPresentation.trendGlyph(snapshot.trend))".trimmingCharacters(in: .whitespaces))
                .font(smallDataFont)
                .foregroundStyle(trendColor(snapshot.trend))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(snapshot.message)
                .font(smallDataFont)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// systemMedium ウィジェット用に最適化されたデータ行を描画します。
    private func mediumDataRows(_ snapshot: DamWidgetSnapshot) -> some View {
        Group {
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                let observedAt = DamCoreWidgetPresentation.observedAt(snapshot.observedAt)
                if !observedAt.isEmpty {
                    Text("\(observedAt) ")
                        .font(widgetFont)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                Text("\(DamCoreWidgetPresentation.percent(snapshot.storagePercentage)) \(DamCoreWidgetPresentation.trendGlyph(snapshot.trend))".trimmingCharacters(in: .whitespaces))
                    .font(widgetFont)
                    .foregroundStyle(trendColor(snapshot.trend))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            dayChangeRow(snapshot: snapshot)
            Text(snapshot.message)
                .font(widgetFont)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 貯水率の前日比（日変化量）を示す行を描画します。
    private func dayChangeRow(snapshot: DamWidgetSnapshot, font: Font? = nil) -> some View {
        let trendValue = snapshot.dayChangeTrend ?? "unknown"
        return Text("\(WidgetText.dayChangeLabel) \(DamCoreWidgetPresentation.percent(snapshot.storagePercentageDayChange)) \(DamCoreWidgetPresentation.trendGlyph(trendValue))".trimmingCharacters(in: .whitespaces))
            .font(font ?? widgetFont)
            .foregroundStyle(trendColor(trendValue))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    /// デフォルトのテキスト要素用に設定された動的フォントサイズ。
    private var widgetFont: Font {
        .system(size: widgetFontSize)
    }

    /// より小さいテキスト要素用に設定された動的フォントサイズ。
    private var smallDataFont: Font {
        .system(size: smallDataFontSize)
    }

    /// トレンドの方向に応じて適切な色を返します。
    private func trendColor(_ trend: String) -> Color {
        switch trend {
        case "up": return .red
        case "down": return .blue
        default: return .primary
        }
    }

}

/// 早明浦ダムの貯水率やその他のリアルタイム観測データを表示するウィジェット。
struct TCSameuraDamMonitorWidget: Widget {
    /// ウィジェットの一意の識別子。
    let kind = "TCSameuraDamMonitorWidget"

    #if os(iOS)
    private var supportedFamilies: [WidgetFamily] {
        [.systemSmall, .systemMedium, .accessoryInline, .accessoryCircular, .accessoryRectangular]
    }
    #else
    private var supportedFamilies: [WidgetFamily] {
        [.systemSmall, .systemMedium]
    }
    #endif

    /// ウィジェットの設定とコンテンツ。
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DamWidgetProvider()) { entry in
            #if os(macOS)
            TCSameuraDamMonitorMacWidgetEntryView(entry: entry)
                .widgetURL(URL(string: "tcsameuradammonitor://widget/realtime"))
            #else
            TCSameuraDamMonitorWidgetEntryView(entry: entry)
            #endif
        }
        .configurationDisplayName(WidgetText.appName)
        .description(WidgetText.configurationDescription)
        .supportedFamilies(supportedFamilies)
    }
}

#if os(macOS)
/// macOSのWidgetKit Simulatorと通知センター向けに、systemSmall/systemMediumだけを描画する軽量ビュー。
struct TCSameuraDamMonitorMacWidgetEntryView: View {
    /// アクティブなウィジェットファミリー。
    @Environment(\.widgetFamily) private var family

    /// 早明浦ダムのスナップショットデータを含むタイムラインエントリ。
    let entry: DamWidgetEntry

    /// ビューの本体。
    var body: some View {
        VStack(spacing: 4) {
            Spacer(minLength: 0)
            if let snapshot = entry.snapshot {
                content(snapshot)
            } else {
                initialContent
            }
            Spacer(minLength: 0)
        }
        .padding(0)
        .containerBackground(.background, for: .widget)
    }

    /// スナップショットに基づく表示内容。
    @ViewBuilder
    private func content(_ snapshot: DamWidgetSnapshot) -> some View {
        let isSmall = family == .systemSmall
        Text(snapshot.damName)
            .font(isSmall ? .system(size: 16) : .system(size: 20))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

        if snapshot.storagePercentage == nil && snapshot.observedAt.isEmpty {
            Text(snapshot.message)
                .font(isSmall ? .system(size: 12) : .system(size: 16))
                .lineLimit(isSmall ? 2 : 1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if isSmall {
            smallDataRows(snapshot)
        } else {
            mediumDataRows(snapshot)
        }
    }

    /// 初期状態の表示内容。
    private var initialContent: some View {
        Group {
            Text(damDisplayNameForWidget() ?? WidgetText.placeholderDamName)
            Text(WidgetText.promptLine1)
            Text(WidgetText.promptLine2)
        }
        .font(.system(size: 16))
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// systemSmall用のデータ行。
    private func smallDataRows(_ snapshot: DamWidgetSnapshot) -> some View {
        VStack(spacing: 4) {
            Text(DamCoreWidgetPresentation.observedAt(snapshot.observedAt))
                .font(.system(size: 12))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(DamCoreWidgetPresentation.percent(snapshot.storagePercentage)) \(DamCoreWidgetPresentation.trendGlyph(snapshot.trend))".trimmingCharacters(in: .whitespaces))
                .font(.system(size: 12))
                .foregroundStyle(trendColor(snapshot.trend))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .trailing)
            dayChangeRow(snapshot: snapshot, fontSize: 12)
            Text(snapshot.message)
                .font(.system(size: 12))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// systemMedium用のデータ行。
    private func mediumDataRows(_ snapshot: DamWidgetSnapshot) -> some View {
        Group {
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                let observedAt = DamCoreWidgetPresentation.observedAt(snapshot.observedAt)
                if !observedAt.isEmpty {
                    Text("\(observedAt) ")
                        .font(.system(size: 16))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                Text("\(DamCoreWidgetPresentation.percent(snapshot.storagePercentage)) \(DamCoreWidgetPresentation.trendGlyph(snapshot.trend))".trimmingCharacters(in: .whitespaces))
                    .font(.system(size: 16))
                    .foregroundStyle(trendColor(snapshot.trend))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            dayChangeRow(snapshot: snapshot, fontSize: 16)
            Text(snapshot.message)
                .font(.system(size: 16))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 貯水率の前日比（日変化量）を示す行。
    private func dayChangeRow(snapshot: DamWidgetSnapshot, fontSize: CGFloat) -> some View {
        let trendValue = snapshot.dayChangeTrend ?? "unknown"
        return Text("\(WidgetText.dayChangeLabel) \(DamCoreWidgetPresentation.percent(snapshot.storagePercentageDayChange)) \(DamCoreWidgetPresentation.trendGlyph(trendValue))".trimmingCharacters(in: .whitespaces))
            .font(.system(size: fontSize))
            .foregroundStyle(trendColor(trendValue))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    /// トレンドの方向に応じて適切な色を返します。
    private func trendColor(_ trend: String) -> Color {
        switch trend {
        case "up": return .red
        case "down": return .blue
        default: return .primary
        }
    }
}

#endif

/// 設定されたダムの表示名を取得します（デフォルトは「早明浦ダム」）。
/// - Returns: 表示名。
private func damDisplayNameForWidget() -> String? {
    WidgetDefaultsStore.shared.string(forKey: WidgetDefaultsKey.damDisplayName)
}

/// 設定された観測所 ID が早明浦ダムかどうかを判定します。
/// - Returns: 早明浦ダムの場合は true。
private func isSameuraDamForWidget() -> Bool {
    WidgetDefaultsStore.shared.string(forKey: WidgetDefaultsKey.stationId) == WidgetDataFetcher.sameuraStationId
}

/// ウィジェットの初期ステータスメッセージを取得します。
/// - Returns: 初期ステータスメッセージ。
private func initialMessageForWidget() -> String? {
    guard let data = WidgetDefaultsStore.shared.data(forKey: WidgetDefaultsKey.messages),
          let messages = try? JSONDecoder().decode([String: String].self, from: data) else { return nil }
    return messages[DamCoreWidgetMessageKey.initial.rawValue]
}

extension DamWidgetSnapshot {
    /// データがない場合に使用される静的なプレースホルダー・スナップショット。
    static var placeholder: DamWidgetSnapshot {
        DamWidgetProvider.makeNoDataSnapshot()
    }
}
