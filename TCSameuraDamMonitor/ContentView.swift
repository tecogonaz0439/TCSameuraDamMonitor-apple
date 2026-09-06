// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import SwiftData
import SwiftUI

#if os(macOS)
enum MacLayout {
    static let sidebarMaxWidth: CGFloat = 350
    static let detailContentPadding: CGFloat = 100
    static let minWindowWidth: CGFloat = sidebarMaxWidth * 2 + detailContentPadding
    static let minWindowHeight: CGFloat = sidebarMaxWidth
}
#endif

/// 早明浦ダムモニター（Sameura Dam Monitor）アプリケーションのルートビュー。レイアウト表示（コンパクト画面 vs 分割画面）およびアプリ状態の監視を管理します。
struct ContentView: View {
    /// SwiftData のモデルコンテキスト。
    @Environment(\.modelContext) private var modelContext
    /// 環境の水平サイズクラス。
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// シーンの現在のフェーズ。
    @Environment(\.scenePhase) private var scenePhase
    /// アプリケーションデータモデル。
    let appModel: DamAppModel
    /// ナビゲーションスプリットビュー列の表示状態。
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    /// デバッグルーティング用のナビゲーションパス。
    @State private var debugPath: [DebugRoute] = []
    /// アプリ情報ルーティング用のナビゲーションパス。
    @State private var appInfoPath: [AppInfoRoute] = []
    /// ダッシュボード詳細画面内のナビゲーションパス。
    @State private var dashboardPath: [DashboardRoute] = []
    /// 現在スナックバーに表示されているメッセージ。
    @State private var snackbarMessage: String?

    /// メインビューのコンテンツとレイアウト。
    var body: some View {
        @Bindable var model = appModel
        Group {
            if horizontalSizeClass == .compact {
                CompactRootView(appModel: appModel, onSnackbar: showSnackbar)
            } else {
                splitRoot
            }
        }
        .accessibilityIdentifier("app.root")
        .snackbarMessage($snackbarMessage)
        .task {
            appModel.isSceneActive = (scenePhase != .background)
            appModel.configure(modelContext: modelContext, launchContext: appConfigureLaunchContext)
        }
        .sheet(isPresented: $model.showHistoricalSearch) {
            HistoricalSearchView(appModel: appModel)
        }
        .alert(AppText.dialogInitialAutoUpdateTitle, isPresented: $model.showInitialAutoUpdateDialog) {
            Button(AppText.actionYes) {
                model.enableAutoUpdateFromInitialDialog()
                model.markInitialAutoUpdateDialogShown()
            }
            Button(AppText.actionNo) {
                model.markInitialAutoUpdateDialogShown()
            }
        } message: {
            Text(AppText.dialogInitialAutoUpdateMessage)
        }
        .task(id: model.showInitialNotificationPermissionRequest) {
            if model.showInitialNotificationPermissionRequest {
                await model.requestInitialNotificationPermission()
            }
        }
        .onChange(of: appModel.errorMessage) { _, newValue in
            if let message = newValue {
                showSnackbar(message)
            }
        }
        .onChange(of: appModel.updateSnackbarMessage) { _, newValue in
            if let message = newValue {
                showSnackbar(message)
                appModel.updateSnackbarMessage = nil
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            appModel.isSceneActive = (newValue != .background)
        }
        .onChange(of: appModel.selectedDetail) { oldValue, newValue in
            if DashboardNavigation.shouldResetPath(oldSelection: oldValue, newSelection: newValue) {
                dashboardPath.removeAll()
            }
            if newValue != .debug, newValue != .debugLog {
                debugPath.removeAll()
            }
            if newValue != .appInfo {
                appInfoPath.removeAll()
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            if newValue == .active {
                appModel.completeForegroundStartupIfNeeded(reason: "sceneActive")
                AppLaunchContextStore.markForegroundActive()
            }
        }
        .preferredColorScheme(colorScheme)
    }

    /// `NavigationSplitView` を使用した、非コンパクト幅の画面用のルートビュー。
    private var splitRoot: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(appModel: appModel, selection: detailSelection, onSnackbar: showSnackbar)
                .navigationTitle(AppText.appName)
                 #if os(macOS)
                 .navigationSplitViewColumnWidth(min: 260, ideal: 280, max: MacLayout.sidebarMaxWidth)
                 #endif
        } detail: {
            DetailRouterView(
                appModel: appModel,
                hideSummaryCard: isShowingSidebarAndDetail,
                dashboardPath: $dashboardPath,
                debugPath: $debugPath,
                appInfoPath: $appInfoPath,
                onSnackbar: showSnackbar
            )
        }
        #if os(macOS)
        .navigationSplitViewStyle(.balanced)
        #endif
    }

