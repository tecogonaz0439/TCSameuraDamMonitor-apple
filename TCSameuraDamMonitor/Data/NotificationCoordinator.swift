// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation
import UserNotifications

/// ローカル通知の許可確認、権限要求、および送信処理を調整する構造体。
internal struct NotificationCoordinator {
    /// 通知センター。
    internal let center: UNUserNotificationCenter

    /// 通知コーディネーターを初期化します。
    /// - Parameter center: 使用する `UNUserNotificationCenter`。デフォルトは `.current()` です。
    internal init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    /// 現在の通知許可設定が、通知送信を許容する状態にあるかを判定します。
    /// - Returns: 通知送信が許可されている場合は `true`、それ以外は `false`。
    internal func currentAuthorizationAllowsNotification() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    /// 必要に応じて、ユーザーに対してローカル通知の受信許可を要求します。
    /// - Returns: 最終的に許可が得られた（または既に許可されている）場合は `true`、却下された場合は `false`。
    internal func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default:
            return false
        }
    }

    /// 即時実行のローカル通知を送信します。
    /// - Parameters:
    ///   - identifier: 通知要求を一意に識別するID。
    ///   - title: 通知のタイトル。
    ///   - body: 通知の本文メッセージ。
    internal func send(identifier: String, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        try? await center.add(request)
    }
}

