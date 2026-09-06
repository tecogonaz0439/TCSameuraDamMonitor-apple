// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation
import TCSameuraDamCore

/// ウィジェットとメインアプリのユーザーデフォルトを管理する、スレッドセーフなストア。
///
/// 共有のApp Groupスイートを使用して、アプリとウィジェットの間でデータを共有します。
struct WidgetDefaultsStore: Sendable {
    /// デフォルトストアの共有インスタンス。
    static let shared = WidgetDefaultsStore()

    private let groupSuiteName = "group.net.tecogonaz.TCSameuraDamMonitor"

    private var groupDefaults: UserDefaults? {
        UserDefaults(suiteName: groupSuiteName)
    }

    private var stores: [UserDefaults] {
        var result: [UserDefaults] = []
        if let groupDefaults {
            result.append(groupDefaults)
        }
        result.append(.standard)
        return result
    }

    private static let transientLogKeys: Set<String> = [
        WidgetDefaultsKey.fetchLog,
        WidgetDefaultsKey.fetchFailLog,
        WidgetDefaultsKey.timelineCallLog,
        WidgetDefaultsKey.fetchDecisionLog,
        WidgetDefaultsKey.reloadCallLog,
    ]

    private func isTransientLogKey(_ key: String) -> Bool {
        Self.transientLogKeys.contains(key)
    }

    /// 指定されたキーに関連付けられたデータを取得します。
    /// - Parameter key: デフォルトデータベースのキー。
    /// - Returns: キーに関連付けられたデータ。見つからない場合は `nil`。
    func data(forKey key: String) -> Data? {
        groupDefaults?.data(forKey: key) ?? UserDefaults.standard.data(forKey: key)
    }

    /// 指定されたキーに関連付けられた文字列を取得します。
    /// - Parameter key: デフォルトデータベースのキー。
    /// - Returns: キーに関連付けられた文字列。見つからない場合は `nil`。
    func string(forKey key: String) -> String? {
        groupDefaults?.string(forKey: key) ?? UserDefaults.standard.string(forKey: key)
    }

    /// 指定されたキーに関連付けられた文字列の配列を取得します。
    /// - Parameter key: デフォルトデータベースのキー。
    /// - Returns: 文字列の配列。見つからない場合は空の配列。
    func stringArray(forKey key: String) -> [String] {
        if isTransientLogKey(key) {
            return groupDefaults?.stringArray(forKey: key) ?? []
        }
        return groupDefaults?.stringArray(forKey: key) ?? UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    /// 指定されたキーに関連付けられた真偽値を取得します。値が存在しない場合はデフォルト値にフォールバックします。
    /// - Parameters:
    ///   - key: デフォルトデータベースのキー。
    ///   - defaultValue: キーが存在しない場合に返すデフォルト値。
    /// - Returns: 真偽値。
    func bool(forKey key: String, default defaultValue: Bool = false) -> Bool {
        if groupDefaults?.object(forKey: key) != nil {
            return groupDefaults?.bool(forKey: key) ?? defaultValue
        }
        if UserDefaults.standard.object(forKey: key) != nil {
            return UserDefaults.standard.bool(forKey: key)
        }
        return defaultValue
    }

    /// 指定されたキーに関連付けられた実数（Double）を取得します。
    /// - Parameter key: デフォルトデータベースのキー。
    /// - Returns: 実数値。グループスイートにない場合は、標準の UserDefaults の値にフォールバックします。
    func double(forKey key: String) -> Double {
        let groupValue = groupDefaults?.double(forKey: key) ?? 0
        return groupValue > 0 ? groupValue : UserDefaults.standard.double(forKey: key)
    }

    /// 配下のすべてのユーザーデフォルトストアにおいて、指定されたキーの値を設定します。
    /// - Parameters:
    ///   - value: 書き込む値。
    ///   - key: 値を関連付けるキー。
    func set(_ value: Any, forKey key: String) {
        if isTransientLogKey(key) {
            groupDefaults?.set(value, forKey: key)
            return
        }
        stores.forEach { $0.set(value, forKey: key) }
    }

    /// 配下のすべてのユーザーデフォルトストアから、指定されたキーの値を削除します。
    /// - Parameter key: 値を削除するキー。
    func removeObject(forKey key: String) {
        stores.forEach { $0.removeObject(forKey: key) }
    }
}