    /// 選択された詳細ビューの同期を管理する、計算されたバインディング。
    private var detailSelection: Binding<DamAppModel.DetailSelection?> {
        Binding(
            get: { appModel.selectedDetail },
            set: { selection in
                guard let selection else { return }
                selectDetail(selection)
            }
        )
    }

    /// 詳細の選択を処理し、選択状態を更新し、指定されたビューに遷移します。
    /// - Parameter selection: 遷移先詳細の選択状態。
    private func selectDetail(_ selection: DamAppModel.DetailSelection) {
        if selection != .debug, selection != .debugLog {
            debugPath.removeAll()
        }
        if selection != .appInfo {
            appInfoPath.removeAll()
        }
        dashboardPath.removeAll()
        switch selection {
        case .realtime:
            appModel.selectedHistoricalMeta = nil
            appModel.historicalRows = []
            appModel.selectedDetail = .realtime
            appModel.bumpGraphDataRevision()
        case let .historical(metaId):
            Task { await appModel.openHistorical(metaId: metaId) }
        case .sudmonitorHistory:
            appModel.selectedHistoricalMeta = nil
            appModel.historicalRows = []
            appModel.resetHistoricalDisplayRange()
            appModel.selectedDetail = .sudmonitorHistory
            appModel.bumpGraphDataRevision()
        case .settings:
            appModel.selectedDetail = .settings
        case .historicalManage, .debug, .debugLog, .appInfo:
            appModel.selectedDetail = selection
        }
    }

    /// サイドバーと詳細ビューの両方が表示されているかどうかを示すブール値。
    private var isShowingSidebarAndDetail: Bool {
        guard horizontalSizeClass != .compact else { return false }
        return columnVisibility != .detailOnly
    }

    /// ユーザーが優先するカラースキーム（ライト、ダーク、またはシステムデフォルト）。
    private var colorScheme: ColorScheme? {
        switch appModel.settings.theme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// アプリ起動時の構成設定中に必要となるコンテキスト。
    private var appConfigureLaunchContext: AppConfigureLaunchContext {
        AppLaunchContextStore.launchContext(
            sceneIsBackground: scenePhase == .background,
            sceneIsActive: scenePhase == .active
        )
    }

    /// スナックバーメッセージの表示をトリガーします。
    /// - Parameter message: 表示するメッセージテキスト。
    private func showSnackbar(_ message: String) {
        snackbarMessage = message
    }
}

/// コンパクト幅の画面（iPhoneなど）で使用されるナビゲーションルート。
enum CompactNavigationRoute: Hashable {
    /// コンパクトメニューパス。
    case menu
    /// 履歴データ管理パス。
    case historicalManage
    /// 設定パス。
    case settings
    /// デバッグ設定パス。
    case debug
    /// アプリ情報パス。
    case appInfo
}

/// コンパクト幅の画面で使用されるルートビュー。カスタムナビゲーションパスとメニューを提供します。
private struct CompactRootView: View {
    /// アプリケーションデータモデル。
    let appModel: DamAppModel
    /// スナックバーメッセージを表示するために呼び出されるアクションクロージャ。
    let onSnackbar: (String) -> Void
    /// コンパクト画面のビュー遷移用のナビゲーションパス制御。
    @State private var path = NavigationPath()

