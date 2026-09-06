// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// ダッシュボード画面内でのナビゲーション用ルート定義。
enum DashboardRoute: Hashable {
    /// 観測データ一覧画面。
    case fullHistory
}

/// ダッシュボード画面内のナビゲーション状態を扱うユーティリティ。
enum DashboardNavigation {
    /// 詳細画面の選択変更時に、ダッシュボード内のナビゲーションパスをリセットするかを返します。
    /// - Parameters:
    ///   - oldSelection: 変更前の詳細選択。
    ///   - newSelection: 変更後の詳細選択。
    /// - Returns: パスをリセットすべき場合は `true`。
    static func shouldResetPath(
        oldSelection: DamAppModel.DetailSelection,
        newSelection: DamAppModel.DetailSelection
    ) -> Bool {
        oldSelection != newSelection
    }
}

/// デバッグ画面内でのナビゲーション用ルート定義。
enum DebugRoute: Hashable {
    /// デバッグログ詳細画面。
    case debugLog
}

/// アプリ情報画面内でのナビゲーション用ルート定義。
enum AppInfoRoute: Hashable {
    /// 利用規約画面（英語）。
    case termsOfUse
    /// 利用規約画面（日本語）。
    case termsOfUseJa
    /// プライバシーポリシー画面（英語）。
    case privacyPolicy
    /// プライバシーポリシー画面（日本語）。
    case privacyPolicyJa
    /// ライセンス画面。
    case license
    /// オープンソースソフトウェア（OSS）ライセンス画面。
    case ossLicense
}

/// 選択されたメニュー項目に基づいて詳細画面のナビゲーションを処理するルータービュー。
struct DetailRouterView: View {
    /// 状態とビジネスロジックを保持するアプリケーションモデル。
    let appModel: DamAppModel
    /// ダッシュボードの概要カードを非表示にするかどうかを示す真偽値。
    let hideSummaryCard: Bool
    /// ダッシュボード詳細画面用のナビゲーションパス。
    @Binding var dashboardPath: [DashboardRoute]
    /// デバッグ画面用のナビゲーションパス。
    @Binding var debugPath: [DebugRoute]
    /// アプリ情報画面用のナビゲーションパス。
    @Binding var appInfoPath: [AppInfoRoute]
    /// スナックバーメッセージを表示するためのコールバック関数。
    let onSnackbar: (String) -> Void

    /// 詳細ルータービューのコンテンツとレイアウト。
    var body: some View {
        switch appModel.selectedDetail {
        case .realtime, .historical, .sudmonitorHistory:
            NavigationStack(path: $dashboardPath) {
                DamDashboardView(
                    appModel: appModel,
                    hideSummaryCard: hideSummaryCard,
                    onSnackbar: onSnackbar,
                    isSudmonitorHistory: appModel.selectedDetail == .sudmonitorHistory
                )
                .navigationDestination(for: DashboardRoute.self) { route in
                    switch route {
                    case .fullHistory:
                        ObservationHistoryFullView(rows: fullHistoryRows, isHistorical: fullHistoryIsHistorical)
                    }
                }
            }
        case .settings:
            NavigationStack {
                SettingsView(appModel: appModel)
            }
        case .debug:
            NavigationStack(path: $debugPath) {
                DebugView(appModel: appModel) {
                    appModel.selectedDetail = .realtime
                }
                .navigationDestination(for: DebugRoute.self) { route in
                    switch route {
                    case .debugLog:
                        DebugLogView(appModel: appModel)
                    }
                }
            }
        case .historicalManage:
            NavigationStack {
                HistoricalManageView(appModel: appModel, onSnackbar: onSnackbar)
            }
        case .debugLog:
            NavigationStack {
                DebugLogView(appModel: appModel)
            }
        case .appInfo:
            NavigationStack(path: $appInfoPath) {
                AppInfoView(appModel: appModel, onSnackbar: onSnackbar)
                    .navigationDestination(for: AppInfoRoute.self) { route in
                        AppInfoDetailView(route: route)
                    }
            }
        }
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

    /// 観測データ一覧を履歴（新しい順）表示として扱うかどうかを示す真偽値。
    private var fullHistoryIsHistorical: Bool {
        appModel.selectedDetail == .sudmonitorHistory || appModel.selectedHistoricalMeta != nil
    }
}
