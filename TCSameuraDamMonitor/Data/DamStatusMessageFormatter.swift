// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation
import TCSameuraDamCore

/// ダムの観測状況や貯水率 (Storage rate) に基づき、UI表示（スナックバー、プッシュ通知、ウィジェットなど）用のフォーマットされた各種メッセージを構築する構造体。
internal struct DamStatusMessageFormatter {
    /// アプリ設定。
    internal let settings: AppSettings
    /// 日本語で出力するかどうかのフラグ。
    internal let isJapanese: Bool

    /// ステータスフォーマッタを初期化します。
    /// - Parameters:
    ///   - settings: アプリ設定。
    ///   - isJapanese: 日本語で出力するかどうかのフラグ。
    internal init(settings: AppSettings, isJapanese: Bool) {
        self.settings = settings
        self.isJapanese = isJapanese
    }

    /// トレンド（変化方向）に対応する矢印記号テキストを取得します。
    /// - Parameter trend: トレンド種別。
    /// - Returns: 矢印記号（"↗"、"↘"、"→"、または空文字）。
    internal static func trendText(_ trend: Trend) -> String {
        switch trend {
        case .up: return "↗"
        case .down: return "↘"
        case .flat: return "→"
        case .unknown: return ""
        }
    }

    /// ダム時間文字列を解析し、日付部分と時刻部分（ローカルタイムゾーンが日本以外の場合はJSTサフィックス付き）に分離してフォーマットします。
    /// - Parameter damTime: ダム時間文字列。
    /// - Returns: 日付文字列と時刻文字列のタプル。
    internal func formattedDateTime(from damTime: String?) -> (dateStr: String, timeStr: String) {
        guard let damTime else {
            return ("", "")
        }
        let normalized = TimeFormatters.normalizeDamTime(damTime)
        guard let date = TimeFormatters.jstDisplay.date(from: normalized) else {
            return ("", "")
        }
        let dateStr = TimeFormatters.jstDateSlash.string(from: date)
        let timeOnly = Calendar.jst.dateComponents([.hour, .minute], from: date)
        let timeStr = String(format: "%02d:%02d", timeOnly.hour ?? 0, timeOnly.minute ?? 0)
        return (dateStr, DamCoreJSTSupport.appendingJstSuffix(timeStr, isLocalJst: DisplayFormatters.isJST))
    }

    /// ダム観測データの主要測定情報（日時、貯水率 (Storage rate)、トレンド）を1行のテキスト文字列としてフォーマットします。
    /// - Parameter data: ダム観測データ。
    /// - Returns: スペース区切りで構成された1行のテキスト。
    internal func dataLine(data: DamData) -> String {
        let percentageStr: String
        let trendStr: String
        if let percentage = data.storagePercentage {
            percentageStr = String(format: "%.2f%%", percentage)
            trendStr = Self.trendText(data.storagePercentageTrend)
        } else {
            percentageStr = "-- %"
            trendStr = ""
        }
        let (dateStr, timeStr) = formattedDateTime(from: data.storagePercentageTime ?? data.updatedAt)
        return [dateStr, timeStr, percentageStr, trendStr]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// アプリ画面内のスナックバーで表示するためのダム状況メッセージを構築します。
    /// - Parameters:
    ///   - data: ダム観測データ。
    ///   - damName: ダム名。
    ///   - overrideMessage: 強制適用する上書きメッセージ（配信停止など）。
    /// - Returns: スナックバー用の案内文。
    internal func snackbarMessage(data: DamData, damName: String, overrideMessage: String? = nil) -> String {
        if let overrideMessage {
            return "\(damName) \(overrideMessage)".trimmingCharacters(in: .whitespaces)
        }
        let dataLine = dataLine(data: data)
        let stateText: String
        if let percentage = data.storagePercentage {
            let state = settings.stateMessage(
                for: percentage,
                isJapanese: isJapanese,
                isSameura: data.observationStationId == AppSettings.defaultDamId,
                storageVolumeForMessage: data.storageVolumeForMessage
            )
            stateText = "\(state.0) \(state.1)".trimmingCharacters(in: .whitespaces)
        } else {
            stateText = abnormalMessage(
                isAllDataInvalid: data.isAllObservationDataInvalid,
                isSameura: data.observationStationId == AppSettings.defaultDamId
            )
        }
        return [damName, dataLine, stateText]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// バックグラウンドでのローカルプッシュ通知配信用メッセージを構築します。
    /// - Parameters:
    ///   - data: ダム観測データ。
    ///   - damName: ダム名。
    ///   - overrideMessage: 強制適用する上書きメッセージ。
    /// - Returns: プッシュ通知用の本文メッセージ。
    internal func notificationMessage(data: DamData, damName: String, overrideMessage: String? = nil) -> String {
        if let overrideMessage {
            return "\(damName) \(overrideMessage)".trimmingCharacters(in: .whitespaces)
        }
        let dataLine = dataLine(data: data)
        let stateText: String
        if let percentage = data.storagePercentage {
            let state = settings.stateMessage(
                for: percentage,
                isJapanese: isJapanese,
                isSameura: data.observationStationId == AppSettings.defaultDamId,
                storageVolumeForMessage: data.storageVolumeForMessage
            )
            stateText = "\(state.0) \(state.1)".trimmingCharacters(in: .whitespaces)
        } else {
            stateText = abnormalMessage(
                isAllDataInvalid: data.isAllObservationDataInvalid,
                isSameura: data.observationStationId == AppSettings.defaultDamId
            )
        }
        if stateText.isEmpty {
            return "\(damName) \(dataLine)".trimmingCharacters(in: .whitespaces)
        }
        return "\(damName) \(dataLine) \(stateText)".trimmingCharacters(in: .whitespaces)
    }

    /// ホーム画面ウィジェット内で表示するためのダム状況ステータスメッセージを構築します。
    /// - Parameters:
    ///   - data: ダム観測データ。
    ///   - overrideMessage: 強制適用する上書きメッセージ。
    /// - Returns: ウィジェット用の短縮された状況説明テキスト。
    internal func widgetMessage(data: DamData, overrideMessage: String? = nil) -> String {
        if let overrideMessage { return overrideMessage }
        if let percentage = data.storagePercentage {
            let state = settings.stateMessage(
                for: percentage,
                isJapanese: isJapanese,
                isSameura: data.observationStationId == AppSettings.defaultDamId,
                storageVolumeForMessage: data.storageVolumeForMessage
            )
            return "\(state.0) \(state.1)".trimmingCharacters(in: .whitespaces)
        }
        return abnormalMessage(
            isAllDataInvalid: data.isAllObservationDataInvalid,
            isSameura: data.observationStationId == AppSettings.defaultDamId
        )
    }

    /// データが欠測、または異常値である場合の警告メッセージを生成します。
    private func abnormalMessage(isAllDataInvalid: Bool, isSameura: Bool) -> String {
        let pair = settings.storageRateMessage(
            for: nil,
            isJapanese: isJapanese,
            isAllDataInvalid: isAllDataInvalid,
            isSameura: isSameura
        )
        return "\(pair.0) \(pair.1)".trimmingCharacters(in: .whitespaces)
    }
}