    /// コンパクトルートビューのコンテンツとレイアウト。
    var body: some View {
        NavigationStack(path: $path) {
            DamDashboardView(
                appModel: appModel,
                hideSummaryCard: false,
                onSnackbar: onSnackbar,
                isSudmonitorHistory: appModel.selectedDetail == .sudmonitorHistory
            )
                .toolbar {
                    ToolbarItem(placement: compactMenuToolbarPlacement) {
                        Button {
                            path.append(CompactNavigationRoute.menu)
                        } label: {
                            Label(AppText.appName, systemImage: "line.3.horizontal")
                        }
                        .accessibilityLabel(AppText.appName)
                        .accessibilityIdentifier("nav.menu")
                    }
                }
                .navigationDestination(for: CompactNavigationRoute.self) { route in
                    switch route {
                    case .menu:
                        CompactMenuView(appModel: appModel, path: $path, onSnackbar: onSnackbar)
                    case .historicalManage:
                        HistoricalManageView(appModel: appModel, onSnackbar: onSnackbar)
                    case .settings:
                        SettingsView(appModel: appModel)
                    case .debug:
                        DebugView(appModel: appModel) {
                            resetPath()
                        }
                    case .appInfo:
                        AppInfoView(appModel: appModel, onSnackbar: onSnackbar)
                    }
                }
                .navigationDestination(for: DashboardRoute.self) { route in
                    switch route {
                    case .fullHistory:
                        ObservationHistoryFullView(
                            rows: fullHistoryRows,
                            isHistorical: appModel.selectedDetail == .sudmonitorHistory || appModel.selectedHistoricalMeta != nil
                        )
                    }
                }
                .navigationDestination(for: DebugRoute.self) { route in
                    switch route {
                    case .debugLog:
                        DebugLogView(appModel: appModel)
                    }
                }
                .navigationDestination(for: AppInfoRoute.self) { route in
                    AppInfoDetailView(route: route)
                }
        }
        .onChange(of: appModel.selectedDetail) { _, selection in
            switch selection {
            case .realtime, .historical, .sudmonitorHistory:
                resetPath()
            case .historicalManage:
                setPath(to: .historicalManage)
            case .settings:
                setPath(to: .settings)
            case .debug, .debugLog:
                setPath(to: .debug)
            case .appInfo:
                setPath(to: .appInfo)
            }
        }
    }

    /// コンパクトナビゲーションパスを単一のルート遷移先に設定します。
    /// - Parameter route: 遷移先のナビゲーションルート。
    private func setPath(to route: CompactNavigationRoute) {
        var newPath = NavigationPath()
        newPath.append(route)
        path = newPath
    }

    /// 現在のコンパクトナビゲーションスタックをクリアします。
    private func resetPath() {
        path = NavigationPath()
    }

    /// OS に応じて、コンパクトメニューボタンの最適なツールバーアイテムの配置を決定します。
    private var compactMenuToolbarPlacement: ToolbarItemPlacement {
        #if os(macOS)
        .automatic
        #else
        .topBarLeading
        #endif
    }

    /// 観測データ一覧に表示する現在選択中の行。
    private var fullHistoryRows: [DamHistoricalData] {
        if appModel.selectedDetail == .sudmonitorHistory {
            return appModel.visibleSudmonitorHistoryRows
        }
        if appModel.selectedHistoricalMeta != nil {
            return appModel.visibleHistoricalRows
        }
        return appModel.damData?.historicalData ?? []
    }
}

/// コンパクトデバイスで特に使用されるメニュービュー。リアルタイム観測データ、履歴データ、設定、アプリ情報のセクションを表示します。
private struct CompactMenuView: View {
    /// アプリケーションデータモデル。
    let appModel: DamAppModel
    /// 親スタックのナビゲーションパスへのバインディング。
    @Binding var path: NavigationPath
    /// スナックバーメッセージを表示するために呼び出されるアクションクロージャ。
    let onSnackbar: (String) -> Void

