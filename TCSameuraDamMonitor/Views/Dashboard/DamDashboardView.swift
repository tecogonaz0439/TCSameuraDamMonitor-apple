// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// 早明浦ダムおよびその他のダムのリアルタイム観測データと過去データチャートを表示するダッシュボードビュー。
struct DamDashboardView: View {
    /// 状態とビジネスロジックを保持するアプリケーションモデル。
    let appModel: DamAppModel
    /// サマリー（概要）カードを非表示にするかどうかを示す真偽値フラグ。
    let hideSummaryCard: Bool
    /// スナックバーメッセージを表示するためのコールバック関数。
    let onSnackbar: (String) -> Void
    /// sudmonitor 日次過去データを日次モードで表示するかどうかを示す真偽値フラグ。
    var isSudmonitorHistory: Bool = false

    /// 過去データ範囲ピッカーシートが表示されているかどうかを決定するローカル状態。
    @State private var showHistoricalRangeSheet = false

    /// 現在の選択が過去データ検索ビューであるかどうかを示す真偽値プロパティ。
    private var isHistorical: Bool {
        appModel.selectedHistoricalMeta != nil
    }

    /// sudmonitor 日次過去データ表示モードが有効かどうか（ゲート有効かつ対象ダムのレコード読込済み）。
    private var isDailyMode: Bool {
        isSudmonitorHistory
            && appModel.isSudmonitorHistoryAvailable
    }

    /// リアルタイム観測のタイムラインを表す履歴データの行。
    private var realtimeRows: [DamHistoricalData] {
        appModel.damData?.historicalData ?? []
    }

    /// sudmonitor 日次過去データの観測行（昇順）。
    private var dailyHistoryRows: [DamHistoricalData] {
        appModel.sudmonitorHistoryRows
    }

    /// 観測データ（一覧）Card に表示する行。
    private var historyCardRows: [DamHistoricalData] {
        if isDailyMode { return appModel.visibleSudmonitorHistoryRows }
        return isHistorical ? appModel.visibleHistoricalRows : realtimeRows
    }

    /// 観測データ（グラフ）Card に表示する行。
    private var graphRows: [DamHistoricalData] {
        if isDailyMode { return appModel.visibleSudmonitorHistoryRows }
        return appModel.activeRowsForGraph
    }

    /// 日次モードのグラフ表示開始日（絞り込み中は絞り込み値、未指定は読込済み期間の開始日）。
    private var dailyRangeStartDate: String? {
        if appModel.isHistoricalDisplayRangeFiltered {
            return appModel.historicalDisplayStartDate
        }
        return appModel.sudmonitorHistoryRecord?.periodStartDay
    }

    /// 日次モードのグラフ表示終了日（絞り込み中は絞り込み値、未指定は読込済み期間の終了日）。
    private var dailyRangeEndDate: String? {
        if appModel.isHistoricalDisplayRangeFiltered {
            return appModel.historicalDisplayEndDate
        }
        return appModel.sudmonitorHistoryRecord?.periodEndDay
    }

    /// アクティブなダムの設定詳細。
    private var activeConfig: DamConfig? {
        if let meta = appModel.selectedHistoricalMeta {
            return DamListData.dam(id: meta.damConfigId)
        }
        return appModel.currentDamConfig
    }

    /// ダッシュボードのリセット状態を表す一意の識別子。
    private var dashboardResetID: String {
        "\(appModel.selectedDetail.hashValue)_\(appModel.settings.targetDamId)"
    }

