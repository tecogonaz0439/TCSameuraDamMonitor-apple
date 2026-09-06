// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import UniformTypeIdentifiers
import TCSameuraDamCore

/// 生データ（.datファイル）のインポート/エクスポートを含む、さまざまなデバッグおよびシミュレーションユーティリティを提供するビュー。
struct DebugView: View {
    /// .dat ファイルに関連付けられたデフォルトの UTType 分類。
    private static let datContentType = UTType(filenameExtension: "dat") ?? .data

    /// 状態とビジネスロジックを含むアプリケーションモデル。
    let appModel: DamAppModel
    /// デバッグ設定を無効にするときに実行されるクロージャ。
    let onDisableDebug: () -> Void

    /// ファイルインポーターシートの表示状態を決定するローカルステート。
    @State private var importingRealtimeDat = false
    @State private var importingHistoricalDailyDat = false
    /// ファイルエクスポーターシートの表示状態を決定するローカルステート。
    @State private var exportingDat = false
    /// エクスポートされたファイルコンテンツの UTType 表現。
    @State private var exportContentType = DebugView.datContentType
    /// エクスポート時に推奨されるデフォルトのファイル名。
    @State private var exportDefaultFilename = DatExportVariant.raw.exportFilename(baseName: nil)
    /// ファイルエクスポート操作用にラップされたドキュメントオブジェクト。
    @State private var exportedDat = DataDocument(data: Data(), contentType: .data)
    /// 選択された .dat ファイルのエンコーディング。
    @State private var realtimeExportEncodingSelection: DatExportEncodingSelection = .prompt
    @State private var historicalDailyExportEncodingSelection: DatExportEncodingSelection = .prompt
    /// 選択されたピッカーの選択値表現。
    @State private var debugDataPeriodPickerSelection: DebugDataPeriodPickerSelection = .all
    /// カスタム範囲選択シートの表示状態を決定するローカルステート。
    @State private var showDebugDataPeriodSheet = false

