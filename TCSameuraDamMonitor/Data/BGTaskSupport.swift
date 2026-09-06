// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// アプリがフォアグラウンドまたはバックグラウンドのどちらで起動されたかのコンテキスト状態を表す列挙型。
internal enum AppConfigureLaunchContext: String, Equatable, Sendable {
    /// フォアグラウンド起動。
    case foreground
    /// バックグラウンド起動。
    case background

    /// フォアグラウンドでの起動時初期化処理を実行可能かどうかを示すフラグ。
    internal var allowsForegroundStartup: Bool {
        self == .foreground
    }
}

/// アプリの初期起動コンテキストを管理および格納するメインスレッド制約のストア。
@MainActor
internal enum AppLaunchContextStore {
    /// 初期起動時のコンテキスト。デフォルトはフォアグラウンドです。
    internal private(set) static var initialLaunchContext: AppConfigureLaunchContext = .foreground

    /// 現在のシーン（ウィンドウ等）のライフサイクル状態から、適切な起動コンテキストを判定します。
    /// - Parameters:
    ///   - sceneIsBackground: シーンがバックグラウンドにあるかどうか。
    ///   - sceneIsActive: シーンがアクティブ（フォアグラウンドでアクティブ）であるかどうか。
    /// - Returns: 判定された `AppConfigureLaunchContext`。
    internal static func launchContext(sceneIsBackground: Bool, sceneIsActive: Bool) -> AppConfigureLaunchContext {
        if sceneIsBackground {
            return .background
        }
        if sceneIsActive {
            return .foreground
        }
        if initialLaunchContext == .background {
            return .background
        }
        return .foreground
    }

    /// 起動コンテキストをフォアグラウンドにリセット（マーク）します。
    internal static func markForegroundActive() {
        initialLaunchContext = .foreground
    }
}

/// アプリがフォアグラウンドに戻った際に、実行し損ねた自動更新をどのように復旧（リカバリ）するかを表すアクション列挙型。
internal enum ForegroundAutoUpdateRecoveryAction: Equatable, Sendable {
    /// リカバリは不要。
    case none
    /// ウィジェットで既に新データが取得されているため、ウィジェットのデータをインポート（同期）する。
    case importWidget
    /// 最新データを即座にフェッチする。
    case fetchLatest
}

/// 自動更新の予定時刻が過ぎていた（タスクの実行漏れが発生した）場合のポリシーを決定するユーティリティ。
internal enum AutoUpdateMissedDuePolicy {
    /// 自動更新予定日時が現在より過去にあり、実行漏れが発生している場合にその予定日時を返します。
    /// - Parameters:
    ///   - settings: アプリ設定。
    ///   - now: 現在の日時。
    /// - Returns: 実行漏れの予定日時。該当しない場合は `nil`。
    internal static func missedDueDate(settings: AppSettings, now: Date) -> Date? {
        guard settings.autoUpdateEnabled, settings.nextRequestedUpdate <= now else {
            return nil
        }
        return settings.nextRequestedUpdate
    }

    /// 実行漏れ発生の状況から、フォアグラウンド復帰時に実行すべきリカバリアクションを決定します。
    /// - Parameters:
    ///   - autoUpdateEnabled: 自動更新が有効かどうか。
    ///   - dueAt: 実行漏れした予定日時。
    ///   - now: 現在の日時。
    ///   - startupUpdateScheduled: 起動時更新タスクが既にスケジュールされているかどうか。
    ///   - widgetLastFetchAt: ウィジェットが最後にデータをフェッチした日時。
    /// - Returns: 推奨される `ForegroundAutoUpdateRecoveryAction`。
    internal static func recoveryAction(
        autoUpdateEnabled: Bool,
        dueAt: Date?,
        now: Date,
        startupUpdateScheduled: Bool,
        widgetLastFetchAt: Date?
    ) -> ForegroundAutoUpdateRecoveryAction {
        guard autoUpdateEnabled,
              let dueAt,
              dueAt <= now,
              !startupUpdateScheduled else {
            return .none
        }
        if let widgetLastFetchAt, widgetLastFetchAt >= dueAt {
            return .importWidget
        }
        return .fetchLatest
    }
}