    /// ダムダッシュボードビューのコンテンツとレイアウト。
    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    Color.clear.frame(height: 0).id("top")
                    if !isHistorical && !isDailyMode && !hideSummaryCard {
                        SummaryCard(appModel: appModel)
                    }
                    if isHistorical && !hideSummaryCard {
                        HistoricalSummaryCard(appModel: appModel)
                    }
                    if isDailyMode && !hideSummaryCard {
                        SudmonitorHistorySummaryCard(appModel: appModel)
                    }
                    ObservationInfoCard(
                        appModel: appModel,
                        isExpanded: expansionBinding(
                            for: isHistorical || isDailyMode ? .historicalObservation : .realtimeObservation
                        ),
                        expansionKey: isHistorical || isDailyMode ? .historicalObservation : .realtimeObservation
                    )
                    if !isHistorical && !isDailyMode {
                        LatestDataCard(
                            appModel: appModel,
                            isExpanded: expansionBinding(for: .realtimeLatest)
                        )
                    }
                    if !realtimeRows.isEmpty || (isHistorical && !appModel.visibleHistoricalRows.isEmpty) || (isDailyMode && !dailyHistoryRows.isEmpty) {
                        ObservationHistoryCard(
                            rows: historyCardRows,
                            meta: isDailyMode ? nil : appModel.selectedHistoricalMeta,
                            isHistorical: isHistorical || isDailyMode,
                            isExpanded: expansionBinding(
                                for: isHistorical || isDailyMode ? .historicalHistory : .realtimeHistory
                            ),
                            expansionKey: isHistorical || isDailyMode ? .historicalHistory : .realtimeHistory
                        )
                    }
                    if !graphRows.isEmpty {
                        ObservationGraphCard(
                            rows: graphRows,
                            meta: isDailyMode ? nil : appModel.selectedHistoricalMeta,
                            isHistorical: isHistorical || isDailyMode,
                            rangeStartDate: isDailyMode ? dailyRangeStartDate : appModel.historicalDisplayStartDate,
                            rangeEndDate: isDailyMode ? dailyRangeEndDate : appModel.historicalDisplayEndDate,
                            isExpanded: expansionBinding(
                                for: isHistorical || isDailyMode ? .historicalGraph : .realtimeGraph
                            ),
                            expansionKey: isHistorical || isDailyMode ? .historicalGraph : .realtimeGraph,
                            damConfig: activeConfig,
                            comparisonService: appModel.comparisonService,
                            dataRevision: appModel.graphDataRevision,
                            isSudmonitorDaily: isDailyMode,
                            dailyHistoryRows: dailyHistoryRows
                        )
                    }
                    SourceLinksCard(
                        damConfig: activeConfig,
                        lastFetchTime: appModel.lastFetchTime,
                        isExpanded: expansionBinding(
                            for: isHistorical || isDailyMode ? .historicalLinks : .realtimeLinks
                        ),
                        expansionKey: isHistorical || isDailyMode ? .historicalLinks : .realtimeLinks
                    )
                }
                .id(dashboardResetID)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .accessibilityIdentifier("dashboard.root")
            .onChange(of: dashboardResetID) { _, _ in
                withAnimation(.snappy) {
                    scrollProxy.scrollTo("top", anchor: .top)
                }
            }
        }
        .navigationTitle(navigationTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if isDailyMode {
                if appModel.isHistoricalDisplayRangeFiltered {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            appModel.resetHistoricalDisplayRange()
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                        .accessibilityLabel(AppText.historicalRangeResetIconDesc)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showHistoricalRangeSheet = true
                    } label: {
                        Image(systemName: "calendar")
                    }
                    .accessibilityLabel(AppText.historicalRangeIconButtonDesc)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onSnackbar(appModel.sudmonitorHistoryAutoUpdateUserMessage())
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .symbolEffect(.rotate, options: .repeat(.continuous), isActive: appModel.isSudmonitorHistoryAutoStyleRunning)
                            .foregroundStyle(appModel.settings.autoUpdateEnabled ? .primary : .secondary)
                    }
                    .accessibilityLabel(AppText.navAutoUpdate)
                    .accessibilityIdentifier("nav.autoUpdate")
                    .help(appModel.sudmonitorHistoryAutoUpdateUserMessage())
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            if let message = await appModel.performSudmonitorHistoryManualUpdate() {
                                onSnackbar(message)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .symbolEffect(.rotate, options: .repeat(.continuous), isActive: appModel.isSudmonitorHistoryManualRunning)
                            .foregroundStyle(appModel.sudmonitorHistoryManualUpdateBlockedMessage == nil ? .primary : .secondary)
                    }
                    .accessibilityLabel(AppText.navManualUpdate)
                    .accessibilityIdentifier("nav.manualUpdate")
                    .help(appModel.sudmonitorHistoryManualUpdateBlockedMessage ?? AppText.navManualUpdate)
                }
            }
            if isHistorical {
                ToolbarItem(placement: .primaryAction) {
                    if appModel.isHistoricalDisplayRangeFiltered {
                        Button {
                            appModel.resetHistoricalDisplayRange()
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                        .accessibilityLabel(AppText.historicalRangeResetIconDesc)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showHistoricalRangeSheet = true
                    } label: {
                        Image(systemName: "calendar")
                    }
                    .accessibilityLabel(AppText.historicalRangeIconButtonDesc)
                }
            }
            if !isHistorical && !isDailyMode {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onSnackbar(appModel.autoUpdateUserMessage())
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .symbolEffect(.rotate, options: .repeat(.continuous), isActive: appModel.isAutoUpdateRunning)
                            .foregroundStyle(appModel.settings.autoUpdateEnabled ? .primary : .secondary)
                    }
                    .accessibilityLabel(AppText.navAutoUpdate)
                    .accessibilityIdentifier("nav.autoUpdate")
                    .help(appModel.autoUpdateUserMessage())
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            if let message = await appModel.performManualUpdateFromUserAction() {
                                onSnackbar(message)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .symbolEffect(.rotate, options: .repeat(.continuous), isActive: appModel.isManualUpdateRunning)
                            .foregroundStyle(appModel.manualUpdateBlockedMessage == nil ? .primary : .secondary)
                    }
                    .accessibilityLabel(AppText.navManualUpdate)
                    .accessibilityIdentifier("nav.manualUpdate")
                    .help(appModel.manualUpdateBlockedMessage ?? AppText.navManualUpdate)
                }
            }
        }
        .sheet(isPresented: $showHistoricalRangeSheet) {
            if isDailyMode, let record = appModel.sudmonitorHistoryRecord {
                HistoricalRangeSheet(
                    appModel: appModel,
                    dailyPeriod: (record.periodStartDay, record.periodEndDay),
                    dailyDam: appModel.currentDamConfig
                )
            } else if let meta = appModel.selectedHistoricalMeta {
                HistoricalRangeSheet(appModel: appModel, meta: meta)
            }
        }
    }

    /// 過去データを表示しているか、リアルタイム観測データを表示しているかによって決定されるナビゲーションタイトル。
    private var navigationTitle: String {
        if isDailyMode {
            return AppText.titleSudmonitorHistory
        }
        if isHistorical {
            return AppText.titleHistoricalData()
        }
        return AppText.titleRealtimeData()
    }

    /// 永続化されたDashboard Card開閉状態を各Cardへ渡すBindingを生成する。
    private func expansionBinding(for key: DashboardCardExpansionKey) -> Binding<Bool> {
        Binding(
            get: { appModel.isDashboardCardExpanded(key) },
            set: { appModel.setDashboardCardExpanded(key, isExpanded: $0) }
        )
    }
}

