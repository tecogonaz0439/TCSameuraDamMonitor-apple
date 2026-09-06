// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Observation
import SwiftData
import TCSameuraDamCore
import UserNotifications

/// 端末の再起動（ブート）を検出するためのユーティリティ。
internal enum BootDetector {
    /// 保存されている稼働時間（Uptime）と現在の値から、新しいブート（再起動）が発生したかどうかを判定します。
    /// - Parameters:
    ///   - currentUptime: 現在のシステムの稼働時間。
    ///   - savedUptime: 保存されていたシステムの稼働時間。
    /// - Returns: 新しいブートが発生した場合は `true`、それ以外は `false`。
    internal nonisolated static func isNewBoot(currentUptime: Double, savedUptime: Double) -> Bool {
        savedUptime > 0 && currentUptime < savedUptime
    }
}

/// ウィジェットのデータ取得に関するログ情報の分類および解析を行うユーティリティ。
internal enum WidgetFetchLog {
    /// 取得イベントのエントリタイプ。
    internal enum EntryType: String, Sendable, CaseIterable {
        /// 自動更新。
        case auto
        /// 初回読み込み。
        case initial
        /// 端末起動（ブート）。
        case boot
    }

    /// ログエントリの文字列から取得タイプをパースします。
    /// - Parameter entry: ログレコード文字列。
    /// - Returns: パースされた `EntryType`。無効な形式の場合は `nil`。
    internal nonisolated static func parseType(entry: String) -> EntryType? {
        let parts = entry.components(separatedBy: ";")
        guard parts.count >= 4 else { return nil }
        if parts.count >= 5, parts[1] == "b" { return .boot }
        if parts.count >= 5, parts[1] == "i" { return .initial }
        return .auto
    }
}

/// ウィジェットへの同期データ（設定等）の変更イベントの同一性検証を行うための構造体。
internal struct WidgetBridgeIdentity: Equatable, Sendable {
    /// 自動更新が有効かどうか。
    internal let autoUpdateEnabled: Bool
    /// 通知を表示するかどうか。
    internal let showNotification: Bool
    /// 自動更新の時間間隔。
    internal let autoUpdateInterval: AutoUpdateInterval
    /// 次回の自動更新予定日時。
    internal let nextRequestedUpdate: Date
    /// 対象のダム構成ID。
    internal let targetDamId: String
    /// リアルタイム観測データ (Real-time observation data) の取得ソース。
    internal let realtimeDataSource: RealtimeDataSource
    /// 貯水率メッセージを表示するかどうか。
    internal let showStorageRateMessage: Bool
    /// 貯水率 (Storage rate) の表示メッセージ配列。
    internal let storageMessages: [String]
    /// その他のメッセージ配列。
    internal let otherMessages: [String]

    /// アプリ設定からアイデンティティを作成します。
    /// - Parameter settings: アプリ設定。
    internal init(settings: AppSettings) {
        autoUpdateEnabled = settings.autoUpdateEnabled
        showNotification = settings.showNotification
        autoUpdateInterval = settings.autoUpdateInterval
        nextRequestedUpdate = settings.nextRequestedUpdate
        targetDamId = settings.targetDamId
        realtimeDataSource = settings.realtimeDataSource
        showStorageRateMessage = settings.showStorageRateMessage
        storageMessages = settings.storageRateMessageIdentity()
        otherMessages = settings.otherMessageIdentity()
    }
}

/// アプリ全体の主要なステート（リアルタイムデータ、過去履歴データ、デバッグ、設定など）を一元管理し、更新ロジックを統括する ViewModel / Service クラス。
@MainActor
@Observable
final class DamAppModel {
    /// 過去データ検索 (Historical data search) の最大保存件数。
    internal static let maxHistoricalSearchCount = 16
    /// デバッグログの最大保存件数。
    internal static let maxDebugLogCount = 128
    /// ピン留めできる過去データ検索の最大件数。
    internal static let maxPinnedCount = 5
    /// 手動更新が許可される最小時間間隔（クールダウン期間、10分）。
    internal static let manualRefreshCooldown: TimeInterval = 10 * 60

    /// アプリの詳細画面の選択先を表す列挙型。
    internal enum DetailSelection: Hashable {
        /// リアルタイム観測データ (Real-time observation data) 画面。
        case realtime
        /// 過去データ検索 (Historical data search) の結果詳細画面。
        case historical(UUID)
        /// sudmonitor 日次過去データ表示画面。
        case sudmonitorHistory
        /// 設定画面。
        case settings
        /// デバッグ画面。
        case debug
        /// 過去データ検索 (Historical data search) の一覧管理画面。
        case historicalManage
        /// デバッグログ画面。
        case debugLog
        /// アプリ情報画面。
        case appInfo
    }

    var settings: AppSettings
    var dashboardCardExpansionState: DashboardCardExpansionState
    var damData: DamData?
    var historicalRows: [DamHistoricalData] = []
    var selectedHistoricalMeta: HistoricalSearchMeta?
    var historicalMetaList: [HistoricalSearchMeta] = []
    var historicalDisplayStartDate: String?
    var historicalDisplayEndDate: String?
    var debugLogs: [DebugLogEntry] = []
    var selectedDetail: DetailSelection = .realtime
    var isLoading = false
    var isManualUpdateRunning = false
    var isAutoUpdateRunning = false
    var canManualRefresh = false
    var isHistoricalLoading = false
    /// sudmonitor 日次過去データの初回起動取得・ダム変更取得の実行中フラグ。
    var isSudmonitorHistoryInitialRunning = false
    /// sudmonitor 日次過去データの定期自動更新タイマー連動取得の実行中フラグ。
    var isSudmonitorHistoryAutoUpdateRunning = false
    /// sudmonitor 日次過去データの手動更新取得の実行中フラグ。
    var isSudmonitorHistoryManualRunning = false
    var errorMessage: String?
    var showHistoricalSearch = false
    var lastFetchTime: Date?
    /// 手動更新クールダウンの終了時刻(`X-TCS-Next-Update-At` 由来。欠落時・MLIT 直接時は `lastFetchTime` + 10 分)。
    var manualRefreshAvailableAt: Date?
    var isNetworkError = false
    var damLoadStatus: DamLoadStatus = .initial
    var isDebugModeTransitioning = false
    /// グラフ入力（ダムデータ・過去履歴行・選択中メタ等）の変更ごとに単調増加するリビジョン。
    private(set) var graphDataRevision = 0
    /// sudmonitor 日次過去データレコードの保存・復元ごとに単調増加するリビジョン。
    ///
    /// 日次過去データレコードは SwiftData からの computed fetch のため、
    /// Observation の追跡を確立して保存変更時の UI 再評価をトリガーするために使う。
    private(set) var sudmonitorHistoryRevision = 0
    /// `sudmonitorHistoryRecord` の検索結果キャッシュ(revision・damId単位)。
    @ObservationIgnored private var sudmonitorHistoryRecordCache: SudmonitorHistoryRecordCache?
    /// `sudmonitorHistoryRows` のパース済み行キャッシュ(revision・レコード内容キー単位)。
    @ObservationIgnored private var sudmonitorHistoryRowsCache: SudmonitorHistoryRowsCache?

    /// `sudmonitorHistoryRecord` の検索結果キャッシュ。
    private struct SudmonitorHistoryRecordCache {
        let revision: Int
        let damId: String
        let record: SudmonitorHistoryRecord?
    }

    /// `sudmonitorHistoryRows` のパース結果キャッシュ。
    ///
    /// レコードのrawバイトは revision 変化(保存・復元・ウィジェット取り込み)時のみ
    /// 入れ替わるため、revision・damId・期間境界をキーに同一内容の再パースを回避する。
    private struct SudmonitorHistoryRowsCache {
        let revision: Int
        let damId: String
        let periodStartDay: String
        let periodEndDay: String
        let rows: [DamHistoricalData]
    }

    @ObservationIgnored private var modelContext: ModelContext?
    @ObservationIgnored private let parser: MlitDamParser
    @ObservationIgnored private let realtimeDataService: RealtimeDataService
    @ObservationIgnored private let historicalSearchService: HistoricalSearchService
    @ObservationIgnored private let sudmonitorHistoryService: SudmonitorHistoryService
    @ObservationIgnored private let settingsRepository: SettingsRepository
    @ObservationIgnored private let dashboardCardExpansionRepository: DashboardCardExpansionRepository
    @ObservationIgnored private let widgetDefaults: WidgetBridgeDefaults
    @ObservationIgnored private let widgetBridgeService: WidgetBridgeService
    @ObservationIgnored private let notificationCoordinator: NotificationCoordinator
    @ObservationIgnored private let autoUpdateScheduler: AutoUpdateScheduler
    @ObservationIgnored private let historicalComparisonService: HistoricalComparisonService
    @ObservationIgnored private let debugDataSessionService: DebugDataSessionService?
    @ObservationIgnored internal var transientViewedMetaId: UUID?
    @ObservationIgnored private var didRunForegroundStartup = false
    @ObservationIgnored private var previousPercentTime: String?
    @ObservationIgnored internal var isSceneActive = true
    /// UIにスナックバーメッセージを表示するためのトリガー用プロパティ。
    var updateSnackbarMessage: String?
    var showInitialAutoUpdateDialog: Bool = false
    var showInitialNotificationPermissionRequest: Bool = false

    /// ダムアプリケーションモデルを初期化します。
    /// - Parameters:
    ///   - parser: データパーサー。
    ///   - network: ネットワークデータソース。
    ///   - networkAvailability: ネットワークの接続可能判定を提供するプロバイダ。
    ///   - historicalAssets: ローカルの過去データアセットストア。
    ///   - settingsRepository: アプリ設定の永続化リポジトリ。
    ///   - dashboardCardExpansionRepository: Dashboard Card開閉状態の永続化リポジトリ。
    ///   - widgetGroupDefaults: App Group用の共有 `UserDefaults`。
    ///   - widgetStandardDefaults: アプリ標準の `UserDefaults`。
    ///   - notificationCoordinator: 通知の送信および権限コーディネーター。
    init(
        parser: MlitDamParser = MlitDamParser(),
        network: MlitNetworkDataSource = MlitNetworkDataSource(),
        networkAvailability: any NetworkAvailabilityProviding = NetworkAvailabilityMonitor(),
        historicalAssets: HistoricalAssetStore = HistoricalAssetStore(),
        settingsRepository: SettingsRepository = SettingsRepository(),
        dashboardCardExpansionRepository: DashboardCardExpansionRepository = DashboardCardExpansionRepository(),
        widgetGroupDefaults: UserDefaults? = UserDefaults(suiteName: "group.net.tecogonaz.TCSameuraDamMonitor"),
        widgetStandardDefaults: UserDefaults = .standard,
        notificationCoordinator: NotificationCoordinator = NotificationCoordinator(),
        historicalComparisonService: HistoricalComparisonService = HistoricalComparisonService(),
        debugDataSessionService: DebugDataSessionService? = nil
    ) {
        self.parser = parser
        self.realtimeDataService = RealtimeDataService(
            parser: parser,
            network: network,
            networkAvailability: networkAvailability
        )
        let sudmonitorClient = SudmonitorHistoricalClient(network: network)
        self.historicalSearchService = HistoricalSearchService(
            parser: parser,
            network: network,
            historicalAssets: historicalAssets,
            networkAvailability: networkAvailability,
            sudmonitorClient: sudmonitorClient
        )
        self.sudmonitorHistoryService = SudmonitorHistoryService(sudmonitorClient: sudmonitorClient)
        self.settingsRepository = settingsRepository
        self.dashboardCardExpansionRepository = dashboardCardExpansionRepository
        let widgetDefaults = WidgetBridgeDefaults(groupDefaults: widgetGroupDefaults, standardDefaults: widgetStandardDefaults)
        self.widgetDefaults = widgetDefaults
        self.widgetBridgeService = WidgetBridgeService(defaults: widgetDefaults)
        self.notificationCoordinator = notificationCoordinator
        self.autoUpdateScheduler = AutoUpdateScheduler()
        self.historicalComparisonService = historicalComparisonService
        self.debugDataSessionService = debugDataSessionService ?? (try? DebugDataSessionService())
        settings = settingsRepository.load()
        dashboardCardExpansionState = dashboardCardExpansionRepository.load()
    }

    /// 指定したDashboard Cardが展開されているかを返す。
    func isDashboardCardExpanded(_ key: DashboardCardExpansionKey) -> Bool {
        dashboardCardExpansionState[key]
    }

    /// 指定したDashboard Cardの開閉状態をメモリとUserDefaultsへ保存する。
    func setDashboardCardExpanded(_ key: DashboardCardExpansionKey, isExpanded: Bool) {
        dashboardCardExpansionState.set(isExpanded, for: key)
        dashboardCardExpansionRepository.save(isExpanded, for: key)
    }

