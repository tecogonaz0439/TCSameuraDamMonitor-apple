// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// 自動更新のタイマー処理および手動更新制限時間（クールダウン）解除のタイマー処理を管理するスケジューラクラス。
@MainActor
internal final class AutoUpdateScheduler {
    /// 自動更新判定用の定期実行タイマー。
    private var autoRefreshTimer: Timer?
    /// 手動更新許可の切り替え判定用のワンショットタイマー。
    private var manualRefreshAvailabilityTimer: Timer?

    /// 自動更新の定期実行判定タイマーをスケジュールします（1分周期で発火）。
    /// - Parameters:
    ///   - settings: アプリ設定。
    ///   - onDue: 実行時間が到来した際に呼び出される処理。
    internal func scheduleAutoRefresh(settings: AppSettings, onDue: @escaping @MainActor () async -> Void) {
        autoRefreshTimer?.invalidate()
        guard settings.autoUpdateEnabled else {
            return
        }
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                await onDue()
            }
        }
    }

    /// 手動更新が許可されるタイミングまで待機するタイマーをスケジュールします。
    /// - Parameters:
    ///   - canRefresh: 現在手動更新が可能であるかどうかのフラグ。
    ///   - lastFetchTime: 最後に手動更新または自動更新を行った日時。
    ///   - cooldown: 更新可能になるまでのクールダウン時間間隔。
    ///   - onAvailabilityChanged: クールダウン時間が経過して更新可能になった際に呼び出される処理。
    internal func scheduleManualRefreshAvailability(
        canRefresh: Bool,
        lastFetchTime: Date?,
        cooldown: TimeInterval,
        onAvailabilityChanged: @escaping @MainActor () -> Void
    ) {
        manualRefreshAvailabilityTimer?.invalidate()
        guard !canRefresh,
              let lastFetchTime,
              let next = Calendar.jst.date(byAdding: .second, value: Int(cooldown), to: lastFetchTime) else {
            return
        }
        let delay = max(0, next.timeIntervalSinceNow)
        manualRefreshAvailabilityTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            Task { @MainActor in
                onAvailabilityChanged()
            }
        }
    }
}

