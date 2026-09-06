// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// 表示されている過去データ検索結果（または sudmonitor 日次過去データ）の日付範囲をフィルターまたは調整できるシートビュー。
struct HistoricalRangeSheet: View {
    /// 環境から提供されるディスミス（画面を閉じる）アクション。
    @Environment(\.dismiss) private var dismiss
    /// 状態とビジネスロジックを保持するアプリケーションモデル。
    let appModel: DamAppModel
    /// 有効な過去データ検索を記述するメタデータ（日次モードでは nil）。
    let meta: HistoricalSearchMeta?
    /// 日次モードの読込済み期間（yyyyMMdd、JST 日単位）。
    let dailyPeriod: (startDay: String, endDay: String)?
    /// 日次モードの対象ダム設定。
    let dailyDam: DamConfig?

    /// 選択された開始日を保持するローカル状態。
    @State private var startDate: Date
    /// 選択された終了日を保持するローカル状態。
    @State private var endDate: Date
    /// デフォルトの初期範囲境界の設定値。
    @State private var initialRange: (start: Date, end: Date)

    /// 新しい過去データ範囲選択シートを初期化します。
    /// - Parameters:
    ///   - appModel: アプリケーションモデル。
    ///   - meta: 過去データ検索のメタデータ（日次モードでは nil）。
    ///   - dailyPeriod: 日次モードの読込済み期間（yyyyMMdd）。
    ///   - dailyDam: 日次モードの対象ダム設定。
    init(appModel: DamAppModel, meta: HistoricalSearchMeta? = nil, dailyPeriod: (startDay: String, endDay: String)? = nil, dailyDam: DamConfig? = nil) {
        self.appModel = appModel
        self.meta = meta
        self.dailyPeriod = dailyPeriod
        self.dailyDam = dailyDam
        let rangeStart = Self.boundStart(meta: meta, dailyPeriod: dailyPeriod)
        let rangeEnd = Self.boundEnd(meta: meta, dailyPeriod: dailyPeriod)
        let currentStart = appModel.historicalDisplayStartDate
            .flatMap { TimeFormatters.jstDay.date(from: $0) }
            .map { DisplayFormatters.startOfJSTDay($0) } ?? rangeStart
        let currentEnd = appModel.historicalDisplayEndDate
            .flatMap { TimeFormatters.jstDay.date(from: $0) }
            .map { DisplayFormatters.startOfJSTDay($0) } ?? rangeEnd
        _startDate = State(initialValue: currentStart)
        _endDate = State(initialValue: currentEnd)
        _initialRange = State(initialValue: (rangeStart, rangeEnd))
    }

    /// 日次モードまたは過去データ検索の開始日境界を解決します。
    private static func boundStart(meta: HistoricalSearchMeta?, dailyPeriod: (startDay: String, endDay: String)?) -> Date {
        if let dailyPeriod {
            return DisplayFormatters.startOfJSTDay(TimeFormatters.jstDay.date(from: dailyPeriod.startDay) ?? .distantPast)
        }
        return DisplayFormatters.startOfJSTDay(TimeFormatters.jstDay.date(from: meta?.searchBgnDate ?? "") ?? .distantPast)
    }

    /// 日次モードまたは過去データ検索の終了日境界を解決します。
    private static func boundEnd(meta: HistoricalSearchMeta?, dailyPeriod: (startDay: String, endDay: String)?) -> Date {
        if let dailyPeriod {
            return DisplayFormatters.startOfJSTDay(TimeFormatters.jstDay.date(from: dailyPeriod.endDay) ?? .distantPast)
        }
        return DisplayFormatters.startOfJSTDay(TimeFormatters.jstDay.date(from: meta?.searchEndDate ?? "") ?? .distantPast)
    }

    /// 過去データ検索の開始日パラメータを評価します。
    private var searchStartDate: Date {
        Self.boundStart(meta: meta, dailyPeriod: dailyPeriod)
    }

