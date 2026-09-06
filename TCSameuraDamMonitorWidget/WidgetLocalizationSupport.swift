// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// ウィジェット内のローカライズされた文字列を取得するためのヘルパー。
enum WidgetLocalized {
    /// 指定されたキーに関連付けられたローカライズ済みの文字列を返します。
    /// - Parameters:
    ///   - key: ローカライズする文字列のキー。
    ///   - locale: ローカライズに使用するロケール。デフォルトは `.autoupdatingCurrent`。
    ///   - bundle: ローカライズテーブルを含むバンドル。デフォルトは `.main`。
    /// - Returns: ローカライズされた文字列。
    nonisolated static func text(_ key: String, locale: Locale = .autoupdatingCurrent, bundle: Bundle = .main) -> String {
        String(localized: String.LocalizationValue(key), table: "Localizable", bundle: bundle, locale: locale)
    }
}
