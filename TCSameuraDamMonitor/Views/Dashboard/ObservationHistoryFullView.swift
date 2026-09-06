// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// 詳細なスクロール可能グリッドレイアウトで、完全な観測履歴データレコードを表示するビュー。
struct ObservationHistoryFullView: View {
    /// 過去の観測データレコードの生のリスト。
    let rows: [DamHistoricalData]
    /// これが過去データ検索結果を表示しているかどうかを示す真偽値フラグ。
    let isHistorical: Bool

    /// 水平方向の外余白のパディング境界。
    private let screenPadding: CGFloat = 16
    /// 内部テーブルを囲む外側レイアウト余白のパディング。
    private let cardPadding: CGFloat = 16

    /// グリッド構造での表示用にフォーマットされたマッピング済みの行アイテム。
    private var tableRows: [ObservationHistoryTableRowModel] {
        DashboardRowCache.descending(rows).map(ObservationHistoryTableRowModel.init)
    }

    /// 観測履歴詳細ビューのコンテンツとレイアウト。
    var body: some View {
        content
            .navigationTitle(AppText.fullHistory)
            .accessibilityIdentifier("dashboard.history.fullView")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
    }

    /// 行が利用可能かどうかに基づいてレイアウト表現を生成します。
    @ViewBuilder
    private var content: some View {
        if tableRows.isEmpty {
            ContentUnavailableView(AppText.noData, systemImage: "tablecells", description: Text(AppText.noCachedData))
        } else {
            GeometryReader { geometry in
                fullTable(width: geometry.size.width)
            }
        }
    }

    /// 詳細なグリッドレイアウトを描画します。
    /// - Parameter width: 水平レイアウト制約の幅境界。
    /// - Returns: 詳細なデータリストテーブルビューを含む、装飾されたカード。
    private func fullTable(width: CGFloat) -> some View {
        let cardWidth = max(width - screenPadding * 2, 0)
        let tableWidth = max(cardWidth - cardPadding * 2, 0)
        return CardContainer {
            ObservationHistoryTable(
                rows: tableRows,
                isHistorical: isHistorical,
                displayMode: .full,
                containerWidth: tableWidth
            )
                .frame(width: tableWidth, alignment: .topLeading)
                .frame(maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: cardWidth, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .padding(screenPadding)
    }
}
