// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// 観測履歴データレコードのプレビューリストを表示するカードビュー。
struct ObservationHistoryCard: View {
    /// 過去の観測データレコードの生のリスト。
    let rows: [DamHistoricalData]
    /// 該当する場合、過去データ検索のメタデータ。
    let meta: HistoricalSearchMeta?
    /// これが過去データ検索結果を表示しているかどうかを示す真偽値フラグ。
    let isHistorical: Bool
    /// この折りたたみ式カードの永続化された開閉状態。
    @Binding var isExpanded: Bool
    /// 表示モードを含むCard開閉キー。
    let expansionKey: DashboardCardExpansionKey

    /// 時系列の降順にソートされた日付付き履歴レコードの配列。
    private var sortedRows: [DatedHistoricalRow] {
        DashboardRowCache.descending(rows)
    }

    /// プレビューテーブルでの表示用にフォーマットされ準備された行のサブセット。
    private var displayRows: [ObservationHistoryTableRowModel] {
        let initialFrom = ObservationHistoryWindow.initialDisplayFrom(latest: sortedRows.first?.date, isHistorical: isHistorical)
        return sortedRows
            .filter { $0.date >= initialFrom }
            .map(ObservationHistoryTableRowModel.init)
    }

    /// 観測履歴カードのコンテンツとレイアウト。
    var body: some View {
        CollapsibleCard(
            title: AppText.mainHistoryData,
            isExpanded: $isExpanded,
            toggleIdentifier: expansionKey.toggleIdentifier,
            cardIdentifier: "dashboard.historyCard"
        ) {
            VStack(spacing: 14) {
                if displayRows.isEmpty {
                    ContentUnavailableView(AppText.noData, systemImage: "tablecells", description: Text(AppText.noCachedData))
                } else {
                    GeometryReader { geometry in
                        ObservationHistoryTable(
                            rows: displayRows,
                            isHistorical: isHistorical,
                            displayMode: .preview,
                            containerWidth: geometry.size.width
                        )
                        .frame(width: geometry.size.width, alignment: .topLeading)
                    }
                    .frame(height: ObservationHistoryTable.preferredHeight(rowCount: displayRows.count))
                    .padding(.bottom, ObservationHistoryTable.previewBottomControlSpacing)
                }

                NavigationLink(value: DashboardRoute.fullHistory) {
                    Text(AppText.showFullHistory)
                        .macCardBodyFont()
#if os(macOS)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 26)
                        .padding(.vertical, 3)
                        .foregroundStyle(.primary)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
#else
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 26)
                        .padding(.vertical, 3)
                        .foregroundStyle(.primary)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
#endif
                        .accessibilityIdentifier("dashboard.history.full")
                }
#if os(macOS)
                .buttonStyle(.plain)
#else
                .buttonStyle(.plain)
#endif
                .disabled(sortedRows.isEmpty)
                .accessibilityIdentifier("dashboard.history.full")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("dashboard.historyCard")
        }
    }
}