    /// デバッグビューのコンテンツとレイアウト。
    var body: some View {
        Form {
            Section(AppText.settingsHeaderDebug) {
                #if DEBUG
                Toggle(AppText.settingsDebugMode, isOn: debugModeBinding)
                    .accessibilityIdentifier("debug.mode")

                if appModel.settings.debugModeEnabled {
                    Picker(AppText.settingsDebugRealtimeDatFile, selection: debugRealtimeDatSelectionModeBinding) {
                        Text(AppText.debugDatFileBundled).tag(DebugDatSelectionMode.bundled)
                        if appModel.hasRealtimeDatFile() {
                            Text(AppText.debugDatFileLatestRealtime).tag(DebugDatSelectionMode.latest)
                        }
                        Text(AppText.debugDatFileUserSelectedRealtime).tag(DebugDatSelectionMode.userSelected)
                    }
                    .accessibilityIdentifier("debug.realtimeDatFile")

                    if appModel.settings.debugRealtimeDatSelectionMode == .userSelected {
                        Button {
                            importingRealtimeDat = true
                        } label: {
                            LabeledContent(AppText.debugDatFileUserSelectedRealtime) {
                                Text(appModel.settings.debugRealtimeDatFileName ?? AppText.settingsDebugDatNone)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }

                    Picker(AppText.settingsDebugHistoricalDailyDatFile, selection: debugHistoricalDailyDatSelectionModeBinding) {
                        Text(AppText.debugDatFileBundled).tag(DebugDatSelectionMode.bundled)
                        if appModel.hasHistoricalDailyDatFile() {
                            Text(AppText.debugDatFileLatestHistoricalDaily).tag(DebugDatSelectionMode.latest)
                        }
                        Text(AppText.debugDatFileUserSelectedHistorical).tag(DebugDatSelectionMode.userSelected)
                    }
                    .accessibilityIdentifier("debug.historicalDailyDatFile")

                    if appModel.settings.debugHistoricalDailyDatSelectionMode == .userSelected {
                        Button {
                            importingHistoricalDailyDat = true
                        } label: {
                            LabeledContent(AppText.debugDatFileUserSelectedHistorical) {
                                Text(appModel.settings.debugHistoricalDailyDatFileName ?? AppText.settingsDebugDatNone)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }

                    debugDataPeriodPicker

                    Toggle(AppText.debugRealtimeDataPeriodAutoAdvance, isOn: binding(\.debugRealtimeDataPeriodAutoAdvanceEnabled))

                    Picker(AppText.settingsDebugSimulateMode, selection: binding(\.debugSimulateMode)) {
                        Text(AppText.simulateNone).tag(DebugSimulateMode.none)
                        Text(AppText.simulateNetworkUnavailable).tag(DebugSimulateMode.networkUnavailable)
                        Text(AppText.simulateLoadingFailure).tag(DebugSimulateMode.loadingFailure)
                    }
                }

                if !appModel.settings.debugModeEnabled {
                    if appModel.hasRealtimeDatFile() {
                        exportMenu(purpose: .realtime)
                    }
                    if appModel.hasHistoricalDailyDatFile() {
                        exportMenu(purpose: .historicalDaily)
                    }
                }
                #endif

                NavigationLink(value: DebugRoute.debugLog) {
                    Text(AppText.debugLogTitle)
                }
                .accessibilityIdentifier("debug.log")
            }

            Section {
                Button {
                    appModel.disableDebugSettings()
                    onDisableDebug()
                } label: {
                    Text(AppText.disableDebug)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .tint(.primary)
                .accessibilityIdentifier("debug.disable")
            }
        }
        .navigationTitle(AppText.navDebug)
        .accessibilityIdentifier("debug.root")
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .fileImporter(isPresented: $importingRealtimeDat, allowedContentTypes: [Self.datContentType]) { result in
            if case let .success(url) = result {
                appModel.importDebugRealtimeDat(from: url)
            }
        }
        .fileImporter(isPresented: $importingHistoricalDailyDat, allowedContentTypes: [Self.datContentType]) { result in
            if case let .success(url) = result {
                appModel.importDebugHistoricalDailyDat(from: url)
            }
        }
        .fileExporter(
            isPresented: $exportingDat,
            document: exportedDat,
            contentType: exportContentType,
            defaultFilename: exportDefaultFilename
        ) { _ in
            realtimeExportEncodingSelection = .prompt
            historicalDailyExportEncodingSelection = .prompt
        }
        .onChange(of: exportingDat) { _, isPresented in
            if !isPresented {
                realtimeExportEncodingSelection = .prompt
                historicalDailyExportEncodingSelection = .prompt
            }
        }
        .sheet(isPresented: $showDebugDataPeriodSheet) {
            DebugDataPeriodSheet(appModel: appModel, isPresented: $showDebugDataPeriodSheet)
        }
    }

    /// デバッグデータ期間ピッカー要素を表すビュー。
    private var debugDataPeriodPicker: some View {
        ZStack {
            Picker(AppText.debugRealtimeDataPeriod, selection: debugDataPeriodPickerSelectionBinding) {
                ForEach(DebugDataPeriodPickerSelection.allCases) { option in
                    Text(option.label)
                        .multilineTextAlignment(.trailing)
                        .tag(option)
                }
            }
            .multilineTextAlignment(.trailing)
            .opacity(appModel.settings.debugRealtimeDataEndDate == nil ? 1 : 0.01)

            if appModel.settings.debugRealtimeDataEndDate != nil {
                LabeledContent(AppText.debugRealtimeDataPeriod) {
                    HStack(spacing: 6) {
                        Text(debugDataPeriodLabel)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .multilineTextAlignment(.trailing)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .allowsHitTesting(false)
            }
        }
    }

    /// エクスポートオプションのコンテキストメニューを表すビュー。
    private func exportMenu(purpose: DebugDatPurpose) -> some View {
        Picker(purpose.exportLabel, selection: exportDatEncodingSelectionBinding(for: purpose)) {
            ForEach(DatExportEncodingSelection.allCases) { option in
                Text(option.label)
                    .multilineTextAlignment(.trailing)
                    .tag(option)
            }
        }
        .multilineTextAlignment(.trailing)
    }

    /// アクティブな範囲説明ラベルを表す文字列。
    private var debugDataPeriodLabel: String {
        let availableDates = (try? appModel.debugRealtimeDataTimes()) ?? []
        return DebugDataPeriodSelection.periodLabel(
            start: availableDates.first,
            end: appModel.settings.debugRealtimeDataEndDate,
            max: availableDates.last,
            allPeriodLabel: AppText.debugDataPeriodAll
        )
    }

    /// デバッグモード設定を切り替えるためのバインディング。
    private var debugModeBinding: Binding<Bool> {
        Binding(
            get: { appModel.settings.debugModeEnabled },
            set: { appModel.updateDebugModeEnabled($0) }
        )
    }

    /// デバッグ用 .dat ファイルのソースモードタイプを切り替えるためのバインディング。
    private var debugRealtimeDatSelectionModeBinding: Binding<DebugDatSelectionMode> {
        Binding(
            get: { appModel.settings.debugRealtimeDatSelectionMode },
            set: { mode in
                if mode == .userSelected {
                    #if os(macOS)
                    DispatchQueue.main.async {
                        importingRealtimeDat = true
                    }
                    #else
                    importingRealtimeDat = true
                    #endif
                } else {
                    appModel.updateDebugRealtimeDatSelectionMode(mode)
                }
            }
        )
    }

    private var debugHistoricalDailyDatSelectionModeBinding: Binding<DebugDatSelectionMode> {
        Binding(
            get: { appModel.settings.debugHistoricalDailyDatSelectionMode },
            set: { mode in
                if mode == .userSelected {
                    #if os(macOS)
                    DispatchQueue.main.async {
                        importingHistoricalDailyDat = true
                    }
                    #else
                    importingHistoricalDailyDat = true
                    #endif
                } else {
                    appModel.updateDebugHistoricalDailyDatSelectionMode(mode)
                }
            }
        )
    }

    /// 期間ピッカー要素の選択詳細を表すバインディング。
    private var debugDataPeriodPickerSelectionBinding: Binding<DebugDataPeriodPickerSelection> {
        Binding(
            get: { debugDataPeriodPickerSelection },
            set: { selection in
                debugDataPeriodPickerSelection = .all
                switch selection {
                case .all:
                    appModel.updateDebugRealtimeDataEndDate(nil)
                case .custom:
                    showDebugDataPeriodSheet = true
                }
            }
        )
    }

    /// ネイティブのエクスポートシートを起動するために、選択されたエンコーディング方法をマッピングするバインディング。
    private func exportDatEncodingSelectionBinding(for purpose: DebugDatPurpose) -> Binding<DatExportEncodingSelection> {
        Binding(
            get: {
                switch purpose {
                case .realtime:
                    return realtimeExportEncodingSelection
                case .historicalDaily:
                    return historicalDailyExportEncodingSelection
                }
            },
            set: { selection in
                switch purpose {
                case .realtime:
                    realtimeExportEncodingSelection = selection
                case .historicalDaily:
                    historicalDailyExportEncodingSelection = selection
                }
                guard let variant = selection.variant else { return }
                exportContentType = Self.datContentType
                do {
                    let export: (filename: String, data: Data)
                    switch purpose {
                    case .realtime:
                        export = (
                            appModel.realtimeDatExportFilename(variant: variant),
                            try appModel.realtimeDatExportData(variant: variant)
                        )
                    case .historicalDaily:
                        export = (
                            appModel.historicalDailyDatExportFilename(variant: variant),
                            try appModel.historicalDailyDatExportData(variant: variant)
                        )
                    }
                    exportDefaultFilename = export.filename
                    exportedDat = DataDocument(data: export.data, contentType: exportContentType)
                    #if os(macOS)
                    DispatchQueue.main.async {
                        exportingDat = true
                    }
                    #else
                    exportingDat = true
                    #endif
                } catch {
                    appModel.errorMessage = error.localizedDescription
                }
            }
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
}

private enum DebugDatPurpose {
    case realtime
    case historicalDaily

    var exportLabel: String {
        switch self {
        case .realtime:
            return AppText.exportRealtimeDat
        case .historicalDaily:
            return AppText.exportHistoricalDailyDat
        }
    }
}

/// デバッグデータ期間のピッカー選択モードを表す列挙型。
enum DebugDataPeriodPickerSelection: String, CaseIterable, Identifiable {
    /// デバッグファイル内のすべての利用可能なデータを選択するオプション。
    case all
    /// カスタムの時間枠制限を設定するオプション。
    case custom

    /// オプションの一意の識別子。
    var id: String { rawValue }

    /// オプションのローカライズされた表示ラベル。
    var label: String {
        switch self {
        case .all:
            return AppText.debugDataPeriodAll
        case .custom:
            return AppText.debugDataPeriodCustom
        }
    }
}

/// .dat ファイルのエクスポート中に利用可能なエンコーディングオプションを表す列挙型。
enum DatExportEncodingSelection: String, CaseIterable, Identifiable {
    /// オプションが選択されていないことを表すプレースホルダー。
    case prompt
    /// 生バイナリエンコーディングのバリアント。
    case raw
    /// UTF-8 テキストエンコーディングのバリアント。
    case utf8

    /// オプションの一意の識別子。
    var id: String { rawValue }

    /// オプションのローカライズされた表示ラベル。
    var label: String {
        switch self {
        case .prompt:
            return AppText.exportDebugDatEncodingPrompt
        case .raw:
            return AppText.exportDebugDatRaw
        case .utf8:
            return AppText.exportDebugDatUTF8
        }
    }

    /// 対応するドメインモデルバリアントがあれば解決します。
    var variant: DatExportVariant? {
        switch self {
        case .prompt:
            return nil
        case .raw:
            return .raw
        case .utf8:
            return .utf8
        }
    }
}

/// シミュレーション境界範囲のきめ細かな選択コントロールを提供するシートビュー。
struct DebugDataPeriodSheet: View {
    /// 日本標準時（JST）のタイムゾーン分類。
    private static let jst = TimeZone(identifier: "Asia/Tokyo") ?? .current

    /// 状態とビジネスロジックを含むアプリケーションモデル。
    let appModel: DamAppModel
    /// シートの表示状態を制御するバインディング。
    @Binding var isPresented: Bool

    /// 選択された終了日を追跡するローカルステート。
    @State private var selectedEndDate = Date()
    /// デバッグ用 .dat ファイルからパースされた利用可能なタイムスタンプのリスト。
    @State private var availableDates: [Date] = []

    /// データセット内で利用可能な最も古い日付。
    private var minDate: Date? { availableDates.first }
    /// データセット内で利用可能な最も新しい日付。
    private var maxDate: Date? { availableDates.last }
    /// 利用可能な最も近いタイムスタンプに切り捨てられた選択日。
    private var roundedEndDate: Date? {
        DebugDataPeriodSelection.roundedDate(selectedEndDate, in: availableDates)
    }

    /// デバッグデータ期間シートのコンテンツとレイアウト。
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(AppText.historicalSearchDam) {
                        Text(DisplayFormatters.localizedDamName(appModel.currentDamConfig))
                    }
                    LabeledContent(AppText.historicalSearchStartDate) {
                        Text(dateText(minDate))
                    }
                    LabeledContent(AppText.debugDataPeriodStartTime) {
                        Text(timeText(minDate))
                    }
                    if let datePickerRange {
                        DatePicker(
                            AppText.debugDataPeriodEndDate,
                            selection: endDateBinding,
                            in: datePickerRange,
                            displayedComponents: .date
                        )
                        .environment(\.timeZone, Self.jst)
                    } else {
                        DatePicker(
                            AppText.debugDataPeriodEndDate,
                            selection: endDateBinding,
                            displayedComponents: .date
                        )
                        .disabled(true)
                        .environment(\.timeZone, Self.jst)
                    }

                    DatePicker(
                        AppText.debugDataPeriodEndTime,
                        selection: endTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .disabled(availableDates.isEmpty)
                    .environment(\.timeZone, Self.jst)

                    #if !os(macOS)
                    if availableDates.isEmpty {
                        Text(AppText.exportDebugDatNoData)
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else if let minDate, let roundedEndDate {
                        Text(AppText.debugDataPeriodNote(DisplayFormatters.dateTime(minDate), DisplayFormatters.dateTime(roundedEndDate)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    #endif
                } header: {
                    #if os(macOS)
                    Text(AppText.debugRealtimeDataPeriod)
                    #endif
                } footer: {
                    #if os(macOS)
                    if let minDate, let roundedEndDate {
                        Text(AppText.debugDataPeriodNote(DisplayFormatters.dateTime(minDate), DisplayFormatters.dateTime(roundedEndDate)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    #endif
                }
                #if os(macOS)
                if availableDates.isEmpty {
                    Text(AppText.exportDebugDatNoData)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                #endif
            }
            #if !os(macOS)
            .navigationTitle(AppText.debugRealtimeDataPeriod)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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
                        selectedEndDate = maxDate ?? Date()
                    }
                    .disabled(availableDates.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppText.debugDataPeriodSetButton) {
                        guard let roundedEndDate else { return }
                        appModel.updateDebugRealtimeDataEndDate(roundedEndDate)
                        isPresented = false
                    }
                    .disabled(availableDates.isEmpty)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppText.dialogReset) {
                        selectedEndDate = maxDate ?? Date()
                    }
                    .disabled(availableDates.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppText.dialogCancel) {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppText.debugDataPeriodSetButton) {
                        guard let roundedEndDate else { return }
                        appModel.updateDebugRealtimeDataEndDate(roundedEndDate)
                        isPresented = false
                    }
                    .disabled(availableDates.isEmpty)
                }
                #endif
            }
            .onAppear {
                availableDates = (try? appModel.debugRealtimeDataTimes()) ?? []
                selectedEndDate = DebugDataPeriodSelection.clampedDate(
                    appModel.settings.debugRealtimeDataEndDate ?? maxDate ?? Date(),
                    in: availableDates
                ) ?? Date()
            }
        }
    }

    /// 許可される日付ピッカーの範囲制約を評価します。
    private var datePickerRange: ClosedRange<Date>? {
        guard let minDate, let maxDate else { return nil }
        return minDate...maxDate
    }

    /// 選択された日付コンポーネントを表すバインディング。
    private var endDateBinding: Binding<Date> {
        Binding(
            get: { selectedEndDate },
            set: { newDate in
                let candidate = DebugDataPeriodSelection.replacingDate(of: selectedEndDate, with: newDate)
                selectedEndDate = DebugDataPeriodSelection.clampedDate(candidate, in: availableDates) ?? candidate
            }
        )
    }

    /// 選択された時間コンポーネントを表すバインディング。
    private var endTimeBinding: Binding<Date> {
        Binding(
            get: { selectedEndDate },
            set: { newTime in
                let candidate = DebugDataPeriodSelection.replacingTime(of: selectedEndDate, with: newTime)
                selectedEndDate = DebugDataPeriodSelection.clampedDate(candidate, in: availableDates) ?? candidate
            }
        )
    }

    /// 日付文字列をフォーマットします。
    /// - Parameter date: 日付オブジェクト。
    /// - Returns: フォーマットされたテキスト。
    private func dateText(_ date: Date?) -> String {
        guard let date else { return AppText.historicalSearchDateNotSelected }
        return DisplayFormatters.displayDate(date)
    }

    /// 時刻文字列をフォーマットします。
    /// - Parameter date: 日付オブジェクト。
    /// - Returns: フォーマットされたテキスト。
    private func timeText(_ date: Date?) -> String {
        guard let date else { return AppText.historicalSearchDateNotSelected }
        return TimeFormatters.historyRowMinute.string(from: date).split(separator: " ").last.map(String.init) ?? "--"
    }
}

/// シミュレーション設定のカレンダー操作をグループ化する名前空間。
enum DebugDataPeriodSelection {
    /// 共有される東京のカレンダーインスタンス。
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return calendar
    }

    /// 説明範囲の期間ラベルをフォーマットします。
    /// - Parameters:
    ///   - start: 開始日。
    ///   - end: 終了日。
    ///   - max: 最大境界。
    ///   - allPeriodLabel: デフォルトラベル。
    /// - Returns: フォーマットされたラベル。
    static func periodLabel(start: Date?, end: Date?, max: Date?, allPeriodLabel: String) -> String {
        guard let start, let end, let max else {
            return allPeriodLabel
        }
        if end >= max {
            return allPeriodLabel
        }
        return "\(TimeFormatters.jstDisplay.string(from: start)) - \(DamCoreJSTSupport.appendingJstSuffix(TimeFormatters.jstDisplay.string(from: end), isLocalJst: DisplayFormatters.isJST))"
    }

    /// 選択された日付を利用可能な最も近いタイムスタンプに切り捨てます。
    /// - Parameters:
    ///   - date: 対象の日付。
    ///   - availableDates: タイムスタンプのリスト。
    /// - Returns: 丸められた日付。
    static func roundedDate(_ date: Date, in availableDates: [Date]) -> Date? {
        availableDates.last { $0 <= date } ?? availableDates.first
    }

    /// 日付の範囲をデータセットの範囲内に収めます。
    /// - Parameters:
    ///   - date: 対象の日付。
    ///   - availableDates: タイムスタンプのリスト。
    /// - Returns: クランプされた日付。
    static func clampedDate(_ date: Date, in availableDates: [Date]) -> Date? {
        guard let minDate = availableDates.first, let maxDate = availableDates.last else {
            return nil
        }
        return min(max(date, minDate), maxDate)
    }

    /// 時間コンポーネントを保持したまま、Date インスタンスの日付コンポーネントを置き換えます。
    /// - Parameters:
    ///   - original: 元の日付。
    ///   - newDate: 対象の日付コンポーネントのソース。
    /// - Returns: マージされた日付。
    static func replacingDate(of original: Date, with newDate: Date) -> Date {
        let calendar = calendar
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: newDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: original)
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = dateComponents.year
        components.month = dateComponents.month
        components.day = dateComponents.day
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = 0
        components.nanosecond = 0
        return calendar.date(from: components) ?? newDate
    }

    /// 日付コンポーネントを保持したまま、Date インスタンスの時間コンポーネントを置き換えます。
    /// - Parameters:
    ///   - original: 元の日付。
    ///   - newTime: 対象の時間コンポーネントのソース。
    /// - Returns: マージされた日付。
    static func replacingTime(of original: Date, with newTime: Date) -> Date {
        let calendar = calendar
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: original)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: newTime)
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = dateComponents.year
        components.month = dateComponents.month
        components.day = dateComponents.day
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = 0
        components.nanosecond = 0
        return calendar.date(from: components) ?? original
    }
}