    /// 現在選択されているダムの構成設定を取得します。
    var currentDamConfig: DamConfig? {
        DamListData.dam(id: settings.targetDamId)
    }

    /// 過去比較グラフ用のサービスを取得します。
    var comparisonService: HistoricalComparisonService {
        historicalComparisonService
    }

    /// 日次過去データをナビゲーションと表示で利用できるかを返します。
    var isSudmonitorHistoryAvailable: Bool {
        (settings.debugModeEnabled || settings.historicalDataSource == .sudmonitor)
            && sudmonitorHistoryRecord != nil
    }

    /// 画面に表示する読込時刻です。Debug中は観測データ時刻へ揃えます。
    var displayedRealtimeFetchTime: Date? {
        if settings.debugModeEnabled,
           let timestamp = damData?.updatedAt,
           let date = DamCoreDamTime.date(from: timestamp) {
            return date
        }
        return lastFetchTime
    }

    /// 現在グラフ表示に用いられているアクティブなダム履歴データの配列を取得します（過去データ検索詳細またはリアルタイム観測データのいずれか）。
    var activeRowsForGraph: [DamHistoricalData] {
        if selectedHistoricalMeta != nil {
            return visibleHistoricalRows
        }
        return damData?.historicalData ?? []
    }

    /// 対象ダムの sudmonitor 日次過去データレコードを取得します（未読込時・非対応ダムは nil）。
    ///
    /// 先頭で `sudmonitorHistoryRevision` を読むことで、このレコードに依存する
    /// 派生 accessor（行・表示可否・サマリー等）へ Observation の追跡を確立する。
    /// 検索結果は revision・damId 単位でキャッシュし、同一内容の SwiftData fetch の
    /// 再実行を回避する（サイドバー・ダッシュボードの再評価で毎回fetchが走るため）。
    var sudmonitorHistoryRecord: SudmonitorHistoryRecord? {
        _ = sudmonitorHistoryRevision
        guard let context = modelContext else { return nil }
        let damId = settings.targetDamId
        if let cache = sudmonitorHistoryRecordCache,
           cache.revision == sudmonitorHistoryRevision,
           cache.damId == damId {
            return cache.record
        }
        let record = sudmonitorHistoryService.record(damId: damId, context: context)
        sudmonitorHistoryRecordCache = SudmonitorHistoryRecordCache(
            revision: sudmonitorHistoryRevision,
            damId: damId,
            record: record
        )
        return record
    }

    /// sudmonitor 日次過去データをパースした観測行（時刻昇順）を取得します。未読込・パース失敗時は空配列。
    ///
    /// パース+ソートは行数に対して重い処理のため、結果を revision・damId・期間境界を
    /// キーにキャッシュする。サイドバーのトグルやダッシュボードの再評価など、
    /// データ変更なしの再アクセスではキャッシュを返す。
    var sudmonitorHistoryRows: [DamHistoricalData] {
        guard let record = sudmonitorHistoryRecord else { return [] }
        if let cache = sudmonitorHistoryRowsCache,
           cache.revision == sudmonitorHistoryRevision,
           cache.damId == record.damId,
           cache.periodStartDay == record.periodStartDay,
           cache.periodEndDay == record.periodEndDay {
            return cache.rows
        }
        let parsedRows = (try? parser.parseHistoricalDat(
            record.rawDatBytes,
            damConfigId: record.damId,
            startDate: record.periodStartDay,
            endDate: record.periodEndDay
        )).map { parsed in
            parsed.1.sorted { TimeFormatters.millis(fromDamTime: $0.time) < TimeFormatters.millis(fromDamTime: $1.time) }
        } ?? []
        sudmonitorHistoryRowsCache = SudmonitorHistoryRowsCache(
            revision: sudmonitorHistoryRevision,
            damId: record.damId,
            periodStartDay: record.periodStartDay,
            periodEndDay: record.periodEndDay,
            rows: parsedRows
        )
        return parsedRows
    }

    /// 過去データ検索 (Historical data search) 表示において、日付範囲が絞り込みフィルタリングされているかどうかを判定します。
    var isHistoricalDisplayRangeFiltered: Bool {
        historicalDisplayStartDate != nil && historicalDisplayEndDate != nil
    }

    /// サイドナビゲーション等に表示すべき過去検索履歴メタデータのリスト（ピン留め、および一時閲覧中エントリ）を取得します。
    var navigationMetaList: [HistoricalSearchMeta] {
        var result: [HistoricalSearchMeta] = []

        if let tid = transientViewedMetaId,
           let transientMeta = historicalMetaList.first(where: { $0.id == tid }),
           !transientMeta.isPinned {
            result.append(transientMeta)
        }

        for meta in historicalMetaList where meta.isPinned {
            if !result.contains(where: { $0.id == meta.id }) {
                result.append(meta)
            }
        }

        return result
    }

    /// 表示対象の過去履歴データから、絞り込み期間範囲に収まるデータのみを抽出して取得します。
    var visibleHistoricalRows: [DamHistoricalData] {
        guard let startDate = historicalDisplayStartDate,
              let endDate = historicalDisplayEndDate,
              let startDay = TimeFormatters.jstDay.date(from: startDate),
              let endDay = TimeFormatters.jstDay.date(from: endDate) else {
            return historicalRows
        }
        guard let startTime = Calendar.jst.date(byAdding: .hour, value: 1, to: startDay),
              let endTime = Calendar.jst.date(byAdding: .day, value: 1, to: endDay) else {
            return historicalRows
        }
        let startMillis = startTime.timeIntervalSince1970 * 1000
        let endMillis = endTime.timeIntervalSince1970 * 1000
        return historicalRows.filter { row in
            let rowMillis = TimeFormatters.millis(fromDamTime: row.time)
            return rowMillis >= startMillis && rowMillis <= endMillis
        }
    }

    /// 表示対象の sudmonitor 日次過去データから、絞り込み期間範囲に収まるデータのみを抽出して取得します。
    var visibleSudmonitorHistoryRows: [DamHistoricalData] {
        guard let startDate = historicalDisplayStartDate,
              let endDate = historicalDisplayEndDate,
              let startDay = TimeFormatters.jstDay.date(from: startDate),
              let endDay = TimeFormatters.jstDay.date(from: endDate) else {
            return sudmonitorHistoryRows
        }
        guard let startTime = Calendar.jst.date(byAdding: .hour, value: 1, to: startDay),
              let endTime = Calendar.jst.date(byAdding: .day, value: 1, to: endDay) else {
            return sudmonitorHistoryRows
        }
        let startMillis = startTime.timeIntervalSince1970 * 1000
        let endMillis = endTime.timeIntervalSince1970 * 1000
        return sudmonitorHistoryRows.filter { row in
            let rowMillis = TimeFormatters.millis(fromDamTime: row.time)
            return rowMillis >= startMillis && rowMillis <= endMillis
        }
    }

    /// 過去データ検索 (Historical data search) または sudmonitor 日次過去データのグラフ表示期間絞り込みを適用します。
    /// - Parameters:
    ///   - startDate: 開始日。
    ///   - endDate: 終了日。
    func applyHistoricalDisplayRange(startDate: String, endDate: String) {
        guard TimeFormatters.jstDay.date(from: startDate) != nil,
              TimeFormatters.jstDay.date(from: endDate) != nil else { return }
        if let meta = selectedHistoricalMeta, startDate == meta.searchBgnDate && endDate == meta.searchEndDate {
            resetHistoricalDisplayRange()
            return
        }
        if let record = sudmonitorHistoryRecord, startDate == record.periodStartDay && endDate == record.periodEndDay {
            resetHistoricalDisplayRange()
            return
        }
        guard selectedHistoricalMeta != nil || sudmonitorHistoryRecord != nil else { return }
        historicalDisplayStartDate = startDate
        historicalDisplayEndDate = endDate
        bumpGraphDataRevision()
    }

    /// 過去データの表示絞り込みフィルタを解除し、全期間表示に戻します。
    func resetHistoricalDisplayRange() {
        historicalDisplayStartDate = nil
        historicalDisplayEndDate = nil
        bumpGraphDataRevision()
    }

    /// グラフ入力（ダムデータ・過去履歴行・選択中メタ・表示期間フィルタ）の変更を反映するため、
    /// グラフ用のデータリビジョンを1進めます。
    internal func bumpGraphDataRevision() {
        graphDataRevision += 1
    }

    /// sudmonitor 日次過去データレコードの保存・復元を UI へ反映するため、
    /// 日次リビジョンとグラフ用のデータリビジョンを1進めます。
    internal func bumpSudmonitorHistoryRevision() {
        sudmonitorHistoryRevision += 1
        bumpGraphDataRevision()
    }

    /// モデルに `ModelContext` を設定し、キャッシュロードや初期起動時セットアップをトリガーします。
    /// - Parameters:
    ///   - modelContext: SwiftData のモデルコンテキスト。
    ///   - launchContext: アプリの起動されたコンテキスト（フォアグラウンドまたはバックグラウンド）。
    func configure(modelContext: ModelContext, launchContext: AppConfigureLaunchContext = .foreground) {
        if self.modelContext == nil {
            self.modelContext = modelContext
            recoverDebugDataSessionIfNeeded(context: modelContext)
            loadCachedData()
            reloadHistoricalMeta()
            reloadDebugLogs()
            importWidgetLogs()
            saveWidgetSettingsBridge()
        }
        guard launchContext.allowsForegroundStartup else {
            return
        }
        runForegroundStartupIfNeeded(reason: "configure")
    }

