// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
import ServiceManagement

/// macOS のシステム設定にある設定項目への遷移先。
internal enum SettingsSystemDestination {
    /// 「一般 > 言語と地域」。
    internal static let languageAndRegionURL = URL(
        string: "x-apple.systempreferences:com.apple.Localization-Settings.extension"
    )!
}
#endif

/// 通知、自動更新の設定、貯水率メッセージなど、アプリケーションの設定を管理するビュー。
struct SettingsView: View {
    /// 環境から提供される openURL アクション。
    @Environment(\.openURL) private var openURL
    #if os(macOS)
    /// アプリの表示状態。
    @Environment(\.scenePhase) private var scenePhase
    #endif
    /// 状態とビジネスロジックを保持するアプリケーションモデル。
    let appModel: DamAppModel
    /// 貯水率メッセージの選択をリセットするためのローカル状態。
    @State private var storageRateMessageResetSelection: StorageRateMessageResetSelection = .prompt
    /// 確認待ちの貯水率メッセージリセットモード。
    @State private var pendingStorageRateMessageResetMode: StorageRateMessageResetMode?
    /// 貯水率メッセージリセット確認を表示するかどうか。
    @State private var showStorageRateMessageResetConfirmation = false
    /// その他メッセージリセット確認を表示するかどうか。
    @State private var showOtherMessagesResetConfirmation = false
    /// 早明浦ダム以外の貯水率メッセージリセット確認を表示するかどうか。
    @State private var showOtherStorageRateMessagesResetConfirmation = false
    /// ダム選択シートを表示するかどうか。
    @State private var showDamSelectionSheet = false
    /// 確認待ちのリアルタイムデータ取得ソース。
    @State private var pendingRealtimeDataSource: RealtimeDataSource?
    /// リアルタイムデータ取得ソース切替確認を表示するかどうか。
    @State private var showRealtimeDataSourceSwitchConfirmation = false
    #if os(macOS)
    /// ログイン時起動が有効かどうかを示す表示用状態。
    @State private var launchAtLoginEnabled = false
    #endif

