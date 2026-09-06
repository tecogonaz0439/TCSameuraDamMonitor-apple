// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
#if os(macOS)
import AppKit
#endif

/// 早明浦ダムおよびその他のダムのナビゲーションとアクションを提供するサイドバービュー。
struct SidebarView: View {
    /// 状態とビジネスロジックを保持するアプリケーションモデル。
    let appModel: DamAppModel
    /// 現在選択されているナビゲーション項目。
    @Binding var selection: DamAppModel.DetailSelection?
    /// スナックバーメッセージを表示するためのコールバック関数。
    let onSnackbar: (String) -> Void

    /// サイドバービューのコンテンツとレイアウト。
    var body: some View {
        #if os(macOS)
        macSidebarContent
        #else
        List(selection: $selection) {
            Section {
                SidebarRealtimeLabel(
                    data: appModel.damData,
                    damConfig: appModel.currentDamConfig,
                    settings: appModel.settings,
                    damLoadStatus: appModel.damLoadStatus,
                    isSelected: selection == .realtime
                )
                .foregroundStyle(.primary)
                .tag(DamAppModel.DetailSelection.realtime)
                .accessibilityLabel(AppText.navRealtimeData)
                .accessibilityIdentifier("nav.realtime")
            } header: {
                Text(AppText.navRealtimeData)
                    .macSidebarCaptionFont()
            }

            if appModel.isSudmonitorHistoryAvailable {
                Section {
                    SidebarSudmonitorHistoryLabel(appModel: appModel)
                        .foregroundStyle(.primary)
                        .tag(DamAppModel.DetailSelection.sudmonitorHistory)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("nav.sudmonitorHistory")
                } header: {
                    Text(AppText.navSudmonitorHistory)
                        .macSidebarCaptionFont()
                }
            }

            Section {
                ForEach(appModel.navigationMetaList) { meta in
                    SidebarHistoricalLabel(meta: meta)
                        .foregroundStyle(.primary)
                        .tag(DamAppModel.DetailSelection.historical(meta.id))
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("nav.historicalSaved")
                }

                Button {
                    if appModel.historicalMetaList.count >= DamAppModel.maxHistoricalSearchCount {
                        onSnackbar(AppText.historicalSearchMaxCountSnackbar(DamAppModel.maxHistoricalSearchCount))
                    } else {
                        appModel.showHistoricalSearch = true
                    }
                } label: {
                    macSidebarSimpleLabel(AppText.navHistoricalSearch, systemImage: "magnifyingglass")
                        .macSidebarButtonLabelFrame()
                }
                .accessibilityLabel(AppText.navHistoricalSearch)
                .accessibilityIdentifier("nav.historicalSearch")
                .foregroundStyle(.primary)
                .macSidebarPlainButton()

                macSidebarSimpleLabel(AppText.navHistoricalManage, systemImage: "list.bullet.rectangle")
                    .foregroundStyle(.primary)
                    .tag(DamAppModel.DetailSelection.historicalManage)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(AppText.navHistoricalManage)
                    .accessibilityIdentifier("nav.historicalManage")
            } header: {
                Text(AppText.navHistoricalData)
                    .macSidebarCaptionFont()
            }

            Section {
                SourceLinkButton(
                    urlString: "https://www1.river.go.jp/",
                    label: AppText.navSourceDB,
                    systemImage: "link"
                )
                SourceLinkButton(
                    urlString: "https://www1.river.go.jp/WDBrules_20251210.pdf",
                    label: AppText.navSourcePDL,
                    systemImage: "doc.text"
                )
                Text(AppText.navSourceCredit(DisplayFormatters.date(appModel.displayedRealtimeFetchTime)))
                    .macSidebarCaptionFont()
                    .foregroundStyle(.secondary)
                    .macSidebarLineLimit(3)
                    .macSidebarFixedVertical()
            } header: {
                Text(AppText.navSource)
                    .macSidebarCaptionFont()
            }

            Section {
                if appModel.settings.debugSettingsVisible {
                    macSidebarSimpleLabel(AppText.navDebug, systemImage: "wrench.and.screwdriver")
                        .foregroundStyle(.primary)
                        .tag(DamAppModel.DetailSelection.debug)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(AppText.navDebug)
                        .accessibilityIdentifier("nav.debug")
                }
                macSidebarSimpleLabel(AppText.navSettings, systemImage: "gearshape")
                    .foregroundStyle(.primary)
                    .tag(DamAppModel.DetailSelection.settings)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(AppText.navSettings)
                    .accessibilityIdentifier("nav.settings")
                macSidebarSimpleLabel(AppText.navAppInfo, systemImage: "info.circle")
                    .foregroundStyle(.primary)
                    .tag(DamAppModel.DetailSelection.appInfo)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(AppText.navAppInfo)
                    .accessibilityIdentifier("nav.appInfo")
            }
        }
        .accessibilityIdentifier("nav.sidebar")
        #endif
    }