    /// 中断されたDebugデータ切替を通常のcache読込より先に回復します。
    private func recoverDebugDataSessionIfNeeded(context: ModelContext) {
        guard let service = debugDataSessionService else {
            if settings.debugModeEnabled {
                errorMessage = DebugDataSessionError.backupNotFound.localizedDescription
            }
            return
        }
        do {
            let result = try service.recoverAtLaunch(context: context, debugModeEnabled: settings.debugModeEnabled)
            if settings.debugModeEnabled, case .none = result {
                throw DebugDataSessionError.backupNotFound
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// アプリがアクティブ化（フォアグラウンド移行）した際に必要な、初期起動・自動更新チェック処理を完了させます。
    /// - Parameter reason: アクティブ化をトリガーした理由。
    func completeForegroundStartupIfNeeded(reason: String) {
        guard modelContext != nil else { return }
        Task {
            await self.importWidgetDataIfNewer()
            await self.importSudmonitorHistoryBridgeIfNewer()
        }
        runForegroundStartupIfNeeded(reason: reason)
    }

    /// フォアグラウンド移行時の起動初期セットアップ処理を内部実行します。
    private func runForegroundStartupIfNeeded(reason: String) {
        guard !didRunForegroundStartup else { return }
        didRunForegroundStartup = true
        if !settings.initialAutoUpdateDialogShown {
            removeWidgetValue(forKey: WidgetDefaultsKey.snapshotV1)
            removeWidgetValue(forKey: WidgetDefaultsKey.appSnapshot)
        }
        let now = Date()
        let missedDueAt = AutoUpdateMissedDuePolicy.missedDueDate(settings: settings, now: now)
        scheduleAutoRefreshTimer()
        saveWidgetSettingsBridge()

        let currentUptime = ProcessInfo.processInfo.systemUptime
        let savedUptime = widgetDefaults.standardDefaults.double(forKey: "lastKnownSystemUptime")
        let isNewBoot = BootDetector.isNewBoot(currentUptime: currentUptime, savedUptime: savedUptime)
        widgetDefaults.standardDefaults.set(currentUptime, forKey: "lastKnownSystemUptime")
        setWidgetValue(currentUptime, forKey: WidgetDefaultsKey.lastKnownSystemUptime)

        let startupUpdateScheduled = settings.updateOnBoot || damData == nil
        if startupUpdateScheduled {
            if settings.autoUpdateEnabled, missedDueAt != nil {
                settings.nextRequestedUpdate = settings.nextRunTime(after: now)
                scheduleAutoRefreshTimer()
                saveWidgetSettingsBridge()
            }
            let workType = damData == nil ? "Initial load" : "Boot update"
            Task {
                if let cachedData = damData,
                   let availableAt = effectiveManualRefreshAvailableAt(),
                   Date() < availableAt {
                    if let config = currentDamConfig {
                        addDebugLog(
                            message: "Boot update skipped.",
                            details: buildSuccessDetails(damNameEn: config.nameEn, parsed: cachedData)
                        )
                    }
                    return
                }
                if damData != nil, isNewBoot,
                   let config = currentDamConfig,
                   widgetRawDatBridge(for: config) != nil {
                    let widgetBootDone = widgetDate(forKey: WidgetDefaultsKey.widgetBootUpdateDoneAt)
                    let appBootDone = widgetDate(forKey: WidgetDefaultsKey.appBootUpdateDoneAt)
                    if let widgetBootDone, (appBootDone == nil || widgetBootDone > appBootDone!) {
                        await importWidgetData(logContext: "Boot update (from widget)")
                        return
                    }
                }
                await fetchLatest(workType: workType)
            }
        } else {
            let recoveryAction = AutoUpdateMissedDuePolicy.recoveryAction(
                autoUpdateEnabled: settings.autoUpdateEnabled,
                dueAt: missedDueAt,
                now: now,
                startupUpdateScheduled: startupUpdateScheduled,
                widgetLastFetchAt: widgetDate(forKey: WidgetDefaultsKey.widgetLastFetchAt)
            )
            switch recoveryAction {
            case .none:
                break
            case .importWidget:
                let pendingNext = settings.nextRunTime(after: now)
                if missedDueAt != nil {
                    settings.nextRequestedUpdate = pendingNext
                    scheduleAutoRefreshTimer()
                    saveWidgetSettingsBridge()
                }
                Task {
                    await self.importWidgetData()

                }
            case .fetchLatest:
                let pendingNext = settings.nextRunTime(after: now)
                if missedDueAt != nil {
                    settings.nextRequestedUpdate = pendingNext
                    scheduleAutoRefreshTimer()
                    saveWidgetSettingsBridge()
                }
                Task {
                    await self.fetchLatest(workType: "Auto update (missed)")

                }
            }
        }
        if !settings.initialAutoUpdateDialogShown {
            showInitialAutoUpdateDialog = true
        }
        Task {
            await self.fetchSudmonitorHistoryIfNeeded(workType: "Daily history initial load")
        }
        scheduleManualRefreshAvailabilityTimer()
        scheduleManualRefreshAvailabilityTimer()
    }

    /// 現在の自動更新設定と動作状態に応じた案内ユーザーメッセージを取得します。
    /// - Parameter now: 基準とする現在時間。
    /// - Returns: ローカライズされた自動更新の案内表示テキスト。
    func autoUpdateUserMessage(now: Date = Date()) -> String {
        if isAutoUpdateRunning {
            return AppText.mainAutorenewInProgress
        }
        guard settings.autoUpdateEnabled else {
            return AppText.mainAutorenewDisabled
        }
        let interval = settings.autoUpdateInterval.localizedLabel
        if let last = settings.lastAutoUpdate {
            return AppText.mainAutorenewEnabledWithLast(interval: interval, last: autoUpdateDateTime(last))
        }
        return AppText.mainAutorenewEnabledFirst(interval: interval, next: autoUpdateDateTime(settings.nextRunTime(after: now)))
    }

    /// 手動更新がブロックされている場合のエラー説明テキストを取得します。
    var manualUpdateBlockedMessage: String? {
        manualUpdateBlockedMessage()
    }

    /// 現在のロード中状態やクールダウン設定から、手動更新がブロックされている場合のメッセージを取得します。
    /// - Parameter now: 基準となる現在日時。
    /// - Returns: 手動更新が許可されない理由を示す説明文字列。許可される場合は `nil`。
    func manualUpdateBlockedMessage(now: Date = Date()) -> String? {
        if isAutoUpdateRunning {
            return AppText.mainAutorenewInProgress
        }
        if isLoading {
            return damData == nil ? AppText.mainInitialLoadInProgress : AppText.mainManualUpdateInProgress
        }
        if !canManualRefresh {
            return AppText.mainRefreshTooEarly(nextManualRefreshDateTimeText)
        }
        return nil
    }

    /// ユーザー操作による手動更新要求を処理します。
    /// - Returns: 更新がブロックされていればそのエラー通知テキスト、実行された場合は `nil`。
    func performManualUpdateFromUserAction() async -> String? {
        if let blockedMessage = manualUpdateBlockedMessage() {
            return blockedMessage
        }
        let previousSnackbarMessage = updateSnackbarMessage
        await fetchLatest()
        if let msg = updateSnackbarMessage, msg != previousSnackbarMessage {
            updateSnackbarMessage = nil
            return msg
        }
        return nil
    }

    /// 次回手動更新が可能になる時刻の簡易文字列表記（JST基準）を取得します。
    var nextManualRefreshTimeText: String {
        guard let next = effectiveManualRefreshAvailableAt() else {
            return "--"
        }
        return DamCoreJSTSupport.appendingJstSuffix(TimeFormatters.jstTimeNoLeadingZero.string(from: next), isLocalJst: DisplayFormatters.isJST)
    }

    /// 次回手動更新が可能になる日時の詳細表記を取得します。
    var nextManualRefreshDateTimeText: String {
        guard let next = effectiveManualRefreshAvailableAt() else {
            return "--"
        }
        return dateTimeWithJSTSuffix(next, includeWeekday: false)
    }

    /// sudmonitor 日次過去データの手動更新に対する自動系の取得が実行中かどうかを返します。
    ///
    /// リアルタイム定期自動更新（タイマー onDue 前半の取得）、日次の初回起動取得・ダム変更取得、
    /// 日次の定期自動更新取得を含みます（リアルタイム表示の `isAutoUpdateRunning` と同等の扱い）。
    var isSudmonitorHistoryAutoStyleRunning: Bool {
        isAutoUpdateRunning || isSudmonitorHistoryInitialRunning || isSudmonitorHistoryAutoUpdateRunning
    }

    /// sudmonitor 日次過去データの何らかの取得（初回 / ダム変更 / 自動更新 / 手動）が実行中かどうかを返します。
    ///
    /// 日次取得の同時並行を抑止するためのガード判定に使う。
    private var isAnySudmonitorHistoryFetchRunning: Bool {
        isSudmonitorHistoryInitialRunning || isSudmonitorHistoryAutoUpdateRunning || isSudmonitorHistoryManualRunning
    }

    /// sudmonitor 日次過去データの自動更新状態に応じた案内ユーザーメッセージを取得します。
    /// - Parameter now: 基準とする現在時間。
    /// - Returns: ローカライズされた日次過去データ自動更新の案内表示テキスト。
    func sudmonitorHistoryAutoUpdateUserMessage(now: Date = Date()) -> String {
        if isSudmonitorHistoryAutoStyleRunning {
            return AppText.mainAutorenewInProgress
        }
        if isSudmonitorHistoryManualRunning {
            return AppText.mainManualUpdateInProgress
        }
        guard settings.autoUpdateEnabled else {
            return AppText.mainAutorenewDisabled
        }
        let interval = sudmonitorHistoryEffectiveIntervalLabel
        if let record = sudmonitorHistoryRecord {
            return AppText.mainAutorenewEnabledWithLast(interval: interval, last: dateTimeWithJSTSuffix(record.fetchedAt, includeWeekday: false))
        }
        return AppText.mainAutorenewEnabledFirst(interval: interval, next: dateTimeWithJSTSuffix(settings.nextRunTime(after: now), includeWeekday: false))
    }

    /// ユーザー操作による sudmonitor 日次過去データの手動更新要求を処理します。
    ///
    /// 自動系（リアルタイム定期自動更新・日次の初回起動取得・ダム変更取得・日次定期自動更新）の
    /// 取得実行中は自動更新進行中メッセージでブロックし、手動更新の実行中は手動更新進行中メッセージで
    /// ブロックする（リアルタイム表示の手動更新ブロックと同等の分岐）。
    /// - Returns: 更新がブロックまたは失敗した場合はその通知テキスト、実行された場合は `nil`。
    func performSudmonitorHistoryManualUpdate() async -> String? {
        if isSudmonitorHistoryAutoStyleRunning {
            return AppText.mainAutorenewInProgress
        }
        guard !isSudmonitorHistoryManualRunning else {
            return AppText.mainManualUpdateInProgress
        }
        guard let context = modelContext else {
            return AppError.modelContextNotReady.localizedDescription
        }
        let damId = settings.targetDamId
        if !settings.debugModeEnabled,
           let availableAt = sudmonitorHistoryService.manualRefreshAvailableAt(damId: damId, context: context),
           Date() < availableAt {
            return AppText.mainRefreshTooEarly(sudmonitorHistoryNextManualRefreshDateTimeText)
        }
        isSudmonitorHistoryManualRunning = true
        defer { isSudmonitorHistoryManualRunning = false }
        let outcome = await performSudmonitorHistoryFetchOutcome(damId: damId, context: context)
        logSudmonitorHistoryOutcome(outcome, workType: "Daily history manual update", damId: damId)
        switch outcome {
        case .stored:
            return nil
        case .failure(let error):
            return sudmonitorHistoryManualUpdateFailureMessage(error)
        case .skippedNotFound, .skippedInvalidPeriod, .skippedByCooldown, .gateDisabled:
            return nil
        }
    }

    /// 次回 sudmonitor 日次過去データの手動更新が可能になる日時の詳細表記を取得します。
    var sudmonitorHistoryNextManualRefreshDateTimeText: String {
        if settings.debugModeEnabled { return "--" }
        guard let context = modelContext,
              let availableAt = sudmonitorHistoryService.manualRefreshAvailableAt(damId: settings.targetDamId, context: context) else {
            return "--"
        }
        return dateTimeWithJSTSuffix(availableAt, includeWeekday: false)
    }

    /// sudmonitor 日次過去データの手動更新がクールダウン中のためブロックされている場合のメッセージを取得します。
    var sudmonitorHistoryManualUpdateBlockedMessage: String? {
        if settings.debugModeEnabled { return nil }
        guard let nextUpdateAt = sudmonitorHistoryRecord?.nextUpdateAt,
              nextUpdateAt > Date() else { return nil }
        return AppText.mainRefreshTooEarly(sudmonitorHistoryNextManualRefreshDateTimeText)
    }

    /// 日次過去データの自動更新間隔の実効表示ラベル（1時間/12時間は「1日」）を取得します。
    private var sudmonitorHistoryEffectiveIntervalLabel: String {
        settings.autoUpdateInterval == .oneWeek
            ? AutoUpdateInterval.oneWeek.localizedLabel
            : AutoUpdateInterval.oneDay.localizedLabel
    }

    /// sudmonitor 日次過去データの手動更新失敗時の通知テキスト（リアルタイム同款）を構築します。
    /// - Parameter error: 取得時に発生したエラー。
    /// - Returns: 失敗通知テキスト。
    private func sudmonitorHistoryManualUpdateFailureMessage(_ error: Error) -> String {
        let isNetErr = Self.isNetworkFailure(error)
        let statusText = isNetErr
            ? settings.networkUnavailableText(isJapanese: AppLocale.isJapanese)
            : settings.loadingErrorText(isJapanese: AppLocale.isJapanese)
        let damName = currentDamConfig?.localizedName ?? ""
        return statusText.isEmpty ? damName : "\(damName) \(statusText)".trimmingCharacters(in: .whitespaces)
    }

    /// 設定値の変更処理を適用し、自動更新の次回時刻再計算やブリッジの同期等を行います。
    /// - Parameter transform: 設定構造体の変更処理用クロージャ。
    func updateSettings(_ transform: (inout AppSettings) -> Void) {
        let oldSettings = settings
        transform(&settings)
        let becameEnabled = !oldSettings.autoUpdateEnabled && settings.autoUpdateEnabled
        let becameDisabled = oldSettings.autoUpdateEnabled && !settings.autoUpdateEnabled
        let intervalChanged = oldSettings.autoUpdateEnabled && settings.autoUpdateEnabled && oldSettings.autoUpdateInterval != settings.autoUpdateInterval
        let damChanged = oldSettings.targetDamId != settings.targetDamId
        let nextTimingChanged = oldSettings.autoUpdateEnabled && settings.autoUpdateEnabled
            && oldSettings.nextRequestedUpdate != settings.nextRequestedUpdate
            && oldSettings.autoUpdateInterval == settings.autoUpdateInterval
        let widgetBridgeChanged = widgetBridgeRelevantSettingsChanged(from: oldSettings, to: settings)
        if becameEnabled && oldSettings.initialAutoUpdateDialogShown {
            settings.recalculateNextRequestedUpdate(after: Date())
        } else if intervalChanged {
            settings.recalculateNextRequestedUpdate(after: Date())
        }
        if becameEnabled || intervalChanged {
            var next = settings.nextRequestedUpdate
            while next.timeIntervalSinceNow < AppSettings.minScheduleAdvanceSeconds {
                next = next.addingTimeInterval(settings.autoUpdateInterval.interval)
            }
            settings.nextRequestedUpdate = next
        }
        if becameEnabled {
            let next = settings.nextRequestedUpdate
            addDebugLog(message: "Auto update enabled.", details: "Interval: \(settings.autoUpdateInterval.androidName), Next scheduled: \(TimeFormatters.iso8601JST.string(from: next))")
        } else if becameDisabled {
            addDebugLog(message: "Auto update disabled.")
        } else if intervalChanged {
            let next = settings.nextRequestedUpdate
            addDebugLog(message: "Auto update interval changed.", details: "Interval: \(oldSettings.autoUpdateInterval.androidName) → \(settings.autoUpdateInterval.androidName), Next scheduled: \(TimeFormatters.iso8601JST.string(from: next))")
        }
        if damChanged {
            let oldDam = DamListData.allDams.first(where: { $0.id == oldSettings.targetDamId })
            let newDam = DamListData.allDams.first(where: { $0.id == settings.targetDamId })
            addDebugLog(message: "Dam changed.", details: "Dam name: \(oldDam?.nameEn ?? oldSettings.targetDamId) → \(newDam?.nameEn ?? settings.targetDamId)")
            settings.wasLastDataAllInvalid = false
            settings.lastLoadResultMessage = ""
            selectedHistoricalMeta = nil
            historicalRows = []
            historicalDisplayStartDate = nil
            historicalDisplayEndDate = nil
            selectedDetail = .realtime
            bumpGraphDataRevision()
            Task {
                await self.fetchSudmonitorHistoryForDamChange()
            }
        }
        if nextTimingChanged {
            let jstComponents = Calendar.jst.dateComponents([.hour, .minute], from: settings.nextRequestedUpdate)
            if let hour = jstComponents.hour, let minute = jstComponents.minute {
                settings.initialAutoUpdateAnchorMinuteOfDay = hour * 60 + minute
            }
            addDebugLog(message: "Auto update next timing set.", details: "Interval: \(settings.autoUpdateInterval.androidName), Next scheduled: \(TimeFormatters.iso8601JST.string(from: settings.nextRequestedUpdate))")
        }
        settingsRepository.save(settings)
        scheduleAutoRefreshTimer()
        saveWidgetSettingsBridge()
        scheduleManualRefreshAvailabilityTimer()
        if widgetBridgeChanged || becameEnabled || becameDisabled || intervalChanged || damChanged || nextTimingChanged {
            reloadWidgetTimeline(reason: "settingsChanged")
        }

    }


    /// ユーザーが監視対象のダムを変更することを確認・確定します。
    /// - Parameter id: 新しく設定するダムID。
    /// - Returns: 設定変更が実際に発生した（旧IDと異なっていた）場合は `true`、同じだった場合は `false`。
    @discardableResult
    func confirmTargetDamId(_ id: String) -> Bool {
        guard settings.targetDamId != id else {
            return false
        }
        let oldSettings = settings
        let oldDam = DamListData.allDams.first(where: { $0.id == oldSettings.targetDamId })
        let newDam = DamListData.allDams.first(where: { $0.id == id })
        addDebugLog(message: "Dam changed.", details: "Dam name: \(oldDam?.nameEn ?? oldSettings.targetDamId) → \(newDam?.nameEn ?? id)")

        settings.targetDamId = id
        settings.wasLastDataAllInvalid = false
        settings.lastLoadResultMessage = ""
        settingsRepository.save(settings)

        clearRealtimeDataForDamChange()
        scheduleAutoRefreshTimer()
        clearWidgetRealtimeData()
        saveWidgetSettingsBridge()
        reloadWidgetTimeline(reason: "damChanged")
        Task {
            await self.fetchSudmonitorHistoryForDamChange()
        }

        return true
    }

    /// リアルタイム観測データ (Real-time observation data) の取得ソース切替に、ダム変更の確認ダイアログが必要かどうかを返します。
    /// - Parameter source: 切替先の取得ソース。
    /// - Returns: sudmonitor へ切り替える際に対象ダムが早明浦ダム以外であれば `true`。
    func realtimeDataSourceSwitchNeedsDamConfirmation(_ source: RealtimeDataSource) -> Bool {
        source == .sudmonitor && !RealtimeDataSource.sudmonitorSupportedDamIds.contains(settings.targetDamId)
    }

    /// リアルタイム観測データ (Real-time observation data) の取得ソースを切り替えます。
    ///
    /// sudmonitor へ切り替える際に対象ダムが対応ダム以外の場合、既存のダム変更処理を再利用して早明浦ダムへ変更します。
    /// - Parameter source: 切替先の取得ソース。
    func setRealtimeDataSource(_ source: RealtimeDataSource) {
        let previous = settings.realtimeDataSource
        if realtimeDataSourceSwitchNeedsDamConfirmation(source) {
            confirmTargetDamId(AppSettings.defaultDamId)
        }
        updateSettings { $0.realtimeDataSource = source }
        addDebugLog(message: "Realtime data source changed.", details: "Source: \(previous.rawValue) → \(source.rawValue)")
    }

    /// 過去データ検索 (Historical data search) のデータソースを設定します。
    func setHistoricalDataSource(_ source: RealtimeDataSource) {
        updateSettings { $0.general.historicalDataSource = source }
    }

    /// 初回自動更新ダイアログの表示完了を記録します。
    func markInitialAutoUpdateDialogShown() {
        if !settings.initialAutoUpdateDialogShown && !settings.autoUpdateEnabled {
            settings.recalculateInitialNextRequestedUpdate()
        }
        updateSettings { $0.initialAutoUpdateDialogShown = true }
        showInitialAutoUpdateDialog = false
        showInitialNotificationPermissionRequest = true
    }

    /// 初回ダイアログのUI指示から自動更新を有効化します。
    func enableAutoUpdateFromInitialDialog() {
        updateSettings { settings in
            settings.autoUpdateEnabled = true
        }
        let next = settings.nextRequestedUpdate
        addDebugLog(message: "Auto update enabled (initial dialog).", details: "Interval: \(settings.autoUpdateInterval.androidName), Next scheduled: \(TimeFormatters.iso8601JST.string(from: next))")
    }

    /// 初回通知許諾のお願いダイアログ表示完了を記録します。
    func markInitialNotificationPermissionRequested() {
        showInitialNotificationPermissionRequest = false
    }

    /// 起動初期の通知許諾要求プロセスを実行します（UIテスト時はスキップ）。
    func requestInitialNotificationPermission() async {
        #if DEBUG
        if UITestLaunchSupport.isEnabled {
            updateSettings { $0.showNotification = false }
            markInitialNotificationPermissionRequested()
            return
        }
        #endif
        let granted = await notificationCoordinator.requestAuthorizationIfNeeded()
        syncNotificationAuthorization(granted: granted, showDeniedMessage: false)
        markInitialNotificationPermissionRequested()
    }

    /// 通知機能の有効/無効を設定変更し、許可要求が必要な場合は実行します。
    /// - Parameter enabled: 通知を有効化するかどうかのフラグ。
    func setShowNotification(_ enabled: Bool) {
        guard enabled else {
            updateSettings { $0.showNotification = false }
            return
        }
        Task {
            await requestNotificationAuthorizationFromUserAction()
        }
    }

    /// デバッグ用の各種詳細設定メニューの表示状態を有効化します。
    func toggleDebugSettingsVisibility() {
        guard !settings.debugSettingsVisible else { return }
        updateSettings {
            $0.debugSettingsVisible = true
            #if !DEBUG
            $0.debugModeEnabled = false
            $0.debugSimulateMode = .none
            #endif
        }
    }

    /// すべてのデバッグ設定項目を無効（初期設定値にリセット）にし、デバッグファイルの読み込みもクリアします。
    func disableDebugSettings() {
        if settings.debugModeEnabled {
            updateDebugModeEnabled(false)
            guard !settings.debugModeEnabled else { return }
        }
        updateSettings { settings in
            settings = settings.resettingDebugSettings()
        }
    }

    /// 貯水率 (Storage rate) の変化時メッセージ設定をデフォルトにリセットします。
    /// - Parameter mode: リセット対象の貯水率状態モード。
    func resetStorageRateMessages(mode: StorageRateMessageResetMode) {
        updateSettings { settings in
            settings.resetStorageRateMessages(mode: mode)
        }
    }

    /// 早明浦ダム以外の貯水率 (Storage rate) の変化時メッセージ設定を既定値（一般向け）にリセットします。
    func resetOtherStorageRateMessages() {
        updateSettings { settings in
            settings.resetOtherStorageRateMessages()
        }
    }

    /// 特定のその他通知条件のメッセージ文言を初期値にリセットします。
    /// - Parameter field: 対象のメッセージ項目。
    func resetOtherMessageItem(field: OtherMessageField) {
        updateSettings { settings in
            settings.resetOtherMessageItem(field: field)
        }
    }

    /// すべてのその他状態メッセージの文言を一括でリセットします。
    func resetOtherMessages() {
        updateSettings { settings in
            settings.resetOtherMessages()
        }
    }

    /// ダム諸量データのフェッチおよび解析処理を実行し、結果を永続化キャッシュに保存します。
    /// - Parameter workType: 更新の動機（手動、自動、起動時など）。
    func fetchLatest(workType: String = "Manual update") async {
        guard !isLoading else { return }
        guard let context = modelContext else {
            errorMessage = AppError.modelContextNotReady.localizedDescription
            return
        }
        guard let config = currentDamConfig else {
            errorMessage = AppError.damConfigMissing.localizedDescription
            return
        }
        let isManual = workType == "Manual update"
        if isManual, !canRefresh() {
            return
        }
        let isAuto = workType.hasPrefix("Auto update")
        let shouldShowFailureSnackbar = isManual || workType == "Initial load"
        let isAutoStyle = isAuto || workType == "Initial load" || workType == "Boot update"
        isLoading = true
        if isManual { isManualUpdateRunning = true }
        if isAutoStyle { isAutoUpdateRunning = true }
        errorMessage = nil

        do {
            try Task.checkCancellation()
            let result = try await fetchLatestData(config: config)
            try Task.checkCancellation()
            let parsed = result.data
            let rawBytes = result.rawBytes
            let rawDatFileName = result.rawDatFileName
            let nextDebugDataEndDate = result.nextDebugDataEndDate
            let originFetchedAt = result.originFetchedAt
            let nextUpdateAt = result.nextUpdateAt
            let encoded = try JSONEncoder().encode(parsed)
            let existing = try context.fetch(FetchDescriptor<DamDataRecord>())
            existing.forEach { context.delete($0) }
            let recordLastFetchTime = !(isManual && settings.debugModeEnabled)
            let newManualRefreshAvailableAt: Date?
            if recordLastFetchTime {
                newManualRefreshAvailableAt = nextUpdateAt ?? Calendar.jst.date(byAdding: .minute, value: 10, to: Date())
            } else {
                newManualRefreshAvailableAt = existing.first?.manualRefreshAvailableAt
            }
            context.insert(DamDataRecord(
                encodedData: encoded,
                lastFetchTime: recordLastFetchTime ? Date() : (lastFetchTime ?? Date()),
                rawDatBytes: rawBytes,
                rawDatFileName: rawDatFileName,
                manualRefreshAvailableAt: newManualRefreshAvailableAt
            ))
            try context.save()

            damData = parsed
            let resetToRealtime = workType == "Initial load"
            if resetToRealtime {
                historicalRows = []
                selectedHistoricalMeta = nil
                selectedDetail = .realtime
            }
            bumpGraphDataRevision()
            if recordLastFetchTime {
                lastFetchTime = Date()
                manualRefreshAvailableAt = newManualRefreshAvailableAt
            }
            isNetworkError = false
            damLoadStatus = .success
            errorMessage = nil
            let successMessages = messagesForSuccessfulFetch(parsed)
            let notificationMessage = successMessages.notification
            settings.lastLoadResultMessage = notificationMessage
            let currentPercentTime = damData?.storagePercentageTime ?? damData?.updatedAt
            let isTimeChanged = previousPercentTime != nil && previousPercentTime != currentPercentTime
            if let overrideMessage = successMessages.overrideMessage {
                updateSnackbarMessage = "\(config.localizedName) \(overrideMessage)".trimmingCharacters(in: .whitespaces)
            } else if isTimeChanged {
                let snackbarMsg = DamStatusMessageFormatter(
                    settings: settings,
                    isJapanese: AppLocale.isJapanese
                ).snackbarMessage(data: parsed, damName: config.localizedName)
                updateSnackbarMessage = snackbarMsg
            }
            previousPercentTime = currentPercentTime
            if isAuto {
                settings.lastAutoUpdate = Date()
                settings.nextRequestedUpdate = settings.nextRunTime(after: Date())
            }
            if let nextDebugDataEndDate {
                settings.debugRealtimeDataEndDate = nextDebugDataEndDate
            }
            if let originFetchedAt {
                settings.originFetchedAt = originFetchedAt
            }
            settingsRepository.save(settings)
            saveWidgetSnapshot(data: parsed, message: successMessages.widget)
            saveWidgetRawDatBridge(rawBytes: rawBytes, rawDatFileName: rawDatFileName, nextUpdateAt: nextUpdateAt)
            let logTitle: String
            if isAuto {
                logTitle = "Auto update"
            } else {
                logTitle = workType
            }
            let sourceLabel = settings.realtimeDataSource == .sudmonitor ? RealtimeDataSource.sudmonitorHost : "MLIT"
            addDebugLog(message: "\(logTitle) succeeded.", details: "Data Source: \(sourceLabel), \(buildSuccessDetails(damNameEn: config.nameEn, parsed: parsed))")
            if workType == "Boot update" {
                setWidgetValue(Date().timeIntervalSinceReferenceDate, forKey: WidgetDefaultsKey.appBootUpdateDoneAt)
            }
            await sendNotificationIfNeeded(message: notificationMessage)
        } catch {
            let loadError = RealtimeLoadError(error)
            let isNetErr = loadError.isNetworkFailure
            let reason: String
            if let appError = error as? AppError, appError == .simulatedNetworkUnavailable {
                reason = "Simulated network unavailable"
            } else if isNetErr {
                reason = "Network unavailable"
            } else if let networkError = error as? MlitNetworkError {
                reason = String(describing: networkError)
            } else if error is AppError {
                reason = String(describing: type(of: error))
            } else {
                reason = (error as NSError).description
            }
            let logTitle: String
            if isAuto {
                logTitle = "Auto update"
            } else {
                logTitle = workType
            }
            addDebugLog(message: "\(logTitle) failed.", details: "Reason: \(reason)")
            isNetworkError = isNetErr
            damLoadStatus = isNetErr ? .networkUnavailable : .loadingFailure
            let statusText: String
            if isNetErr {
                statusText = settings.networkUnavailableText(isJapanese: AppLocale.isJapanese)
            } else {
                statusText = settings.loadingErrorText(isJapanese: AppLocale.isJapanese)
            }
            let failureMessage = statusText.isEmpty
                ? config.localizedName
                : "\(config.localizedName) \(statusText)".trimmingCharacters(in: .whitespaces)
            if shouldShowFailureSnackbar {
                updateSnackbarMessage = failureMessage
                settings.lastLoadResultMessage = failureMessage
            }
            saveWidgetErrorSnapshot(message: statusText)
            settingsRepository.save(settings)
        }
        isLoading = false
        if isManual { isManualUpdateRunning = false }
        if isAutoStyle { isAutoUpdateRunning = false }

        scheduleManualRefreshAvailabilityTimer()
    }

    /// エラーオブジェクトがネットワーク関連であるかどうかを判定します。
    private static func isNetworkFailure(_ error: Error) -> Bool {
        if let appError = error as? AppError {
            return appError == .simulatedNetworkUnavailable || appError == .networkUnavailable
        }
        if error is MlitNetworkError {
            return true
        }
        if error is URLError {
            return true
        }
        return (error as NSError).domain == NSURLErrorDomain
    }

    /// デバッグログ用の成功詳細文字列をビルドします。
    private func buildSuccessDetails(damNameEn: String, parsed: DamData) -> String {
        let dataTime = formatDamTimeForDebugLog(parsed.updatedAt)
        var result = "Dam name: \(damNameEn), Data time: \(dataTime)"
        if let storageTimeStr = parsed.storagePercentageTime.map({ formatDamTimeForDebugLog($0) }) {
            result += ", Data time (Storage): \(storageTimeStr)"
        }
        return result
    }

    /// 表示用ダム時間文字列を ISO8601 形式のデバッグログ用表現にフォーマットします。
    private func formatDamTimeForDebugLog(_ damTime: String) -> String {
        guard let date = DamCoreDamTime.date(from: damTime) else { return damTime }
        return TimeFormatters.iso8601JST.string(from: date)
    }

    /// 手動更新がブロックされていないかを判定します（公開インターフェース用）。
    /// - Parameter now: 基準とする現在日時。
    /// - Returns: 手動更新可能である場合は `true`、それ以外は `false`。
    func canRefresh(now: Date = Date()) -> Bool {
        guard !isLoading else { return false }
        #if DEBUG
        if settings.debugModeEnabled {
            return true
        }
        #endif
        guard let availableAt = effectiveManualRefreshAvailableAt() else { return true }
        return now >= availableAt
    }

    /// 手動更新クールダウンの終了時刻を取得します（保存済み `X-TCS-Next-Update-At` が優先。欠落時は `lastFetchTime` + 10 分）。
    private func effectiveManualRefreshAvailableAt() -> Date? {
        if let manualRefreshAvailableAt {
            return manualRefreshAvailableAt
        }
        guard let lastFetchTime else { return nil }
        return Calendar.jst.date(byAdding: .minute, value: 10, to: lastFetchTime)
    }

    /// 自動更新の基準日時テキスト表現を取得します。
    private func autoUpdateDateTime(_ date: Date) -> String {
        dateTimeWithJSTSuffix(date, includeWeekday: settings.autoUpdateInterval == .oneWeek)
    }

    /// JSTタイムゾーン指定のサフィックスを考慮して日時をフォーマットします。
    private func dateTimeWithJSTSuffix(_ date: Date, includeWeekday: Bool) -> String {
        let formatter = includeWeekday ? TimeFormatters.jstDisplayWithWeekday : TimeFormatters.jstDisplay
        return DamCoreJSTSupport.appendingJstSuffix(formatter.string(from: date), isLocalJst: DisplayFormatters.isJST)
    }

    /// 指定された期間・ダムに対する過去データ検索 (Historical data search) を実行し、メタデータおよび履歴行を保存・選択状態にします。
    /// - Parameters:
    ///   - damConfig: 対象のダム構成設定。
    ///   - startDate: 検索開始日。
    ///   - endDate: 検索終了日。
    func searchHistorical(damConfig: DamConfig, startDate: Date, endDate: Date) async {
        guard !isHistoricalLoading else { return }
        guard let context = modelContext else {
            errorMessage = AppError.modelContextNotReady.localizedDescription
            return
        }
        isHistoricalLoading = true
        errorMessage = nil
        defer { isHistoricalLoading = false }

        do {
            let result = try await historicalSearchService.search(
                damConfig: damConfig,
                startDate: startDate,
                endDate: endDate,
                historicalDataSource: settings.debugModeEnabled ? .sudmonitor : settings.historicalDataSource,
                context: context,
                maxSearchCount: Self.maxHistoricalSearchCount
            )
            reloadHistoricalMeta()
            if result.source != .bundled {
                let sourceLabel = result.source == .sudmonitor ? RealtimeDataSource.sudmonitorHost : "MLIT"
                addDebugLog(message: "Historical search succeeded.", details: "Data Source: \(sourceLabel), Dam name: \(damConfig.nameEn), Period(Start): \(TimeFormatters.iso8601JST.string(from: startDate)), Period(End): \(TimeFormatters.iso8601JST.string(from: endDate))")
            }
            await openHistorical(metaId: result.meta.id)
        } catch {
            _ = HistoricalSearchError(error)
            errorMessage = error.localizedDescription
            if let appError = error as? AppError, appError == .networkUnavailable { return }
            switch HistoricalSearchError(error) {
            case .duplicate, .limitExceeded:
                break
            default:
                addDebugLog(message: "Historical search failed.", details: "Data Source: MLIT, Dam name: \(damConfig.nameEn), Period(Start): \(TimeFormatters.iso8601JST.string(from: startDate)), Period(End): \(TimeFormatters.iso8601JST.string(from: endDate)), Reason: \((error as NSError).description)")
            }
        }
    }

    /// 指定された過去検索履歴詳細データを開いて、グラフおよび一覧に展開します。
    /// - Parameter metaId: 対象の検索結果メタデータID。
    func openHistorical(metaId: UUID) async {
        guard let context = modelContext else { return }
        do {
            let metas = try context.fetch(FetchDescriptor<HistoricalSearchMetaRecord>())
            guard let meta = metas.first(where: { $0.id == metaId }) else { return }
            let rows = try context.fetch(FetchDescriptor<HistoricalDamDataRecord>())
                .filter { $0.searchMetaId == metaId }
                .sorted { $0.timeMillis < $1.timeMillis }
                .map(\.domain)
            selectedHistoricalMeta = meta.domain
            historicalRows = rows
            historicalDisplayStartDate = nil
            historicalDisplayEndDate = nil
            selectedDetail = .historical(metaId)
            if !meta.isPinned {
                transientViewedMetaId = metaId
            }
            bumpGraphDataRevision()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 指定された過去データ検索結果（メタデータおよび関連する詳細レコード）をデータベースから削除します。
    /// - Parameter metaId: 削除対象のメタデータID。
    func deleteHistorical(metaId: UUID) {
        guard let context = modelContext else { return }
        do {
            try context.fetch(FetchDescriptor<HistoricalDamDataRecord>())
                .filter { $0.searchMetaId == metaId }
                .forEach { context.delete($0) }
            try context.fetch(FetchDescriptor<HistoricalSearchMetaRecord>())
                .filter { $0.id == metaId }
                .forEach { context.delete($0) }
            try context.save()
            if transientViewedMetaId == metaId {
                transientViewedMetaId = nil
            }
            if selectedHistoricalMeta?.id == metaId {
                selectedHistoricalMeta = nil
                historicalRows = []
                selectedDetail = .realtime
            }
            bumpGraphDataRevision()
            reloadHistoricalMeta()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 保存されているすべての過去データ検索の記録を一括削除します。
    func deleteAllHistorical() {
        guard let context = modelContext else { return }
        do {
            try context.fetch(FetchDescriptor<HistoricalDamDataRecord>()).forEach { context.delete($0) }
            try context.fetch(FetchDescriptor<HistoricalSearchMetaRecord>()).forEach { context.delete($0) }
            try context.save()
            selectedHistoricalMeta = nil
            historicalRows = []
            selectedDetail = .realtime
            transientViewedMetaId = nil
            bumpGraphDataRevision()
            reloadHistoricalMeta()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 過去データ検索結果の表示順序を入れ替えます（並び替え機能用）。
    /// - Parameters:
    ///   - source: 移動元の要素インデックスセット。
    ///   - destination: 移動先の挿入位置インデックス。
    func moveHistorical(from source: IndexSet, to destination: Int) {
        var current = historicalMetaList
        let movingItems = source.sorted().map { current[$0] }
        for index in source.sorted(by: >) {
            current.remove(at: index)
        }
        let adjustedDestination = destination - source.filter { $0 < destination }.count
        current.insert(contentsOf: movingItems, at: max(0, min(adjustedDestination, current.count)))
        guard let context = modelContext else { return }
        do {
            let records = try context.fetch(FetchDescriptor<HistoricalSearchMetaRecord>())
            for (index, meta) in current.enumerated() {
                records.first { $0.id == meta.id }?.sortOrder = index
            }
            try context.save()
            reloadHistoricalMeta()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 過去データ検索履歴をピン留め（または解除）します。
    /// - Parameter metaId: 対象のメタデータID。
    /// - Returns: ピン留めが上限を超過して失敗した場合はエラー説明テキスト、成功した場合は `nil`。
    func togglePin(metaId: UUID) async -> String? {
        guard let context = modelContext else { return nil }
        do {
            let records = try context.fetch(FetchDescriptor<HistoricalSearchMetaRecord>())
            guard let record = records.first(where: { $0.id == metaId }) else { return nil }

            if !record.isPinned {
                let pinnedCount = records.filter { $0.isPinned }.count
                if pinnedCount >= Self.maxPinnedCount {
                    return AppText.historicalManagePinLimit
                }
            }

            record.isPinned.toggle()
            try context.save()
            reloadHistoricalMeta()

            if !record.isPinned {
                if selectedHistoricalMeta?.id == metaId {
                    transientViewedMetaId = metaId
                } else if transientViewedMetaId == metaId {
                    transientViewedMetaId = nil
                }
            }
            bumpGraphDataRevision()
        } catch {
            errorMessage = error.localizedDescription
        }
        return nil
    }

    func importDebugRealtimeDat(from url: URL) {
        importDebugDat(from: url, isHistoricalDaily: false)
    }

    func importDebugHistoricalDailyDat(from url: URL) {
        importDebugDat(from: url, isHistoricalDaily: true)
    }

    private func importDebugDat(from url: URL, isHistoricalDaily: Bool) {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart { url.stopAccessingSecurityScopedResource() }
        }
        do {
            guard url.pathExtension.caseInsensitiveCompare("dat") == .orderedSame else {
                throw AppError.invalidDebugDatFile
            }
            let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            if fileSize > MlitURLPolicy.maxResponseBytes {
                throw AppError.responseTooLarge
            }
            let data = try Data(contentsOf: url)
            guard let config = currentDamConfig else { throw AppError.damConfigMissing }
            if isHistoricalDaily {
                _ = try SudmonitorHistoryService.validateDebugDat(data, damId: config.id)
            } else {
                _ = try parser.parseRealtimeDat(data, stationId: config.id, stationName: config.nameJa)
            }
            let destination = try debugDatURL(fileName: isHistoricalDaily ? "debug-historical-daily.dat" : "debug-realtime.dat")
            try data.write(to: destination, options: .atomic)
            excludeFromBackup(destination)
            updateSettings {
                if isHistoricalDaily {
                    $0.debugHistoricalDailyDatSelectionMode = .userSelected
                    $0.debugHistoricalDailyDatFileName = url.lastPathComponent
                } else {
                    $0.debugRealtimeDatSelectionMode = .userSelected
                    $0.debugRealtimeDatFileName = url.lastPathComponent
                    $0.debugRealtimeDataEndDate = nil
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// デバッグモードの有効・無効を設定変更します。
    /// - Parameter enabled: 有効化する場合は `true`、それ以外は `false`。
    func updateDebugModeEnabled(_ enabled: Bool) {
        guard enabled != settings.debugModeEnabled, !isDebugModeTransitioning else { return }
        guard let context = modelContext, let service = debugDataSessionService else {
            errorMessage = AppError.modelContextNotReady.localizedDescription
            return
        }
        isDebugModeTransitioning = true
        defer { isDebugModeTransitioning = false }
        do {
            if enabled {
                try service.beginSession(context: context)
                updateSettings { $0.debugModeEnabled = true }
            } else {
                try service.restoreSession(context: context)
                var restoredSettings = settings.resettingDebugSettings()
                restoredSettings.debugSettingsVisible = settings.debugSettingsVisible
                settings = restoredSettings
                settingsRepository.save(settings)
                reloadAfterDebugDataRestore()
                try service.removeBackupAfterSuccessfulExit()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateDebugRealtimeDatSelectionMode(_ mode: DebugDatSelectionMode) {
        updateSettings {
            $0.debugRealtimeDatSelectionMode = mode
            if mode != .userSelected {
                $0.debugRealtimeDatFileName = nil
            }
            $0.debugRealtimeDataEndDate = nil
        }
    }

    func updateDebugHistoricalDailyDatSelectionMode(_ mode: DebugDatSelectionMode) {
        updateSettings {
            $0.debugHistoricalDailyDatSelectionMode = mode
            if mode != .userSelected {
                $0.debugHistoricalDailyDatFileName = nil
            }
        }
    }

    /// デバッグデータの終了日時を指定（更新絞り込みの進行設定用）します。
    /// - Parameter date: 指定するデータ上限日時。
    func updateDebugRealtimeDataEndDate(_ date: Date?) {
        let rounded: Date?
        if let date {
            rounded = (try? debugRealtimeDataTimes().last { $0 <= date }) ?? date
        } else {
            rounded = nil
        }
        updateSettings {
            $0.debugRealtimeDataEndDate = rounded
        }
    }

    /// キャッシュされたリアルタイムDATファイルが存在するかどうかを判定します。
    /// - Returns: 存在する場合は `true`、それ以外は `false`。
    func hasRealtimeDatFile() -> Bool {
        if settings.debugModeEnabled {
            guard let debugDataSessionService else { return false }
            return (try? debugDataSessionService.backedUpRealtimeDatFile()) != nil
        }
        return latestRawDatBytes() != nil
    }

    func hasHistoricalDailyDatFile() -> Bool {
        if settings.debugModeEnabled {
            guard let debugDataSessionService else { return false }
            return (try? debugDataSessionService.backedUpHistoricalDailyDatFile(damId: settings.targetDamId)) != nil
        }
        return currentHistoricalDailyDatFile() != nil
    }

    /// 現在デバッグ用に指定されているDATファイルに含まれる、日付時刻のリストを抽出して取得します。
    /// - Returns: DATデータ内の日付配列。
    /// - Throws: データの読み込みやパースに失敗した場合のエラー。
    func debugRealtimeDataTimes() throws -> [Date] {
        let data = try debugRealtimeDatBytes(for: settings)
        return try parser.realtimeDataTimes(data)
    }

    /// キャッシュされている最新の生のDATファイルバイナリデータを取得します。
    func latestRawDatBytes() -> Data? {
        guard let context = modelContext else { return nil }
        return try? context.fetch(FetchDescriptor<DamDataRecord>()).first?.rawDatBytes
    }

    /// 現在キャッシュされているDATファイルの書き出し用ファイル名を取得します。
    /// - Parameter variant: 書き出しバリアント設定。
    /// - Returns: エクスポート用の推奨ファイル名。
    func realtimeDatExportFilename(variant: DatExportVariant) -> String {
        guard let context = modelContext else {
            return variant.exportFilename(baseName: nil)
        }
        let record = try? context.fetch(FetchDescriptor<DamDataRecord>()).first
        let baseName = record?.rawDatFileName
        return variant.exportFilename(baseName: baseName)
    }

    /// キャッシュされているDATファイルを指定されたバリアント（生のまま、またはUTF-8等）に変換したエクスポート用バイナリデータを取得します。
    /// - Parameter variant: 変換出力の形式。
    /// - Returns: 変換された書き出し対象バイナリデータ。
    /// - Throws: データ変換エラー。
    func realtimeDatExportData(variant: DatExportVariant) throws -> Data {
        let raw = latestRawDatBytes() ?? Data()
        switch variant {
        case .raw:
            return raw
        case .utf8:
            return try DatExportConverter.utf8Data(from: raw)
        }
    }

    func historicalDailyDatExportFilename(variant: DatExportVariant) -> String {
        variant.exportFilename(baseName: currentHistoricalDailyDatFile()?.fileName)
    }

    func historicalDailyDatExportData(variant: DatExportVariant) throws -> Data {
        guard let raw = currentHistoricalDailyDatFile()?.bytes else { throw AppError.debugFileMissing }
        return variant == .raw ? raw : try DatExportConverter.utf8Data(from: raw)
    }

    private func currentHistoricalDailyDatFile() -> DebugDataSessionDatFile? {
        guard let record = sudmonitorHistoryRecord else { return nil }
        return DebugDataSessionDatFile(bytes: record.rawDatBytes, fileName: record.rawDatFileName)
    }

    /// 記録されているすべてのデバッグログを CSV 形式のテキスト文字列として取得します。
    func debugLogCSV() -> String {
        var rows = ["timestamp,message,details"]
        rows += debugLogs.map { entry in
            [
                TimeFormatters.iso8601JST.string(from: entry.timestamp),
                entry.message,
                entry.details
            ].map(Self.csvField).joined(separator: ",")
        }
        return rows.joined(separator: "\n")
    }

    /// デバッグログのエクスポート用ファイル名を生成します。
    func generateDebugLogFileName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyyMMdd'T'HHmmssZ"
        let timestamp = formatter.string(from: Date()).replacingOccurrences(of: "+", with: "_")
        return "TCSameuraDamMonitor-DebugLog-\(timestamp).csv"
    }

    /// 現在表示されているエラーメッセージを消去して初期化します。
    func clearError() {
        errorMessage = nil
    }

    /// データベース上のデバッグログエントリをすべて消去します。
    func clearDebugLog() {
        guard let context = modelContext else { return }
        do {
            try context.fetch(FetchDescriptor<DebugLogRecord>()).forEach { context.delete($0) }
            try context.save()
            reloadDebugLogs()
            importWidgetLogs()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// リアルタイム観測サービスを用いて最新のデータを取得します。
    private func fetchLatestData(config: DamConfig) async throws -> RealtimeFetchResult {
        try await realtimeDataService.fetchLatestData(
            config: config,
            settings: settings,
            debugDatBytes: debugRealtimeDatBytes(for:),
            nextAutoAdvancedDebugDataEndDate: { [weak self] data, settings in
                self?.nextAutoAdvancedDebugDataEndDate(from: data, settings: settings)
            }
        )
    }

    /// データベースキャッシュから最新のダムデータをメモリに復元ロードします。
    private func loadCachedData() {
        guard let context = modelContext else { return }
        do {
            let records = try context.fetch(FetchDescriptor<DamDataRecord>())
            guard let latest = records.sorted(by: { $0.lastFetchTime > $1.lastFetchTime }).first else { return }
            damData = latest.damData
            lastFetchTime = latest.lastFetchTime
            manualRefreshAvailableAt = latest.manualRefreshAvailableAt
            previousPercentTime = damData?.storagePercentageTime ?? damData?.updatedAt
            bumpGraphDataRevision()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reloadAfterDebugDataRestore() {
        damData = nil
        lastFetchTime = nil
        manualRefreshAvailableAt = nil
        previousPercentTime = nil
        loadCachedData()
        removeWidgetValue(forKey: WidgetDefaultsKey.dailyHistoryBridgeV1)
        clearWidgetRealtimeData()
        if let data = damData {
            let messages = messagesForSuccessfulFetch(data)
            saveWidgetSnapshot(data: data, message: messages.widget)
            if let raw = latestRawDatBytes(), let config = currentDamConfig {
                let record = try? modelContext?.fetch(FetchDescriptor<DamDataRecord>()).first
                widgetBridgeService.saveRawDatBridge(
                    rawBytes: raw,
                    rawDatFileName: record?.rawDatFileName,
                    config: config,
                    nextUpdateAt: record?.manualRefreshAvailableAt
                )
            }
        } else {
            saveWidgetSettingsBridge()
        }
        if selectedDetail == .sudmonitorHistory, sudmonitorHistoryRecord == nil {
            selectedDetail = .realtime
            resetHistoricalDisplayRange()
        }
        bumpSudmonitorHistoryRevision()
        scheduleManualRefreshAvailabilityTimer()
        reloadWidgetTimeline(reason: "debugDataRestored")
    }

    /// データベースレコードから過去データ検索の履歴一覧メタデータをメモリに再ロードします。
    private func reloadHistoricalMeta() {
        guard let context = modelContext else { return }
        historicalMetaList = ((try? context.fetch(FetchDescriptor<HistoricalSearchMetaRecord>())) ?? [])
            .map(\.domain)
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// デバッグログリストをメモリに再ロードし、ウィジェットから出力された共有ログも読み込んでマージします。
    func refreshDebugLogs() {
        reloadDebugLogs()
        importWidgetLogs()
        reloadDebugLogs()
    }

    /// デバッグログデータをメモリに再ロードします。
    private func reloadDebugLogs() {
        guard let context = modelContext else { return }
        debugLogs = ((try? context.fetch(FetchDescriptor<DebugLogRecord>())) ?? [])
            .map(\.domain)
            .sorted { $0.timestamp > $1.timestamp }
    }

    /// ウィジェットバックグラウンド処理の進捗ログが共有デフォルトに記録されている場合、これをアプリのログにインポートして消去します。
    private func importWidgetLogs() {
        let groupDefaults = widgetDefaults.groupDefaults

        if let entries = groupDefaults?.stringArray(forKey: WidgetDefaultsKey.fetchLog) {
            removeWidgetValue(forKey: WidgetDefaultsKey.fetchLog)
            for entry in entries.suffix(50) {
                let parts = entry.components(separatedBy: ";")
                guard parts.count >= 4, let ts = Double(parts[0]) else { continue }
                let entryType = WidgetFetchLog.parseType(entry: entry)
                let isBoot = entryType == .boot
                let isInitial = entryType == .initial
                let base = parts.count >= 5 ? 2 : 1
                let damNameFromLog = parts[base]
                let updatedAt = parts.count > base ? parts[base + 1] : ""
                let observedAt = parts.count > base + 1 ? parts[base + 2] : ""
                let date = Date(timeIntervalSinceReferenceDate: ts)
                let damNameEn = currentDamConfig?.nameEn ?? damNameFromLog
                let dataTime = formatDamTimeForDebugLog(updatedAt)
                let storageTime = formatDamTimeForDebugLog(observedAt)
                let details = "Dam name: \(damNameEn), Data time: \(dataTime), Data time (Storage): \(storageTime)"
                let message: String
                if isBoot {
                    message = "Boot update (widget) succeeded."
                } else if isInitial {
                    message = "Initial load (widget) succeeded."
                } else {
                    message = "Auto update (widget) succeeded."
                }
                addDebugLogIfAbsent(message: message, details: details, timestamp: date)
            }
        }

        if let entries = groupDefaults?.stringArray(forKey: WidgetDefaultsKey.fetchFailLog) {
            removeWidgetValue(forKey: WidgetDefaultsKey.fetchFailLog)
            for entry in entries.suffix(50) {
                let parts = entry.components(separatedBy: ";")
                guard parts.count >= 2, let ts = Double(parts[0]) else { continue }
                let date = Date(timeIntervalSinceReferenceDate: ts)
                let reason = parts.dropFirst(1).joined(separator: ";")
                let details = "Reason: \(reason)"
                addDebugLogIfAbsent(message: "Auto update (widget) failed.", details: details, timestamp: date)
            }
        }
    }

    /// 同一時刻・同一内容のデバッグログが存在しない場合のみ追加します。
    private func addDebugLogIfAbsent(message: String, details: String = "", timestamp: Date) {
        guard let context = modelContext else { return }
        let existing = (try? context.fetch(FetchDescriptor<DebugLogRecord>())) ?? []
        guard !existing.contains(where: {
            $0.timestamp == timestamp && $0.message == message && $0.details == details
        }) else {
            return
        }
        addDebugLog(message: message, details: details, timestamp: timestamp)
    }

    /// 新しいデバッグログをデータベースに追加します（上限を超えた古いエントリは自動削除されます）。
    /// - Parameters:
    ///   - message: メインメッセージ。
    ///   - details: 詳細説明。
    ///   - timestamp: ログ発生日時。デフォルトは現在時間です。
    func addDebugLog(message: String, details: String = "", timestamp: Date = Date()) {
        guard let context = modelContext else {
            return
        }
        let entry = DebugLogEntry(id: UUID(), timestamp: timestamp, message: message, details: details)
        context.insert(DebugLogRecord(entry: entry))
        do {
            let all = try context.fetch(FetchDescriptor<DebugLogRecord>())
                .sorted { $0.timestamp > $1.timestamp }
            for old in all.dropFirst(Self.maxDebugLogCount) {
                context.delete(old)
            }
            try context.save()
        } catch {
            errorMessage = error.localizedDescription
        }
        reloadDebugLogs()
    }

    /// データ内容に基づいた通知配信用テキストを生成します。
    private func notificationMessage(for data: DamData) -> String {
        guard let config = currentDamConfig else { return "" }
        return DamStatusMessageFormatter(settings: settings, isJapanese: AppLocale.isJapanese)
            .notificationMessage(data: data, damName: config.localizedName)
    }

    /// データ内容に基づいたウィジェット表示用テキストを生成します。
    private func widgetMessage(for data: DamData) -> String {
        DamStatusMessageFormatter(settings: settings, isJapanese: AppLocale.isJapanese)
            .widgetMessage(data: data)
    }

    /// フェッチ成功時に各種配信先（通知、ウィジェット、スナックバー用）向けに最適なメッセージセットを構築します。
    private func messagesForSuccessfulFetch(_ data: DamData) -> (notification: String, widget: String, overrideMessage: String?) {
        let wasAllInvalid = settings.wasLastDataAllInvalid
        let isAllInvalid = data.isAllObservationDataInvalid
        let override: String?
        if isAllInvalid && !wasAllInvalid {
            override = settings.dataDistributionStoppedText(isJapanese: AppLocale.isJapanese)
        } else if !isAllInvalid && wasAllInvalid {
            override = settings.dataDistributionResumedText(isJapanese: AppLocale.isJapanese)
        } else {
            override = nil
        }
        settings.wasLastDataAllInvalid = isAllInvalid
        guard let config = currentDamConfig else {
            let widget = override ?? widgetMessage(for: data)
            return (widget, widget, override)
        }
        let formatter = DamStatusMessageFormatter(
            settings: settings,
            isJapanese: AppLocale.isJapanese
        )
        return (
            formatter.notificationMessage(data: data, damName: config.localizedName, overrideMessage: override),
            formatter.widgetMessage(data: data, overrideMessage: override),
            override
        )
    }

    /// バックグラウンドや非アクティブ時などの条件を満たしている場合に、必要に応じてローカルプッシュ通知を送信します。
    private func sendNotificationIfNeeded(message: String) async {
        guard settings.showNotification, !message.isEmpty else { return }
        guard !isSceneActive else {
            return
        }
        guard await notificationCoordinator.currentAuthorizationAllowsNotification() else {
            syncNotificationAuthorization(granted: false, showDeniedMessage: false)
            return
        }
        await notificationCoordinator.send(
            identifier: "dam-update",
            title: AppText.appName,
            body: message
        )
    }

    /// ユーザーの直接設定変更アクションを受けて、ローカル通知の権限取得を要求します。
    private func requestNotificationAuthorizationFromUserAction() async {
        let granted = await notificationCoordinator.requestAuthorizationIfNeeded()
        syncNotificationAuthorization(granted: granted, showDeniedMessage: true)
    }

    /// システム上の通知許諾結果とアプリ設定上の通知フラグを同期し、不許可時は必要に応じてスナックバーで警告を表示します。
    private func syncNotificationAuthorization(granted: Bool, showDeniedMessage: Bool) {
        updateSettings { $0.showNotification = granted }
        if !granted && showDeniedMessage {
            updateSnackbarMessage = AppText.settingsNotificationDenied
        }
    }

    /// ウィジェット用デフォルトストアに値を書き込みます。
    private func setWidgetValue(_ value: Any, forKey key: String) {
        widgetBridgeService.set(value, forKey: key)
    }

    /// ウィジェット用デフォルトストアから値を削除します。
    private func removeWidgetValue(forKey key: String) {
        widgetBridgeService.removeValue(forKey: key)
    }

    /// 監視対象のダム変更に伴い、内部のリアルタイム表示データを初期化します。
    private func clearRealtimeDataForDamChange() {
        if let context = modelContext {
            do {
                try context.fetch(FetchDescriptor<DamDataRecord>()).forEach { context.delete($0) }
                try context.save()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        damData = nil
        lastFetchTime = nil
        manualRefreshAvailableAt = nil
        isNetworkError = false
        selectedHistoricalMeta = nil
        historicalRows = []
        historicalDisplayStartDate = nil
        historicalDisplayEndDate = nil
        selectedDetail = .realtime
        bumpGraphDataRevision()
        scheduleManualRefreshAvailabilityTimer()
    }

    /// ウィジェット共有メモリ領域上のリアルタイムデータを消去します。
    private func clearWidgetRealtimeData() {
        widgetBridgeService.clearRealtimeData()
    }

    /// ウィジェット共有メモリ領域から指定キーのバイナリデータを取得します。
    private func widgetData(forKey key: String) -> Data? {
        widgetBridgeService.data(forKey: key)
    }

    /// ウィジェット共有メモリ領域から指定キーの数値を `Double` で取得します。
    private func widgetDouble(forKey key: String) -> Double {
        widgetBridgeService.double(forKey: key)
    }

    /// ウィジェット共有メモリ領域から指定キーの文字列を取得します。
    private func widgetString(forKey key: String) -> String? {
        widgetBridgeService.string(forKey: key)
    }

    /// ウィジェット共有メモリ領域から指定キーの日付を取得します。
    private func widgetDate(forKey key: String) -> Date? {
        widgetBridgeService.date(forKey: key)
    }

    /// アプリ設定と現在のダム設定のブリッジ設定値をウィジェットに同期保存します。
    private func saveWidgetSettingsBridge() {
        guard let config = currentDamConfig else { return }
        widgetBridgeService.saveSettingsBridge(
            settings: settings,
            config: config,
            damDisplayName: config.localizedName,
            initialLoadDone: damData != nil
        )
    }

    /// 成功時のダム観測データをウィジェット表示用スナップショットとして保存します。
    private func saveWidgetSnapshot(data: DamData, message: String) {
        widgetBridgeService.saveSnapshot(data: data, message: message, config: currentDamConfig, isNetworkError: isNetworkError)
        saveWidgetSettingsBridge()
    }

    /// エラー状態をウィジェット用スナップショットに反映して保存します。
    private func saveWidgetErrorSnapshot(message: String) {
        widgetBridgeService.saveErrorSnapshot(message: message, config: currentDamConfig)
        saveWidgetSettingsBridge()
    }

    /// ウィジェットの描画表示に影響する設定値に変更があったかを判定します。
    private func widgetBridgeRelevantSettingsChanged(from old: AppSettings, to new: AppSettings) -> Bool {
        WidgetBridgeIdentity(settings: old) != WidgetBridgeIdentity(settings: new)
    }

    /// ウィジェットに対して、表示全体の再ロード指示（タイムライン更新）を投げます。
    private func reloadWidgetTimeline(reason: String) {
        widgetBridgeService.reloadTimeline()
    }

    /// キャッシュ書き出し用に生のDATファイルとURL情報をブリッジに保存します。
    private func saveWidgetRawDatBridge(rawBytes: Data, rawDatFileName: String?, nextUpdateAt: Date?) {
        guard let config = currentDamConfig else { return }
        widgetBridgeService.saveRawDatBridge(rawBytes: rawBytes, rawDatFileName: rawDatFileName, config: config, nextUpdateAt: nextUpdateAt)
    }

    /// ウィジェットから共有されている生のDATブリッジキャッシュを取得します。
    private func widgetRawDatBridge(for config: DamConfig) -> DamCoreRawDatBridge? {
        widgetBridgeService.rawDatBridge(for: config)
    }

    /// ウィジェット側がバックグラウンドで取得した sudmonitor 日次過去データを、アプリの SwiftData レコードへ取り込みます（実績時刻はウィジェット側の取得完了時刻）。
    private func importSudmonitorHistoryBridgeIfNewer() async {
        guard !settings.debugModeEnabled,
              settings.historicalDataSource == .sudmonitor,
              let context = modelContext,
              let data = widgetBridgeService.data(forKey: WidgetDefaultsKey.dailyHistoryBridgeV1),
              let bridge = try? JSONDecoder().decode(DamCoreDailyHistoryBridge.self, from: data),
              bridge.version == DamCoreDailyHistoryBridge.currentVersion,
              bridge.stationId == settings.targetDamId else { return }
        let saved = sudmonitorHistoryService.record(damId: bridge.stationId, context: context)
        guard bridge.fetchedAt > (saved?.fetchedAt ?? .distantPast) else { return }
        let outcome = sudmonitorHistoryService.importBridge(bridge, context: context)
        if case .stored = outcome {
            bumpSudmonitorHistoryRevision()
            addDebugLog(message: "Daily history import (from widget) succeeded.", details: "Dam ID: \(bridge.stationId)")
        }
    }

    /// ウィジェット側の最終取得時刻がアプリ側より新しい場合だけ、Widget bridge から最新データを取り込みます。
    @discardableResult
    private func importWidgetDataIfNewer(logContext: String = "Auto update (from widget)") async -> Bool {
        guard !settings.debugModeEnabled,
              let config = currentDamConfig,
              let bridge = widgetRawDatBridge(for: config),
              let widgetLastFetchAt = widgetDate(forKey: WidgetDefaultsKey.widgetLastFetchAt) else {
            return false
        }
        let currentLastFetch = lastFetchTime ?? .distantPast
        guard bridge.fetchedAt > currentLastFetch,
              widgetLastFetchAt >= bridge.fetchedAt.addingTimeInterval(-60) else {
            return false
        }
        await importWidgetData(logContext: logContext)
        return true
    }

    /// Widget 実行時刻を基準に、アプリ側の次回自動更新リクエストを決定します。
    private func nextRequestedUpdateAfterWidgetFetch(fetchTime: Date) -> Date {
        if let widgetNext = widgetDate(forKey: WidgetDefaultsKey.nextRequestedUpdate),
           widgetNext > fetchTime {
            return widgetNext
        }
        return settings.nextRunTime(after: fetchTime)
    }

    /// ウィジェット拡張機能側が先行してバックグラウンドフェッチした最新のデータが存在する場合、それをアプリ側のレコードに読み込み同期します。
    private func importWidgetData(logContext: String = "Auto update (from widget)") async {
        guard !settings.debugModeEnabled,
              let config = currentDamConfig,
              let bridge = widgetRawDatBridge(for: config),
              let context = modelContext else { return }
        do {
            let rawData = bridge.rawBytes
            let fetchTime = bridge.fetchedAt
            let availableAt = bridge.nextUpdateAt ?? Calendar.jst.date(byAdding: .minute, value: 10, to: fetchTime)
            let parsed = try await Task.detached(priority: .userInitiated) {
                try MlitDamParser().parseRealtimeDat(rawData, stationId: config.id, stationName: config.nameJa)
            }.value
            let encoded = try JSONEncoder().encode(parsed)
            let existing = try context.fetch(FetchDescriptor<DamDataRecord>())
            existing.forEach { context.delete($0) }
            context.insert(DamDataRecord(
                encodedData: encoded,
                lastFetchTime: fetchTime,
                rawDatBytes: rawData,
                rawDatFileName: bridge.rawDatFileName,
                manualRefreshAvailableAt: availableAt
            ))
            try context.save()
            damData = parsed
            historicalRows = []
            selectedHistoricalMeta = nil
            selectedDetail = .realtime
            bumpGraphDataRevision()
            lastFetchTime = fetchTime
            manualRefreshAvailableAt = availableAt
            isNetworkError = false
            let successMessages = messagesForSuccessfulFetch(parsed)
            let notificationMessage = successMessages.notification
            settings.lastLoadResultMessage = notificationMessage
            let currentPercentTime = damData?.storagePercentageTime ?? damData?.updatedAt
            let isTimeChanged = previousPercentTime != nil && previousPercentTime != currentPercentTime
            if let overrideMessage = successMessages.overrideMessage {
                updateSnackbarMessage = "\(config.localizedName) \(overrideMessage)".trimmingCharacters(in: .whitespaces)
            } else if isTimeChanged {
                let snackbarMsg = DamStatusMessageFormatter(
                    settings: settings,
                    isJapanese: AppLocale.isJapanese
                ).snackbarMessage(data: parsed, damName: config.localizedName)
                updateSnackbarMessage = snackbarMsg
            }
            previousPercentTime = currentPercentTime
            settings.lastAutoUpdate = fetchTime
            settings.nextRequestedUpdate = nextRequestedUpdateAfterWidgetFetch(fetchTime: fetchTime)
            settingsRepository.save(settings)

            saveWidgetSnapshot(data: parsed, message: successMessages.widget)
            await sendNotificationIfNeeded(message: notificationMessage)
            addDebugLogIfAbsent(message: "\(logContext) succeeded.", details: buildSuccessDetails(damNameEn: config.nameEn, parsed: parsed), timestamp: fetchTime)
            isLoading = false
            isAutoUpdateRunning = false
            scheduleManualRefreshAvailabilityTimer()
        } catch {
            addDebugLog(message: "\(logContext) failed.", details: "Reason: \((error as NSError).description)")
            isLoading = false
            isAutoUpdateRunning = false
            scheduleManualRefreshAvailabilityTimer()
        }
    }

    /// 自動更新の定期実行スケジューラをセットアップします。
    private func scheduleAutoRefreshTimer() {
        autoUpdateScheduler.scheduleAutoRefresh(settings: settings) { [weak self] in
            guard let self, self.settings.autoUpdateEnabled else { return }
            if await self.importWidgetDataIfNewer() {
                return
            }
            let now = Date()
            guard now >= self.settings.nextRequestedUpdate else { return }
            self.saveWidgetSettingsBridge()

            let widgetFetchInterval = self.widgetDouble(forKey: WidgetDefaultsKey.widgetLastFetchAt)
            if widgetFetchInterval > 0, Date(timeIntervalSinceReferenceDate: widgetFetchInterval) >= self.settings.nextRequestedUpdate {
                await self.importWidgetDataIfNewer()
                return
            }
            await self.fetchLatest(workType: "Auto update (app)")
            await self.fetchSudmonitorHistoryAutoUpdate()
        }
    }

    /// 手動更新がブロック状態かどうかの監視判定タイマーをスケジュールします。
    private func scheduleManualRefreshAvailabilityTimer() {
        canManualRefresh = canRefresh()
        let cooldown: TimeInterval
        if let availableAt = effectiveManualRefreshAvailableAt(), let lastFetchTime {
            cooldown = max(0, availableAt.timeIntervalSince(lastFetchTime))
        } else {
            cooldown = Self.manualRefreshCooldown
        }
        autoUpdateScheduler.scheduleManualRefreshAvailability(
            canRefresh: canManualRefresh,
            lastFetchTime: lastFetchTime,
            cooldown: cooldown
        ) { [weak self] in
            guard let self else { return }
            self.canManualRefresh = self.canRefresh()
            self.scheduleManualRefreshAvailabilityTimer()
        }
    }

    /// sudmonitor 日次過去データの初回取得（対象ダムのレコード未保存時のみ）を実行します。
    ///
    /// 他の日次取得が実行中の場合は並行抑止のためスキップします。
    internal func fetchSudmonitorHistoryIfNeeded(workType: String) async {
        guard !isAnySudmonitorHistoryFetchRunning else { return }
        guard let context = modelContext else { return }
        let damId = settings.targetDamId
        guard sudmonitorHistoryService.record(damId: damId, context: context) == nil else { return }
        isSudmonitorHistoryInitialRunning = true
        defer { isSudmonitorHistoryInitialRunning = false }
        await performSudmonitorHistoryFetch(workType: workType, damId: damId, context: context)
    }

    /// ダム変更に伴う sudmonitor 日次過去データの自動再取得（常に実行・上書き）を実行します。
    ///
    /// 他の日次取得が実行中の場合は並行抑止のためスキップします。
    internal func fetchSudmonitorHistoryForDamChange() async {
        guard !isAnySudmonitorHistoryFetchRunning else { return }
        guard let context = modelContext else { return }
        isSudmonitorHistoryInitialRunning = true
        defer { isSudmonitorHistoryInitialRunning = false }
        await performSudmonitorHistoryFetch(workType: "Daily history dam change", damId: settings.targetDamId, context: context)
    }

    /// 自動更新スケジューラに連動した sudmonitor 日次過去データの自動取得を実行します。
    ///
    /// 他の日次取得が実行中の場合は並行抑止のためスキップします。
    /// 非Debug経路の `autoFetch` 結果が `.stored` のときもリビジョンを進めます。
    internal func fetchSudmonitorHistoryAutoUpdate() async {
        guard !isAnySudmonitorHistoryFetchRunning else { return }
        guard let context = modelContext else { return }
        isSudmonitorHistoryAutoUpdateRunning = true
        defer { isSudmonitorHistoryAutoUpdateRunning = false }
        if settings.debugModeEnabled {
            let outcome = await performSudmonitorHistoryFetchOutcome(damId: settings.targetDamId, context: context)
            logSudmonitorHistoryOutcome(outcome, workType: "Daily history auto update", damId: settings.targetDamId)
            return
        }
        let outcome = await sudmonitorHistoryService.autoFetch(
            interval: settings.autoUpdateInterval,
            damId: settings.targetDamId,
            context: context,
            historicalDataSource: settings.historicalDataSource
        )
        if case .stored = outcome {
            bumpSudmonitorHistoryRevision()
        }
        logSudmonitorHistoryOutcome(outcome, workType: "Daily history auto update", damId: settings.targetDamId)
    }

    /// sudmonitor 日次過去データの取得・保存を実行し、結果をデバッグログへ記録します。
    private func performSudmonitorHistoryFetch(workType: String, damId: String, context: ModelContext) async {
        let outcome = await performSudmonitorHistoryFetchOutcome(damId: damId, context: context)
        logSudmonitorHistoryOutcome(outcome, workType: workType, damId: damId)
    }

    /// sudmonitor 日次過去データの取得・保存を実行し、保存成功時は UI 反映用リビジョンを進めます。
    private func performSudmonitorHistoryFetchOutcome(damId: String, context: ModelContext) async -> SudmonitorHistoryFetchOutcome {
        let outcome = await sudmonitorHistoryFetchOutcome(damId: damId, context: context)
        if case .stored = outcome {
            bumpSudmonitorHistoryRevision()
        }
        return outcome
    }

    /// sudmonitor 日次過去データの取得・保存（またはデバッグDAT保存）を実行します。
    private func sudmonitorHistoryFetchOutcome(damId: String, context: ModelContext) async -> SudmonitorHistoryFetchOutcome {
        guard settings.debugModeEnabled else {
            return await sudmonitorHistoryService.fetchAndStore(
                damId: damId,
                context: context,
                historicalDataSource: settings.historicalDataSource
            )
        }
        switch settings.debugSimulateMode {
        case .networkUnavailable:
            return .failure(AppError.simulatedNetworkUnavailable)
        case .loadingFailure:
            return .failure(AppError.simulatedLoadingFailure)
        case .none:
            break
        }
        do {
            let file = try debugHistoricalDailyDatFile(damId: damId)
            return sudmonitorHistoryService.storeDebugDat(
                file.bytes,
                rawDatFileName: file.fileName,
                damId: damId,
                context: context
            )
        } catch {
            return .failure(error)
        }
    }

    private func debugHistoricalDailyDatFile(damId: String) throws -> DebugDataSessionDatFile {
        switch settings.debugHistoricalDailyDatSelectionMode {
        case .bundled:
            guard let url = Bundle.main.url(forResource: "historical_daily_sameura", withExtension: "dat", subdirectory: "Resources/debug")
                ?? Bundle.main.url(forResource: "historical_daily_sameura", withExtension: "dat") else {
                throw AppError.debugFileMissing
            }
            return DebugDataSessionDatFile(bytes: try Data(contentsOf: url), fileName: "historical_daily_sameura.dat")
        case .latest:
            guard let file = try debugDataSessionService?.backedUpHistoricalDailyDatFile(damId: damId) else {
                throw AppError.debugFileMissing
            }
            return file
        case .userSelected:
            let url = try debugDatURL(fileName: "debug-historical-daily.dat")
            guard FileManager.default.fileExists(atPath: url.path) else { throw AppError.debugFileMissing }
            return DebugDataSessionDatFile(bytes: try Data(contentsOf: url), fileName: settings.debugHistoricalDailyDatFileName)
        }
    }

    /// sudmonitor 日次過去データの取得結果をデバッグログへ記録します（失敗は握りつぶし、ログのみ）。
    private func logSudmonitorHistoryOutcome(_ outcome: SudmonitorHistoryFetchOutcome, workType: String, damId: String) {
        switch outcome {
        case .stored:
            addDebugLog(message: "\(workType) succeeded.", details: "Dam ID: \(damId)")
        case .skippedNotFound:
            addDebugLog(message: "\(workType) skipped.", details: "Daily history not found (Dam ID: \(damId))")
        case .skippedInvalidPeriod:
            addDebugLog(message: "\(workType) skipped.", details: "Daily history period headers missing (Dam ID: \(damId))")
        case .skippedByCooldown:
            addDebugLog(message: "\(workType) skipped.", details: "Next update not reached (Dam ID: \(damId))")
        case .gateDisabled:
            break
        case .failure(let error):
            addDebugLog(message: "\(workType) failed.", details: "Reason: \((error as NSError).description), Dam ID: \(damId)")
        }
    }


    /// デバッグ用に指定されたDATファイルの書き込み先ローカルパスURLを取得します。
    private func debugDatURL(fileName: String) throws -> URL {
        let baseURL = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = baseURL.appendingPathComponent("net.tecogonaz.TCSameuraDamMonitor", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        excludeFromBackup(dir)
        return dir.appendingPathComponent(fileName)
    }

    /// 指定されたパスURLを iCloud バックアップ対象から除外します。
    private nonisolated func excludeFromBackup(_ url: URL) {
        var resourceURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? resourceURL.setResourceValues(values)
    }

    /// デバッグモードの設定に応じたDATデータバイナリを取得（読み込み）します。
    private func debugRealtimeDatBytes(for settings: AppSettings) throws -> Data {
        switch settings.debugRealtimeDatSelectionMode {
        case .bundled:
            if let bundled = Bundle.main.url(
                forResource: "531368080700010202605241048683",
                withExtension: "dat",
                subdirectory: "Resources/debug"
            ) ?? Bundle.main.url(forResource: "531368080700010202605241048683", withExtension: "dat") {
                return try Data(contentsOf: bundled)
            }
            throw AppError.debugFileMissing
        case .latest:
            guard let raw = try debugDataSessionService?.backedUpRealtimeDatFile()?.bytes, !raw.isEmpty else {
                throw AppError.debugFileMissing
            }
            return raw
        case .userSelected:
            let url = try debugDatURL(fileName: "debug-realtime.dat")
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw AppError.debugFileMissing
            }
            return try Data(contentsOf: url)
        }
    }

    /// 自動進行デバッグ設定時に、次のデータ進行時間（1時間先等）を取得します。
    private func nextAutoAdvancedDebugDataEndDate(from data: Data, settings: AppSettings) -> Date? {
        guard settings.debugRealtimeDataPeriodAutoAdvanceEnabled,
              let currentEndDate = settings.debugRealtimeDataEndDate,
              let times = try? parser.realtimeDataTimes(data),
              let currentIndex = times.lastIndex(where: { $0 <= currentEndDate }),
              currentIndex + 1 < times.count else {
            return nil
        }
        return times[currentIndex + 1]
    }

    /// 文字列フィールドを CSV カンマエスケープ規則に従ってフォーマットします。
    private static func csvField(_ text: String) -> String {
        if text.contains(",") || text.contains("\"") || text.contains("\n") || text.contains("\r") {
            return "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return text
    }
}
