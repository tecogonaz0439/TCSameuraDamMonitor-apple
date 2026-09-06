// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// ダムに関連付けられた様々な情報源のWebリソースへのリンクを表示するカードビュー。
struct SourceLinksCard: View {
    /// ダムの設定詳細。
    let damConfig: DamConfig?
    /// 最後にデータを取得した日時のタイムスタンプ。
    let lastFetchTime: Date?
    /// この折りたたみ式カードの永続化された開閉状態。
    @Binding var isExpanded: Bool
    /// 表示モードを含むCard開閉キー。
    let expansionKey: DashboardCardExpansionKey

    /// 情報源リンクカードのコンテンツとレイアウト。
    var body: some View {
        CollapsibleCard(
            title: AppText.mainURLCardTitle,
            isExpanded: $isExpanded,
            toggleIdentifier: expansionKey.toggleIdentifier,
            cardIdentifier: "dashboard.sourceCard"
        ) {
            VStack(spacing: 8) {
                if let damConfig {
                    if !damConfig.disasterInfoUrl.isEmpty {
                        LinkRow(label: AppText.urlDisaster, title: damConfig.disasterInfoUrl, url: damConfig.disasterInfoUrl, alignValueTrailing: true)
                    }
                    if !damConfig.siteInfoUrl.isEmpty {
                        LinkRow(label: AppText.urlSiteInfo, title: damConfig.siteInfoUrl, url: damConfig.siteInfoUrl, alignValueTrailing: true)
                    }
                    if !damConfig.dataUrl.isEmpty {
                        LinkRow(label: AppText.urlData, title: damConfig.dataUrl, url: damConfig.dataUrl, alignValueTrailing: true)
                    }
                    let searchURL = damConfig.historicalSearchUrl(startDate: "20200101", endDate: "20200101")
                    if !searchURL.isEmpty {
                        LinkRow(label: AppText.urlSearch, title: searchURL, url: searchURL, alignValueTrailing: true)
                    }
                    ForEach(damConfig.otherUrls, id: \.url) { item in
                        if !item.url.isEmpty {
                            LinkRow(label: item.title, title: item.url, url: item.url, alignValueTrailing: true)
                        }
                    }
                }
            }
        }
    }
}