/// 履歴データレコードを解析された Swift Date オブジェクトとバインドするラッパー構造体。
struct DatedHistoricalRow: Identifiable, Hashable, Sendable {
    /// 基盤となる生の履歴データレコード。
    let row: DamHistoricalData
    /// 解析された Date オブジェクト。
    let date: Date

    /// 基盤となる履歴レコードにマッピングされる一意の識別子。
    var id: String { row.id }
}

/// 履歴レコードの日付解析とソートを提供するユーティリティ名前空間。
///
/// `descending` は直近1件の結果をキャッシュする。ダッシュボードの各Cardは
/// サイドバー開閉などデータ変更なしの再評価でも全行の再ソート・日付解析を
/// 実行していたため、全行内容のfingerprintをキーに同一入力の再計算を回避する。
enum DashboardRowCache {
    /// `descending` の直近結果キャッシュ。
    private static var descendingCache: (key: DescendingCacheKey, rows: [DatedHistoricalRow])?

    /// `descending` キャッシュのキー。全行内容をHasherへ結合した値で同一性判定する。
    private struct DescendingCacheKey: Equatable {
        let idFingerprint: Int
    }

    /// 履歴レコードを時系列の昇順でマッピングおよびソートします。
    /// - Parameter rows: 生の履歴データ行。
    /// - Returns: 日付付き履歴レコードの昇順配列。
    static func ascending(_ rows: [DamHistoricalData]) -> [DatedHistoricalRow] {
        rows.map { DatedHistoricalRow(row: $0, date: DisplayFormatters.rowDate($0)) }
            .sorted { $0.date < $1.date }
    }