    /// 過去データ検索の終了日パラメータを評価します。
    private var searchEndDate: Date {
        Self.boundEnd(meta: meta, dailyPeriod: dailyPeriod)
    }

    /// 選択されたダムの設定詳細を解決します。
    private var selectedDam: DamConfig? {
        if let dailyDam { return dailyDam }
        return meta.flatMap { DamListData.dam(id: $0.damConfigId) }
    }

    /// 選択された表示日付の制約を検証し、無効な場合はローカライズされた警告文字列を返します。
    private var validationError: String? {
        let start = DisplayFormatters.startOfJSTDay(startDate)
        let end = DisplayFormatters.startOfJSTDay(endDate)
        let searchStart = searchStartDate
        let searchEnd = searchEndDate
        if start > end { return AppText.historicalSearchErrorDateRange }
        if start < searchStart || end > searchEnd { return AppText.historicalRangeErrorOutOfBounds }
        return nil
    }

    /// 過去データ範囲シートのコンテンツとレイアウト。
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(AppText.historicalSearchDam)
                        Spacer()
                        Text(DisplayFormatters.localizedDamName(selectedDam))
                            .foregroundStyle(.secondary)
                    }
                    DatePicker(AppText.historicalSearchStartDate, selection: $startDate, in: searchStartDate...searchEndDate, displayedComponents: .date)
                        .onChange(of: startDate) { _, newStart in
                            let newStartDay = DisplayFormatters.startOfJSTDay(newStart)
                            let endDay = DisplayFormatters.startOfJSTDay(endDate)
                            if newStartDay > endDay {
                                endDate = newStart
                            }
                        }
                    DatePicker(AppText.historicalSearchEndDate, selection: $endDate, in: searchStartDate...searchEndDate, displayedComponents: .date)
                        .onChange(of: endDate) { _, newEnd in
                            let startDay = DisplayFormatters.startOfJSTDay(startDate)
                            let newEndDay = DisplayFormatters.startOfJSTDay(newEnd)
                            if startDay > newEndDay {
                                startDate = newEnd
                            }
                        }
                } header: {
                    #if os(macOS)
                    Text(AppText.historicalRangeTitle)
                    #endif
                } footer: {
                    Text(AppText.historicalSearchPeriodNote(
                        start: DisplayFormatters.displayDate(DisplayFormatters.startOfJSTDay(startDate)),
                        endNextDay: DisplayFormatters.displayDate(
                            Calendar.jst.date(byAdding: .day, value: 1, to: DisplayFormatters.startOfJSTDay(endDate)) ?? endDate
                        )
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                if let validationError {
                    Text(validationError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            #if !os(macOS)
            .navigationTitle(AppText.historicalRangeTitle)
            #endif
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            .toolbar {
                #if os(macOS)
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppText.cancel) { dismiss() }
                }
                ToolbarItem(placement: .automatic) {
                    Button(AppText.historicalRangeReset) {
                        startDate = initialRange.start
                        endDate = initialRange.end
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppText.historicalRangeDisplayButton) {
                        guard validationError == nil else { return }
                        appModel.applyHistoricalDisplayRange(
                            startDate: DisplayFormatters.searchDate(startDate),
                            endDate: DisplayFormatters.searchDate(endDate)
                        )
                        dismiss()
                    }
                    .disabled(validationError != nil)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    HStack(spacing: 8) {
                        Button(AppText.historicalRangeReset) {
                            startDate = initialRange.start
                            endDate = initialRange.end
                        }
                        Button(AppText.cancel) { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppText.historicalRangeDisplayButton) {
                        guard validationError == nil else { return }
                        appModel.applyHistoricalDisplayRange(
                            startDate: DisplayFormatters.searchDate(startDate),
                            endDate: DisplayFormatters.searchDate(endDate)
                        )
                        dismiss()
                    }
                    .disabled(validationError != nil)
                }
                #endif
            }
        }
    }
}