    /// 設定ビューのコンテンツとレイアウト。
    var body: some View {
        Form {
            #if os(iOS)
            Section {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    HStack {
                        Text(AppText.settingsSystemAppSettings)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.systemAppSettings")
            } header: {
                Text(AppText.settingsHeaderSystem)
            } footer: {
                Text(AppText.settingsSystemAppSettingsFooter)
            }
            #endif

            #if os(macOS)
            Section {
                Button {
                    openURL(SettingsSystemDestination.languageAndRegionURL)
                } label: {
                    HStack {
                        Text(AppText.settingsLanguage)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.language")
            } header: {
                Text(AppText.settingsHeaderSystem)
            }
            #endif

            Section {
                Picker(AppText.settingsAppearance, selection: binding(\.theme)) {
                    Text(AppText.appearanceAuto).tag(AppTheme.system)
                    Text(AppText.appearanceLight).tag(AppTheme.light)
                    Text(AppText.appearanceDark).tag(AppTheme.dark)
                }
                .accessibilityIdentifier("settings.appearance")
            }

            dataSourceSection

            #if os(macOS)
            Section {
                Toggle(AppText.settingsLaunchAtLogin, isOn: launchAtLoginBinding)
                    .accessibilityIdentifier("settings.launchAtLogin")
            } header: {
                Text(AppText.settingsHeaderGeneral)
            } footer: {
                Text(AppText.settingsLaunchAtLoginFooter)
            }

            Section {
                Picker(AppText.settingsMenuBarResidency, selection: binding(\.menuBarResidencyMode)) {
                    ForEach(MenuBarResidencyMode.allCases) { mode in
                        Text(mode.localizedLabel).tag(mode)
                    }
                }
                .accessibilityIdentifier("settings.menuBarResidency")
            } footer: {
                switch appModel.settings.menuBarResidencyMode {
                case .notResident:
                    Text(AppText.settingsMenuBarResidencyFooterNotResident)
                case .residentHidden:
                    Text(AppText.settingsMenuBarResidencyFooterResidentHidden)
                case .residentVisible:
                    Text(AppText.settingsMenuBarResidencyFooterResidentVisible)
                }
            }
            #endif

            Section {
                Toggle(AppText.settingsShowNotification, isOn: notificationBinding)
                    .accessibilityIdentifier("settings.notification")
            } header: {
                #if os(iOS)
                Text(AppText.settingsHeaderGeneral)
                #endif
            } footer: {
                #if os(macOS)
                Text(AppText.settingsShowNotificationFooterMacos)
                #else
                Text(AppText.settingsShowNotificationFooter)
                #endif
            }

            Section {
                Toggle(AppText.settingsUpdateOnBoot, isOn: binding(\.updateOnBoot))
                    .accessibilityIdentifier("settings.updateOnBoot")
            } footer: {
                #if os(macOS)
                Text(AppText.settingsUpdateOnBootFooterMacos)
                #else
                Text(AppText.settingsUpdateOnBootFooter)
                #endif
            }

            Section {
                Toggle(AppText.settingsAutoUpdate, isOn: binding(\.autoUpdateEnabled))
                    .accessibilityIdentifier("settings.autoUpdate")
            } footer: {
                #if os(macOS)
                Text(AppText.settingsAutoUpdateFooterMacos)
                #else
                Text(AppText.settingsAutoUpdateFooter)
                #endif
            }

            if appModel.settings.autoUpdateEnabled {
                Section {
                    Picker(AppText.settingsAutoUpdateInterval, selection: binding(\.autoUpdateInterval)) {
                        ForEach(AutoUpdateInterval.allCases) { interval in
                            Text(interval.localizedLabel).tag(interval)
                        }
                    }
                } footer: {
                    if appModel.settings.autoUpdateInterval == .oneHour || appModel.settings.autoUpdateInterval == .twelveHours {
                        Text(AppText.settingsAutoUpdateIntervalDailyHistoryFooter)
                    }
                }
            }

            if appModel.settings.autoUpdateEnabled {
                Section {
                    if let last = appModel.settings.lastAutoUpdate {
                        LabeledContent(AppText.settingsAutoUpdateLast) {
                            Text(DisplayFormatters.dateTime(last))
                                .foregroundStyle(.secondary)
                        }
                    }
                    AutoUpdateNextSettingItem(appModel: appModel)
                } footer: {
                    #if os(iOS)
                    Text(AppText.settingsAutoUpdateNextFooterIos)
                    #endif
                }
            }

            Section {
                Toggle(AppText.settingsShowStorageMessage, isOn: binding(\.showStorageRateMessage))
                    .accessibilityIdentifier("settings.showStorageMessage")
            } header: {
                Text(AppText.settingsMessagesSameura)
            } footer: {
                Text(AppText.settingsShowStorageMessageDesc)
            }

            if appModel.settings.showStorageRateMessage {
                Section {
                    ForEach(AppSettings.storageRateMessageDescriptors, id: \.widgetKey) { descriptor in
                        storageRateMessageEditButton(descriptor, onSave: resetStorageRateMessageResetSelection)
                    }
                    ResetAllMessagesPicker(selection: resetStorageRateMessagesSelectionBinding)
                } header: {
                    Text(AppText.settingsStorageMessagesSameuraTitle)
                }

                Section {
                    ForEach(AppSettings.otherStorageRateMessageDescriptors, id: \.widgetKey) { descriptor in
                        storageRateMessageEditButton(descriptor)
                    }
                    Button {
                        requestOtherStorageRateMessagesReset()
                    } label: {
                        Text(AppText.resetOtherStorageRateMessages)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.resetOtherStorageRateMessages")
                } header: {
                    Text(AppText.settingsStorageMessagesOtherTitle)
                }
            }

            Section {
                ForEach(AppSettings.otherMessageDescriptors, id: \.field) { descriptor in
                    otherMessageEditButton(descriptor)
                }
                Button {
                    requestOtherMessagesReset()
                } label: {
                    Text(AppText.resetAllOtherMessages)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } header: {
                Text(AppText.settingsOtherMessages)
            }
        }
        .navigationTitle(AppText.navSettings)
        .alert(AppText.resetStorageRateMessagesConfirmTitle, isPresented: $showStorageRateMessageResetConfirmation) {
            Button(AppText.dialogOK) {
                if let mode = pendingStorageRateMessageResetMode {
                    performStorageRateMessagesReset(mode: mode)
                }
            }
            Button(AppText.dialogCancel, role: .cancel) {
                pendingStorageRateMessageResetMode = nil
                resetStorageRateMessageResetSelection()
            }
        } message: {
            Text(AppText.resetStorageRateMessagesConfirmMessage)
        }
        .alert(AppText.resetOtherMessagesConfirmTitle, isPresented: $showOtherMessagesResetConfirmation) {
            Button(AppText.dialogOK) {
                appModel.resetOtherMessages()
            }
            Button(AppText.dialogCancel, role: .cancel) {}
        } message: {
            Text(AppText.resetOtherMessagesConfirmMessage)
        }
        .alert(AppText.resetOtherStorageRateMessagesConfirmTitle, isPresented: $showOtherStorageRateMessagesResetConfirmation) {
            Button(AppText.dialogOK) {
                appModel.resetOtherStorageRateMessages()
            }
            Button(AppText.dialogCancel, role: .cancel) {}
        } message: {
            Text(AppText.resetOtherStorageRateMessagesConfirmMessage)
        }
        .alert(AppText.settingsDataSourceSwitchConfirmTitle, isPresented: $showRealtimeDataSourceSwitchConfirmation) {
            Button(AppText.settingsDataSourceSwitchConfirmAction) {
                if let source = pendingRealtimeDataSource {
                    appModel.setRealtimeDataSource(source)
                }
                pendingRealtimeDataSource = nil
            }
            Button(AppText.dialogCancel, role: .cancel) {
                pendingRealtimeDataSource = nil
            }
        } message: {
            Text(AppText.settingsDataSourceSwitchConfirmMessage)
        }
        .accessibilityIdentifier("settings.root")
        #if os(macOS)
        .formStyle(.grouped)
        .onAppear {
            refreshLaunchAtLoginState()
        }
        .onChange(of: scenePhase) { _, newValue in
            if newValue == .active {
                refreshLaunchAtLoginState()
            }
        }
        #endif
    }

    /// 「データソース」セクション群。リアルタイム・過去・ダムを各独立Sectionでまとめます。
    ///
    /// iOS / iPadOS / macOS のいずれも「システム」大分類の直後に配置されます。
    @ViewBuilder
    private var dataSourceSection: some View {
        Group {
            Section {
                Picker(AppText.settingsDataSourceRealtime, selection: realtimeDataSourceBinding) {
                    ForEach(RealtimeDataSource.allCases) { source in
                        Text(source.localizedLabel)
                            .tag(source)
                            .accessibilityIdentifier("settings.realtimeDataSource.\(source.rawValue)")
                    }
                }
                .accessibilityIdentifier("settings.realtimeDataSource")
            } header: {
                Text(AppText.settingsHeaderDataSource)
            } footer: {
                Text(appModel.settings.realtimeDataSource == .sudmonitor
                    ? AppText.settingsDataSourceRealtimeHelpSudmonitor(RealtimeDataSource.sudmonitorHost)
                    : AppText.settingsDataSourceRealtimeHelpMlit)
                    .accessibilityIdentifier("settings.realtimeDataSourceFooter")
            }

            Section {
                Picker(AppText.settingsDataSourceHistorical, selection: historicalDataSourceBinding) {
                    ForEach(RealtimeDataSource.allCases) { source in
                        Text(source.localizedLabel)
                            .tag(source)
                            .accessibilityIdentifier("settings.historicalDataSource.\(source.rawValue)")
                    }
                }
                .accessibilityIdentifier("settings.historicalDataSource")
            } footer: {
                Text(appModel.settings.historicalDataSource == .sudmonitor
                    ? AppText.settingsDataSourceHistoricalHelpSudmonitor(RealtimeDataSource.sudmonitorHost)
                    : AppText.settingsDataSourceHistoricalHelpMlit)
                    .accessibilityIdentifier("settings.historicalDataSourceFooter")
            }

            Section {
                Button {
                    showDamSelectionSheet = true
                } label: {
                    LabeledContent {
                        HStack(spacing: 6) {
                            Text(DisplayFormatters.localizedDamName(appModel.currentDamConfig))
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    } label: {
                        Text(AppText.settingsDamName)
                            .foregroundStyle(.primary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(appModel.settings.realtimeDataSource == .sudmonitor)
                .accessibilityIdentifier("settings.damSelection")
                .sheet(isPresented: $showDamSelectionSheet) {
                    DamSelectionSheet(appModel: appModel, isPresented: $showDamSelectionSheet)
                }
            } footer: {
                if appModel.settings.realtimeDataSource == .sudmonitor {
                    Text(AppText.settingsDataSourceDamLocked)
                        .accessibilityIdentifier("settings.damLockedFooter")
                }
            }
        }
    }

    /// リアルタイムデータ取得ソースの選択を確定します。ダム変更を伴う場合は確認ダイアログを介します。
    /// - Parameter source: 選択された取得ソース。
    private func selectRealtimeDataSource(_ source: RealtimeDataSource) {
        guard source != appModel.settings.realtimeDataSource else { return }
        if appModel.realtimeDataSourceSwitchNeedsDamConfirmation(source) {
            pendingRealtimeDataSource = source
            showRealtimeDataSourceSwitchConfirmation = true
        } else {
            appModel.setRealtimeDataSource(source)
        }
    }

    /// 過去データ検索のデータソースの選択を確定します。
    /// - Parameter source: 選択された取得ソース。
    private func selectHistoricalDataSource(_ source: RealtimeDataSource) {
        guard source != appModel.settings.historicalDataSource else { return }
        appModel.setHistoricalDataSource(source)
    }

    /// リアルタイムデータ取得ソースの Picker 用バインディング。確認が必要な切替はダイアログを介します。
    private var realtimeDataSourceBinding: Binding<RealtimeDataSource> {
        Binding(
            get: { appModel.settings.realtimeDataSource },
            set: { selectRealtimeDataSource($0) }
        )
    }

    /// 過去データ検索のデータソースの Picker 用バインディング。
    private var historicalDataSourceBinding: Binding<RealtimeDataSource> {
        Binding(
            get: { appModel.settings.historicalDataSource },
            set: { selectHistoricalDataSource($0) }
        )
    }

    /// アプリケーション設定のプロパティへのバインディングを作成します。
    /// - Parameter keyPath: 設定プロパティへのキーパス。
    /// - Returns: 設定プロパティへのバインディング。
    private func binding<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(
            get: { appModel.settings[keyPath: keyPath] },
            set: { value in appModel.updateSettings { $0[keyPath: keyPath] = value } }
        )
    }

    /// 通知表示設定のバインディング。
    private var notificationBinding: Binding<Bool> {
        Binding(
            get: { appModel.settings.showNotification },
            set: { appModel.setShowNotification($0) }
        )
    }

    #if os(macOS)
    /// ログイン時起動設定のバインディング。
    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLoginEnabled },
            set: { enabled in
                setLaunchAtLogin(enabled)
            }
        )
    }

    /// macOSのログイン項目登録状態を表示用状態へ反映します。
    private func refreshLaunchAtLoginState() {
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }

    /// macOSのログイン項目登録を更新します。
    /// - Parameter enabled: ログイン時起動を有効化するかどうか。
    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            appModel.addDebugLog(message: "Launch at login setting failed.", details: (error as NSError).description)
        }
        refreshLaunchAtLoginState()
    }
    #endif

    /// 貯水率メッセージのリセット選択肢のバインディング。
    private var resetStorageRateMessagesSelectionBinding: Binding<StorageRateMessageResetSelection> {
        Binding(
            get: { storageRateMessageResetSelection },
            set: { selection in
                storageRateMessageResetSelection = selection
                if let mode = selection.resetMode {
                    requestStorageRateMessagesReset(mode: mode)
                }
            }
        )
    }

    /// 貯水率メッセージのリセット選択肢をデフォルト状態にリセットします。
    private func resetStorageRateMessageResetSelection() {
        storageRateMessageResetSelection = .prompt
    }

    /// 貯水率メッセージのリセットを必要に応じて確認付きで開始します。
    /// - Parameter mode: 適用するリセットモード。
    private func requestStorageRateMessagesReset(mode: StorageRateMessageResetMode) {
        if appModel.settings.needsStorageRateMessagesResetConfirmation() {
            pendingStorageRateMessageResetMode = mode
            showStorageRateMessageResetConfirmation = true
        } else {
            performStorageRateMessagesReset(mode: mode)
        }
    }

    /// 貯水率メッセージのリセットを実行します。
    /// - Parameter mode: 適用するリセットモード。
    private func performStorageRateMessagesReset(mode: StorageRateMessageResetMode) {
        appModel.resetStorageRateMessages(mode: mode)
        pendingStorageRateMessageResetMode = nil
    }

    /// その他メッセージのリセットを必要に応じて確認付きで開始します。
    private func requestOtherMessagesReset() {
        if appModel.settings.needsOtherMessagesResetConfirmation() {
            showOtherMessagesResetConfirmation = true
        } else {
            appModel.resetOtherMessages()
        }
    }

    /// 早明浦ダム以外の貯水率メッセージのリセットを必要に応じて確認付きで開始します。
    private func requestOtherStorageRateMessagesReset() {
        if appModel.settings.needsOtherStorageRateMessagesResetConfirmation() {
            showOtherStorageRateMessagesResetConfirmation = true
        } else {
            appModel.resetOtherStorageRateMessages()
        }
    }

    /// ディスクリプタに関連付けられた貯水率メッセージを編集するボタンを生成します。
    /// - Parameters:
    ///   - descriptor: 貯水率メッセージを定義するディスクリプタ。
    ///   - onSave: 編集を保存したときに実行されるアクション。
    /// - Returns: メッセージ編集シートを表示するビュー。
    private func storageRateMessageEditButton(
        _ descriptor: StorageRateMessageDescriptor,
        onSave: @escaping () -> Void = {}
    ) -> some View {
        MessageEditButton(
            title: descriptor.title.text(),
            state: binding(descriptor.state),
            messageNonJa: binding(descriptor.message),
            messageJa: binding(descriptor.japaneseMessage),
            defaultState: descriptor.defaultState,
            defaultMessageJa: descriptor.japaneseDefault(Locale(identifier: "ja")),
            defaultMessageNonJa: descriptor.nonJapanesePreset.message(),
            dialogTitleKey: "dialogSetTitleStorage",
            onSave: onSave
        )
    }

    /// ディスクリプタに関連付けられたその他のメッセージを編集するボタンを生成します。
    /// - Parameter descriptor: その他のメッセージを定義するディスクリプタ。
    /// - Returns: メッセージ編集シートを表示するビュー。
    private func otherMessageEditButton(_ descriptor: OtherMessageDescriptor) -> some View {
        MessageEditButton(
            title: descriptor.title.text(),
            state: binding(descriptor.state),
            messageNonJa: binding(descriptor.message),
            messageJa: binding(descriptor.japaneseMessage),
            defaultState: descriptor.defaultState,
            defaultMessageJa: descriptor.japanesePreset.message(locale: Locale(identifier: "ja")),
            defaultMessageNonJa: descriptor.nonJapanesePreset.message(),
            dialogTitleKey: "dialogSetTitleOther"
        )
    }
}

/// メッセージの現在値を表示し、タップされたときに編集シートを提示するボタン。
struct MessageEditButton: View {
    /// メッセージフィールドのタイトルラベル。
    let title: String
    /// メッセージの状態表現（通常は1文字）へのバインディング。
    @Binding var state: String
    /// メッセージの英語（日本語以外）バージョンへのバインディング。
    @Binding var messageNonJa: String
    /// メッセージの日本語バージョンへのバインディング。
    @Binding var messageJa: String
    /// デフォルトの状態値。
    let defaultState: String
    /// デフォルトの日本語メッセージの内容。
    let defaultMessageJa: String
    /// デフォルトの英語メッセージの内容。
    let defaultMessageNonJa: String
    /// ローカライズにおけるシートのタイトルを表すキー。
    let dialogTitleKey: String
    /// 編集を保存するときに実行されるクロージャ。
    let onSave: () -> Void
    /// 編集シートを表示するかどうかを決定する状態値。
    @State private var showDialog = false

    /// 新しいメッセージ編集ボタンを初期化します。
    /// - Parameters:
    ///   - title: タイトルラベル。
    ///   - state: 状態文字列へのバインディング。
    ///   - messageNonJa: 日本語以外のメッセージへのバインディング。
    ///   - messageJa: 日本語メッセージへのバインディング。
    ///   - defaultState: デフォルトの状態文字列。
    ///   - defaultMessageJa: デフォルトの日本語メッセージ。
    ///   - defaultMessageNonJa: デフォルトの日本語以外のメッセージ。
    ///   - dialogTitleKey: ダイアログタイトルのローカライズ文字列キー。
    ///   - onSave: 保存時に実行されるオプションのアクション。
    init(
        title: String,
        state: Binding<String>,
        messageNonJa: Binding<String>,
        messageJa: Binding<String>,
        defaultState: String,
        defaultMessageJa: String,
        defaultMessageNonJa: String,
        dialogTitleKey: String,
        onSave: @escaping () -> Void = {}
    ) {
        self.title = title
        self._state = state
        self._messageNonJa = messageNonJa
        self._messageJa = messageJa
        self.defaultState = defaultState
        self.defaultMessageJa = defaultMessageJa
        self.defaultMessageNonJa = defaultMessageNonJa
        self.dialogTitleKey = dialogTitleKey
        self.onSave = onSave
    }

    /// メッセージ編集ボタンのコンテンツとレイアウト。
    var body: some View {
        Button {
            showDialog = true
        } label: {
            let displayedMsg = AppLocale.isJapanese ? messageJa : messageNonJa
            let display = [state, displayedMsg].filter { !$0.isEmpty }.joined(separator: " ")
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text(title)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(display.isEmpty ? AppText.notSet : display)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                VStack(alignment: .trailing) {
                    Text(title)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(display.isEmpty ? AppText.notSet : display)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDialog) {
            StateMessageEditSheet(
                title: AppLocalized.format(dialogTitleKey, title),
                state: $state,
                messageNonJa: $messageNonJa,
                messageJa: $messageJa,
                defaultState: defaultState,
                defaultMessageJa: defaultMessageJa,
                defaultMessageNonJa: defaultMessageNonJa,
                isPresented: $showDialog,
                onSave: onSave
            )
        }
    }
}

/// 状態インジケータとバイリンガルメッセージを編集できるシートビュー。
struct StateMessageEditSheet: View {
    /// 編集シートのタイトル。
    let title: String
    /// 状態文字列へのバインディング。
    @Binding var state: String
    /// 日本語以外のメッセージコンテンツへのバインディング。
    @Binding var messageNonJa: String
    /// 日本語のメッセージコンテンツへのバインディング。
    @Binding var messageJa: String
    /// デフォルトの状態文字列。
    let defaultState: String
    /// デフォルトの日本語メッセージ。
    let defaultMessageJa: String
    /// デフォルトの日本語以外のメッセージ。
    let defaultMessageNonJa: String
    /// このシートの表示を制御するバインディング。
    @Binding var isPresented: Bool
    /// 編集が正常に保存されたときに実行されるクロージャ。
    let onSave: () -> Void

    /// 編集中の状態文字のローカル状態。
    @State private var editingState: String = ""
    /// 編集中の英語メッセージのローカル状態。
    @State private var editingMessageNonJa: String = ""
    /// 編集中の日本語メッセージのローカル状態。
    @State private var editingMessageJa: String = ""
    #if os(macOS)
    /// フォーカス制御用。
    @FocusState private var focusedField: Field?

    /// フォーカスフィールドの種類。
    private enum Field: Hashable {
        case state
        case messageJa
        case messageNonJa
    }
    #endif

    /// 状態文字列が正確に1文字であるかどうかを検証する計算プロパティ。
    private var isStateValid: Bool {
        editingState.count == 1
    }

    /// 状態メッセージ編集シートのコンテンツとレイアウト。
    var body: some View {
        NavigationStack {
            Form {
                #if os(macOS)
                macBody
                #else
                iosBody
                #endif
            }
            #if os(macOS)
            .formStyle(.grouped)
            #else
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppText.dialogCancel) {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppText.dialogSave) {
                        state = editingState
                        messageNonJa = editingMessageNonJa
                        messageJa = editingMessageJa
                        onSave()
                        isPresented = false
                    }
                    .disabled(!isStateValid)
                }
            }
            .onAppear {
                editingState = state
                editingMessageNonJa = messageNonJa
                editingMessageJa = messageJa
                #if os(macOS)
                DispatchQueue.main.async {
                    focusedField = nil
                    NSApp.keyWindow?.makeFirstResponder(nil)
                }
                #endif
            }
        }
    }

    #if os(macOS)
    @ViewBuilder
    private var macBody: some View {
        Section {
            TextField(AppText.dialogStateLabel, text: $editingState)
                .focused($focusedField, equals: .state)
            HStack {
                Text(AppText.dialogMessageJaLabel)
                TextField("", text: $editingMessageJa)
                    .focused($focusedField, equals: .messageJa)
            }
            HStack {
                Text(AppText.dialogMessageNonJaLabel)
                TextField("", text: $editingMessageNonJa)
                    .focused($focusedField, equals: .messageNonJa)
            }
        } header: {
            Text(title)
        } footer: {
            if !isStateValid {
                Text(AppText.dialogErrorOneCharOnly)
                    .foregroundStyle(.red)
            }
        }
    }
    #else
    @ViewBuilder
    private var iosBody: some View {
        Section {
            TextField(AppText.dialogStateLabel, text: $editingState)
        } header: {
            Text(AppText.dialogStateLabel)
        } footer: {
            if !isStateValid {
                Text(AppText.dialogErrorOneCharOnly)
                    .foregroundStyle(.red)
            }
        }
        Section {
            TextField(AppText.dialogMessageJaLabel, text: $editingMessageJa)
        } header: {
            Text(AppText.dialogMessageJaLabel)
        }
        Section {
            TextField(AppText.dialogMessageNonJaLabel, text: $editingMessageNonJa)
        } header: {
            Text(AppText.dialogMessageNonJaLabel)
        }
    }
    #endif
}

/// 貯水率メッセージのリセットオプションを表す列挙型。
enum StorageRateMessageResetSelection: String, CaseIterable, Identifiable {
    /// アクションが実行されていないことを表すプロンプトオプション。
    case prompt
    /// すべてのカスタムメッセージを削除するオプション。
    case delete
    /// メッセージを早明浦ダムのデフォルトの日本語メッセージにリセットするオプション。
    case sameura
    /// メッセージを日本語以外のデフォルトメッセージにリセットするオプション。
    case nonJapanese

