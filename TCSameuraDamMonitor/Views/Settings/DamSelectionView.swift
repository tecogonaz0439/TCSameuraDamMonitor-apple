// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// 設定画面から表示されるダム選択シート。
struct DamSelectionSheet: View {
    /// 状態とビジネスロジックを保持するアプリケーションモデル。
    let appModel: DamAppModel
    /// シートの表示状態。
    @Binding var isPresented: Bool
    /// 確定前に選択されたダムID。
    @State private var selectedDamId: String

    /// 指定されたアプリケーションモデルでシートを初期化します。
    /// - Parameters:
    ///   - appModel: アプリケーションモデル。
    ///   - isPresented: シートの表示状態。
    init(appModel: DamAppModel, isPresented: Binding<Bool>) {
        self.appModel = appModel
        self._isPresented = isPresented
        _selectedDamId = State(initialValue: appModel.settings.targetDamId)
    }

    /// 選択されたダムの設定。
    private var selectedDam: DamConfig? {
        DamListData.dam(id: selectedDamId)
    }

    /// ダム選択シートのコンテンツ。
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    damSelectionControl
                } header: {
                    #if os(macOS)
                    Text(AppText.damSelectionTitle)
                    #endif
                }
            }
            #if !os(macOS)
            .navigationTitle(AppText.damSelectionTitle)
            #endif
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            .accessibilityIdentifier("settings.damSelection.sheet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppText.dialogCancel) {
                        isPresented = false
                    }
                    .accessibilityIdentifier("settings.damSelection.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppText.damSelectionSelectAction) {
                        confirmSelection()
                    }
                    .accessibilityIdentifier("settings.damSelection.select")
                }
            }
        }
    }

    /// プラットフォームに適したダム選択コントロール。
    @ViewBuilder
    private var damSelectionControl: some View {
        #if os(macOS)
        LabeledContent {
            Menu {
                if let sameuraDam = DamListData.dam(id: AppSettings.defaultDamId) {
                    damMenuButton(sameuraDam)
                    Divider()
                }
                ForEach(DamListData.allDams) { dam in
                    damMenuButton(dam)
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
            .accessibilityIdentifier("settings.damSelection.menu")
        } label: {
            Text(AppText.settingsDamName)
        }
        #else
        NavigationLink {
            DamPickerView(
                selectedDamId: $selectedDamId,
                accessibilityPrefix: "settings.damSelection"
            )
        } label: {
            HStack {
                Text(AppText.settingsDamName)
                Spacer()
                Text(DisplayFormatters.localizedDamName(selectedDam))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("settings.damSelection.dam")
        #endif
    }

    #if os(macOS)
    /// macOS のダム選択メニュー項目。
    private func damMenuButton(_ dam: DamConfig) -> some View {
        Button {
            selectedDamId = dam.id
        } label: {
            Text(damMenuItemText(dam, isSelected: dam.id == selectedDamId))
        }
    }
    #endif

    /// 選択されたダムを確定します。
    private func confirmSelection() {
        guard selectedDamId != appModel.settings.targetDamId else {
            isPresented = false
            return
        }
        Task {
            let didChange = appModel.confirmTargetDamId(selectedDamId)
            appModel.selectedDetail = .realtime
            isPresented = false
            if didChange {
                await appModel.fetchLatest(workType: "Initial load")
            }
        }
    }
}

#if os(macOS)
/// ダム所在地を現在のロケール向けに整形します。
private func damSelectionLocationText(_ dam: DamConfig) -> String {
    if AppLocale.isJapanese {
        return "\(dam.prefecture) / \(dam.waterSystem) / \(dam.river)"
    }
    return "\(dam.prefectureEn) / \(dam.waterSystemEn) / \(dam.riverEn)"
}

/// macOSのMenu向けにダム名と所在地を1行で整形します。
private func damMenuText(_ dam: DamConfig) -> String {
    "\(DisplayFormatters.localizedDamName(dam)) (\(damSelectionLocationText(dam)))"
}

/// 選択記号または空白を先頭へ付けたmacOSのMenu項目。
private func damMenuItemText(_ dam: DamConfig, isSelected: Bool) -> String {
    "\(isSelected ? "✓" : "  ") \(damMenuText(dam))"
}
#endif
