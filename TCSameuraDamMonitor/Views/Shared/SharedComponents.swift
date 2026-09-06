// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif
import MapKit

import TCSameuraDamCore

/// リンクをコピーまたは共有するオプションが付いた、Webリソースのリンクを表示するボタン。
struct SourceLinkButton: View {
    /// 遷移先URLの文字列。
    let urlString: String
    /// ボタンに表示するテキストラベル。
    let label: String
    /// アイコンとして使用するシステム画像の名前。
    let systemImage: String
    /// 確認ダイアログの表示を制御するローカル状態。
    @State private var showMenu = false
    #if os(macOS)
    /// macOS共有ピッカーを表示中に保持する状態。
    @State private var activeSharePicker: NSSharingServicePicker?
    #endif
    /// urlString から解析された遷移先 URL。
    private var url: URL? {
        URL(string: urlString)
    }

    /// 情報源リンクボタンのコンテンツとレイアウト。
    var body: some View {
        Button {
            #if os(macOS)
            presentMacSourceLinkAlert()
            #else
            showMenu = true
            #endif
        } label: {
            sourceLinkLabel
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .foregroundStyle(.primary)
        .buttonStyle(.plain)
        #if !os(macOS)
        .confirmationDialog(
            label,
            isPresented: $showMenu,
            titleVisibility: .visible
        ) {
            Button(AppText.copyLinkTitle) {
                copyToClipboard(text: label)
            }
            ShareLink(item: label) {
                Text(AppText.shareLinkTitle)
            }
            if let url {
                Link(AppText.openURL, destination: url)
            }
            ShareLink(item: urlString) {
                Text(AppText.shareURL)
            }
        } message: {
            Text(AppText.selectLinkAction)
        }
        #endif
    }

    /// macOSではサイドバー行と同じ固定配置にして、システムのテキストサイズ変更による余白変動を避ける。
    private var sourceLinkLabel: some View {
        #if os(macOS)
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: systemImage)
                .macSourceLinkBodyFont()
                .frame(width: 20)
            Text(label)
                .macSourceLinkBodyFont()
        }
        #else
        Label(label, systemImage: systemImage)
        #endif
    }

    #if os(macOS)
    /// macOSで出典リンク操作をNSAlertとして表示します。
    private func presentMacSourceLinkAlert() {
        presentMacActionAlert(
            title: label,
            message: AppText.selectLinkAction,
            actions: [
                MacAlertAction(title: AppText.copyLinkTitle) { _ in
                    copyToClipboard(text: label)
                },
                MacAlertAction(title: AppText.shareLinkTitle) { window in
                    showMacSharePicker(items: [label], window: window, activePicker: $activeSharePicker)
                },
                MacAlertAction(title: AppText.openURL, isEnabled: url != nil) { _ in
                    if let url {
                        NSWorkspace.shared.open(url)
                    }
                },
                MacAlertAction(title: AppText.shareURL) { window in
                    showMacSharePicker(items: [url ?? urlString], window: window, activePicker: $activeSharePicker)
                },
            ]
        )
    }
    #endif
}

#if os(macOS)
/// macOSのNSAlertで選択できる操作。
struct MacAlertAction {
    /// ボタンに表示するタイトル。
    let title: String
    /// 操作が有効かどうかを示すフラグ。
    let isEnabled: Bool
    /// 選択時に実行する処理。
    let handler: (NSWindow?) -> Void

    /// 新しいNSAlert操作を初期化します。
    init(title: String, isEnabled: Bool = true, handler: @escaping (NSWindow?) -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.handler = handler
    }
}

/// macOSの操作選択NSAlertを対象ウインドウのsheetとして表示します。
func presentMacActionAlert(title: String, message: String, actions: [MacAlertAction]) {
    let enabledActions = actions.filter(\.isEnabled)
    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = title
    alert.informativeText = message
    enabledActions.forEach { alert.addButton(withTitle: $0.title) }
    alert.addButton(withTitle: AppText.cancel)

    let window = NSApp.keyWindow ?? NSApp.mainWindow
    let handleResponse: (NSApplication.ModalResponse) -> Void = { response in
        let index = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        guard enabledActions.indices.contains(index) else { return }
        enabledActions[index].handler(window)
    }

    if let window {
        alert.beginSheetModal(for: window, completionHandler: handleResponse)
    } else {
        handleResponse(alert.runModal())
    }
}

