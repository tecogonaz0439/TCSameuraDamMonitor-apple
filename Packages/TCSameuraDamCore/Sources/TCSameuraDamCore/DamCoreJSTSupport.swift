// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// JST（日本標準時）判定と、非JST環境向け "(JST)" サフィックス付与を集約したユーティリティ。
///
/// JST判定はIANA識別子（"Asia/Tokyo"等）との文字列比較ではなくオフセット比較で行うため、
/// "Etc/GMT-9" 等の実効オフセットが +9h のタイムゾーンもJSTとして扱う。
public enum DamCoreJSTSupport {
    /// JSTの標準時オフセット（+9時間 = 32400秒）。
    public static let jstStandardOffsetSeconds: Int = 32400

    /// 非JST環境で時刻表記の末尾へ付与するサフィックス。
    public static let jstSuffix: String = " (JST)"

    /// 指定タイムゾーンが基準時刻においてJSTであるかどうかを判定します。
    ///
    /// 標準時オフセットと現在の実効オフセットがともに +9h の場合のみJSTとみなします（夏時間考慮）。
    /// - Parameters:
    ///   - timeZone: 判定対象のタイムゾーン。nil は非JST扱い。
    ///   - date: 実効オフセットを評価する基準時刻。
    /// - Returns: JSTの場合はtrue。
    public static func isJst(_ timeZone: TimeZone?, at date: Date = Date()) -> Bool {
        guard let timeZone else { return false }
        let effectiveOffset = timeZone.secondsFromGMT(for: date)
        let standardOffset = effectiveOffset - Int(timeZone.daylightSavingTimeOffset(for: date))
        return effectiveOffset == jstStandardOffsetSeconds && standardOffset == jstStandardOffsetSeconds
    }

    /// タイムゾーン識別子からJST判定します。無効な識別子は非JST扱いです。
    /// - Parameters:
    ///   - identifier: タイムゾーン識別子。nil や不正な値は非JST扱い。
    ///   - date: 実効オフセットを評価する基準時刻。
    /// - Returns: JSTの場合はtrue。
    public static func isJst(identifier: String?, at date: Date = Date()) -> Bool {
        guard let identifier else { return false }
        return isJst(TimeZone(identifier: identifier), at: date)
    }

    /// 非JST環境の場合に時刻文字列の末尾へ "(JST)" サフィックスを付与します。
    ///
    /// すでに末尾にサフィックスがある場合は二重に付与しません（冪等）。JST環境では入力をそのまま返します。
    /// - Parameters:
    ///   - text: 対象の時刻文字列。
    ///   - isLocalJst: 端末（または注入された）タイムゾーンがJSTかどうか。
    /// - Returns: サフィックス適用後の文字列。
    public static func appendingJstSuffix(_ text: String, isLocalJst: Bool) -> String {
        if isLocalJst { return text }
        if text.hasSuffix(jstSuffix) { return text }
        return text + jstSuffix
    }
}