    /// 履歴レコードを時系列の降順でマッピングおよびソートします。
    ///
    /// 同一入力（全行内容のfingerprintが一致）への再呼び出しではキャッシュを返します。
    /// - Parameter rows: 生の履歴データ行。
    /// - Returns: 日付付き履歴レコードの降順配列。
    static func descending(_ rows: [DamHistoricalData]) -> [DatedHistoricalRow] {
        var hasher = Hasher()
        for row in rows {
            hasher.combine(row)
        }
        let key = DescendingCacheKey(idFingerprint: hasher.finalize())
        if let cache = descendingCache, cache.key == key {
            return cache.rows
        }
        let sorted = rows.map { DatedHistoricalRow(row: $0, date: DisplayFormatters.rowDate($0)) }
            .sorted { $0.date > $1.date }
        descendingCache = (key, sorted)
        return sorted
    }
}

/// ダムのリアルタイムステータスと貯水率の詳細を表示するサマリーカードビュー。
struct SummaryCard: View {
    /// 状態とビジネスロジックを保持するアプリケーションモデル。
    let appModel: DamAppModel

    /// データが存在しない場合の状態記号付きメッセージを返す。
    /// 読込中（initial / success）は虚偽のメッセージ表示を避けるためnilを返し、
    /// 確定した失敗状態（ネットワーク未接続 / 取得失敗）のみメッセージを返す。
    internal static func unavailableMessageText(settings: AppSettings, damLoadStatus: DamLoadStatus) -> String? {
        switch damLoadStatus {
        case .networkUnavailable:
            let text = settings.networkUnavailableText(isJapanese: AppLocale.isJapanese)
            return text.isEmpty ? nil : text
        case .loadingFailure:
            let text = settings.loadingErrorText(isJapanese: AppLocale.isJapanese)
            return text.isEmpty ? nil : text
        case .initial, .success:
            return nil
        }
    }