/// macOS標準の共有ピッカーを表示し、表示中のインスタンスを保持します。
func showMacSharePicker(
    items: [Any],
    window: NSWindow?,
    activePicker: Binding<NSSharingServicePicker?>
) {
    DispatchQueue.main.async {
        guard let view = window?.contentView, view.window != nil else {
            return
        }
        let picker = NSSharingServicePicker(items: items)
        activePicker.wrappedValue = picker
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }
}
#endif

private extension View {
    @ViewBuilder
    func macSourceLinkBodyFont() -> some View {
        #if os(macOS)
        self.font(.system(size: NSFont.systemFontSize))
        #else
        self
        #endif
    }
}

extension View {
    @ViewBuilder
    func macCardBodyFont(iOSFont: Font = .body) -> some View {
        #if os(macOS)
        self.font(.system(size: NSFont.systemFontSize))
        #else
        self.font(iOSFont)
        #endif
    }

    @ViewBuilder
    func macCardCaptionFont(iOSFont: Font = .caption) -> some View {
        #if os(macOS)
        self.font(.system(size: NSFont.smallSystemFontSize))
        #else
        self.font(iOSFont)
        #endif
    }

    func macCardHeadlineFont() -> some View {
        macCardBodyFont(iOSFont: .headline)
    }

    @ViewBuilder
    func macCardTitleFont() -> some View {
        #if os(macOS)
        self.font(.system(size: NSFont.systemFontSize + 2))
        #else
        self.font(.title2)
        #endif
    }
}

extension View {
    @ViewBuilder
    func macCenteredSettingsContent(maxWidth: CGFloat = 600) -> some View {
        #if os(macOS)
        self
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity, alignment: .center)
        #else
        self
        #endif
    }
}

/// 過去データ検索と設定画面で共有するダム選択一覧。
struct DamPickerView: View {
    /// 環境から提供されるディスミスアクション。
    @Environment(\.dismiss) private var dismiss
    /// 選択されたダムID。
    @Binding var selectedDamId: String
    /// UIテスト用アクセシビリティ識別子の接頭辞。
    let accessibilityPrefix: String

    /// ダム選択一覧のコンテンツ。
    var body: some View {
        List {
            if let sameuraDam = DamListData.dam(id: AppSettings.defaultDamId) {
                damRow(sameuraDam)
                DamPickerDivider()
            }
            ForEach(DamListData.allDams) { dam in
                damRow(dam)
            }
        }
        .navigationTitle(AppText.historicalSearchDam)
        .listStyle(.plain)
        .macCenteredSettingsContent()
        .accessibilityIdentifier("\(accessibilityPrefix).damPicker")
    }

    /// 単一のダム選択行。
    private func damRow(_ dam: DamConfig) -> some View {
        DamPickerRow(
            dam: dam,
            isSelected: dam.id == selectedDamId,
            accessibilityIdentifier: "\(accessibilityPrefix).damPicker.row.\(dam.id)"
        ) {
            selectedDamId = dam.id
            dismiss()
        }
    }
}

/// ダム選択一覧内の選択可能な行。
private struct DamPickerRow: View {
    /// ダムの設定詳細。
    let dam: DamConfig
    /// 現在選択されているかどうか。
    let isSelected: Bool
    /// UIテスト用アクセシビリティ識別子。
    let accessibilityIdentifier: String
    /// 行選択時の処理。
    let onSelect: () -> Void

    /// ダム所在地のローカライズ済み表記。
    private var locationText: String {
        if AppLocale.isJapanese {
            return "\(dam.prefecture) / \(dam.waterSystem) / \(dam.river)"
        }
        return "\(dam.prefectureEn) / \(dam.waterSystemEn) / \(dam.riverEn)"
    }