    /// オプションの一意の識別子。
    var id: String { rawValue }

    /// オプションのローカライズされた表示ラベル。
    var label: String {
        switch self {
        case .prompt:
            return AppText.resetStorageRateMessagesPrompt
        case .delete:
            return AppText.resetOptionDelete
        case .sameura:
            return AppText.resetOptionSameura
        case .nonJapanese:
            return AppText.resetOptionNonJa
        }
    }

    /// 対応するリセットモードモデル（存在する場合）。
    var resetMode: StorageRateMessageResetMode? {
        switch self {
        case .prompt:
            return nil
        case .delete:
            return .delete
        case .sameura:
            return .japanese
        case .nonJapanese:
            return .nonJapanese
        }
    }

}

/// ユーザーが全ての貯水率メッセージをリセットできるようにするピッカービュー。
struct ResetAllMessagesPicker: View {
    /// 選択されたリセットオプションへのバインディング。
    @Binding var selection: StorageRateMessageResetSelection

    /// すべてのメッセージリセットピッカーのコンテンツとレイアウト。
    var body: some View {
        Picker(AppText.resetAllMessages, selection: $selection) {
            ForEach(StorageRateMessageResetSelection.allCases) { option in
                Text(option.label)
                    .multilineTextAlignment(.trailing)
                    .tag(option)
            }
        }
        .multilineTextAlignment(.trailing)
    }
}

/// 次回の自動更新スケジュールタイミングを表示する設定項目ビュー。
struct AutoUpdateNextSettingItem: View {
    /// 状態とビジネスロジックを保持するアプリケーションモデル。
    let appModel: DamAppModel
    /// 選択ダイアログシートが表示されているかどうかを決定するローカル状態。
    @State private var showDialog = false

