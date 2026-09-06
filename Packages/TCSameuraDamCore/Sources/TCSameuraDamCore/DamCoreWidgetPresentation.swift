// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// ダムの情報をウィジェットやUI向けに整形して表示するためのプレゼンテーションユーティリティ。
public enum DamCoreWidgetPresentation {
    /// 貯水率 (Storage rate) の値をパーセント表記の文字列（例: "85.20%"）に整形します。
    ///
    /// - Parameter value: 貯水率 (Storage rate) の浮動小数点数値。
    /// - Returns: 整形されたパーセント文字列。値が nil の場合は "-- %" を返します。
    public static func percent(_ value: Float?) -> String {
        guard let value else { return "-- %" }
        return String(format: "%.2f%%", value)
    }

    /// 貯水率 (Storage rate) の値を小数点第2位までの数値文字列（例: "85.20"）に整形します（末尾の「%」は含みません）。
    ///
    /// - Parameter value: 貯水率 (Storage rate) の浮動小数点数値。
    /// - Returns: 整形された文字列。値が nil の場合は "--" を返します。
    public static func percentValue(_ value: Float?) -> String {
        guard let value else { return "--" }
        return String(format: "%.2f", value)
    }

    /// 貯水量 (Storage volume) の値を整数表記の文字列（万立方メートル単位を想定）に整形します。
    ///
    /// - Parameter value: 貯水量 (Storage volume) の数値。
    /// - Returns: 小数点を四捨五入した文字列。値が nil の場合は "--" を返します。
    public static func volume(_ value: Float?) -> String {
        guard let value else { return "--" }
        return String(format: "%.0f", value)
    }

    /// 増減傾向の文字列から対応する矢印の記号（glyph）を取得します。
    ///
    /// - Parameter trend: 傾向を表す文字列 ("up", "down", "flat")。
    /// - Returns: 傾向に対応する矢印記号（"↗", "↘", "→" など）。不明な傾向の場合は空文字を返します。
    public static func trendGlyph(_ trend: String) -> String {
        switch trend {
        case "up": return "↗"
        case "down": return "↘"
        case "flat": return "→"
        default: return ""
        }
    }

    /// メッセージ文字列の先頭から状態を表す絵文字（Emoji）を抽出します。
    ///
    /// - Parameter message: メッセージ文字列（例: "😊 メッセージ内容"）。
    /// - Returns: 抽出された絵文字。空白で区切られた最初のセグメントを返します。
    public static func stateEmoji(from message: String) -> String {
        message.components(separatedBy: " ").first ?? ""
    }

    /// 観測日時を表す文字列を、タイムゾーンを考慮した読みやすい形式（"yyyy/MM/dd HH:mm"）に整形します。
    ///
    /// - Parameters:
    ///   - text: 元の観測日時文字列。
    ///   - currentTimeZoneIdentifier: 現在設定されているタイムゾーンの識別子。オフセット比較でJST判定し（"Etc/GMT-9"等もJST）、無効な識別子は非JST扱い。
    /// - Returns: 整形された日時文字列。日本標準時（JST）以外のタイムゾーンの場合は、末尾に " (JST)" を付与します。
    public static func observedAt(_ text: String, currentTimeZoneIdentifier: String = TimeZone.current.identifier) -> String {
        guard let date = DamCoreDamTime.date(from: text) else {
            return text
        }
        let base = "\(Formatters.jstDateSlash.string(from: date)) \(Formatters.jstHourMinute.string(from: date))"
        return DamCoreJSTSupport.appendingJstSuffix(base, isLocalJst: DamCoreJSTSupport.isJst(identifier: currentTimeZoneIdentifier))
    }

