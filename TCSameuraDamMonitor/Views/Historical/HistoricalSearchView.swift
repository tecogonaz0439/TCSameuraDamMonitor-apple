// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// 過去データ検索を実行するためのインターフェース詳細を提供するビュー。
struct HistoricalSearchView: View {
    /// 環境から提供されるディスミス（画面を閉じる）アクション。
    @Environment(\.dismiss) private var dismiss
    /// 状態とビジネスロジックを保持するアプリケーションモデル。
    let appModel: DamAppModel
    /// 選択されたダムIDを保持するローカル状態。
    @State private var damId: String
    /// 選択された開始日を保持するローカル状態。
    @State private var startDate = DisplayFormatters.thirtyDaysAgoStart()
    /// 選択された終了日を保持するローカル状態。
    @State private var endDate = DisplayFormatters.yesterdayStart()

    /// 新しい過去データ検索ビューを初期化します。
    /// - Parameter appModel: アプリケーションモデル。
    init(appModel: DamAppModel) {
        self.appModel = appModel
        _damId = State(initialValue: appModel.settings.targetDamId)
    }

    /// 過去データ検索で許容される最も古い日付。
    private var earliestDate: Date { HistoricalSearchDatePolicy.earliestDate }

    /// 選択されたダムの設定を解決します。
    private var selectedDam: DamConfig? {
        DamListData.dam(id: damId)
    }

    /// 日付範囲の制約を検証し、無効な場合はエラーメッセージを返します。
    private var validationError: String? {
        HistoricalSearchDatePolicy.validate(
            start: startDate,
            end: endDate,
            existingSearches: appModel.historicalMetaList.map { ($0.damConfigId, $0.searchBgnDate, $0.searchEndDate) },
            damId: damId,
            now: Date(),
            historicalDataSource: appModel.settings.debugModeEnabled ? .sudmonitor : appModel.settings.historicalDataSource,
            loadedDailyHistory: loadedDailyHistory
        )?.localizedDescription
    }

    /// 選択ダムの読込済み sudmonitor 日次過去データの期間（yyyyMMdd）。未読込・対象外ダムは nil。
    private var loadedDailyHistory: (start: String, end: String)? {
        guard let record = appModel.sudmonitorHistoryRecord, record.damId == damId else { return nil }
        return (record.periodStartDay, record.periodEndDay)
    }

    /// 過去データ検索ビューのコンテンツとレイアウト。
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    damSelectionControl
                    startDatePicker
                    endDatePicker
                } header: {
                    #if os(macOS)
                    Text(AppText.historicalSearchTitle)
                    #endif
                } footer: {
                    Text(periodNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let validationError {
                    Text(validationError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("historicalSearch.validationError")
                }
                if appModel.isHistoricalLoading {
                    ProgressView(AppText.historicalSearchSearching)
                        .accessibilityIdentifier("historicalSearch.progress")
                }
            }
            #if !os(macOS)
            .navigationTitle(AppText.historicalSearchTitle)
            #endif
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            .accessibilityIdentifier("historicalSearch.root")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppText.cancel) { dismiss() }
                        .accessibilityIdentifier("historicalSearch.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(appModel.isHistoricalLoading ? AppText.historicalSearchSearching : AppText.historicalSearchButton) {
                        guard validationError == nil, let dam = DamListData.dam(id: damId) else { return }
                        Task {
                            await appModel.searchHistorical(
                                damConfig: dam,
                                startDate: DisplayFormatters.startOfJSTDay(startDate),
                                endDate: DisplayFormatters.startOfJSTDay(endDate)
                            )
                            if appModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(appModel.isHistoricalLoading || validationError != nil)
                    .accessibilityIdentifier("historicalSearch.submit")
                }
            }
        }
    }

    /// ダム選択コントロール。
    @ViewBuilder
    private var damSelectionControl: some View {
        #if os(macOS)
        LabeledContent {
            Menu {
                if let sameuraDam = DamListData.dam(id: AppSettings.defaultDamId) {
                    historicalDamMenuButton(sameuraDam)
                    Divider()
                }
                ForEach(DamListData.allDams) { dam in
                    historicalDamMenuButton(dam)
                }
            } label: {
                HStack(spacing: 6) {
                    Text(DisplayFormatters.localizedDamName(selectedDam))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        } label: {
            Text(AppText.historicalSearchDam)
        }
        .disabled(appModel.isHistoricalLoading)
        .accessibilityIdentifier("historicalSearch.dam")
        #else
        NavigationLink {
            DamPickerView(
                selectedDamId: $damId,
                accessibilityPrefix: "historicalSearch"
            )
        } label: {
            HStack {
                Text(AppText.historicalSearchDam)
                Spacer()
                Text(DisplayFormatters.localizedDamName(selectedDam))
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(appModel.isHistoricalLoading)
        .accessibilityIdentifier("historicalSearch.dam")
        #endif
    }

    /// 開始日ピッカー。
    private var startDatePicker: some View {
        DatePicker(AppText.historicalSearchStartDate, selection: $startDate, in: earliestDate...DisplayFormatters.yesterdayStart(), displayedComponents: .date)
            .disabled(appModel.isHistoricalLoading)
            .accessibilityIdentifier("historicalSearch.startDate")
            .onChange(of: startDate) { _, newStart in
                let adjusted = HistoricalSearchDatePolicy.adjustedRangeAfterStartChange(start: newStart, end: endDate)
                startDate = adjusted.start
                endDate = adjusted.end
            }
    }

    /// 終了日ピッカー。
    private var endDatePicker: some View {
        DatePicker(AppText.historicalSearchEndDate, selection: $endDate, in: earliestDate...DisplayFormatters.yesterdayStart(), displayedComponents: .date)
            .disabled(appModel.isHistoricalLoading)
            .accessibilityIdentifier("historicalSearch.endDate")
            .onChange(of: endDate) { _, newEnd in
                let adjusted = HistoricalSearchDatePolicy.adjustedRangeAfterEndChange(start: startDate, end: newEnd)
                startDate = adjusted.start
                endDate = adjusted.end
            }
    }

    /// 検索対象期間の注記。
    private var periodNote: String {
        AppText.historicalSearchPeriodNote(
            start: DisplayFormatters.displayDate(DisplayFormatters.startOfJSTDay(startDate)),
            endNextDay: DisplayFormatters.displayDate(Calendar.jst.date(byAdding: .day, value: 1, to: DisplayFormatters.startOfJSTDay(endDate)) ?? endDate)
        )
    }

    /// macOS の過去検索ダムメニュー項目。
    @ViewBuilder
    private func historicalDamMenuButton(_ dam: DamConfig) -> some View {
        Button {
            damId = dam.id
        } label: {
            Text(historicalDamMenuItemText(dam, isSelected: dam.id == damId))
        }
    }
}

/// macOS の標準 Picker メニュー向けに、1行でダム名と所在地を表記します。
private func historicalDamMenuText(_ dam: DamConfig) -> String {
    let location: String
    if AppLocale.isJapanese {
        location = "\(dam.prefecture) / \(dam.waterSystem) / \(dam.river)"
    } else {
        location = "\(dam.prefectureEn) / \(dam.waterSystemEn) / \(dam.riverEn)"
    }
    return "\(DisplayFormatters.localizedDamName(dam)) (\(location))"
}

/// Menu 内の項目インデントを揃えるため、選択記号または同幅相当の空白を先頭へ付与します。
private func historicalDamMenuItemText(_ dam: DamConfig, isSelected: Bool) -> String {
    "\(isSelected ? "✓" : "  ") \(historicalDamMenuText(dam))"
}
