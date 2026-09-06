// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Dashboardで開閉可能なCardを、リアルタイム・過去データの表示モード別に識別するキー。
internal enum DashboardCardExpansionKey: String, CaseIterable, Sendable {
    case realtimeObservation = "realtime.observation"
    case realtimeLatest = "realtime.latest"
    case realtimeHistory = "realtime.history"
    case realtimeGraph = "realtime.graph"
    case realtimeLinks = "realtime.links"
    case historicalObservation = "historical.observation"
    case historicalHistory = "historical.history"
    case historicalGraph = "historical.graph"
    case historicalLinks = "historical.links"

    /// UI testとaccessibilityで使用する開閉ボタンの識別子。
    internal var toggleIdentifier: String {
        "dashboard.cardToggle.\(rawValue)"
    }
}

/// Dashboard Cardのロード済み開閉状態。未保存のCardは展開を既定とする。
internal struct DashboardCardExpansionState: Equatable, Sendable {
    private var values: [DashboardCardExpansionKey: Bool]

    internal init(values: [DashboardCardExpansionKey: Bool] = [:]) {
        self.values = values
    }

    internal subscript(key: DashboardCardExpansionKey) -> Bool {
        values[key] ?? true
    }

    internal mutating func set(_ isExpanded: Bool, for key: DashboardCardExpansionKey) {
        values[key] = isExpanded
    }
}

/// Dashboard Cardの開閉状態を通常設定やWidget共有領域から独立して保存する。
internal final class DashboardCardExpansionRepository {
    private static let keyPrefix = "dashboard.cardExpansion.v1."
    private let defaults: UserDefaults

    internal init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 全Cardの保存済み状態を読み込む。キーが存在しない場合は展開状態とする。
    internal func load() -> DashboardCardExpansionState {
        var values: [DashboardCardExpansionKey: Bool] = [:]
        for key in DashboardCardExpansionKey.allCases {
            let defaultsKey = Self.defaultsKey(for: key)
            if defaults.object(forKey: defaultsKey) != nil {
                values[key] = defaults.bool(forKey: defaultsKey)
            }
        }
        return DashboardCardExpansionState(values: values)
    }

    /// 1枚のCardの状態だけを保存する。
    internal func save(_ isExpanded: Bool, for key: DashboardCardExpansionKey) {
        defaults.set(isExpanded, forKey: Self.defaultsKey(for: key))
    }

    private static func defaultsKey(for key: DashboardCardExpansionKey) -> String {
        "\(keyPrefix)\(key.rawValue)"
    }
}
