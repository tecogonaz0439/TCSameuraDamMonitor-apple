// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// アプリの設定情報（`AppSettings`）を `UserDefaults` を用いて永続化・ロードするリポジトリクラス。
internal final class SettingsRepository {
    /// 永続化保存キー。
    private let key = "app.settings.v2"
    /// 読み書き対象の `UserDefaults`。
    private let defaults: UserDefaults

    /// 設定リポジトリを初期化します。
    /// - Parameter defaults: 保存・読み込みに使用する `UserDefaults` ストア。デフォルトは `.standard` です。
    internal init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 保存されているアプリ設定を読み込みます。データが存在しない、または破損している場合はデフォルト値の設定オブジェクトを返します。
    /// - Returns: ロードされた `AppSettings` オブジェクト。
    internal func load() -> AppSettings {
        guard let data = defaults.data(forKey: key) else {
            var initial = AppSettings()
            initial.recalculateInitialNextRequestedUpdate()
            return initial
        }
        guard var settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            var initial = AppSettings()
            initial.recalculateInitialNextRequestedUpdate()
            return initial
        }
        #if !DEBUG
        settings.debugModeEnabled = false
        settings.debugSimulateMode = .none
        #endif
        return settings
    }

    /// アプリ設定オブジェクトをエンコードして `UserDefaults` に永続化保存します。
    /// - Parameter settings: 保存する `AppSettings` オブジェクト。
    internal func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}

