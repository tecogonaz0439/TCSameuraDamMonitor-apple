// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// 過去データ検索 (Historical data search) の検証エラーを表す列挙型。
internal enum HistoricalSearchValidationError: LocalizedError, Sendable {
    /// 指定された日付が古すぎる（データ提供開始日より前）。
    case tooOld
    /// 開始日が終了日より後になっている。
    case dateRange
    /// 今日または未来の日付が検索範囲に含まれている。
    case today
    /// 検索範囲の期間が長すぎる（最大日数を超えている）。
    case tooLong
    /// 既に同じ検索条件（観測所IDと期間）が存在している。
    case duplicate
    /// 指定期間が sudmonitor の日次過去データとして読み込み済みである。
    case sudmonitorHistoryLoaded

    /// エラーのローカライズされた説明文字列。
    internal var errorDescription: String? {
        switch self {
        case .tooOld: return AppLocalized.text("historical.search.errorTooOld")
        case .dateRange: return AppLocalized.text("historical.search.errorDateRange")
        case .today: return AppLocalized.text("historical.search.errorToday")
        case .tooLong: return AppLocalized.text("historical.search.errorTooLong")
        case .duplicate: return AppLocalized.text("historical.search.duplicate")
        case .sudmonitorHistoryLoaded: return AppLocalized.text("historical.sudmonitorHistory.duplicateLoaded")
        }
    }
}

/// 過去データ検索 (Historical data search) 時の期間検証・修正ルールを定義するユーティリティ。
internal enum HistoricalSearchDatePolicy: Sendable {
    /// 検索可能な最古の日付（2002年6月1日）。
    internal static let earliestDate = Calendar.jst.date(from: DateComponents(year: 2002, month: 6, day: 1)) ?? Date.distantPast
    /// 一度の検索で指定可能な最大日数（31日間）。
    internal static let maxDays = 31

    /// 入力された検索期間と既存の検索履歴から、検索リクエストが妥当かどうかを検証します。
    /// - Parameters:
    ///   - start: 検索開始日。
    ///   - end: 検索終了日。
    ///   - existingSearches: 既存の検索履歴リスト。
    ///   - damId: ダム構成設定ID。
    ///   - now: 現在の日時。
    ///   - historicalDataSource: 過去データ検索のデータソース設定(機能ゲート判定)。
    ///   - loadedDailyHistory: 読込済み sudmonitor 日次過去データの期間 (yyyyMMdd)。
    /// - Returns: 検証エラーがある場合は `HistoricalSearchValidationError`、妥当な場合は `nil`。
    internal static func validate(
        start: Date,
        end: Date,
        existingSearches: [(damConfigId: String, searchBgnDate: String, searchEndDate: String)],
        damId: String,
        now: Date,
        historicalDataSource: RealtimeDataSource = .sudmonitor,
        loadedDailyHistory: (start: String, end: String)? = nil
    ) -> HistoricalSearchValidationError? {
        let startDay = DisplayFormatters.startOfJSTDay(start)
        let endDay = DisplayFormatters.startOfJSTDay(end)
        let today = Calendar.jst.startOfDay(for: now)
        if startDay < earliestDate || endDay < earliestDate {
            return .tooOld
        }
        if startDay > endDay {
            return .dateRange
        }
        if endDay >= today {
            return .today
        }
        let days = Calendar.jst.dateComponents([.day], from: startDay, to: endDay).day ?? 0
        if days >= maxDays {
            return .tooLong
        }
        let startKey = DisplayFormatters.searchDate(start)
        let endKey = DisplayFormatters.searchDate(end)
        if existingSearches.contains(where: { $0.damConfigId == damId && $0.searchBgnDate == startKey && $0.searchEndDate == endKey }) {
            return .duplicate
        }
        if historicalDataSource == .sudmonitor,
           let loadedDailyHistory,
           loadedDailyHistory.start == startKey,
           loadedDailyHistory.end == endKey {
            return .sudmonitorHistoryLoaded
        }
        return nil
    }

    /// 開始日が変更された際に、最大日数（31日）制限に収まるように終了日を自動調整します。
    /// - Parameters:
    ///   - start: 新しい開始日。
    ///   - end: 現在の終了日。
    /// - Returns: 調整済みの開始日と終了日のタプル。
    internal static func adjustedRangeAfterStartChange(start: Date, end: Date) -> (start: Date, end: Date) {
        let startDay = DisplayFormatters.startOfJSTDay(start)
        let endDay = DisplayFormatters.startOfJSTDay(end)
        if startDay > endDay {
            return (start, start)
        }
        let days = Calendar.jst.dateComponents([.day], from: startDay, to: endDay).day ?? 0
        if days >= maxDays {
            return (start, Calendar.jst.date(byAdding: .day, value: maxDays - 1, to: startDay) ?? start)
        }
        return (start, end)
    }

    /// 終了日が変更された際に、最大日数（31日）制限に収まるように開始日を自動調整します。
    /// - Parameters:
    ///   - start: 現在の開始日。
    ///   - end: 新しい終了日。
    /// - Returns: 調整済みの開始日と終了日のタプル。
    internal static func adjustedRangeAfterEndChange(start: Date, end: Date) -> (start: Date, end: Date) {
        let startDay = DisplayFormatters.startOfJSTDay(start)
        let endDay = DisplayFormatters.startOfJSTDay(end)
        if startDay > endDay {
            return (end, end)
        }
        let days = Calendar.jst.dateComponents([.day], from: startDay, to: endDay).day ?? 0
        if days >= maxDays {
            return (Calendar.jst.date(byAdding: .day, value: -(maxDays - 1), to: endDay) ?? end, end)
        }
        return (start, end)
    }
}

