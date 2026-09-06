// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// サイドバーと macOS メニューバーに表示するリアルタイムデータの状態行。
internal struct RealtimeStatusMenuLines: Equatable {
    /// ダム表示名。
    let title: String
    /// リアルタイムデータがある場合の観測時刻と貯水率。
    let detail: String?
    /// 観測時刻の文字列（iOS/iPadOS で貯水率と分離して色替えするため）。
    let timeText: String?
    /// 貯水率の文字列（iOS/iPadOS で個別に色替えするため）。
    let percentText: String?
    /// 表示対象の貯水率メッセージまたは読込状態メッセージ。
    let status: String?
    /// 貯水率の推移。
    let trend: Trend

    /// リアルタイムデータのサイドバー項目と同じ表示行を構築します。
    /// - Parameters:
    ///   - data: 現在のリアルタイムダムデータ。
    ///   - damConfig: 選択中のダム設定。
    ///   - settings: 貯水率メッセージと読込状態メッセージに使うアプリ設定。
    ///   - damLoadStatus: 現在のリアルタイムデータ読込状態。
    /// - Returns: 3行表示に対応するリアルタイムデータ状態。
    static func make(
        data: DamData?,
        damConfig: DamConfig?,
        settings: AppSettings,
        damLoadStatus: DamLoadStatus
    ) -> RealtimeStatusMenuLines {
        let title = DisplayFormatters.localizedDamName(damConfig)
        guard let data else {
            let status: String?
            switch damLoadStatus {
            case .networkUnavailable:
                let text = settings.networkUnavailableText(isJapanese: AppLocale.isJapanese)
                status = text.isEmpty ? nil : text
            case .loadingFailure:
                let text = settings.loadingErrorText(isJapanese: AppLocale.isJapanese)
                status = text.isEmpty ? nil : text
            case .initial, .success:
                status = nil
            }
            return RealtimeStatusMenuLines(title: title, detail: nil, timeText: nil, percentText: nil, status: status, trend: .unknown)
        }

        let timeText = DisplayFormatters.damDateTime(data.storagePercentageTime ?? data.updatedAt)
        let percentText = DisplayFormatters.percent(data.storagePercentage)
        let detail = [timeText, percentText].joined(separator: " ")
        let status = settings.showStorageRateMessage
            ? DisplayFormatters.statusText(
                settings: settings,
                percentage: data.storagePercentage,
                isAllDataInvalid: data.isAllObservationDataInvalid,
                isSameura: data.observationStationId == AppSettings.defaultDamId,
                storageVolumeForMessage: data.storageVolumeForMessage
            )
            : nil

        return RealtimeStatusMenuLines(
            title: title,
            detail: detail,
            timeText: timeText,
            percentText: percentText,
            status: status,
            trend: data.storagePercentageTrend
        )
    }
}
