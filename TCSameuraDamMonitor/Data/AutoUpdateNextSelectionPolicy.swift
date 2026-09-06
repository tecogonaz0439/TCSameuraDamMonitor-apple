// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// 自動更新の次回実行予定日時の選択ポリシーを定義するユーティリティ。
internal enum AutoUpdateNextSelectionPolicy: Sendable {
    /// 自動更新の最小時間間隔（15分）。
    internal static let minIntervalMinutes = 15

    /// 現在時刻から許容される最小の次回実行日時を返します。
    /// - Parameter now: 現在の日時。
    /// - Returns: 許容される最小の実行日時。
    internal static func minimumValidDate(now: Date) -> Date {
        Calendar.jst.date(byAdding: .minute, value: minIntervalMinutes, to: now) ?? now
    }

    /// 選択された日時がポリシー違反（最小時間間隔より前など）であるかを判定します。
    /// - Parameters:
    ///   - selectedDate: ユーザーが選択した日時。
    ///   - now: 現在の日時。
    /// - Returns: ポリシーに違反している場合は `true`、それ以外は `false`。
    internal static func isInvalidSelection(selectedDate: Date, now: Date) -> Bool {
        selectedDate <= minimumValidDate(now: now)
    }

    /// 選択可能な次の有効な実行日時を文字列（JST表示形式）で返します。
    /// - Parameter now: 現在の日時。
    /// - Returns: JST表示形式の次回実行日時文字列。
    internal static func nextValidDate(now: Date) -> String {
        TimeFormatters.jstDisplay.string(from: minimumValidDate(now: now))
    }
}

