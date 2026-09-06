// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// アプリケーション内でローカライズされた文字列リソース（多言語テキスト）を取得およびフォーマットするためのヘルパー。
internal enum AppLocalized {
    /// 指定されたキー、ロケール、およびバンドル情報に基づいて、ローカライズされたテキストを取得します。
    /// - Parameters:
    ///   - key: ローカライズファイル内の一意なキー。
    ///   - locale: 対象のロケール。デフォルトは現在の自動更新ロケールです。
    ///   - bundle: 対象のバンドル。デフォルトはメインバンドルです。
    /// - Returns: ローカライズされた翻訳文字列。
    internal nonisolated static func text(_ key: String, locale: Locale = .autoupdatingCurrent, bundle: Bundle = .main) -> String {
        let languageCode = locale.language.languageCode?.identifier
        let localizedBundle = languageCode
            .flatMap { bundle.path(forResource: $0, ofType: "lproj") }
            .flatMap(Bundle.init(path:))
            ?? bundle
        return localizedBundle.localizedString(forKey: key, value: nil, table: "Localizable")
    }

    /// 引数リストを用いて、現在のシステムロケールでローカライズされた文字列をフォーマットします。
    /// - Parameters:
    ///   - key: フォーマット前の文字列テンプレートのローカライズキー。
    ///   - arguments: 挿入する可変長引数。
    /// - Returns: フォーマット後の文字列。
    internal nonisolated static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: .autoupdatingCurrent, arguments: arguments)
    }

    /// 指定されたロケールと引数リストを用いて、ローカライズされた文字列をフォーマットします。
    /// - Parameters:
    ///   - key: フォーマット前の文字列テンプレートのローカライズキー。
    ///   - locale: 使用するロケール設定。
    ///   - arguments: 挿入する可変長引数。
    /// - Returns: フォーマット後の文字列。
    internal nonisolated static func format(_ key: String, locale: Locale, _ arguments: CVarArg...) -> String {
        String(format: text(key, locale: locale), locale: locale, arguments: arguments)
    }
}