    /// サマリーカードのコンテンツとレイアウト。
    var body: some View {
        CardContainer {
            if let data = appModel.damData {
                VStack(alignment: .leading, spacing: 4) {
                    Text(DisplayFormatters.localizedDamName(appModel.currentDamConfig))
                        .macCardTitleFont()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("dashboard.summary.damName")
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text(DisplayFormatters.damDateTime(data.storagePercentageTime ?? data.updatedAt))
                            .macCardBodyFont()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .accessibilityIdentifier("dashboard.summary.dateTime")
                        Spacer(minLength: 0)
                        Text(
                            "\(DisplayFormatters.percent(data.storagePercentage)) \(DisplayFormatters.trendGlyph(data.storagePercentageTrend))"
                                .trimmingCharacters(in: .whitespaces)
                        )
                        .macCardBodyFont()
                        .foregroundStyle(
                            DisplayFormatters.usesTrendColor(data.storagePercentageTrend)
                                ? DisplayFormatters.trendColor(data.storagePercentageTrend)
                                : .primary
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityLabel(DisplayFormatters.percent(data.storagePercentage))
                        .accessibilityValue(DisplayFormatters.trendLabel(data.storagePercentageTrend))
                        .accessibilityIdentifier("dashboard.summary.percentage")
                    }
                    HStack {
                        Spacer(minLength: 0)
                        Text(
                            "\(AppText.summaryDayChange) \(DisplayFormatters.changePercent(data.storagePercentageDayChange)) \(DisplayFormatters.trendGlyph(data.storagePercentageDayChangeTrend))"
                                .trimmingCharacters(in: .whitespaces)
                        )
                            .macCardBodyFont()
                            .foregroundStyle(
                                DisplayFormatters.usesTrendColor(data.storagePercentageDayChangeTrend)
                                    ? DisplayFormatters.trendColor(data.storagePercentageDayChangeTrend)
                                    : .primary
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .accessibilityValue(DisplayFormatters.trendLabel(data.storagePercentageDayChangeTrend))
                            .accessibilityIdentifier("dashboard.summary.dayChange")
                    }
                    let statusText = DisplayFormatters.statusText(
                        settings: appModel.settings,
                        percentage: data.storagePercentage,
                        isAllDataInvalid: data.isAllObservationDataInvalid,
                        isSameura: data.observationStationId == AppSettings.defaultDamId,
                        storageVolumeForMessage: data.storageVolumeForMessage
                    )
                    if !statusText.isEmpty {
                        Text(statusText)
                            .macCardBodyFont()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityAddTraits(.updatesFrequently)
                            .accessibilityIdentifier("dashboard.summary.status")
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(DisplayFormatters.localizedDamName(appModel.currentDamConfig))
                        .macCardTitleFont()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("dashboard.summary.damName")
                    if let message = SummaryCard.unavailableMessageText(
                        settings: appModel.settings,
                        damLoadStatus: appModel.damLoadStatus
                    ) {
                        Text(message)
                            .macCardBodyFont()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityAddTraits(.updatesFrequently)
                            .accessibilityIdentifier("dashboard.summary.status")
                    }
                }
            }
        }
        .accessibilityIdentifier("dashboard.summaryCard")
    }
}

/// 過去データ検索設定の詳細を表示するサマリーカードビュー。
struct HistoricalSummaryCard: View {
    /// 状態とビジネスロジックを保持するアプリケーションモデル。
    let appModel: DamAppModel

    /// 関連付けられた過去データ検索クエリのメタデータ。
    private var meta: HistoricalSearchMeta? {
        appModel.selectedHistoricalMeta
    }

    /// 対象ダムのローカライズされた名前を解決します。
    private var damName: String {
        guard let meta, let config = DamListData.dam(id: meta.damConfigId) else {
            return meta?.damConfigId ?? ""
        }
        return DisplayFormatters.localizedDamName(config)
    }

    /// iOS / iPadOSの既存レイアウトを維持しつつ、macOSではリアルタイムサマリーと行間を揃える。
    private var rowSpacing: CGFloat {
        #if os(macOS)
        4
        #else
        10
        #endif
    }

    /// 過去データサマリーカードのコンテンツとレイアウト。
    var body: some View {
        CardContainer {
            if let meta {
                VStack(alignment: .leading, spacing: rowSpacing) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(damName)
                            .macCardTitleFont()
                    }
                    HStack(alignment: .center, spacing: 8) {
                        Spacer()
                        Text(DisplayFormatters.historicalPeriodLine(meta))
                            .macCardBodyFont()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    HStack(alignment: .center, spacing: 8) {
                        Spacer()
                        Text(DisplayFormatters.historicalRangeLine(meta))
                            .macCardBodyFont()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
            }
        }
        .accessibilityIdentifier("dashboard.historicalSummaryCard")
    }
}

/// sudmonitor 日次過去データの期間と貯水率推移を表示するサマリーカードビュー。
struct SudmonitorHistorySummaryCard: View {
    /// 状態とビジネスロジックを保持するアプリケーションモデル。
    let appModel: DamAppModel

    /// 対象ダムのローカライズされた名前を解決します。
    private var damName: String {
        guard let config = appModel.currentDamConfig else { return "" }
        return DisplayFormatters.localizedDamName(config)
    }

    /// iOS / iPadOSの既存レイアウトを維持しつつ、macOSではリアルタイムサマリーと行間を揃える。
    private var rowSpacing: CGFloat {
        #if os(macOS)
        4
        #else
        10
        #endif
    }

    /// sudmonitor 日次過去データサマリーカードのコンテンツとレイアウト。
    var body: some View {
        CardContainer {
            if let record = appModel.sudmonitorHistoryRecord {
                VStack(alignment: .leading, spacing: rowSpacing) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(damName)
                            .macCardTitleFont()
                    }
                    HStack(alignment: .center, spacing: 8) {
                        Spacer()
                        Text(DisplayFormatters.sudmonitorHistoryPeriodLine(record))
                            .macCardBodyFont()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    HStack(alignment: .center, spacing: 8) {
                        Spacer()
                        Text(DisplayFormatters.sudmonitorHistoryRangeLine(appModel.sudmonitorHistoryRows))
                            .macCardBodyFont()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
            }
        }
        .accessibilityIdentifier("dashboard.sudmonitorHistorySummaryCard")
    }
}

/// 選択されたダムの観測メタデータを表示するカード。
struct ObservationInfoCard: View {
    /// 状態とビジネスロジックを保持するアプリケーションモデル。
    let appModel: DamAppModel
    /// 詳細セクションの永続化された開閉状態。
    @Binding var isExpanded: Bool
    /// 表示モードを含むCard開閉キー。
    let expansionKey: DashboardCardExpansionKey

    /// 関連付けられた過去データ検索クエリのメタデータ。
    private var meta: HistoricalSearchMeta? { appModel.selectedHistoricalMeta }
    /// 選択されたダムの設定。
    private var config: DamConfig? {
        if let meta {
            return DamListData.dam(id: meta.damConfigId)
        }
        return appModel.currentDamConfig
    }

    /// 観測情報カードのコンテンツとレイアウト。
    var body: some View {
        CollapsibleCard(
            title: AppText.mainObservationData,
            isExpanded: $isExpanded,
            toggleIdentifier: expansionKey.toggleIdentifier,
            cardIdentifier: "dashboard.observationInfoCard"
        ) {
            VStack(spacing: 0) {
                InfoRow(label: AppText.mainStationID, value: meta?.observationStationId ?? appModel.damData?.observationStationId ?? "--")
                InfoRow(label: AppText.mainStationName, value: DisplayFormatters.localizedDamName(config))
                InfoRow(label: AppText.mainRiverSystem, value: localizedWaterSystem)
                InfoRow(label: AppText.mainRiverName, value: localizedRiver)
                if let geo = config?.geoUrl, !geo.isEmpty {
                    GeoLinkRow(label: AppText.mainGeo, title: geo, url: geo)
                }
            }
        }
    }

    /// ダムのローカライズされた水系名。
    private var localizedWaterSystem: String {
        guard let config else { return meta?.riverSystemName ?? appModel.damData?.riverSystemName ?? "--" }
        return AppText.isJapanese ? config.waterSystem.ifEmpty("--") : config.waterSystemEn.ifEmpty("--")
    }

    /// ダムのローカライズされた河川名。
    private var localizedRiver: String {
        guard let config else { return meta?.riverName ?? appModel.damData?.riverName ?? "--" }
        return AppText.isJapanese ? config.river.ifEmpty("--") : config.riverEn.ifEmpty("--")
    }
}

/// 最新のリアルタイム観測データを表示するカードビュー。
struct LatestDataCard: View {
    /// 状態とビジネスロジックを保持するアプリケーションモデル。
    let appModel: DamAppModel
    /// 詳細セクションの永続化された開閉状態。
    @Binding var isExpanded: Bool

    /// 最新データカードのコンテンツとレイアウト。
    var body: some View {
        CollapsibleCard(
            title: AppText.mainLatestData,
            isExpanded: $isExpanded,
            toggleIdentifier: DashboardCardExpansionKey.realtimeLatest.toggleIdentifier,
            cardIdentifier: "dashboard.latestDataCard"
        ) {
            VStack(spacing: 0) {
                if let data = appModel.damData {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(AppText.mainDataFetchTime): \(DisplayFormatters.dateTime(appModel.displayedRealtimeFetchTime))")
                        Text("\(AppText.mainDataUpdateTime): \(DisplayFormatters.damDateTime(data.updatedAt))")
                        if data.storagePercentageTime != nil {
                            Text("\(AppText.mainPercentageTime): \(DisplayFormatters.damDateTime(data.storagePercentageTime))")
                        }
                    }
                    .macCardCaptionFont()
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 12)
                }

                DataRow(label: AppText.mainRainfall, value: DisplayFormatters.rainfall(appModel.damData?.catchmentAverageRainfall), trend: .unknown, isMissing: appModel.damData?.catchmentAverageRainfall == nil)
                DataRow(label: AppText.mainStorageVolume, value: DisplayFormatters.value(appModel.damData?.storageVolume), trend: appModel.damData?.storageVolumeTrend ?? .unknown, isMissing: appModel.damData?.storageVolume == nil)
                DataRow(label: AppText.mainInflow, value: DisplayFormatters.value(appModel.damData?.inflow, decimals: 2), trend: .unknown, isMissing: appModel.damData?.inflow == nil)
                DataRow(label: AppText.mainOutflow, value: DisplayFormatters.value(appModel.damData?.outflow, decimals: 2), trend: .unknown, isMissing: appModel.damData?.outflow == nil)
                DataRow(label: AppText.mainStoragePercentage, value: DisplayFormatters.percentValue(appModel.damData?.storagePercentage), trend: appModel.damData?.storagePercentageTrend ?? .unknown, isMissing: appModel.damData?.storagePercentage == nil)
                DataRow(label: AppText.mainDayChange, value: DisplayFormatters.change(appModel.damData?.storagePercentageDayChange), trend: appModel.damData?.storagePercentageDayChangeTrend ?? .unknown, isMissing: appModel.damData?.storagePercentageDayChange == nil)
                DataRow(label: AppText.mainWeekChange, value: DisplayFormatters.change(appModel.damData?.storagePercentageWeekChange), trend: appModel.damData?.storagePercentageWeekChangeTrend ?? .unknown, isMissing: appModel.damData?.storagePercentageWeekChange == nil)
            }
        }
    }
}
