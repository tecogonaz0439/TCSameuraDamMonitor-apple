// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
#if os(macOS)
import AppKit
#endif

/// キャッシュされた過去データ検索の管理機能（並べ替え、ピン留め、削除）を提供するビュー。
struct HistoricalManageView: View {
    /// 状態とビジネスロジックを保持するアプリケーションモデル。
    let appModel: DamAppModel
    /// スナックバーメッセージを表示するためのコールバック関数。
    var onSnackbar: ((String) -> Void)? = nil
    #if os(macOS)
    /// macOS用の編集モード状態。
    @State private var macIsEditing = false
    #else
    /// editMode 環境変数。
    @Environment(\.editMode) private var editMode
    #endif
    /// 削除確認ダイアログが表示されているかどうかを決定するローカル状態。
    @State private var showDeleteAllConfirm = false

    /// ビューが現在編集モードであるかどうかを示す真偽値フラグ。
    private var isEditing: Bool {
        #if os(macOS)
        macIsEditing
        #else
        editMode?.wrappedValue == .active
        #endif
    }

    /// 過去データ管理ビューのコンテンツとレイアウト。
    var body: some View {
        List {
            if appModel.historicalMetaList.isEmpty {
                Text(AppText.historicalManageEmpty)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("historicalManage.empty")
            } else {
                ForEach(appModel.historicalMetaList) { meta in
                    HistoricalManageRow(
                        meta: meta,
                        hideIcon: shouldHideRowIcon,
                        isEditing: isEditing,
                        showMenuButton: !isEditing
                    ) {
                        Task { await appModel.openHistorical(metaId: meta.id) }
                    } onPin: {
                        Task {
                            if let message = await appModel.togglePin(metaId: meta.id) {
                                onSnackbar?(message)
                            }
                        }
                    } onUnpin: {
                        Task {
                            if let message = await appModel.togglePin(metaId: meta.id) {
                                onSnackbar?(message)
                            }
                        }
                    } onDelete: {
                        appModel.deleteHistorical(metaId: meta.id)
                    }
                    .moveDisabled(!isEditing)
                    .deleteDisabled(!isEditing)
                    .contextMenu {
                        if !isEditing {
                            Button(AppText.open) {
                                Task { await appModel.openHistorical(metaId: meta.id) }
                            }
                            if meta.isPinned {
                                Button(AppText.historicalManageUnpin) {
                                    Task {
                                        if let message = await appModel.togglePin(metaId: meta.id) {
                                            onSnackbar?(message)
                                        }
                                    }
                                }
                            } else {
                                Button(AppText.historicalManagePin) {
                                    Task {
                                        if let message = await appModel.togglePin(metaId: meta.id) {
                                            onSnackbar?(message)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    guard isEditing else { return }
                    for index in offsets {
                        appModel.deleteHistorical(metaId: appModel.historicalMetaList[index].id)
                    }
                }
                .onMove(perform: appModel.moveHistorical)

                if isEditing {
                    Section {
                        HStack {
                            Spacer()
                            Button(AppText.deleteAll, role: .destructive) {
                                showDeleteAllConfirm = true
                            }
                            .accessibilityIdentifier("historicalManage.deleteAll")
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle(AppText.historicalManageTitle)
        .accessibilityIdentifier("historicalManage.root")
        .toolbar {
            #if os(macOS)
            if !appModel.historicalMetaList.isEmpty {
                Button(macIsEditing ? AppText.done : AppText.edit) {
                    macIsEditing.toggle()
                }
                .accessibilityIdentifier("historicalManage.edit")
            }
            #else
            EditButton()
            #endif
        }
        .alert(AppText.historicalManageDeleteAllTitle, isPresented: $showDeleteAllConfirm) {
            Button(AppText.deleteAll, role: .destructive) { appModel.deleteAllHistorical() }
                .accessibilityIdentifier("historicalManage.deleteAll.confirm")
            Button(AppText.cancel, role: .cancel) {}
        } message: {
            Text(AppText.historicalManageDeleteAllMessage)
        }
    }

    /// 編集モード時に行アイコンを隠すかどうか。
    private var shouldHideRowIcon: Bool {
        #if os(macOS)
        false
        #else
        isEditing
        #endif
    }
}

/// リスト内の保存された単一の過去データ検索設定を表する行ビュー。
private struct HistoricalManageRow: View {
    /// 過去データ検索のメタデータ。
    let meta: HistoricalSearchMeta
    /// ステータスアイコンを非表示にするかどうかを示す真偽値フラグ。
    let hideIcon: Bool
    /// 行が編集モードで表示されているかどうかを示す真偽値フラグ。
    let isEditing: Bool
    /// オーバーフローオプションメニューボタンが表示されているかどうかを示す真偽値フラグ。
    var showMenuButton: Bool = false
    /// 詳細表示メニューオプションを選択したときに実行されるクロージャ。
    var onShow: (() -> Void)?
    /// この項目をピン留めするときに実行されるクロージャ。
    var onPin: (() -> Void)?
    /// この項目のピン留めを外すときに実行されるクロージャ。
    var onUnpin: (() -> Void)?
    /// この項目を削除するときに実行されるクロージャ。
    var onDelete: (() -> Void)?

    /// 過去データ管理行のコンテンツとレイアウト。
    var body: some View {
        HStack(spacing: 0) {
            historicalLabel
                .foregroundStyle(.primary)

            if showMenuButton {
                Spacer()
                Menu {
                    Button(AppText.open) { onShow?() }
                    if meta.isPinned {
                        Button(AppText.historicalManageUnpin) { onUnpin?() }
                    } else {
                        Button(AppText.historicalManagePin) { onPin?() }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .imageScale(.medium)
                        .frame(width: 44, height: 44)
                }
                .tint(.secondary)
                .accessibilityLabel(AppText.moreActions)
            }

            #if os(macOS)
            if isEditing {
                Spacer(minLength: 12)
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: NSFont.systemFontSize))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }
            #endif
        }
        #if os(macOS)
        .frame(minHeight: 56, alignment: .center)
        .accessibilityElement(children: isEditing ? .contain : .combine)
        #else
        .accessibilityElement(children: .combine)
        #endif
        .accessibilityIdentifier("historicalManage.row.\(meta.id.uuidString)")
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isEditing else { return }
            onShow?()
        }
        .accessibilityAddTraits(isEditing ? [] : [.isButton])
    }

    /// サイドバーの過去データ項目に揃えた行ラベル。
    @ViewBuilder
    private var historicalLabel: some View {
        #if os(macOS)
        HStack(alignment: .center, spacing: 8) {
            if isEditing {
                Button(role: .destructive) {
                    onDelete?()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: NSFont.systemFontSize))
                        .foregroundStyle(.red)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .help(AppText.delete)
                .accessibilityLabel(AppText.delete)
            } else if !hideIcon {
                Image(systemName: meta.isPinned ? "pin.fill" : "chart.xyaxis.line")
                    .font(.system(size: NSFont.systemFontSize))
                    .frame(width: 20)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(DisplayFormatters.localizedDamName(DamListData.dam(id: meta.damConfigId)))
                    .font(.system(size: NSFont.systemFontSize))
                    .lineLimit(2)
                Text(DisplayFormatters.historicalPeriodLine(meta))
                    .font(.system(size: NSFont.smallSystemFontSize))
                    .lineLimit(2)
                Text(DisplayFormatters.historicalRangeLine(meta))
                    .font(.system(size: NSFont.smallSystemFontSize))
                    .lineLimit(2)
            }
        }
        #else
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(DisplayFormatters.localizedDamName(DamListData.dam(id: meta.damConfigId)))
                    .font(.body)
                Text(DisplayFormatters.historicalPeriodLine(meta))
                    .font(.caption)
                Text(DisplayFormatters.historicalRangeLine(meta))
                    .font(.caption)
            }
        } icon: {
            if !hideIcon {
                Image(systemName: meta.isPinned ? "pin.fill" : "chart.xyaxis.line")
            }
        }
        #endif
    }
}