    /// ダム選択行のコンテンツ。
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(DisplayFormatters.localizedDamName(dam))
                        .foregroundStyle(.primary)
                    Text(locationText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowSeparator(.hidden)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityValue(isSelected ? AppText.currentlySelected : "")
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

/// ダム選択一覧の先頭固定項目と全件一覧の間に表示する区切り線。
private struct DamPickerDivider: View {
    /// 区切り線のコンテンツ。
    var body: some View {
        VStack {
            Spacer(minLength: 0)
            Divider()
            Spacer(minLength: 0)
        }
        .frame(height: 8)
        .environment(\.defaultMinListRowHeight, 8)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .accessibilityHidden(true)
    }
}

/// シャドウと角丸で装飾されたカード型のコンテナビュー。
struct CardContainer<Content: View>: View {
    /// カードの内部コンテンツ。
    let content: Content

    /// ビュービルダーを使用して新しいカードコンテナを初期化します。
    /// - Parameter content: カードのコンテンツを生成するビュービルダー。
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    /// カードコンテナのコンテンツとレイアウト。
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.12), radius: 2, y: 0)
        #if os(macOS)
        .compositingGroup()
        #endif
    }
}

/// カスタムコンテンツを折りたたみ可能なセクションとして保持するカードビュー。
struct CollapsibleCard<Content: View>: View {
    /// カードのヘッダータイトル。
    let title: String
    /// カードのコンテンツが展開されているかどうかを制御するバインディング。
    @Binding var isExpanded: Bool
    /// 開閉ボタンのaccessibility/UI test識別子。
    let toggleIdentifier: String
    /// Card見出しのaccessibility/UI test識別子。
    let cardIdentifier: String
    /// 折りたたみセクションの内部コンテンツ。
    let content: Content

    /// 新しい折りたたみ式カードを初期化します。
    /// - Parameters:
    ///   - title: ヘッダーのタイトル。
    ///   - isExpanded: 展開状態を制御するバインディング。
    ///   - toggleIdentifier: 開閉ボタンのaccessibility/UI test識別子。
    ///   - content: 折りたたみコンテンツを生成するビュービルダー。
    init(
        title: String,
        isExpanded: Binding<Bool>,
        toggleIdentifier: String,
        cardIdentifier: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self._isExpanded = isExpanded
        self.toggleIdentifier = toggleIdentifier
        self.cardIdentifier = cardIdentifier
        self.content = content()
    }

    /// 折りたたみ式カードのコンテンツとレイアウト。
    var body: some View {
        CardContainer {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Text(title)
                        .macCardHeadlineFont()
                        .foregroundStyle(.tint)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier(cardIdentifier)
                    Spacer(minLength: 0)
                    Button {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .animation(.easeInOut(duration: 0.2), value: isExpanded)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(AppText.cardToggleAccessibilityLabel(title: title, isExpanded: isExpanded))
                    .accessibilityValue(isExpanded ? AppText.cardExpanded : AppText.cardCollapsed)
                    .accessibilityIdentifier(toggleIdentifier)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                if isExpanded {
                    content
                        .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                }
            }
        }
    }
}

/// シンプルなキーと値の情報行。
struct InfoRow: View {
    /// 説明用ラベル。
    let label: String
    /// ラベルに対応する値のテキスト。
    let value: String

    /// 情報行のコンテンツとレイアウト。
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .macCardBodyFont()
                .foregroundStyle(.primary)
            Spacer(minLength: 12)
            Text(value)
                .macCardBodyFont()
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

/// 地理座標リンクを含むインタラクティブな行。
struct GeoLinkRow: View {
    /// 説明用ラベル。
    let label: String
    /// 表示テキストまたは座標。
    let title: String
    /// 地図アプリのURLスキームまたはリンク。
    let url: String
    /// 確認ダイアログの表示を制御するローカル状態。
    @State private var showMenu = false
    #if os(macOS)
    /// macOS共有ピッカーを表示中に保持する状態。
    @State private var activeSharePicker: NSSharingServicePicker?
    #endif
 