    #if os(macOS)
    /// macOS向けの固定メトリクスサイドバー。`List(selection:)` の行高がシステムのテキストサイズに追従するため、独自行で構成する。
    private var macSidebarContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text(AppText.appName)
                    .font(.system(size: NSFont.systemFontSize + 2, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                    .accessibilityIdentifier("nav.sidebarTitle")

                macSidebarSection(AppText.navRealtimeData) {
                    macSidebarNavigationRow(selectionValue: .realtime, rowHeight: 60) {
                        let realtimeSelected = selection == .realtime
                        SidebarRealtimeLabel(
                            data: appModel.damData,
                            damConfig: appModel.currentDamConfig,
                            settings: appModel.settings,
                            damLoadStatus: appModel.damLoadStatus,
                            isSelected: realtimeSelected
                        )
                        .accessibilityLabel(AppText.navRealtimeData)
                        .accessibilityIdentifier("nav.realtime")
                    }
                }

                if appModel.isSudmonitorHistoryAvailable {
                    macSidebarSection(AppText.navSudmonitorHistory) {
                        macSidebarNavigationRow(selectionValue: .sudmonitorHistory, rowHeight: 60) {
                            SidebarSudmonitorHistoryLabel(appModel: appModel)
                                .accessibilityElement(children: .combine)
                                .accessibilityIdentifier("nav.sudmonitorHistory")
                        }
                    }
                }

                macSidebarSection(AppText.navHistoricalData) {
                    ForEach(appModel.navigationMetaList) { meta in
                        macSidebarNavigationRow(selectionValue: .historical(meta.id), rowHeight: 60) {
                            SidebarHistoricalLabel(meta: meta)
                                .accessibilityElement(children: .combine)
                                .accessibilityIdentifier("nav.historicalSaved")
                        }
                    }

                    macSidebarActionRow {
                        if appModel.historicalMetaList.count >= DamAppModel.maxHistoricalSearchCount {
                            onSnackbar(AppText.historicalSearchMaxCountSnackbar(DamAppModel.maxHistoricalSearchCount))
                        } else {
                            appModel.showHistoricalSearch = true
                        }
                    } label: {
                        macSidebarSimpleLabel(AppText.navHistoricalSearch, systemImage: "magnifyingglass")
                            .foregroundStyle(.primary)
                            .accessibilityLabel(AppText.navHistoricalSearch)
                            .accessibilityIdentifier("nav.historicalSearch")
                    }

                    macSidebarNavigationRow(selectionValue: .historicalManage) {
                        macSidebarSimpleLabel(AppText.navHistoricalManage, systemImage: "list.bullet.rectangle")
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(AppText.navHistoricalManage)
                            .accessibilityIdentifier("nav.historicalManage")
                    }
                }

                macSidebarSection(AppText.navSource) {
                    SourceLinkButton(
                        urlString: "https://www1.river.go.jp/",
                        label: AppText.navSourceDB,
                        systemImage: "link"
                    )
                    .macSidebarFixedRow(height: 36)
                    SourceLinkButton(
                        urlString: "https://www1.river.go.jp/WDBrules_20251210.pdf",
                        label: AppText.navSourcePDL,
                        systemImage: "doc.text"
                    )
                    .macSidebarFixedRow(height: 36)
                    Text(AppText.navSourceCredit(DisplayFormatters.date(appModel.displayedRealtimeFetchTime)))
                        .macSidebarCaptionFont()
                        .foregroundStyle(.secondary)
                        .macSidebarLineLimit(3)
                        .macSidebarFixedVertical()
                        .macSidebarFixedRow(height: 58)
                }

                macSidebarSection {
                    if appModel.settings.debugSettingsVisible {
                        macSidebarNavigationRow(selectionValue: .debug) {
                            macSidebarSimpleLabel(AppText.navDebug, systemImage: "wrench.and.screwdriver")
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(AppText.navDebug)
                                .accessibilityIdentifier("nav.debug")
                        }
                    }
                    macSidebarNavigationRow(selectionValue: .settings) {
                        macSidebarSimpleLabel(AppText.navSettings, systemImage: "gearshape")
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(AppText.navSettings)
                            .accessibilityIdentifier("nav.settings")
                    }
                    macSidebarNavigationRow(selectionValue: .appInfo) {
                        macSidebarSimpleLabel(AppText.navAppInfo, systemImage: "info.circle")
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(AppText.navAppInfo)
                            .accessibilityIdentifier("nav.appInfo")
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .accessibilityIdentifier("nav.sidebar")
    }

    /// 見出し付きのmacOSサイドバーセクションを生成します。
    /// - Parameters:
    ///   - title: セクション見出し。nilの場合は見出しを表示しない。
    ///   - content: セクション内の行。
    /// - Returns: 固定余白のセクションビュー。
    private func macSidebarSection<Content: View>(
        _ title: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .macSidebarCaptionFont()
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer()
                    .frame(height: 10)
            }
            content()
        }
    }

    /// 選択状態を持つmacOSサイドバー行を生成します。
    /// - Parameters:
    ///   - selectionValue: 選択時に設定する詳細画面。
    ///   - label: 行の表示内容。
    /// - Returns: 固定行メトリクスのナビゲーションボタン。
    private func macSidebarNavigationRow<Content: View>(
        selectionValue: DamAppModel.DetailSelection,
        rowHeight: CGFloat = 36,
        @ViewBuilder label: () -> Content
    ) -> some View {
        let isSelected = selection == selectionValue
        return Button {
            selection = selectionValue
        } label: {
            label()
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .macSidebarFixedRow(height: rowHeight, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    /// 選択状態を持たないmacOSサイドバー操作行を生成します。
    /// - Parameters:
    ///   - action: 押下時の処理。
    ///   - label: 行の表示内容。
    /// - Returns: 固定行メトリクスの操作ボタン。
    private func macSidebarActionRow<Content: View>(
        rowHeight: CGFloat = 36,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Content
    ) -> some View {
        Button(action: action) {
            label()
                .macSidebarFixedRow(height: rowHeight)
        }
        .buttonStyle(.plain)
    }
    #endif
}

/// サイドバーにリアルタイム観測データを表示するラベルビュー。
struct SidebarRealtimeLabel: View {
    /// ダムのリアルタイム観測データ。
    let data: DamData?
    /// ダムの設定詳細。
    let damConfig: DamConfig?
    /// アプリケーション設定。
    let settings: AppSettings
    /// ダムデータの読み込みプロセスのステータス。
    let damLoadStatus: DamLoadStatus
    /// サイドバー行が選択状態かどうか（選択ハイライト時のトレンド色抑制に使用）。
    var isSelected: Bool = false

    /// リアルタイム観測データラベルのコンテンツとレイアウト。
    var body: some View {
        let lines = RealtimeStatusMenuLines.make(
            data: data,
            damConfig: damConfig,
            settings: settings,
            damLoadStatus: damLoadStatus
        )
        macSidebarIconLabel(systemImage: "chart.line.uptrend.xyaxis") {
            realtimeContent(lines: lines)
        }
        .accessibilityElement(children: .combine)
        .macSidebarVerticalPadding()
    }

    /// リアルタイム観測データラベルのテキストコンテンツ。
    /// - Parameter lines: 表示対象の行データ。
    /// - Returns: サイドバー行内のテキスト群。
    private func realtimeContent(lines: RealtimeStatusMenuLines) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(lines.title)
                    .macSidebarBodyFont()
                    .macSidebarLineLimit(1)
            if let detail = lines.detail {
                HStack(spacing: 4) {
                    #if os(macOS)
                    // macOS と iOS/iPadOS は将来の変更に備えて分離
                    if let timeText = lines.timeText {
                        Text(timeText)
                    }
                    if let percentText = lines.percentText {
                        Text(percentText)
                            .foregroundStyle(realtimeDetailForegroundStyle(lines.trend, isSelected: isSelected))
                    }
                    #else
                    if let timeText = lines.timeText {
                        Text(timeText)
                    }
                    if let percentText = lines.percentText {
                        Text(percentText)
                            .foregroundStyle(realtimeDetailForegroundStyle(lines.trend, isSelected: isSelected))
                    }
                    #endif
                    if lines.trend != .unknown {
                        #if os(macOS)
                        // macOS と iOS/iPadOS は将来の変更に備えて分離
                        Image(systemName: DisplayFormatters.trendSystemImage(lines.trend))
                            .foregroundStyle(realtimeDetailForegroundStyle(lines.trend, isSelected: isSelected))
                            .accessibilityLabel(DisplayFormatters.trendLabel(lines.trend))
                        #else
                        Image(systemName: DisplayFormatters.trendSystemImage(lines.trend))
                            .foregroundStyle(realtimeDetailForegroundStyle(lines.trend, isSelected: isSelected))
                            .accessibilityLabel(DisplayFormatters.trendLabel(lines.trend))
                        #endif
                    }
                }
                .macSidebarCaptionFont()
                if let status = lines.status {
                    Text(status)
                        .macSidebarCaptionFont()
                        .macSidebarLineLimit(1)
                }
            } else if let status = lines.status {
                Text(status)
                    .macSidebarCaptionFont()
                    .macSidebarLineLimit(1)
            }
        }
    }

    /// リアルタイム詳細行の前景色。macOS と iOS/iPadOS は将来の変更に備えて分離。
    /// - Parameters:
    ///   - trend: 貯水率の推移。
    ///   - isSelected: 選択状態の場合にトレンド色を抑制する。
    /// - Returns: 詳細行に適用する色。
    private func realtimeDetailForegroundStyle(_ trend: Trend, isSelected: Bool = false) -> Color {
        #if os(macOS)
        // macOS と iOS/iPadOS は将来の変更に備えて分離
        // 選択時は選択ハイライト背景上での可読性を優先しトレンド色を使わない
        if isSelected { return .white }
        return Self.shouldUseTrendColor(trend, isSelected: isSelected) ? DisplayFormatters.trendColor(trend) : .primary
        #else
        Self.shouldUseTrendColor(trend, isSelected: isSelected) ? DisplayFormatters.trendColor(trend) : .primary
        #endif
    }

    /// サイドバーの選択状態を考慮してトレンド色を適用するか判定します。
    /// - Parameters:
    ///   - trend: 貯水率の推移。
    ///   - isSelected: サイドバー行が選択状態かどうか。
    /// - Returns: 未選択かつ上昇・下降の場合は `true`。
    static func shouldUseTrendColor(_ trend: Trend, isSelected: Bool) -> Bool {
        !isSelected && DisplayFormatters.usesTrendColor(trend)
    }
}

/// サイドバーに過去データ検索のメタデータを表示するラベルビュー。
struct SidebarHistoricalLabel: View {
    /// 過去データ検索のメタデータ。
    let meta: HistoricalSearchMeta

    /// 過去データ検索ラベルのコンテンツとレイアウト。
    var body: some View {
        macSidebarIconLabel(systemImage: meta.isPinned ? "pin.fill" : "chart.xyaxis.line") {
            VStack(alignment: .leading, spacing: 3) {
                Text(DisplayFormatters.localizedDamName(DamListData.dam(id: meta.damConfigId)))
                    .macSidebarBodyFont()
                    .macSidebarLineLimit(1)
                Text(DisplayFormatters.historicalPeriodLine(meta))
                    .macSidebarCaptionFont()
                    .macSidebarLineLimit(1)
                Text(DisplayFormatters.historicalRangeLine(meta))
                    .macSidebarCaptionFont()
                    .macSidebarLineLimit(1)
            }
            .macSidebarTextColumnFrame()
        }
        .accessibilityElement(children: .combine)
        .macSidebarVerticalPadding()
    }
}

/// サイドバーに sudmonitor 日次過去データの読込状態を表示するラベルビュー。
struct SidebarSudmonitorHistoryLabel: View {
    /// 状態とビジネスロジックを保持するアプリケーションモデル。
    let appModel: DamAppModel

    /// 日次過去データラベルのコンテンツとレイアウト。
    var body: some View {
        macSidebarIconLabel(systemImage: "chart.xyaxis.line") {
            VStack(alignment: .leading, spacing: 3) {
                Text(DisplayFormatters.localizedDamName(appModel.currentDamConfig))
                    .macSidebarBodyFont()
                    .macSidebarLineLimit(1)
                Text(appModel.sudmonitorHistoryRecord.map { DisplayFormatters.sudmonitorHistoryPeriodLine($0) } ?? "")
                    .macSidebarCaptionFont()
                    .macSidebarLineLimit(1)
                Text(DisplayFormatters.sudmonitorHistoryRangeLine(appModel.sudmonitorHistoryRows))
                    .macSidebarCaptionFont()
                    .macSidebarLineLimit(1)
            }
            .macSidebarTextColumnFrame()
        }
        .accessibilityElement(children: .combine)
        .macSidebarVerticalPadding()
    }
}

@ViewBuilder
private func macSidebarSimpleLabel(
    _ title: String,
    systemImage: String
) -> some View {
    #if os(macOS)
    macSidebarIconLabel(systemImage: systemImage) {
        Text(title)
            .macSidebarBodyFont()
    }
    #else
    Label(title, systemImage: systemImage)
    #endif
}

@ViewBuilder
private func macSidebarIconLabel<Content: View>(
    systemImage: String,
    @ViewBuilder content: () -> Content
) -> some View {
    #if os(macOS)
    HStack(alignment: .center, spacing: 8) {
        Image(systemName: systemImage)
            .macSidebarBodyFont()
            .frame(width: 20)
        content()
            .macSidebarTextColumnFrame()
    }
    #else
    Label {
        content()
    } icon: {
        Image(systemName: systemImage)
    }
    #endif
}

private extension View {
    @ViewBuilder
    func macSidebarLineLimit(_ limit: Int) -> some View {
        #if os(macOS)
        self.lineLimit(limit)
        #else
        self
        #endif
    }

    @ViewBuilder
    func macSidebarVerticalPadding() -> some View {
        #if os(macOS)
        self.padding(.vertical, 6)
        #else
        self
        #endif
    }

    @ViewBuilder
    func macSidebarFixedVertical() -> some View {
        #if os(macOS)
        self.fixedSize(horizontal: false, vertical: true)
        #else
        self
        #endif
    }

    @ViewBuilder
    func macSidebarTextColumnFrame() -> some View {
        #if os(macOS)
        self.frame(maxWidth: .infinity, alignment: .leading)
        #else
        self
        #endif
    }

    @ViewBuilder
    func macSidebarBodyFont() -> some View {
        #if os(macOS)
        self.font(.system(size: NSFont.systemFontSize))
        #else
        self
        #endif
    }

    @ViewBuilder
    func macSidebarCaptionFont() -> some View {
        #if os(macOS)
        self.font(.system(size: NSFont.smallSystemFontSize))
        #else
        self.font(.caption)
        #endif
    }

    @ViewBuilder
    func macSidebarButtonLabelFrame() -> some View {
        #if os(macOS)
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        #else
        self
        #endif
    }

    @ViewBuilder
    func macSidebarPlainButton() -> some View {
        #if os(macOS)
        self.buttonStyle(.plain)
        #else
        self
        #endif
    }

    @ViewBuilder
    func macSidebarFixedRow(height: CGFloat, isSelected: Bool = false) -> some View {
        #if os(macOS)
        self
            .frame(height: height, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            }
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .clipped()
        #else
        self
        #endif
    }
}
