// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation
import TCSameuraDamCore

/// 日本標準時（JST）に基づく日付・時刻表示のフォーマットや、ダム時間の変換ユーティリティ。
internal struct TimeFormatters {
    /// JST表示形式の日時フォーマッタ（例: "2026/06/17 00:00"）。
    internal static let jstDisplay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()

    /// 過去データ検索 (Historical data search) で用いられる日付キー用フォーマッタ（例: "20260617"）。
    internal static let jstDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    /// スラッシュ区切り形式の日付用フォーマッタ（例: "2026/06/17"）。
    internal static let jstDateSlash: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()

    /// 履歴テーブル行向けの簡略日時フォーマッタ（例: "06/17 00:00"）。
    internal static let historyRowMinute: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter
    }()

    /// 短縮表示かつ 'JST' 表記を付与したフォーマッタ（例: "06/17 00:00 JST"）。
    internal static let shortJST: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "MM/dd HH:mm 'JST'"
        return formatter
    }()

    /// ISO8601規格（JSTタイムゾーン固定）のフォーマッタ（例: "2026-06-17T00:00:00+09:00"）。
    internal static let iso8601JST: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXX"
        return formatter
    }()

    /// 先頭ゼロを省略した時間用フォーマッタ（例: "0:00"）。
    internal static let jstTimeNoLeadingZero: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "H:mm"
        return formatter
    }()

    /// 曜日情報を付加したJST表示用フォーマッタ（例: "2026/06/17(水) 00:00"）。
    internal static let jstDisplayWithWeekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.effectiveLocale
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy/MM/dd(EEE) HH:mm"
        return formatter
    }()

    /// ダム時間文字列からエポックミリ秒を計算します。
    /// - Parameter text: ダム時間文字列。
    /// - Returns: 計算されたミリ秒（Double値）。無効な形式の場合は `NaN`。
    internal static func millis(fromDamTime text: String) -> Double {
        millisIfValid(fromDamTime: text) ?? .nan
    }

    /// ダム時間文字列から有効なエポックミリ秒を計算します（Option型）。
    /// - Parameter text: ダム時間文字列。
    /// - Returns: 計算されたミリ秒。無効な形式の場合は `nil`。
    internal nonisolated static func millisIfValid(fromDamTime text: String) -> Double? {
        DamCoreDamTime.millis(from: text)
    }

    /// 日本時間の変則表記（日付またぎ等）を考慮し、ダム時間表現を正規化します。
    /// - Parameter text: 元の時間表現文字列。
    /// - Returns: 正規化された時間文字列。
    internal static func normalizeDamTime(_ text: String) -> String {
        DamCoreDamTime.normalizedString(text) ?? text
    }

    /// ダム時間文字列を ISO8601 形式に変換します。
    /// - Parameter damTime: ダム時間文字列。
    /// - Returns: ISO8601 形式の文字列。変換できない場合は元の文字列。
    internal static func toIso8601(_ damTime: String) -> String {
        guard let date = DamCoreDamTime.date(from: damTime) else { return damTime }
        return iso8601JST.string(from: date)
    }
}