    /// 地理座標リンク行のコンテンツとレイアウト。
    var body: some View {
        Group {
            if let link = URL(string: url) {
                Button {
                    #if os(macOS)
                    presentMacGeoLinkAlert(link: link)
                    #else
                    showMenu = true
                    #endif
                } label: {
                    rowContent(valueStyle: .accentColor)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                #if !os(macOS)
                .confirmationDialog(
                    title,
                    isPresented: $showMenu,
                    titleVisibility: .visible
                ) {
                    Button(AppText.copyGeoUrl) {
                        copyToClipboard(text: title)
                    }
                    ShareLink(item: title) {
                        Text(AppText.shareGeoUrl)
                    }
                    Button(AppText.openMap) {
                        openMap(link: link)
                    }
                } message: {
                    Text(AppText.selectGeoAction)
                }
                #endif
            } else {
                rowContent(valueStyle: .secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// 行のレイアウトコンテンツを描画します。
    /// - Parameter valueStyle: 値テキストに使用するカラースタイル。
    /// - Returns: ラベルと値のスタイル付きビュー表現。
    private func rowContent(valueStyle: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .macCardBodyFont()
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(title)
                .macCardBodyFont()
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
                .foregroundStyle(valueStyle)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// geo URIをApple Mapsで開きます。
    private func openMap(link: URL) {
        guard let coordinate = Self.parseGeoCoordinate(from: link) else {
            #if os(macOS)
            NSWorkspace.shared.open(link)
            #endif
            return
        }
        let placemark = MKPlacemark(coordinate: coordinate)
        MKMapItem(placemark: placemark).openInMaps()
    }

    /// geo URIから緯度・経度を抽出します。
    static func parseGeoCoordinate(from url: URL) -> CLLocationCoordinate2D? {
        guard url.scheme?.lowercased() == "geo" else { return nil }
        let coordinates = url.absoluteString
            .dropFirst("geo:".count)
            .split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
            .first?
            .split(separator: ",", maxSplits: 2)
        guard
            let coordinates,
            coordinates.count >= 2,
            let latitude = CLLocationDegrees(String(coordinates[0])),
            let longitude = CLLocationDegrees(String(coordinates[1]))
        else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    #if os(macOS)
    /// macOSでgeo URI操作をNSAlertとして表示します。
    private func presentMacGeoLinkAlert(link: URL) {
        presentMacActionAlert(
            title: title,
            message: AppText.selectGeoAction,
            actions: [
                MacAlertAction(title: AppText.copyGeoUrl) { _ in
                    copyToClipboard(text: title)
                },
                MacAlertAction(title: AppText.shareGeoUrl) { window in
                    showMacSharePicker(items: [title], window: window, activePicker: $activeSharePicker)
                },
                MacAlertAction(title: AppText.openMap) { _ in
                    openMap(link: link)
                },
            ]
        )
    }
    #endif
}

/// トレンドインジケータとステータスカラーを含む観測データを表示する行。
struct DataRow: View {
    /// パラメータ名を表すラベルテキスト。
    let label: String
    /// フォーマットされた観測値。
    let value: String
    /// 観測値のトレンドステータス。
    let trend: Trend
    /// 観測データが欠損または無効であるかを示す真偽値。
    let isMissing: Bool
    /// トレンドアイコンの描画用に割り当てられた幅。
    private let trendSlotWidth: CGFloat = 28

    /// データ行のコンテンツとレイアウト。
    var body: some View {
        HStack(alignment: .center) {
            Text(label)
                .macCardBodyFont()
                .foregroundStyle(.primary)
            Spacer(minLength: 12)
            HStack(spacing: 8) {
                Text(value)
                    .macCardBodyFont()
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(valueForegroundStyle)
                HStack {
                    Spacer(minLength: 0)
                    if !isMissing && trend != .unknown {
                        Image(systemName: DisplayFormatters.trendSystemImage(trend))
                            .macCardCaptionFont()
                            .foregroundStyle(trendIconForegroundStyle)
                            .accessibilityLabel(DisplayFormatters.trendLabel(trend))
                    }
                }
                .frame(width: trendSlotWidth)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    /// 観測値のフォアグラウンドカラースタイル。
    private var valueForegroundStyle: Color {
        if isMissing { return .secondary }
        return DisplayFormatters.usesTrendColor(trend) ? DisplayFormatters.trendColor(trend) : .primary
    }

    /// トレンドアイコンのフォアグラウンドカラースタイル。
    private var trendIconForegroundStyle: Color {
        DisplayFormatters.usesTrendColor(trend) ? DisplayFormatters.trendColor(trend) : .primary
    }
}

/// インタラクティブなリンクを表す行。
struct LinkRow: View {
    /// 説明用ラベル。
    let label: String
    /// リンクのタイトル。
    let title: String
    /// URL文字列。
    let url: String
    /// リンクの値を右端に揃えるべきかを示すフラグ。
    var alignValueTrailing = false
    /// 確認ダイアログの表示を制御するローカル状態。
    @State private var showMenu = false
    #if os(macOS)
    /// macOS共有ピッカーを表示中に保持する状態。
    @State private var activeSharePicker: NSSharingServicePicker?
    #else
    /// 環境から提供される openURL アクション。
    @Environment(\.openURL) private var openURL
    #endif

    /// リンク行のコンテンツとレイアウト。
    var body: some View {
        if let link = URL(string: url) {
            Button {
                #if os(macOS)
                presentMacLinkRowAlert(link: link)
                #else
                showMenu = true
                #endif
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .macCardBodyFont()
                        .foregroundStyle(.primary)
                    HStack {
                        if alignValueTrailing { Spacer(minLength: 12) }
                        Text(title)
                            .macCardCaptionFont()
                            .multilineTextAlignment(alignValueTrailing ? .trailing : .leading)
                            .foregroundStyle(.tint)
                    }
                    .frame(maxWidth: .infinity, alignment: alignValueTrailing ? .trailing : .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            #if !os(macOS)
            .confirmationDialog(
                label,
                isPresented: $showMenu,
                titleVisibility: .visible
            ) {
                Button(AppText.copyLinkTitle) {
                    copyToClipboard(text: label)
                }
                ShareLink(item: label) {
                    Text(AppText.shareLinkTitle)
                }
                Button(AppText.openURL) {
                    openURL(link)
                }
                ShareLink(item: url) {
                    Text(AppText.shareURL)
                }
            } message: {
                Text(AppText.selectLinkAction)
            }
            #endif
            .padding(.vertical, 4)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .macCardBodyFont()
                HStack {
                    if alignValueTrailing { Spacer(minLength: 12) }
                    Text(title)
                        .macCardCaptionFont()
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: alignValueTrailing ? .trailing : .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    #if os(macOS)
    /// macOSでURLリンク操作をNSAlertとして表示します。
    private func presentMacLinkRowAlert(link: URL) {
        presentMacActionAlert(
            title: label,
            message: AppText.selectLinkAction,
            actions: [
                MacAlertAction(title: AppText.copyLinkTitle) { _ in
                    copyToClipboard(text: label)
                },
                MacAlertAction(title: AppText.shareLinkTitle) { window in
                    showMacSharePicker(items: [label], window: window, activePicker: $activeSharePicker)
                },
                MacAlertAction(title: AppText.openURL) { _ in
                    NSWorkspace.shared.open(link)
                },
                MacAlertAction(title: AppText.shareURL) { window in
                    showMacSharePicker(items: [link], window: window, activePicker: $activeSharePicker)
                },
            ]
        )
    }
    #endif
}

/// 指定されたテキスト文字列をシステムのクリップボード/ペーストボードにコピーします。
/// - Parameter text: コピーする文字列テキスト。
func copyToClipboard(text: String) {
    #if os(iOS)
    UIPasteboard.general.string = text
    #elseif os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    #endif
}

/// FileDocument に準拠した、エクスポート可能なデータのドキュメントラッパー。
struct DataDocument: FileDocument {
    /// サポートされている読み取り可能なコンテンツタイプ。
    static var readableContentTypes: [UTType] { [.data, .commaSeparatedText, .plainText] }

    /// ファイルの生のバイナリコンテンツ。
    var data: Data
    /// UTTypeコンテンツ識別子。
    var contentType: UTType

    /// 生のデータとタイプからドキュメントを初期化します。
    /// - Parameters:
    ///   - data: バイナリコンテンツ。
    ///   - contentType: UTType分類。
    init(data: Data, contentType: UTType) {
        self.data = data
        self.contentType = contentType
    }

    /// 設定データを読み取ってドキュメントを初期化します。
    /// - Parameter configuration: 生のファイルラッパーを含むシステム読み取り設定。
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        contentType = configuration.contentType
    }

    /// ドキュメントデータを含むファイルラッパーを描画します。
    /// - Parameter configuration: 書き込み設定。
    /// - Returns: ファイルラッパーインスタンス。
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

extension DisplayFormatters {
    /// タイムライン行の時間文字列に一致するJST（日本標準時）の日付を計算します。
    /// - Parameter row: 過去の観測レコード。
    /// - Returns: 解析された日付。解析に失敗した場合は Date.distantPast。
    static func rowDate(_ row: DamHistoricalData) -> Date {
        TimeFormatters.jstDisplay.date(from: TimeFormatters.normalizeDamTime(row.time)) ?? .distantPast
    }

    /// 日付を時刻の詳細付きでフォーマットします。
    /// - Parameter date: フォーマットする日付オブジェクト。
    /// - Returns: ローカライズされた日時文字列。日本時間以外の場合はJSTインジケータを付加。
    static func dateTime(_ date: Date?) -> String {
        guard let date else { return "--" }
        let base = TimeFormatters.jstDisplay.string(from: date)
        return DamCoreJSTSupport.appendingJstSuffix(base, isLocalJst: DisplayFormatters.isJST)
    }

    /// 日付をスラッシュ区切りのフォーマットにフォーマットします。
    /// - Parameter date: フォーマットする日付オブジェクト。
    /// - Returns: ローカライズされた日付文字列。nil の場合はプレースホルダー。
    static func date(_ date: Date?) -> String {
        guard let date else { return "--" }
        return TimeFormatters.jstDateSlash.string(from: date)
    }
}

extension String {
    /// 元の文字列が空の場合はフォールバックを返します。
    /// - Parameter fallback: 元の文字列が空の場合に使用する文字列。
    /// - Returns: 解決された文字列。
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}

extension View {
    /// バインディングテキストが設定されているときに、現在のビューにスナックバーメッセージをオーバーレイします。
    /// - Parameter message: メッセージのテキストコンテンツを含むバインディング。
    /// - Returns: スナックバーオーバーレイを表示するように変更されたビュー。
    func snackbarMessage(_ message: Binding<String?>) -> some View {
        modifier(SnackbarMessageModifier(message: message))
    }
}

/// スナックバーバナーを表示し、自動的に消去するビューモディファイア。
private struct SnackbarMessageModifier: ViewModifier {
    /// 現在のカラースキーム。
    @Environment(\.colorScheme) private var colorScheme
    /// メッセージのテキストコンテンツを含むバインディング。
    @Binding var message: String?
    /// スケジュール実行タスクを追跡する一意の状態ID。
    @State private var dismissID = UUID()

    /// スナックバーのレイアウトでコンテンツビューを変更します。
    /// - Parameter content: オーバーレイするビューボディ。
    /// - Returns: 変更されたビュー。
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(snackbarForegroundColor)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: 520, alignment: .leading)
                        .background(snackbarBackgroundColor, in: RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.32 : 0.18), radius: 3, y: 1)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .accessibilityAddTraits(.isStaticText)
                        .accessibilityIdentifier("snackbar.message")
                }
            }
            .animation(.snappy, value: message)
            .onChange(of: message) { _, newValue in
                guard newValue != nil else { return }
                announceAccessibility(newValue)
                let currentID = UUID()
                dismissID = currentID
                Task {
                    try? await Task.sleep(for: .seconds(4))
                    await MainActor.run {
                        if dismissID == currentID {
                            message = nil
                        }
                    }
                }
            }
    }

    /// Snackbarの背景色。
    private var snackbarBackgroundColor: Color {
        colorScheme == .dark ? .white.opacity(0.94) : .black.opacity(0.88)
    }

    /// Snackbarの文字色。
    private var snackbarForegroundColor: Color {
        colorScheme == .dark ? .black : .white
    }

    /// アクセシビリティリーダー向けにメッセージテキストを読み上げます。
    /// - Parameter message: 読み上げるメッセージテキスト。
    private func announceAccessibility(_ message: String?) {
        #if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
    }
}