    /// 次回自動更新設定項目のコンテンツとレイアウト。
    var body: some View {
        Button {
            showDialog = true
        } label: {
            LabeledContent {
                HStack(spacing: 6) {
                    Text(DisplayFormatters.dateTime(appModel.settings.nextRunTime()))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            } label: {
                Text(AppText.settingsAutoUpdateNext)
                    .foregroundStyle(.primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDialog) {
            AutoUpdateNextSheet(appModel: appModel, isPresented: $showDialog)
        }
    }
}

/// 次回スケジュールされた自動更新時間をユーザーが変更できるようにするシートビュー。
struct AutoUpdateNextSheet: View {
    /// 状態とビジネスロジックを保持するアプリケーションモデル。
    let appModel: DamAppModel
    /// シートの表示状態を制御するバインディング。
    @Binding var isPresented: Bool

    /// 次回更新のために選択された日付。
    @State private var selectedDate: Date
    /// 日付ピッカーを表示するためのローカル状態フラグ。
    @State private var showDatePicker = false
    /// 時刻ピッカーを表示するためのローカル状態フラグ。
    @State private var showTimePicker = false

    /// 選択スケジュールで許容される最小の日付。
    private var minimumValidDate: Date {
        AutoUpdateNextSelectionPolicy.minimumValidDate(now: Date())
    }

    /// 現在選択されている日付が無効であるかどうかを示す真偽値。
    private var isInvalidSelection: Bool {
        AutoUpdateNextSelectionPolicy.isInvalidSelection(selectedDate: selectedDate, now: Date())
    }

    /// 選択が無効な場合に表示される警告テキスト。
    private var invalidWarning: String {
        AppText.settingsAutoUpdateNextTimingWarning(AutoUpdateNextSelectionPolicy.nextValidDate(now: Date()))
    }

    /// 新しい自動更新時間選択シートを初期化します。
    /// - Parameters:
    ///   - appModel: アプリケーションモデル。
    ///   - isPresented: シートの表示を制御するバインディング。
    init(appModel: DamAppModel, isPresented: Binding<Bool>) {
        self.appModel = appModel
        self._isPresented = isPresented
        _selectedDate = State(initialValue: appModel.settings.nextRunTime())
    }

    /// 自動更新時間設定シートのコンテンツとレイアウト。
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        AppText.settingsAutoUpdateNextDialogDate,
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    DatePicker(
                        AppText.settingsAutoUpdateNextDialogTime,
                        selection: $selectedDate,
                        displayedComponents: .hourAndMinute
                    )
                } header: {
                    #if os(macOS)
                    Text(AppText.settingsAutoUpdateNext)
                    #endif
                } footer: {
                    if isInvalidSelection {
                        Text(invalidWarning)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            #if !os(macOS)
            .navigationTitle(AppText.settingsAutoUpdateNext)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            .toolbar {
                #if os(macOS)
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppText.dialogCancel) {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button(AppText.dialogReset) {
                        selectedDate = appModel.settings.nextRunTime()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppText.dialogSave) {
                        appModel.updateSettings { settings in
                            settings.nextRequestedUpdate = selectedDate
                        }
                        isPresented = false
                    }
                    .disabled(isInvalidSelection)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppText.dialogReset) {
                        selectedDate = appModel.settings.nextRunTime()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppText.dialogCancel) {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppText.dialogSave) {
                        appModel.updateSettings { settings in
                            settings.nextRequestedUpdate = selectedDate
                        }
                        isPresented = false
                    }
                    .disabled(isInvalidSelection)
                }
                #endif
            }
        }
    }
}
