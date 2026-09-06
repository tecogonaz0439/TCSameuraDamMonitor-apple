// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// アプリケーションに関する情報（バージョン、ライセンス、利用規約、ソースコードリポジトリへのリンクなど）を表示するビュー。
struct AppInfoView: View {
    /// 状態とビジネスロジックを含むアプリケーションモデル。
    let appModel: DamAppModel
    /// スナックバーメッセージを表示するためのコールバック関数。
    let onSnackbar: ((String) -> Void)?
    /// 開発者向け設定を解放するためのバージョンクリック数を追跡するカウンター。
    @State private var versionTapCount = 0
    /// クリック数をリセットするためのアクティブなタイマータスク。
    @State private var tapResetTask: Task<Void, Never>?
    /// Codeberg共有ダイアログの表示状態を決定するローカルステート。
    @State private var showCodebergMenu = false
    /// GitHub共有ダイアログの表示状態を決定するローカルステート。
    @State private var showGitHubMenu = false
    #if os(macOS)
    /// macOS共有ピッカーを表示中に保持する状態。
    @State private var activeSharePicker: NSSharingServicePicker?
    #endif
    /// GitHubリポジトリのURL。
    private let githubURL = "https://github.com/tecogonaz0439/TCSameuraDamMonitor-apple/"
    /// CodebergリポジトリのURL。
    private let codebergURL = "https://codeberg.org/tecogonaz0439/TCSameuraDamMonitor-apple/"
    /// サードパーティ製OSSのライセンス表示が必要かどうか。
    private let showsThirdPartyOSSLicenses = false

    /// アプリ情報ビューのコンテンツとレイアウト。
    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image("DamHeaderIcon")
                            .resizable()
                            .frame(width: 64, height: 64)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(.primary.opacity(0.12), lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        Text(AppText.appName)
                            .font(.title2)
                            .fontWeight(.medium)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }

