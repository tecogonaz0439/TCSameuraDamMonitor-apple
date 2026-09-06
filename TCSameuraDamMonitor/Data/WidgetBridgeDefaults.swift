// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// アプリ共有グループ（App Group）用とアプリ標準の `UserDefaults` を透過的に扱い、ウィジェット間連携データの書き込み・フォールバック読み込みを提供する構造体。
internal struct WidgetBridgeDefaults {
    /// App Group 共有用の `UserDefaults`。
    internal let groupDefaults: UserDefaults?
    /// アプリ標準の `UserDefaults`。
    internal let standardDefaults: UserDefaults

    /// 値を書き込む対象となるすべての `UserDefaults` ストアの一覧。
    internal var stores: [UserDefaults] {
        var result: [UserDefaults] = []
        if let groupDefaults {
            result.append(groupDefaults)
        }
        result.append(standardDefaults)
        return result
    }

    /// すべての有効なストアに対して、指定されたキーで値を保存します。
    /// - Parameters:
    ///   - value: 保存するオブジェクト。
    ///   - key: 保存先のキー。
    internal func set(_ value: Any, forKey key: String) {
        stores.forEach { $0.set(value, forKey: key) }
    }

    /// すべての有効なストアから、指定されたキーに対応する値を削除します。
    /// - Parameter key: 削除対象のキー。
    internal func removeValue(forKey key: String) {
        stores.forEach { $0.removeObject(forKey: key) }
    }

    /// 指定されたキーに対応するデータをバイナリ形式で取得します（共有優先、標準フォールバック）。
    /// - Parameter key: 取得対象のキー。
    /// - Returns: 取得したバイナリデータ。存在しない場合は `nil`。
    internal func data(forKey key: String) -> Data? {
        groupDefaults?.data(forKey: key) ?? standardDefaults.data(forKey: key)
    }

    /// 指定されたキーに対応する文字列を取得します（共有優先、標準フォールバック）。
    /// - Parameter key: 取得対象のキー.
    /// - Returns: 取得した文字列。存在しない場合は `nil`。
    internal func string(forKey key: String) -> String? {
        groupDefaults?.string(forKey: key) ?? standardDefaults.string(forKey: key)
    }

    /// 指定されたキーに対応する数値を `Double` 型で取得します（共有優先、標準フォールバック）。
    /// - Parameter key: 取得対象のキー。
    /// - Returns: 取得した数値。
    internal func double(forKey key: String) -> Double {
        let groupValue = groupDefaults?.double(forKey: key) ?? 0
        return groupValue > 0 ? groupValue : standardDefaults.double(forKey: key)
    }

    /// 指定されたキーに対応する日時を取得します。内部的には `double` で秒数を取得して変換します。
    /// - Parameter key: 取得対象のキー。
    /// - Returns: 日付オブジェクト。存在しない、または無効な場合は `nil`。
    internal func date(forKey key: String) -> Date? {
        let value = double(forKey: key)
        guard value > 0 else { return nil }
        return Date(timeIntervalSinceReferenceDate: value)
    }
}