    /// 観測日時を表す文字列を、日付部分と時刻部分（タイムゾーン考慮）に分割して整形します。
    ///
    /// - Parameters:
    ///   - text: 元の観測日時文字列。
    ///   - currentTimeZoneIdentifier: 現在設定されているタイムゾーンの識別子。オフセット比較でJST判定し（"Etc/GMT-9"等もJST）、無効な識別子は非JST扱い。
    /// - Returns: 日付文字列と時刻文字列のタプル。日付が解析できない場合は空の文字列を返します。
    public static func observedAtParts(_ text: String, currentTimeZoneIdentifier: String = TimeZone.current.identifier) -> (date: String, time: String) {
        guard let date = DamCoreDamTime.date(from: text) else {
            return ("", "")
        }
        let isLocalJst = DamCoreJSTSupport.isJst(identifier: currentTimeZoneIdentifier)
        let time = DamCoreJSTSupport.appendingJstSuffix(Formatters.jstHourMinute.string(from: date), isLocalJst: isLocalJst)
        return (Formatters.jstDateSlash.string(from: date), time)
    }

    /// 観測日時を表す文字列を、月日と時刻のみのコンパクトな形式（"MM/dd HH:mm"）に整形します。
    ///
    /// - Parameter text: 元の観測日時文字列。
    /// - Returns: 整形されたコンパクトな日時文字列。
    public static func compactDateTime(_ text: String) -> String {
        guard let date = DamCoreDamTime.date(from: text) else { return text }
        return "\(Formatters.jstMonthDay.string(from: date)) \(Formatters.jstHourMinute.string(from: date))"
    }

    /// スナップショット情報を基に、プッシュ通知やローカル通知等で表示するための通知メッセージを構築します。
    ///
    /// - Parameters:
    ///   - snapshot: ダム情報のスナップショット。
    ///   - currentTimeZoneIdentifier: 現在設定されているタイムゾーンの識別子。オフセット比較でJST判定し（"Etc/GMT-9"等もJST）、無効な識別子は非JST扱い。
    /// - Returns: ダム名、観測日時、貯水率 (Storage rate)、傾向、およびメッセージを結合した通知テキスト。
    public static func notificationMessage(snapshot: DamCoreWidgetSnapshot, currentTimeZoneIdentifier: String = TimeZone.current.identifier) -> String {
        let parts = observedAtParts(snapshot.observedAt, currentTimeZoneIdentifier: currentTimeZoneIdentifier)
        var values: [String] = [snapshot.damName]
        if !parts.date.isEmpty { values.append(parts.date) }
        if !parts.time.isEmpty { values.append(parts.time) }
        if let pct = snapshot.storagePercentage {
            values.append(percent(pct))
            let trend = trendGlyph(snapshot.trend)
            if !trend.isEmpty { values.append(trend) }
        } else {
            values.append("-- %")
        }
        if !snapshot.message.isEmpty { values.append(snapshot.message) }
        return values.joined(separator: " ")
    }

    /// ロック画面やステータスバーなどのコンパクトなインラインウィジェット（Accessory Inline）向けのテキストを構築します。
    ///
    /// - Parameters:
    ///   - snapshot: ダム情報のスナップショット。
    ///   - placeholderMessage: 貯水率 (Storage rate) が取得できない場合のデフォルトプレースホルダーメッセージ。
    ///   - initialMessage: スナップショット自体が nil （初期状態など）の場合に表示する初期メッセージ。
    /// - Returns: 状態絵文字、貯水率 (Storage rate) 数値、および増減傾向記号を組み合わせた短いテキスト。
    public static func accessoryInlineText(snapshot: DamCoreWidgetSnapshot?, placeholderMessage: String, initialMessage: String) -> String {
        guard let snapshot else { return initialMessage }
        guard let pct = snapshot.storagePercentage else {
            return snapshot.message.isEmpty ? placeholderMessage : snapshot.message
        }
        return "\(stateEmoji(from: snapshot.message)) \(percentValue(pct))% \(trendGlyph(snapshot.trend))"
            .trimmingCharacters(in: .whitespaces)
    }
}

private enum Formatters {
    static let jstDateSlash: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()

    static let jstMonthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "MM/dd"
        return formatter
    }()

    static let jstHourMinute: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