            Section {
                Button(action: handleVersionTap) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(AppText.appInfoVersion)
                            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
                            let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
                            Text(AppText.dialogVersionFormat(version, build))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "info.circle")
                    }
                    .macAppInfoLabelStyle()
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(AppText.debugLogTitle)
                .accessibilityIdentifier("appInfo.version")

                if AppLocale.isJapanese {
                    NavigationLink(value: AppInfoRoute.termsOfUseJa) {
                        Label(AppText.appInfoTermsOfUse, systemImage: "doc.text")
                            .macAppInfoLabelStyle()
                            .foregroundStyle(.primary)
                    }
                    .accessibilityIdentifier("appInfo.terms")
                } else {
                    NavigationLink(value: AppInfoRoute.termsOfUse) {
                        Label(AppText.appInfoTermsOfUse, systemImage: "doc.text")
                            .macAppInfoLabelStyle()
                            .foregroundStyle(.primary)
                    }
                    .accessibilityIdentifier("appInfo.terms")

                    NavigationLink(value: AppInfoRoute.termsOfUseJa) {
                        Label(AppText.appInfoTermsOfUseJa, systemImage: "doc.text")
                            .macAppInfoLabelStyle()
                            .foregroundStyle(.primary)
                    }
                    .accessibilityIdentifier("appInfo.termsJa")
                }

                if AppLocale.isJapanese {
                    NavigationLink(value: AppInfoRoute.privacyPolicyJa) {
                        Label(AppText.appInfoPrivacyPolicy, systemImage: "hand.raised")
                            .macAppInfoLabelStyle()
                            .foregroundStyle(.primary)
                    }
                    .accessibilityIdentifier("appInfo.privacy")
                } else {
                    NavigationLink(value: AppInfoRoute.privacyPolicy) {
                        Label(AppText.appInfoPrivacyPolicy, systemImage: "hand.raised")
                            .macAppInfoLabelStyle()
                            .foregroundStyle(.primary)
                    }
                    .accessibilityIdentifier("appInfo.privacy")

                    NavigationLink(value: AppInfoRoute.privacyPolicyJa) {
                        Label(AppText.appInfoPrivacyPolicyJa, systemImage: "hand.raised")
                            .macAppInfoLabelStyle()
                            .foregroundStyle(.primary)
                    }
                    .accessibilityIdentifier("appInfo.privacyJa")
                }

                NavigationLink(value: AppInfoRoute.license) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(AppText.appInfoLicense)
                            Text(AppText.appInfoApacheLicense)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "curlybraces")
                    }
                    .macAppInfoLabelStyle()
                    .foregroundStyle(.primary)
                }
                .accessibilityIdentifier("appInfo.license")

                if showsThirdPartyOSSLicenses {
                    NavigationLink(value: AppInfoRoute.ossLicense) {
                        Label(AppText.appInfoOSSLicense, systemImage: "curlybraces")
                            .macAppInfoLabelStyle()
                            .foregroundStyle(.primary)
                    }
                    .accessibilityIdentifier("appInfo.ossLicense")
                }

                Button {
                    #if os(macOS)
                    presentMacRepositoryAlert(title: AppText.appInfoCodeberg, urlString: codebergURL)
                    #else
                    showCodebergMenu = true
                    #endif
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(AppText.appInfoCodeberg)
                            Text(codebergURL)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        repositoryIcon("CodebergIcon")
                    }
                    .macAppInfoLabelStyle()
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .confirmationDialog(
                    AppText.appInfoCodeberg,
                    isPresented: $showCodebergMenu,
                    titleVisibility: .visible
                ) {
                    if let url = URL(string: codebergURL) {
                        Link(AppText.openURL, destination: url)
                    }
                    ShareLink(item: codebergURL) {
                        Text(AppText.shareURL)
                    }
                } message: {
                    Text(AppText.selectRepositoryAction)
                }

                Button {
                    #if os(macOS)
                    presentMacRepositoryAlert(title: AppText.appInfoGitHub, urlString: githubURL)
                    #else
                    showGitHubMenu = true
                    #endif
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(AppText.appInfoGitHub)
                            Text(githubURL)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        repositoryIcon("GitHubIcon")
                    }
                    .macAppInfoLabelStyle()
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .confirmationDialog(
                    AppText.appInfoGitHub,
                    isPresented: $showGitHubMenu,
                    titleVisibility: .visible
                ) {
                    if let url = URL(string: githubURL) {
                        Link(AppText.openURL, destination: url)
                    }
                    ShareLink(item: githubURL) {
                        Text(AppText.shareURL)
                    }
                } message: {
                    Text(AppText.selectRepositoryAction)
                }
            }
        }
        .navigationTitle(AppText.navAppInfo)
        .accessibilityIdentifier("appInfo.root")
        #if os(macOS)
        .formStyle(.grouped)
        #endif
    }

    /// リポジトリアイコンをテーマ色で表示します。
    /// - Parameter name: アセット名。
    /// - Returns: テーマに追従するリポジトリアイコン。
    private func repositoryIcon(_ name: String) -> some View {
        #if os(macOS)
        let iconSize: CGFloat = 16
        #else
        let iconSize: CGFloat = 24
        #endif
        return Image(name)
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: iconSize, height: iconSize)
            .foregroundStyle(.primary)
    }

    /// macOSでApp Info行のアイコン列をサイドバーと同じ中央揃えにします。
    fileprivate struct MacAppInfoLabelStyle: LabelStyle {
        func makeBody(configuration: Configuration) -> some View {
            #if os(macOS)
            HStack(alignment: .center, spacing: 8) {
                configuration.icon
                    .frame(width: 20, alignment: .center)
                configuration.title
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            #else
            Label(configuration)
            #endif
        }
    }

    /// 5回連続タップした後にデバッグメニュー設定を有効にするため、バージョンクリック数をインクリメントします。
    private func handleVersionTap() {
        versionTapCount += 1
        tapResetTask?.cancel()
        if versionTapCount >= 5 {
            versionTapCount = 0
            if !appModel.settings.debugSettingsVisible {
                appModel.toggleDebugSettingsVisibility()
                onSnackbar?(AppText.debugSettingsEnabled)
            }
        } else {
            tapResetTask = Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    versionTapCount = 0
                }
            }
        }
    }

    #if os(macOS)
    /// macOSでリポジトリリンク操作をNSAlertとして表示します。
    private func presentMacRepositoryAlert(title: String, urlString: String) {
        let url = URL(string: urlString)
        presentMacActionAlert(
            title: title,
            message: AppText.selectRepositoryAction,
            actions: [
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

    /// テキストコンテンツをシステムクリップボードのペーストボードにコピーします。
    /// - Parameter text: コピーする文字列コンテンツ。
    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

private extension View {
    @ViewBuilder
    func macAppInfoLabelStyle() -> some View {
        #if os(macOS)
        self.labelStyle(AppInfoView.MacAppInfoLabelStyle())
        #else
        self
        #endif
    }
}

/// 特定のドキュメントコンテンツページを表示する詳細テキスト表示ビュー。
struct AppInfoDetailView: View {
    /// 現在要求されているドキュメントセクションの詳細を示すルート。
    let route: AppInfoRoute

    /// デフォルトの背景カードフレームおよび引用ブロックのレイアウトスタイルの配色。
    private var blockquoteColor: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(.systemGray6)
        #endif
    }

    /// アプリ情報詳細ビューのコンテンツとレイアウト。
    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(title)
        .accessibilityIdentifier("appInfo.detail.\(identifierSuffix)")
    }

    /// 表示中のドキュメントを表すアクセシビリティのサフィックス識別子を解決します。
    private var identifierSuffix: String {
        switch route {
        case .termsOfUse: "terms"
        case .termsOfUseJa: "termsJa"
        case .privacyPolicy: "privacy"
        case .privacyPolicyJa: "privacyJa"
        case .license: "license"
        case .ossLicense: "ossLicense"
        }
    }

    /// アクティブなルートを表すナビゲーションヘッダーのタイトルキーを解決します。
    private var title: String {
        switch route {
        case .termsOfUse:
            AppText.dialogTermsOfUseTitle
        case .termsOfUseJa:
            AppText.dialogTermsOfUseJaTitle
        case .privacyPolicy:
            AppText.dialogPrivacyPolicyTitle
        case .privacyPolicyJa:
            AppText.dialogPrivacyPolicyJaTitle
        case .license:
            AppText.dialogLicenseTitle
        case .ossLicense:
            AppText.dialogOSSLicenseTitle
        }
    }

    /// 要求されたドキュメントシートのレイアウト表現詳細を生成します。
    @ViewBuilder
    private var content: some View {
        switch route {
        case .termsOfUse:
            MarkdownBodyView(text: AppInfoTexts.termsOfUse)
                .padding()
        case .termsOfUseJa:
            MarkdownBodyView(text: AppInfoTexts.termsOfUseJa)
                .padding()
        case .privacyPolicy:
            MarkdownBodyView(text: AppInfoTexts.privacyPolicy)
                .padding()
        case .privacyPolicyJa:
            MarkdownBodyView(text: AppInfoTexts.privacyPolicyJa)
                .padding()
        case .license:
            Text(AppInfoTexts.license)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(blockquoteColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding()
        case .ossLicense:
            Text(AppInfoTexts.ossLicense)
                .font(.body)
                .padding()
        }
    }
}

/// 見出しや箇条書きリストを含むシンプルなMarkdownファイルをレンダリングするために設計されたパーサービュー。
private struct MarkdownBodyView: View {
    /// 未加工のMarkdownテキストコンテンツ。
    let text: String

    /// Markdown本文ビューのコンテンツとレイアウト。
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(blocks, id: \.self) { block in
                renderBlock(block)
            }
        }
    }

    /// 空行で区切られた未加工のMarkdownテキストブロックを分割します。
    private var blocks: [String] {
        text.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// 個々のブロックをパースしてレンダリングします。
    /// - Parameter block: テキストセグメント。
    /// - Returns: 識別されたMarkdownマーカーにマッピングされたスタイル付きのビュー。
    @ViewBuilder
    private func renderBlock(_ block: String) -> some View {
        let lines = block.components(separatedBy: "\n")
        let firstLine = lines.first?.trimmingCharacters(in: .whitespaces) ?? ""

        if firstLine.hasPrefix("### ") {
            heading(String(firstLine.dropFirst(4)), font: .subheadline, topPadding: 6)
        } else if firstLine.hasPrefix("## ") {
            heading(String(firstLine.dropFirst(3)), font: .headline, topPadding: 10)
        } else if firstLine.hasPrefix("# ") {
            heading(String(firstLine.dropFirst(2)), font: .title3, topPadding: 8)
        } else if firstLine.hasPrefix("- ") || firstLine.hasPrefix("* ") {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(lines, id: \.self) { line in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                        HStack(alignment: .top, spacing: 4) {
                            Text("\u{2022}")
                                .frame(width: 12, alignment: .leading)
                            Text(parseInlineBold(String(trimmed.dropFirst(2))))
                                .font(.body)
                        }
                        .padding(.leading, 8)
                    }
                }
            }
        } else if firstLine.hasPrefix("|") {
            Text(block)
                .font(.caption)
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)
        } else if firstLine.hasPrefix("---") {
            Divider()
                .padding(.vertical, 4)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(lines, id: \.self) { line in
                    if line.isEmpty {
                        Color.clear.frame(height: 4)
                    } else {
                        Text(parseInlineBold(line))
                            .font(.body)
                    }
                }
            }
        }
    }

    /// セマンティックタグでスタイル設定されたヘッダーをレンダリングします。
    /// - Parameters:
    ///   - text: ヘッダーラベル。
    ///   - font: フォントサイズ指定。
    ///   - topPadding: 上部の余白スペース。
    /// - Returns: ヘッダーテキストビュー。
    private func heading(_ text: String, font: Font, topPadding: CGFloat) -> some View {
        Text(parseInlineBold(text))
            .font(font)
            .fontWeight(.bold)
            .padding(.top, topPadding)
            .accessibilityAddTraits(.isHeader)
    }

    /// インラインの太字または等幅フォントマーカーを AttributedString 定義にフォーマットします。
    /// - Parameter text: 未加工のテキスト行。
    /// - Returns: フォーマットされたテキストコンテンツ。
    private func parseInlineBold(_ text: String) -> AttributedString {
        var result = AttributedString()
        var remaining = text[...]
        while !remaining.isEmpty {
            if let boldStart = remaining.range(of: "**") {
                result.append(AttributedString(String(remaining[..<boldStart.lowerBound])))
                let afterStart = remaining[boldStart.upperBound...]
                if let boldEnd = afterStart.range(of: "**") {
                    var bold = AttributedString(String(afterStart[..<boldEnd.lowerBound]))
                    bold.font = .body.bold()
                    result.append(bold)
                    remaining = afterStart[boldEnd.upperBound...]
                } else {
                    result.append(AttributedString("**"))
                    remaining = afterStart
                }
            } else if let codeStart = remaining.range(of: "`") {
                result.append(AttributedString(String(remaining[..<codeStart.lowerBound])))
                let afterStart = remaining[codeStart.upperBound...]
                if let codeEnd = afterStart.range(of: "`") {
                    var code = AttributedString(String(afterStart[..<codeEnd.lowerBound]))
                    code.font = .body.monospaced()
                    result.append(code)
                    remaining = afterStart[codeEnd.upperBound...]
                } else {
                    result.append(AttributedString("`"))
                    remaining = afterStart
                }
            } else {
                result.append(AttributedString(String(remaining)))
                remaining = ""
            }
        }
        return result
    }
}