    /// コンパクトメニューリストのコンテンツとレイアウト。
    var body: some View {
        List {
            Section(AppText.navRealtimeData) {
                Button {
                    appModel.selectedHistoricalMeta = nil
                    appModel.historicalRows = []
                    appModel.selectedDetail = .realtime
                    appModel.bumpGraphDataRevision()
                    resetPath()
                } label: {
                    SidebarRealtimeLabel(
                        data: appModel.damData,
                        damConfig: appModel.currentDamConfig,
                        settings: appModel.settings,
                        damLoadStatus: appModel.damLoadStatus
                    )
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AppText.navRealtimeData)
                .accessibilityIdentifier("nav.realtime")
            }

            if appModel.isSudmonitorHistoryAvailable {
                Section(AppText.navSudmonitorHistory) {
                    Button {
                        appModel.selectedHistoricalMeta = nil
                        appModel.historicalRows = []
                        appModel.resetHistoricalDisplayRange()
                        appModel.selectedDetail = .sudmonitorHistory
                        appModel.bumpGraphDataRevision()
                        resetPath()
                    } label: {
                        SidebarSudmonitorHistoryLabel(appModel: appModel)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(AppText.navSudmonitorHistory)
                    .accessibilityIdentifier("nav.sudmonitorHistory")
                }
            }

            Section(AppText.navHistoricalData) {
                ForEach(appModel.navigationMetaList) { meta in
                    Button {
                        Task {
                            await appModel.openHistorical(metaId: meta.id)
                            resetPath()
                        }
                    } label: {
                        SidebarHistoricalLabel(meta: meta)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("nav.historicalSaved")
                }

                Button {
                    resetPath()
                    if appModel.historicalMetaList.count >= DamAppModel.maxHistoricalSearchCount {
                        onSnackbar(AppText.historicalSearchMaxCountSnackbar(DamAppModel.maxHistoricalSearchCount))
                    } else {
                        appModel.showHistoricalSearch = true
                    }
                } label: {
                    Label(AppText.navHistoricalSearch, systemImage: "magnifyingglass")
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(AppText.navHistoricalSearch)
                .accessibilityIdentifier("nav.historicalSearch")
                .buttonStyle(.plain)

                Button {
                    appModel.selectedDetail = .historicalManage
                    setPath(to: .historicalManage)
                } label: {
                    Label(AppText.navHistoricalManage, systemImage: "list.bullet.rectangle")
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(AppText.navHistoricalManage)
                .accessibilityIdentifier("nav.historicalManage")
                .buttonStyle(.plain)
            }

            Section(AppText.navSource) {
                SourceLinkButton(
                    urlString: "https://www1.river.go.jp/",
                    label: AppText.navSourceDB,
                    systemImage: "link"
                )
                SourceLinkButton(
                    urlString: "https://www1.river.go.jp/WDBrules_20251210.pdf",
                    label: AppText.navSourcePDL,
                    systemImage: "doc.text"
                )
                Text(AppText.navSourceCredit(DisplayFormatters.date(appModel.lastFetchTime)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                if appModel.settings.debugSettingsVisible {
                    Button {
                        appModel.selectedDetail = .debug
                        setPath(to: .debug)
                    } label: {
                        Label(AppText.navDebug, systemImage: "wrench.and.screwdriver")
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(AppText.navDebug)
                    .accessibilityIdentifier("nav.debug")
                    .buttonStyle(.plain)
                }

                Button {
                    appModel.selectedDetail = .settings
                    setPath(to: .settings)
                } label: {
                    Label(AppText.navSettings, systemImage: "gearshape")
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(AppText.navSettings)
                .accessibilityIdentifier("nav.settings")
                .buttonStyle(.plain)

                Button {
                    appModel.selectedDetail = .appInfo
                    setPath(to: .appInfo)
                } label: {
                    Label(AppText.navAppInfo, systemImage: "info.circle")
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(AppText.navAppInfo)
                .accessibilityIdentifier("nav.appInfo")
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(AppText.appName)
        .accessibilityIdentifier("nav.menu.list")
    }

    /// コンパクトナビゲーションパスを単一のルート遷移先に設定します。
    /// - Parameter route: 遷移先のナビゲーションルート。
    private func setPath(to route: CompactNavigationRoute) {
        var newPath = NavigationPath()
        newPath.append(route)
        path = newPath
    }

    /// 現在のコンパクトナビゲーションスタックをクリアします。
    private func resetPath() {
        path = NavigationPath()
    }
}
