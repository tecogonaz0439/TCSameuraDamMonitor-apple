// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation
import TCSameuraDamCore

/// ダムの貯水状態などの推移傾向を表する列挙型。
enum Trend: String, Codable, CaseIterable, Sendable {
    /// 上昇傾向。
    case up
    /// 下降傾向。
    case down
    /// 横ばい。
    case flat
    /// 不明。
    case unknown

    /// 傾向に対応する SF Symbols の名前。
    var symbol: String {
        switch self {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .flat: return "arrow.right"
        case .unknown: return "minus"
        }
    }
}

/// ダムの過去の観測履歴データを保持する構造体。
struct DamHistoricalData: Identifiable, Codable, Hashable, Sendable {
    /// 識別子としての時間文字列。
    var id: String { time }
    /// 観測日時の文字列。
    let time: String
    /// 流域平均雨量 (Basin average rainfall) (mm)。
    let catchmentAverageRainfall: Float?
    /// 貯水率 (Storage rate) (%)。
    let storagePercentage: Float?
    /// 貯水量 (Storage volume) (万立方メートル)。
    let storageVolume: Float?
    /// 流入量 (Inflow) (立方メートル毎秒)。
    let inflow: Float?
    /// 放流量 (Outflow) (立方メートル毎秒)。
    let outflow: Float?
}

/// 観測所におけるダムの現在の各種測定データおよび傾向情報を保持する構造体。
struct DamData: Codable, Hashable, Sendable {
    /// 観測所のID。
    let observationStationId: String
    /// 観測所の名前。
    let observationStationName: String
    /// 水系名。
    let riverSystemName: String
    /// 河川名。
    let riverName: String
    /// データの更新日時。
    let updatedAt: String
    /// 流域平均雨量 (Basin average rainfall) (mm)。
    let catchmentAverageRainfall: Float?
    /// 貯水量 (Storage volume) (万立方メートル)。
    let storageVolume: Float?
    /// 貯水率メッセージ分類用の欠測前の最新正常貯水量 (Storage volume)。貯水量列の欠測・異常値が続く場合、新しい順に遡った最後の正常値。欠測が1件もなく最新行が正常なら `storageVolume` と同じ値になる。
    let storageVolumeForMessage: Float?
    /// 貯水量 (Storage volume) の増減傾向。
    let storageVolumeTrend: Trend
    /// 流入量 (Inflow) (立方メートル毎秒)。
    let inflow: Float?
    /// 流入量 (Inflow) の増減傾向。
    let inflowTrend: Trend
    /// 放流量 (Outflow) (立方メートル毎秒)。
    let outflow: Float?
    /// 放流量 (Outflow) の増減傾向。
    let outflowTrend: Trend
    /// 貯水率 (Storage rate) (%)。
    let storagePercentage: Float?
    /// 貯水率 (Storage rate) の増減傾向。
    let storagePercentageTrend: Trend
    /// 貯水率 (Storage rate) が最後に更新された時間。
    let storagePercentageTime: String?
    /// 前日比の貯水率 (Storage rate) 変化量。
    let storagePercentageDayChange: Float?
    /// 前日比の貯水率 (Storage rate) 変化量の増減傾向。
    let storagePercentageDayChangeTrend: Trend
    /// 前週比の貯水率 (Storage rate) 変化量。
    let storagePercentageWeekChange: Float?
    /// 前週比の貯水率 (Storage rate) 変化量の増減傾向。
    let storagePercentageWeekChangeTrend: Trend
    /// 過去の履歴データ配列。
    let historicalData: [DamHistoricalData]

    /// すべての観測データ（貯水量 (Storage volume)、流入量 (Inflow)、放流量 (Outflow)、流域平均雨量 (Basin average rainfall)、貯水率 (Storage rate)）が無効（nil）であるかどうか。
    var isAllObservationDataInvalid: Bool {
        storageVolume == nil
            && inflow == nil
            && outflow == nil
            && catchmentAverageRainfall == nil
            && storagePercentage == nil
    }
}

/// ダムに関連する参照リンク情報を表する構造体。
struct DamRelatedURL: Codable, Hashable, Sendable {
    /// リンクのタイトル。
    let title: String
    /// URL 文字列。
    let url: String
}

/// ダムの基本設定情報を定義する構造体。
struct DamConfig: Identifiable, Codable, Hashable, Sendable {
    /// ダムの識別ID。
    let id: String
    /// 都道府県名。
    let prefecture: String
    /// 都道府県名の英語表記。
    let prefectureEn: String
    /// 水系名。
    let waterSystem: String
    /// 水系名の英語表記。
    let waterSystemEn: String
    /// 河川名。
    let river: String
    /// 河川名の英語表記。
    let riverEn: String
    /// ダム名の日本語表記。
    let nameJa: String
    /// ダム名の英語表記。
    let nameEn: String
    /// データ取得元となる国土交通省 (MLIT) の URL。
    let dataUrl: String
    /// 災害・防災情報ページの URL。
    let disasterInfoUrl: String
    /// その他の関連 URL リスト。
    let otherUrls: [DamRelatedURL]
    /// 地図や地理情報を開くための地理的 URL。
    let geoUrl: String

    /// アプリの言語設定に対応したローカライズされたダムの名前。
    var localizedName: String {
        AppLocale.isJapanese ? nameJa : "\(nameEn) \(nameJa)".trimmingCharacters(in: .whitespaces)
    }

    /// 国土交通省 (MLIT) サーバー上の観測所情報ページの URL。
    var siteInfoUrl: String {
        guard dataUrl.contains("www1.river.go.jp/cgi-bin/DspDamData.exe") else { return "" }
        return "https://www1.river.go.jp/cgi-bin/SiteInfo.exe?ID=\(id)"
    }

    /// 指定された日付範囲における過去履歴データ検索ページの URL を構築します。
    ///
    /// - Parameters:
    ///   - startDate: 検索開始日 (yyyyMMdd)。
    ///   - endDate: 検索終了日 (yyyyMMdd)。
    /// - Returns: 国土交通省 (MLIT) の過去履歴検索 URL。
    func historicalSearchUrl(startDate: String, endDate: String) -> String {
        guard dataUrl.contains("www1.river.go.jp/cgi-bin/DspDamData.exe") else { return "" }
        return "https://www1.river.go.jp/cgi-bin/DspDamData.exe?KIND=1&ID=\(id)&BGNDATE=\(startDate)&ENDDATE=\(endDate)&KAWABOU=NO"
    }
}

/// アプリの表示テーマを定義する列挙型。
nonisolated enum AppTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    /// システム設定に従う。
    case system
    /// ライトモード。
    case light
    /// ダークモード。
    case dark

    /// Identifiable 適合用の識別子。
    var id: String { rawValue }
}

/// 自動更新の間隔を定義する列挙型。
nonisolated enum AutoUpdateInterval: String, Codable, CaseIterable, Identifiable, Sendable {
    /// 1週間。
    case oneWeek
    /// 1日。
    case oneDay
    /// 12時間。
    case twelveHours
    /// 1時間。
    case oneHour

    /// Identifiable 適合用の識別子。
    var id: String { rawValue }

    /// 更新間隔を表する秒数（TimeInterval）。
    var interval: TimeInterval {
        switch self {
        case .oneWeek: return 7 * 24 * 60 * 60
        case .oneDay: return 24 * 60 * 60
        case .twelveHours: return 12 * 60 * 60
        case .oneHour: return 60 * 60
        }
    }

    /// ローカライズされた表示用ラベル文字列。
    var localizedLabel: String {
        switch self {
        case .oneWeek: return AppLocalized.text("autoUpdateInterval.oneWeek")
        case .oneDay: return AppLocalized.text("autoUpdateInterval.oneDay")
        case .twelveHours: return AppLocalized.text("autoUpdateInterval.twelveHours")
        case .oneHour: return AppLocalized.text("autoUpdateInterval.oneHour")
        }
    }

    /// Android 版アプリとの設定連携用の内部表現文字列。
    var androidName: String {
        switch self {
        case .oneWeek: return "ONE_WEEK"
        case .oneDay: return "ONE_DAY"
        case .twelveHours: return "TWELVE_HOURS"
        case .oneHour: return "ONE_HOUR"
        }
    }
}

/// macOS におけるメニューバー常駐モードを定義する列挙型。
nonisolated enum MenuBarResidencyMode: String, Codable, CaseIterable, Identifiable, Sendable {
    /// メニューバーに常駐しない。
    case notResident
    /// メニューバーに常駐し、ウインドウは開かない。
    case residentHidden
    /// メニューバーに常駐し、ウインドウも開く。
    case residentVisible

    /// Identifiable 適合用の識別子。
    var id: String { rawValue }

    /// ローカライズされた表示用ラベル文字列。
    var localizedLabel: String {
        switch self {
        case .notResident: return AppLocalized.text("menuBarResidency.notResident")
        case .residentHidden: return AppLocalized.text("menuBarResidency.residentHidden")
        case .residentVisible: return AppLocalized.text("menuBarResidency.residentVisible")
        }
    }
}

/// リアルタイム観測データ (Real-time observation data) の取得ソースを定義する列挙型。
nonisolated enum RealtimeDataSource: String, Codable, CaseIterable, Identifiable, Sendable {
    /// 国土交通省 (MLIT) の水文水質データベースから直接取得する。
    case mlitDirect
    /// sudmonitor 中継サーバーから取得する。
    case sudmonitor

    /// sudmonitor 中継サーバーのベース URL。
    static let sudmonitorBaseURL = "https://sudmonitor.kusugami-lab.net"
    /// sudmonitor 中継サーバーのホスト名。
    internal static let sudmonitorHost = "sudmonitor.kusugami-lab.net"
    /// sudmonitor 中継取得に対応するダム ID の集合（初期は早明浦ダムのみ）。
    static let sudmonitorSupportedDamIds: Set<String> = [AppSettings.defaultDamId]

    /// Identifiable 適合用の識別子。
    var id: String { rawValue }

    /// 指定されたダム ID に対する sudmonitor 中継取得の `.dat` URL を構築します。
    /// - Parameter damId: ダム ID。
    /// - Returns: sudmonitor の最新 `.dat` 配信 URL。
    static func sudmonitorLatestDatURL(damId: String) -> String {
        "\(sudmonitorBaseURL)/v1/realtime/\(damId)/latest.dat"
    }

    /// ローカライズされた表示用ラベル文字列。
    var localizedLabel: String {
        switch self {
        case .mlitDirect: return AppLocalized.text("settings.dataSourceRealtimeMlit")
        case .sudmonitor: return AppLocalized.text("settings.dataSourceRealtimeSudmonitor")
        }
    }
}

/// 貯水状況やエラーなどに応じたウィジェットや通知で表示するメッセージのプリセットを定義する列挙型。
nonisolated enum StorageMessagePreset: String, Sendable {
    /// 日本語以外：貯水率 80-100%
    case nonJa80_100 = "storage.nonJa.80_100.message"
    /// 日本語以外：貯水率 60-80%
    case nonJa60_80 = "storage.nonJa.60_80.message"
    /// 日本語以外：貯水率 40-60%
    case nonJa40_60 = "storage.nonJa.40_60.message"
    /// 日本語以外：貯水率 20-40%
    case nonJa20_40 = "storage.nonJa.20_40.message"
    /// 日本語以外：貯水率 0-20%
    case nonJa0_20 = "storage.nonJa.0_20.message"
    /// 日本語以外：貯水率 0%
    case nonJa0 = "storage.nonJa.0.message"
    /// 日本語：読み込みエラー
    case loadingErrorJa = "storage.loadingError.ja.message"
    /// 日本語以外：読み込みエラー
    case loadingErrorNonJa = "storage.loadingError.nonJa.message"
    /// 日本語：異常値検出（貯水率データなしなど）
    case allAbnormalJa = "storage.allAbnormal.ja.message"
    /// 日本語以外：異常値検出
    case allAbnormalNonJa = "storage.allAbnormal.nonJa.message"
    /// 日本語：すべてのリアルタイム観測データ (Real-time observation data) が無効
    case allDataInvalidJa = "storage.allDataInvalid.ja.message"
    /// 日本語以外：すべてのリアルタイム観測データ (Real-time observation data) が無効
    case allDataInvalidNonJa = "storage.allDataInvalid.nonJa.message"
    /// 日本語：初期状態
    case initialJa = "storage.initial.ja.message"
    /// 日本語以外：初期状態
    case initialNonJa = "storage.initial.nonJa.message"
    /// 日本語：ネットワーク利用不可
    case networkUnavailableJa = "storage.networkUnavailable.ja.message"
    /// 日本語以外：ネットワーク利用不可
    case networkUnavailableNonJa = "storage.networkUnavailable.nonJa.message"
    /// 日本語：データ配信停止
    case dataDistributionStoppedJa = "storage.dataDistributionStopped.ja.message"
    /// 日本語以外：データ配信停止
    case dataDistributionStoppedNonJa = "storage.dataDistributionStopped.nonJa.message"
    /// 日本語：データ配信再開
    case dataDistributionResumedJa = "storage.dataDistributionResumed.ja.message"
    /// 日本語以外：データ配信再開
    case dataDistributionResumedNonJa = "storage.dataDistributionResumed.nonJa.message"

    /// 指定されたロケールに対応するローカライズされたメッセージを取得します。
    ///
    /// - Parameter locale: 対象のロケール（デフォルトは `effectiveLocale`）。
    /// - Returns: メッセージ文字列。
    nonisolated func message(locale: Locale = AppLocale.effectiveLocale) -> String {
        AppLocalized.text(rawValue, locale: locale)
    }
}

/// デバッグ用のネットワーク・シミュレーションモードを定義する列挙型。
nonisolated enum DebugSimulateMode: String, Codable, CaseIterable, Identifiable, Sendable {
    /// シミュレーションなし。
    case none
    /// ネットワーク利用不可をシミュレート。
    case networkUnavailable
    /// 読み込み失敗をシミュレート。
    case loadingFailure

    /// Identifiable 適合用の識別子。
    var id: String { rawValue }
}

/// デバッグ時のデータ取得元 .dat ファイルの選択モードを定義する列挙型。
nonisolated enum DebugDatSelectionMode: String, Codable, CaseIterable, Identifiable, Sendable {
    /// バンドルされた .dat ファイルを使用する。
    case bundled
    /// Debug Mode ON 直前に保持していた最新データを使用する。
    case latest
    /// ユーザーが選択したカスタム .dat ファイルを使用する。
    case userSelected

    /// Identifiable 適合用の識別子。
    var id: String { rawValue }
}

/// 貯水率 (Storage rate) の表示メッセージをリセットする際のモードを定義する列挙型。
nonisolated enum StorageRateMessageResetMode: String, Sendable {
    /// 削除して空にする。
    case delete
    /// 日本語のデフォルト値にリセットする。
    case japanese = "ja"
    /// 日本語以外のデフォルト値にリセットする。
    case nonJapanese = "non_ja"
}

fileprivate extension StorageRateMessageResetMode {
    nonisolated static let allStandardModes: [StorageRateMessageResetMode] = [.delete, .japanese, .nonJapanese]
}

/// 貯水率以外の表示メッセージのフィールド種類を定義する列挙型。
nonisolated enum OtherMessageField: String, CaseIterable, Sendable {
    /// 初期表示メッセージ。
    case initialMessage = "initial_message"
    /// ネットワーク切断時のメッセージ。
    case networkUnavailable = "network_unavailable"
    /// 読み込みエラー時のメッセージ。
    case loadingError = "loading_error"
    /// データ配信停止時のメッセージ。
    case dataDistributionStopped = "data_distribution_stopped"
    /// データ配信再開時のメッセージ。
    case dataDistributionResumed = "data_distribution_resumed"
}

/// メッセージ記述子のタイトル表現方法を定義する列挙型。
nonisolated enum MessageDescriptorTitle: Hashable, Sendable {
    /// リテラル文字列をそのままタイトルとして用いる。
    case literal(String)
    /// ローカライズされた文字列キー。
    case localized(String)
    /// ローカライズされた文字列キー。キーが未定義（ローカライズファイル未追加）の場合、言語別のフォールバック文字列を用いる。
    case localizedWithFallback(String, fallbackJa: String, fallbackEn: String)

    /// タイトルテキストの確定値を取得します。
    ///
    /// - Returns: 決定されたタイトル文字列。
    func text() -> String {
        switch self {
        case .literal(let value):
            return value
        case .localized(let key):
            return AppLocalized.text(key)
        case .localizedWithFallback(let key, let fallbackJa, let fallbackEn):
            let resolved = AppLocalized.text(key)
            if resolved == key || resolved.isEmpty {
                return AppLocale.isJapanese ? fallbackJa : fallbackEn
            }
            return resolved
        }
    }
}

/// 貯水率 (Storage rate) に応じたウィジェット表示メッセージの設定項目を保持するメタデータ記述子。
nonisolated struct StorageRateMessageDescriptor {
    /// ウィジェットメッセージのキー。
    let widgetKey: DamCoreWidgetMessageKey
    /// 設定画面などで表示されるタイトル。
    let title: MessageDescriptorTitle
    /// 状態（顔文字など）を保存する AppSettings 上のプロパティパス。
    let state: WritableKeyPath<AppSettings, String>
    /// 日本語以外のメッセージ本文を保存する AppSettings 上のプロパティパス。
    let message: WritableKeyPath<AppSettings, String>
    /// 日本語のメッセージ本文を保存する AppSettings 上のプロパティパス。
    let japaneseMessage: WritableKeyPath<AppSettings, String>
    /// デフォルトの状態（顔文字）。
    let defaultState: String
    /// 日本語以外のメッセージデフォルトプリセット。
    let nonJapanesePreset: StorageMessagePreset
    /// 日本語のメッセージデフォルト値を動的に生成するクロージャ。
    let japaneseDefault: @Sendable (Locale) -> String

    func resetMessages(mode: StorageRateMessageResetMode) -> (String, String) {
        let jaLocale = Locale(identifier: "ja")
        switch mode {
        case .delete:
            return ("", "")
        case .japanese:
            return (nonJapanesePreset.message(), japaneseDefault(jaLocale))
        case .nonJapanese:
            let nonJapanese = nonJapanesePreset.message()
            let japanese: String
            switch widgetKey {
            case .abnormal, .allDataInvalid:
                japanese = japaneseDefault(jaLocale)
            default:
                japanese = nonJapanese
            }
            return (nonJapanese, japanese)
        }
    }
}

/// 貯水率以外のステータス（初期状態やネットワークエラー等）に対応するメッセージの設定項目を保持するメタデータ記述子。
nonisolated struct OtherMessageDescriptor {
    /// 該当するメッセージフィールドの種類。
    let field: OtherMessageField
    /// ウィジェットメッセージ of キー（省略可能）。
    let widgetKey: DamCoreWidgetMessageKey?
    /// 設定画面などで表示されるタイトル。
    let title: MessageDescriptorTitle
    /// 状態（顔文字など）を保存する AppSettings 上のプロパティパス。
    let state: WritableKeyPath<AppSettings, String>
    /// 日本語以外のメッセージ本文を保存する AppSettings 上のプロパティパス。
    let message: WritableKeyPath<AppSettings, String>
    /// 日本語のメッセージ本文を保存する AppSettings 上のプロパティパス。
    let japaneseMessage: WritableKeyPath<AppSettings, String>
    /// デフォルトの状態（顔文字）。
    let defaultState: String
    /// 日本語以外のメッセージデフォルトプリセット。
    let nonJapanesePreset: StorageMessagePreset
    /// 日本語のメッセージデフォルトプリセット。
    let japanesePreset: StorageMessagePreset
}

/// アプリの全般的な設定項目を保持する構造体。
nonisolated struct AppSettingsGeneral: Codable, Equatable, Sendable {
    /// アプリの表示テーマ。
    var theme: AppTheme
    /// 通知を表示するかどうか。
    var showNotification: Bool
    /// 対象とするダムの観測所ID。
    var targetDamId: String
    /// リアルタイム観測データ (Real-time observation data) の取得ソース。未設定時は sudmonitor 中継を既定とする。
    var realtimeDataSource: RealtimeDataSource?
    /// 過去データ検索 (Historical data search) の取得ソース。未設定時は sudmonitor 中継を既定とする。
    var historicalDataSource: RealtimeDataSource? = nil
    /// macOS におけるメニューバー常駐モード。未設定時は常駐しないことを既定とする。
    var menuBarResidencyMode: MenuBarResidencyMode? = nil
    /// 未設定時に常駐しないことを返す、メニューバー常駐モードの実効値。
    var effectiveMenuBarResidencyMode: MenuBarResidencyMode { menuBarResidencyMode ?? .notResident }
}

/// アプリの自動更新に関する設定項目を保持する構造体。
nonisolated struct AppSettingsAutoUpdate: Codable, Equatable, Sendable {
    /// 自動更新が有効かどうか。
    var enabled: Bool
    /// 自動更新の実行間隔。
    var interval: AutoUpdateInterval
    /// 初回の自動更新設定ダイアログが表示済みかどうか。
    var initialDialogShown: Bool
    /// 初回の自動更新予約時間を決定するための基準となる、1日の中の分（Minute of Day）情報。
    var initialAnchorMinuteOfDay: Int?
    /// 端末起動時に自動更新を予約または即時実行するかどうか。
    var updateOnBoot: Bool
    /// 次回要求される自動更新日時。
    var nextRequestedUpdate: Date
    /// 最後の自動更新実行日時。
    var lastAutoUpdate: Date?
}

/// アプリのデバッグに関する設定項目を保持する構造体。
nonisolated struct AppSettingsDebug: Codable, Equatable, Sendable {
    /// デバッグモードが有効かどうか。
    var modeEnabled: Bool
    /// デバッグ設定画面を表示するかどうか。
    var settingsVisible: Bool
    /// ネットワークや読み込み状態の擬似シミュレーションモード。
    var simulateMode: DebugSimulateMode
    /// リアルタイムデータ用のデバッグ .dat ファイル選択モード。
    var realtimeDatSelectionMode: DebugDatSelectionMode
    /// ユーザーが選択したリアルタイムデータ用 .dat ファイルの名称。
    var realtimeDatFileName: String?
    /// 過去データ(日次)用のデバッグ .dat ファイル選択モード。
    var historicalDailyDatSelectionMode: DebugDatSelectionMode
    /// ユーザーが選択した過去データ(日次)用 .dat ファイルの名称。
    var historicalDailyDatFileName: String?
    /// デバッグ時のリアルタイムデータ終了日時。
    var realtimeDataEndDate: Date?
    /// リアルタイムデータの期間を観測データ取得ごとに進めるかどうか。
    var realtimeDataPeriodAutoAdvanceEnabled: Bool

    private enum CodingKeys: String, CodingKey {
        case modeEnabled
        case settingsVisible
        case simulateMode
        case realtimeDatSelectionMode
        case realtimeDatFileName
        case historicalDailyDatSelectionMode
        case historicalDailyDatFileName
        case realtimeDataEndDate
        case realtimeDataPeriodAutoAdvanceEnabled
        case datFileMode
        case datFileName
        case dataEndDate
        case dataPeriodAutoAdvanceEnabled
    }

    nonisolated init(
        modeEnabled: Bool,
        settingsVisible: Bool,
        simulateMode: DebugSimulateMode,
        realtimeDatSelectionMode: DebugDatSelectionMode,
        realtimeDatFileName: String?,
        historicalDailyDatSelectionMode: DebugDatSelectionMode,
        historicalDailyDatFileName: String?,
        realtimeDataEndDate: Date?,
        realtimeDataPeriodAutoAdvanceEnabled: Bool
    ) {
        self.modeEnabled = modeEnabled
        self.settingsVisible = settingsVisible
        self.simulateMode = simulateMode
        self.realtimeDatSelectionMode = realtimeDatSelectionMode
        self.realtimeDatFileName = realtimeDatFileName
        self.historicalDailyDatSelectionMode = historicalDailyDatSelectionMode
        self.historicalDailyDatFileName = historicalDailyDatFileName
        self.realtimeDataEndDate = realtimeDataEndDate
        self.realtimeDataPeriodAutoAdvanceEnabled = realtimeDataPeriodAutoAdvanceEnabled
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        modeEnabled = try container.decodeIfPresent(Bool.self, forKey: .modeEnabled) ?? false
        settingsVisible = try container.decodeIfPresent(Bool.self, forKey: .settingsVisible) ?? false
        simulateMode = try container.decodeIfPresent(DebugSimulateMode.self, forKey: .simulateMode) ?? .none

        if let mode = try container.decodeIfPresent(DebugDatSelectionMode.self, forKey: .realtimeDatSelectionMode) {
            realtimeDatSelectionMode = mode
        } else {
            let legacyMode = try container.decodeIfPresent(String.self, forKey: .datFileMode)
            realtimeDatSelectionMode = Self.selectionMode(fromLegacyRawValue: legacyMode)
        }
        let realtimeFileName = try container.decodeIfPresent(String.self, forKey: .realtimeDatFileName)
        let legacyFileName = try container.decodeIfPresent(String.self, forKey: .datFileName)
        realtimeDatFileName = realtimeFileName ?? legacyFileName
        historicalDailyDatSelectionMode = try container.decodeIfPresent(DebugDatSelectionMode.self, forKey: .historicalDailyDatSelectionMode) ?? .bundled
        historicalDailyDatFileName = try container.decodeIfPresent(String.self, forKey: .historicalDailyDatFileName)
        let realtimeEndDate = try container.decodeIfPresent(Date.self, forKey: .realtimeDataEndDate)
        let legacyEndDate = try container.decodeIfPresent(Date.self, forKey: .dataEndDate)
        realtimeDataEndDate = realtimeEndDate ?? legacyEndDate
        let realtimeAutoAdvance = try container.decodeIfPresent(Bool.self, forKey: .realtimeDataPeriodAutoAdvanceEnabled)
        let legacyAutoAdvance = try container.decodeIfPresent(Bool.self, forKey: .dataPeriodAutoAdvanceEnabled)
        realtimeDataPeriodAutoAdvanceEnabled = realtimeAutoAdvance ?? legacyAutoAdvance ?? true
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(modeEnabled, forKey: .modeEnabled)
        try container.encode(settingsVisible, forKey: .settingsVisible)
        try container.encode(simulateMode, forKey: .simulateMode)
        try container.encode(realtimeDatSelectionMode, forKey: .realtimeDatSelectionMode)
        try container.encodeIfPresent(realtimeDatFileName, forKey: .realtimeDatFileName)
        try container.encode(historicalDailyDatSelectionMode, forKey: .historicalDailyDatSelectionMode)
        try container.encodeIfPresent(historicalDailyDatFileName, forKey: .historicalDailyDatFileName)
        try container.encodeIfPresent(realtimeDataEndDate, forKey: .realtimeDataEndDate)
        try container.encode(realtimeDataPeriodAutoAdvanceEnabled, forKey: .realtimeDataPeriodAutoAdvanceEnabled)
    }

    private nonisolated static func selectionMode(fromLegacyRawValue rawValue: String?) -> DebugDatSelectionMode {
        switch rawValue {
        case DebugDatSelectionMode.userSelected.rawValue:
            return .userSelected
        case "realtime", DebugDatSelectionMode.latest.rawValue:
            return .latest
        default:
            return .bundled
        }
    }
}

/// ウィジェット等に表示する各種メッセージの個別設定項目を保持する構造体。
nonisolated struct AppSettingsMessages: Codable, Equatable, Sendable {
    /// 貯水率 (Storage rate) のメッセージを表示するかどうか。
    var showStorageRateMessage: Bool
    /// 貯水率 80-100% 時のステータス顔文字。
    var state80_100: String
    /// 貯水率 80-100% 時のメッセージ本文。
    var msg80_100: String
    /// 貯水率 80-100% 時の日本語メッセージ本文。
    var msg80_100Ja: String
    /// 貯水率 60-80% 時のステータス顔文字。
    var state60_80: String
    /// 貯水率 60-80% 時のメッセージ本文。
    var msg60_80: String
    /// 貯水率 60-80% 時の日本語メッセージ本文。
    var msg60_80Ja: String
    /// 貯水率 40-60% 時のステータス顔文字。
    var state40_60: String
    /// 貯水率 40-60% 時のメッセージ本文。
    var msg40_60: String
    /// 貯水率 40-60% 時の日本語メッセージ本文。
    var msg40_60Ja: String
    /// 貯水率 20-40% 時のステータス顔文字。
    var state20_40: String
    /// 貯水率 20-40% 時のメッセージ本文。
    var msg20_40: String
    /// 貯水率 20-40% 時の日本語メッセージ本文。
    var msg20_40Ja: String
    /// 貯水率 0-20% 時のステータス顔文字。
    var state0_20: String
    /// 貯水率 0-20% 時のメッセージ本文。
    var msg0_20: String
    /// 貯水率 0-20% 時の日本語メッセージ本文。
    var msg0_20Ja: String
    /// 貯水率 0% 時のステータス顔文字。
    var state0: String
    /// 貯水率 0% 時のメッセージ本文。
    var msg0: String
    /// 貯水率 0% 時の日本語メッセージ本文。
    var msg0Ja: String
    /// 貯水率データ異常値（欠測など）時のステータス顔文字。
    var stateAllAbnormal: String
    /// 貯水率データ異常値（欠測など）時のメッセージ本文。
    var msgAllAbnormal: String
    /// 貯水率データ異常値（欠測など）時の日本語メッセージ本文。
    var msgAllAbnormalJa: String
    /// すべてのリアルタイム観測データ (Real-time observation data) が無効な時のステータス顔文字。
    var stateAllDataInvalid: String
    /// すべてのリアルタイム観測データ (Real-time observation data) が無効な時のメッセージ本文。
    var msgAllDataInvalid: String
    /// すべてのリアルタイム観測データ (Real-time observation data) が無効な時の日本語メッセージ本文。
    var msgAllDataInvalidJa: String
    /// 早明浦ダム以外の貯水率 80-100% 時のステータス顔文字。
    var otherState80_100: String
    /// 早明浦ダム以外の貯水率 80-100% 時のメッセージ本文。
    var otherMsg80_100: String
    /// 早明浦ダム以外の貯水率 80-100% 時の日本語メッセージ本文。
    var otherMsg80_100Ja: String
    /// 早明浦ダム以外の貯水率 60-80% 時のステータス顔文字。
    var otherState60_80: String
    /// 早明浦ダム以外の貯水率 60-80% 時のメッセージ本文。
    var otherMsg60_80: String
    /// 早明浦ダム以外の貯水率 60-80% 時の日本語メッセージ本文。
    var otherMsg60_80Ja: String
    /// 早明浦ダム以外の貯水率 40-60% 時のステータス顔文字。
    var otherState40_60: String
    /// 早明浦ダム以外の貯水率 40-60% 時のメッセージ本文。
    var otherMsg40_60: String
    /// 早明浦ダム以外の貯水率 40-60% 時の日本語メッセージ本文。
    var otherMsg40_60Ja: String
    /// 早明浦ダム以外の貯水率 20-40% 時のステータス顔文字。
    var otherState20_40: String
    /// 早明浦ダム以外の貯水率 20-40% 時のメッセージ本文。
    var otherMsg20_40: String
    /// 早明浦ダム以外の貯水率 20-40% 時の日本語メッセージ本文。
    var otherMsg20_40Ja: String
    /// 早明浦ダム以外の貯水率 0-20% 時のステータス顔文字。
    var otherState0_20: String
    /// 早明浦ダム以外の貯水率 0-20% 時のメッセージ本文。
    var otherMsg0_20: String
    /// 早明浦ダム以外の貯水率 0-20% 時の日本語メッセージ本文。
    var otherMsg0_20Ja: String
    /// 早明浦ダム以外の貯水率 0% 時のステータス顔文字。
    var otherState0: String
    /// 早明浦ダム以外の貯水率 0% 時のメッセージ本文。
    var otherMsg0: String
    /// 早明浦ダム以外の貯水率 0% 時の日本語メッセージ本文。
    var otherMsg0Ja: String
    /// 早明浦ダム以外の貯水率データ異常値（欠測など）時のステータス顔文字。
    var otherStateAllAbnormal: String
    /// 早明浦ダム以外の貯水率データ異常値（欠測など）時のメッセージ本文。
    var otherMsgAllAbnormal: String
    /// 早明浦ダム以外の貯水率データ異常値（欠測など）時の日本語メッセージ本文。
    var otherMsgAllAbnormalJa: String
    /// 早明浦ダム以外のすべてのリアルタイム観測データ (Real-time observation data) が無効な時のステータス顔文字。
    var otherStateAllDataInvalid: String
    /// 早明浦ダム以外のすべてのリアルタイム観測データ (Real-time observation data) が無効な時のメッセージ本文。
    var otherMsgAllDataInvalid: String
    /// 早明浦ダム以外のすべてのリアルタイム観測データ (Real-time observation data) が無効な時の日本語メッセージ本文。
    var otherMsgAllDataInvalidJa: String
    /// 初期表示時のステータス顔文字。
    var stateInitialMessage: String
    /// 初期表示時のメッセージ本文。
    var msgInitialMessage: String
    /// 初期表示時の日本語メッセージ本文。
    var msgInitialMessageJa: String
    /// ネットワーク切断時のステータス顔文字。
    var stateNetworkUnavailable: String
    /// ネットワーク切断時のメッセージ本文。
    var msgNetworkUnavailable: String
    /// ネットワーク切断時の日本語メッセージ本文。
    var msgNetworkUnavailableJa: String
    /// 読み込みエラー時のステータス顔文字。
    var stateLoadingError: String
    /// 読み込みエラー時のメッセージ本文。
    var msgLoadingError: String
    /// 読み込みエラー時の日本語メッセージ本文。
    var msgLoadingErrorJa: String
    /// データ配信停止時のステータス顔文字。
    var stateDataDistributionStopped: String
    /// データ配信停止時のメッセージ本文。
    var msgDataDistributionStopped: String
    /// データ配信停止時の日本語メッセージ本文。
    var msgDataDistributionStoppedJa: String
    /// データ配信再開時のステータス顔文字。
    var stateDataDistributionResumed: String
    /// データ配信再開時のメッセージ本文。
    var msgDataDistributionResumed: String
    /// データ配信再開時の日本語メッセージ本文。
    var msgDataDistributionResumedJa: String

    /// すべてのメッセージ設定フィールドを指定して初期化します。
    ///
    /// 引数を省略した場合、一般向け（早明浦ダム以外用）の既定値が使用されます。
    /// 一般向け既定値は `StorageMessagePreset` の日本語以外（nonJa）系メッセージとステータス顔文字で、
    /// 日本語本文は `all_abnormal` / `all_data_invalid` のみ日本語の既定メッセージ、それ以外は日本語以外（nonJa）系と同じ文言です。
    nonisolated init(
        showStorageRateMessage: Bool = true,
        state80_100: String = "😊",
        msg80_100: String = StorageMessagePreset.nonJa80_100.message(),
        msg80_100Ja: String = StorageMessagePreset.nonJa80_100.message(),
        state60_80: String = "😌",
        msg60_80: String = StorageMessagePreset.nonJa60_80.message(),
        msg60_80Ja: String = StorageMessagePreset.nonJa60_80.message(),
        state40_60: String = "😨",
        msg40_60: String = StorageMessagePreset.nonJa40_60.message(),
        msg40_60Ja: String = StorageMessagePreset.nonJa40_60.message(),
        state20_40: String = "😰",
        msg20_40: String = StorageMessagePreset.nonJa20_40.message(),
        msg20_40Ja: String = StorageMessagePreset.nonJa20_40.message(),
        state0_20: String = "😱",
        msg0_20: String = StorageMessagePreset.nonJa0_20.message(),
        msg0_20Ja: String = StorageMessagePreset.nonJa0_20.message(),
        state0: String = "😇",
        msg0: String = StorageMessagePreset.nonJa0.message(),
        msg0Ja: String = StorageMessagePreset.nonJa0.message(),
        stateAllAbnormal: String = "😑",
        msgAllAbnormal: String = StorageMessagePreset.allAbnormalNonJa.message(),
        msgAllAbnormalJa: String = StorageMessagePreset.allAbnormalJa.message(locale: Locale(identifier: "ja")),
        stateAllDataInvalid: String = "😴",
        msgAllDataInvalid: String = StorageMessagePreset.allDataInvalidNonJa.message(),
        msgAllDataInvalidJa: String = StorageMessagePreset.allDataInvalidJa.message(locale: Locale(identifier: "ja")),
        otherState80_100: String = "😊",
        otherMsg80_100: String = StorageMessagePreset.nonJa80_100.message(),
        otherMsg80_100Ja: String = StorageMessagePreset.nonJa80_100.message(),
        otherState60_80: String = "😌",
        otherMsg60_80: String = StorageMessagePreset.nonJa60_80.message(),
        otherMsg60_80Ja: String = StorageMessagePreset.nonJa60_80.message(),
        otherState40_60: String = "😨",
        otherMsg40_60: String = StorageMessagePreset.nonJa40_60.message(),
        otherMsg40_60Ja: String = StorageMessagePreset.nonJa40_60.message(),
        otherState20_40: String = "😰",
        otherMsg20_40: String = StorageMessagePreset.nonJa20_40.message(),
        otherMsg20_40Ja: String = StorageMessagePreset.nonJa20_40.message(),
        otherState0_20: String = "😱",
        otherMsg0_20: String = StorageMessagePreset.nonJa0_20.message(),
        otherMsg0_20Ja: String = StorageMessagePreset.nonJa0_20.message(),
        otherState0: String = "😇",
        otherMsg0: String = StorageMessagePreset.nonJa0.message(),
        otherMsg0Ja: String = StorageMessagePreset.nonJa0.message(),
        otherStateAllAbnormal: String = "😑",
        otherMsgAllAbnormal: String = StorageMessagePreset.allAbnormalNonJa.message(),
        otherMsgAllAbnormalJa: String = StorageMessagePreset.allAbnormalJa.message(locale: Locale(identifier: "ja")),
        otherStateAllDataInvalid: String = "😴",
        otherMsgAllDataInvalid: String = StorageMessagePreset.allDataInvalidNonJa.message(),
        otherMsgAllDataInvalidJa: String = StorageMessagePreset.allDataInvalidJa.message(locale: Locale(identifier: "ja")),
        stateInitialMessage: String = "🥺",
        msgInitialMessage: String = StorageMessagePreset.initialNonJa.message(),
        msgInitialMessageJa: String = StorageMessagePreset.initialJa.message(locale: Locale(identifier: "ja")),
        stateNetworkUnavailable: String = "😢",
        msgNetworkUnavailable: String = StorageMessagePreset.networkUnavailableNonJa.message(),
        msgNetworkUnavailableJa: String = StorageMessagePreset.networkUnavailableJa.message(locale: Locale(identifier: "ja")),
        stateLoadingError: String = "😵",
        msgLoadingError: String = StorageMessagePreset.loadingErrorNonJa.message(),
        msgLoadingErrorJa: String = StorageMessagePreset.loadingErrorJa.message(locale: Locale(identifier: "ja")),
        stateDataDistributionStopped: String = "😪",
        msgDataDistributionStopped: String = StorageMessagePreset.dataDistributionStoppedNonJa.message(),
        msgDataDistributionStoppedJa: String = StorageMessagePreset.dataDistributionStoppedJa.message(locale: Locale(identifier: "ja")),
        stateDataDistributionResumed: String = "🥱",
        msgDataDistributionResumed: String = StorageMessagePreset.dataDistributionResumedNonJa.message(),
        msgDataDistributionResumedJa: String = StorageMessagePreset.dataDistributionResumedJa.message(locale: Locale(identifier: "ja"))
    ) {
        self.showStorageRateMessage = showStorageRateMessage
        self.state80_100 = state80_100
        self.msg80_100 = msg80_100
        self.msg80_100Ja = msg80_100Ja
        self.state60_80 = state60_80
        self.msg60_80 = msg60_80
        self.msg60_80Ja = msg60_80Ja
        self.state40_60 = state40_60
        self.msg40_60 = msg40_60
        self.msg40_60Ja = msg40_60Ja
        self.state20_40 = state20_40
        self.msg20_40 = msg20_40
        self.msg20_40Ja = msg20_40Ja
        self.state0_20 = state0_20
        self.msg0_20 = msg0_20
        self.msg0_20Ja = msg0_20Ja
        self.state0 = state0
        self.msg0 = msg0
        self.msg0Ja = msg0Ja
        self.stateAllAbnormal = stateAllAbnormal
        self.msgAllAbnormal = msgAllAbnormal
        self.msgAllAbnormalJa = msgAllAbnormalJa
        self.stateAllDataInvalid = stateAllDataInvalid
        self.msgAllDataInvalid = msgAllDataInvalid
        self.msgAllDataInvalidJa = msgAllDataInvalidJa
        self.stateInitialMessage = stateInitialMessage
        self.msgInitialMessage = msgInitialMessage
        self.msgInitialMessageJa = msgInitialMessageJa
        self.stateNetworkUnavailable = stateNetworkUnavailable
        self.msgNetworkUnavailable = msgNetworkUnavailable
        self.msgNetworkUnavailableJa = msgNetworkUnavailableJa
        self.stateLoadingError = stateLoadingError
        self.msgLoadingError = msgLoadingError
        self.msgLoadingErrorJa = msgLoadingErrorJa
        self.stateDataDistributionStopped = stateDataDistributionStopped
        self.msgDataDistributionStopped = msgDataDistributionStopped
        self.msgDataDistributionStoppedJa = msgDataDistributionStoppedJa
        self.stateDataDistributionResumed = stateDataDistributionResumed
        self.msgDataDistributionResumed = msgDataDistributionResumed
        self.msgDataDistributionResumedJa = msgDataDistributionResumedJa
        self.otherState80_100 = otherState80_100
        self.otherMsg80_100 = otherMsg80_100
        self.otherMsg80_100Ja = otherMsg80_100Ja
        self.otherState60_80 = otherState60_80
        self.otherMsg60_80 = otherMsg60_80
        self.otherMsg60_80Ja = otherMsg60_80Ja
        self.otherState40_60 = otherState40_60
        self.otherMsg40_60 = otherMsg40_60
        self.otherMsg40_60Ja = otherMsg40_60Ja
        self.otherState20_40 = otherState20_40
        self.otherMsg20_40 = otherMsg20_40
        self.otherMsg20_40Ja = otherMsg20_40Ja
        self.otherState0_20 = otherState0_20
        self.otherMsg0_20 = otherMsg0_20
        self.otherMsg0_20Ja = otherMsg0_20Ja
        self.otherState0 = otherState0
        self.otherMsg0 = otherMsg0
        self.otherMsg0Ja = otherMsg0Ja
        self.otherStateAllAbnormal = otherStateAllAbnormal
        self.otherMsgAllAbnormal = otherMsgAllAbnormal
        self.otherMsgAllAbnormalJa = otherMsgAllAbnormalJa
        self.otherStateAllDataInvalid = otherStateAllDataInvalid
        self.otherMsgAllDataInvalid = otherMsgAllDataInvalid
        self.otherMsgAllDataInvalidJa = otherMsgAllDataInvalidJa
    }

    /// コーディングキー。
    private enum CodingKeys: String, CodingKey {
        case showStorageRateMessage
        case state80_100, msg80_100, msg80_100Ja
        case state60_80, msg60_80, msg60_80Ja
        case state40_60, msg40_60, msg40_60Ja
        case state20_40, msg20_40, msg20_40Ja
        case state0_20, msg0_20, msg0_20Ja
        case state0, msg0, msg0Ja
        case stateAllAbnormal, msgAllAbnormal, msgAllAbnormalJa
        case stateAllDataInvalid, msgAllDataInvalid, msgAllDataInvalidJa
        case stateInitialMessage, msgInitialMessage, msgInitialMessageJa
        case stateNetworkUnavailable, msgNetworkUnavailable, msgNetworkUnavailableJa
        case stateLoadingError, msgLoadingError, msgLoadingErrorJa
        case stateDataDistributionStopped, msgDataDistributionStopped, msgDataDistributionStoppedJa
        case stateDataDistributionResumed, msgDataDistributionResumed, msgDataDistributionResumedJa
        case otherState80_100, otherMsg80_100, otherMsg80_100Ja
        case otherState60_80, otherMsg60_80, otherMsg60_80Ja
        case otherState40_60, otherMsg40_60, otherMsg40_60Ja
        case otherState20_40, otherMsg20_40, otherMsg20_40Ja
        case otherState0_20, otherMsg0_20, otherMsg0_20Ja
        case otherState0, otherMsg0, otherMsg0Ja
        case otherStateAllAbnormal, otherMsgAllAbnormal, otherMsgAllAbnormalJa
        case otherStateAllDataInvalid, otherMsgAllDataInvalid, otherMsgAllDataInvalidJa
    }

    /// デコーダーから設定を復元します。
    ///
    /// 全フィールドを `decodeIfPresent` で読み、欠落したキーは一般向け既定値で補完します。
    /// これにより、other* フィールドを持たない旧 `"app.settings.v2"` 保存データでも
    /// デコードに失敗せず、既存のユーザー設定を保持できます。
    ///
    /// - Parameter decoder: デコードに使用するデコーダー。
    /// - Throws: デコードエラーが発生した場合。
    nonisolated init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showStorageRateMessage = try container.decodeIfPresent(Bool.self, forKey: .showStorageRateMessage) ?? showStorageRateMessage
        state80_100 = try container.decodeIfPresent(String.self, forKey: .state80_100) ?? state80_100
        msg80_100 = try container.decodeIfPresent(String.self, forKey: .msg80_100) ?? msg80_100
        msg80_100Ja = try container.decodeIfPresent(String.self, forKey: .msg80_100Ja) ?? msg80_100Ja
        state60_80 = try container.decodeIfPresent(String.self, forKey: .state60_80) ?? state60_80
        msg60_80 = try container.decodeIfPresent(String.self, forKey: .msg60_80) ?? msg60_80
        msg60_80Ja = try container.decodeIfPresent(String.self, forKey: .msg60_80Ja) ?? msg60_80Ja
        state40_60 = try container.decodeIfPresent(String.self, forKey: .state40_60) ?? state40_60
        msg40_60 = try container.decodeIfPresent(String.self, forKey: .msg40_60) ?? msg40_60
        msg40_60Ja = try container.decodeIfPresent(String.self, forKey: .msg40_60Ja) ?? msg40_60Ja
        state20_40 = try container.decodeIfPresent(String.self, forKey: .state20_40) ?? state20_40
        msg20_40 = try container.decodeIfPresent(String.self, forKey: .msg20_40) ?? msg20_40
        msg20_40Ja = try container.decodeIfPresent(String.self, forKey: .msg20_40Ja) ?? msg20_40Ja
        state0_20 = try container.decodeIfPresent(String.self, forKey: .state0_20) ?? state0_20
        msg0_20 = try container.decodeIfPresent(String.self, forKey: .msg0_20) ?? msg0_20
        msg0_20Ja = try container.decodeIfPresent(String.self, forKey: .msg0_20Ja) ?? msg0_20Ja
        state0 = try container.decodeIfPresent(String.self, forKey: .state0) ?? state0
        msg0 = try container.decodeIfPresent(String.self, forKey: .msg0) ?? msg0
        msg0Ja = try container.decodeIfPresent(String.self, forKey: .msg0Ja) ?? msg0Ja
        stateAllAbnormal = try container.decodeIfPresent(String.self, forKey: .stateAllAbnormal) ?? stateAllAbnormal
        msgAllAbnormal = try container.decodeIfPresent(String.self, forKey: .msgAllAbnormal) ?? msgAllAbnormal
        msgAllAbnormalJa = try container.decodeIfPresent(String.self, forKey: .msgAllAbnormalJa) ?? msgAllAbnormalJa
        stateAllDataInvalid = try container.decodeIfPresent(String.self, forKey: .stateAllDataInvalid) ?? stateAllDataInvalid
        msgAllDataInvalid = try container.decodeIfPresent(String.self, forKey: .msgAllDataInvalid) ?? msgAllDataInvalid
        msgAllDataInvalidJa = try container.decodeIfPresent(String.self, forKey: .msgAllDataInvalidJa) ?? msgAllDataInvalidJa
        stateInitialMessage = try container.decodeIfPresent(String.self, forKey: .stateInitialMessage) ?? stateInitialMessage
        msgInitialMessage = try container.decodeIfPresent(String.self, forKey: .msgInitialMessage) ?? msgInitialMessage
        msgInitialMessageJa = try container.decodeIfPresent(String.self, forKey: .msgInitialMessageJa) ?? msgInitialMessageJa
        stateNetworkUnavailable = try container.decodeIfPresent(String.self, forKey: .stateNetworkUnavailable) ?? stateNetworkUnavailable
        msgNetworkUnavailable = try container.decodeIfPresent(String.self, forKey: .msgNetworkUnavailable) ?? msgNetworkUnavailable
        msgNetworkUnavailableJa = try container.decodeIfPresent(String.self, forKey: .msgNetworkUnavailableJa) ?? msgNetworkUnavailableJa
        stateLoadingError = try container.decodeIfPresent(String.self, forKey: .stateLoadingError) ?? stateLoadingError
        msgLoadingError = try container.decodeIfPresent(String.self, forKey: .msgLoadingError) ?? msgLoadingError
        msgLoadingErrorJa = try container.decodeIfPresent(String.self, forKey: .msgLoadingErrorJa) ?? msgLoadingErrorJa
        stateDataDistributionStopped = try container.decodeIfPresent(String.self, forKey: .stateDataDistributionStopped) ?? stateDataDistributionStopped
        msgDataDistributionStopped = try container.decodeIfPresent(String.self, forKey: .msgDataDistributionStopped) ?? msgDataDistributionStopped
        msgDataDistributionStoppedJa = try container.decodeIfPresent(String.self, forKey: .msgDataDistributionStoppedJa) ?? msgDataDistributionStoppedJa
        stateDataDistributionResumed = try container.decodeIfPresent(String.self, forKey: .stateDataDistributionResumed) ?? stateDataDistributionResumed
        msgDataDistributionResumed = try container.decodeIfPresent(String.self, forKey: .msgDataDistributionResumed) ?? msgDataDistributionResumed
        msgDataDistributionResumedJa = try container.decodeIfPresent(String.self, forKey: .msgDataDistributionResumedJa) ?? msgDataDistributionResumedJa
        otherState80_100 = try container.decodeIfPresent(String.self, forKey: .otherState80_100) ?? otherState80_100
        otherMsg80_100 = try container.decodeIfPresent(String.self, forKey: .otherMsg80_100) ?? otherMsg80_100
        otherMsg80_100Ja = try container.decodeIfPresent(String.self, forKey: .otherMsg80_100Ja) ?? otherMsg80_100Ja
        otherState60_80 = try container.decodeIfPresent(String.self, forKey: .otherState60_80) ?? otherState60_80
        otherMsg60_80 = try container.decodeIfPresent(String.self, forKey: .otherMsg60_80) ?? otherMsg60_80
        otherMsg60_80Ja = try container.decodeIfPresent(String.self, forKey: .otherMsg60_80Ja) ?? otherMsg60_80Ja
        otherState40_60 = try container.decodeIfPresent(String.self, forKey: .otherState40_60) ?? otherState40_60
        otherMsg40_60 = try container.decodeIfPresent(String.self, forKey: .otherMsg40_60) ?? otherMsg40_60
        otherMsg40_60Ja = try container.decodeIfPresent(String.self, forKey: .otherMsg40_60Ja) ?? otherMsg40_60Ja
        otherState20_40 = try container.decodeIfPresent(String.self, forKey: .otherState20_40) ?? otherState20_40
        otherMsg20_40 = try container.decodeIfPresent(String.self, forKey: .otherMsg20_40) ?? otherMsg20_40
        otherMsg20_40Ja = try container.decodeIfPresent(String.self, forKey: .otherMsg20_40Ja) ?? otherMsg20_40Ja
        otherState0_20 = try container.decodeIfPresent(String.self, forKey: .otherState0_20) ?? otherState0_20
        otherMsg0_20 = try container.decodeIfPresent(String.self, forKey: .otherMsg0_20) ?? otherMsg0_20
        otherMsg0_20Ja = try container.decodeIfPresent(String.self, forKey: .otherMsg0_20Ja) ?? otherMsg0_20Ja
        otherState0 = try container.decodeIfPresent(String.self, forKey: .otherState0) ?? otherState0
        otherMsg0 = try container.decodeIfPresent(String.self, forKey: .otherMsg0) ?? otherMsg0
        otherMsg0Ja = try container.decodeIfPresent(String.self, forKey: .otherMsg0Ja) ?? otherMsg0Ja
        otherStateAllAbnormal = try container.decodeIfPresent(String.self, forKey: .otherStateAllAbnormal) ?? otherStateAllAbnormal
        otherMsgAllAbnormal = try container.decodeIfPresent(String.self, forKey: .otherMsgAllAbnormal) ?? otherMsgAllAbnormal
        otherMsgAllAbnormalJa = try container.decodeIfPresent(String.self, forKey: .otherMsgAllAbnormalJa) ?? otherMsgAllAbnormalJa
        otherStateAllDataInvalid = try container.decodeIfPresent(String.self, forKey: .otherStateAllDataInvalid) ?? otherStateAllDataInvalid
        otherMsgAllDataInvalid = try container.decodeIfPresent(String.self, forKey: .otherMsgAllDataInvalid) ?? otherMsgAllDataInvalid
        otherMsgAllDataInvalidJa = try container.decodeIfPresent(String.self, forKey: .otherMsgAllDataInvalidJa) ?? otherMsgAllDataInvalidJa
    }
}

/// アプリ実行時の動的な一時変数を保持する構造体。
nonisolated struct AppSettingsRuntime: Codable, Equatable, Sendable {
    /// 最後に実行されたデータ取得処理の結果メッセージ。
    var lastLoadResultMessage: String
    /// 最後に取得されたデータがすべて無効値（異常値）だったかどうかのフラグ。
    var wasLastDataAllInvalid: Bool
    /// sudmonitor 中継サーバーが記録した MLIT データ取得時刻（`X-TCS-Fetched-At` ヘッダー由来）。
    var originFetchedAt: Date?
}

nonisolated struct AppSettings: Codable, Equatable, Sendable {
    static let defaultDamId = "1368080700010"
    static let defaultAutoUpdateHour = 5
    static let defaultAutoUpdateMinute = 15
    static let initialAutoUpdateStartMinuteOfDay = 0 * 60 + 15
    static let initialAutoUpdateEndMinuteOfDay = 5 * 60 + 59
    static let minScheduleAdvanceSeconds: TimeInterval = 15 * 60

    /// 全般設定。
    var general: AppSettingsGeneral
    /// 自動更新設定。
    var autoUpdate: AppSettingsAutoUpdate
    /// デバッグ設定。
    var debug: AppSettingsDebug
    /// メッセージ設定。
    var messages: AppSettingsMessages
    /// ランタイム一時状態設定。
    var runtime: AppSettingsRuntime

    /// アプリのテーマ。
    var theme: AppTheme {
        get { general.theme }
        set { general.theme = newValue }
    }
    /// 自動更新が有効かどうか。
    var autoUpdateEnabled: Bool {
        get { autoUpdate.enabled }
        set { autoUpdate.enabled = newValue }
    }
    /// 通知を表示するかどうか。
    var showNotification: Bool {
        get { general.showNotification }
        set { general.showNotification = newValue }
    }
    /// 自動更新の間隔。
    var autoUpdateInterval: AutoUpdateInterval {
        get { autoUpdate.interval }
        set { autoUpdate.interval = newValue }
    }
    /// 自動更新設定の初回表示ダイアログが表示済みかどうか。
    var initialAutoUpdateDialogShown: Bool {
        get { autoUpdate.initialDialogShown }
        set { autoUpdate.initialDialogShown = newValue }
    }
    /// 自動更新設定の初回時間決定基準となる分情報。
    var initialAutoUpdateAnchorMinuteOfDay: Int? {
        get { autoUpdate.initialAnchorMinuteOfDay }
        set { autoUpdate.initialAnchorMinuteOfDay = newValue }
    }
    /// 端末起動時に自動更新処理を行うかどうか。
    var updateOnBoot: Bool {
        get { autoUpdate.updateOnBoot }
        set { autoUpdate.updateOnBoot = newValue }
    }
    /// 次回自動更新を要求する日時。
    var nextRequestedUpdate: Date {
        get { autoUpdate.nextRequestedUpdate }
        set { autoUpdate.nextRequestedUpdate = newValue }
    }
    /// 最後の自動更新日時。
    var lastAutoUpdate: Date? {
        get { autoUpdate.lastAutoUpdate }
        set { autoUpdate.lastAutoUpdate = newValue }
    }
    /// 対象ダムのID。
    var targetDamId: String {
        get { general.targetDamId }
        set { general.targetDamId = newValue }
    }
    /// リアルタイム観測データ (Real-time observation data) の取得ソース。未設定時は sudmonitor 中継を既定とする。
    var realtimeDataSource: RealtimeDataSource {
        get { general.realtimeDataSource ?? .sudmonitor }
        set { general.realtimeDataSource = newValue }
    }
    /// 過去データ検索 (Historical data search) のデータソース(既定は sudmonitor 中継)。
    var historicalDataSource: RealtimeDataSource {
        general.historicalDataSource ?? .sudmonitor
    }
    /// macOS におけるメニューバー常駐モード。未設定時は常駐しないことを既定とする。
    var menuBarResidencyMode: MenuBarResidencyMode {
        get { general.effectiveMenuBarResidencyMode }
        set { general.menuBarResidencyMode = newValue }
    }
    /// デバッグモードが有効かどうか。
    var debugModeEnabled: Bool {
        get { debug.modeEnabled }
        set { debug.modeEnabled = newValue }
    }
    /// デバッグ設定画面を表示するかどうか。
    var debugSettingsVisible: Bool {
        get { debug.settingsVisible }
        set { debug.settingsVisible = newValue }
    }
    /// 擬似シミュレーションモード。
    var debugSimulateMode: DebugSimulateMode {
        get { debug.simulateMode }
        set { debug.simulateMode = newValue }
    }
    /// リアルタイムデータ用のデバッグ .dat ファイル選択モード。
    var debugRealtimeDatSelectionMode: DebugDatSelectionMode {
        get { debug.realtimeDatSelectionMode }
        set { debug.realtimeDatSelectionMode = newValue }
    }
    /// ユーザーが選択したリアルタイムデータ用 .dat ファイル名。
    var debugRealtimeDatFileName: String? {
        get { debug.realtimeDatFileName }
        set { debug.realtimeDatFileName = newValue }
    }
    /// 過去データ(日次)用のデバッグ .dat ファイル選択モード。
    var debugHistoricalDailyDatSelectionMode: DebugDatSelectionMode {
        get { debug.historicalDailyDatSelectionMode }
        set { debug.historicalDailyDatSelectionMode = newValue }
    }
    /// ユーザーが選択した過去データ(日次)用 .dat ファイル名。
    var debugHistoricalDailyDatFileName: String? {
        get { debug.historicalDailyDatFileName }
        set { debug.historicalDailyDatFileName = newValue }
    }
    /// リアルタイムデータ用のデバッグデータ終了日時。
    var debugRealtimeDataEndDate: Date? {
        get { debug.realtimeDataEndDate }
        set { debug.realtimeDataEndDate = newValue }
    }
    /// リアルタイムデータの期間を観測データ取得ごとに進めるかどうか。
    var debugRealtimeDataPeriodAutoAdvanceEnabled: Bool {
        get { debug.realtimeDataPeriodAutoAdvanceEnabled }
        set { debug.realtimeDataPeriodAutoAdvanceEnabled = newValue }
    }
    /// 最終更新処理の結果メッセージ。
    var lastLoadResultMessage: String {
        get { runtime.lastLoadResultMessage }
        set { runtime.lastLoadResultMessage = newValue }
    }
    /// sudmonitor 中継サーバーが記録した MLIT データ取得時刻。
    var originFetchedAt: Date? {
        get { runtime.originFetchedAt }
        set { runtime.originFetchedAt = newValue }
    }
    /// 貯水率 (Storage rate) のウィジェット用メッセージを表示するかどうか。
    var showStorageRateMessage: Bool {
        get { messages.showStorageRateMessage }
        set { messages.showStorageRateMessage = newValue }
    }
    /// 貯水率 80-100% 時の顔文字。
    var state80_100: String {
        get { messages.state80_100 }
        set { messages.state80_100 = newValue }
    }
    /// 貯水率 80-100% 時のメッセージ。
    var msg80_100: String {
        get { messages.msg80_100 }
        set { messages.msg80_100 = newValue }
    }
    /// 貯水率 80-100% 時の日本語メッセージ。
    var msg80_100Ja: String {
        get { messages.msg80_100Ja }
        set { messages.msg80_100Ja = newValue }
    }
    /// 貯水率 60-80% 時の顔文字。
    var state60_80: String {
        get { messages.state60_80 }
        set { messages.state60_80 = newValue }
    }
    /// 貯水率 60-80% 時のメッセージ。
    var msg60_80: String {
        get { messages.msg60_80 }
        set { messages.msg60_80 = newValue }
    }
    /// 貯水率 60-80% 時の日本語メッセージ。
    var msg60_80Ja: String {
        get { messages.msg60_80Ja }
        set { messages.msg60_80Ja = newValue }
    }
    /// 貯水率 40-60% 時の顔文字。
    var state40_60: String {
        get { messages.state40_60 }
        set { messages.state40_60 = newValue }
    }
    /// 貯水率 40-60% 時のメッセージ。
    var msg40_60: String {
        get { messages.msg40_60 }
        set { messages.msg40_60 = newValue }
    }
    /// 貯水率 40-60% 時の日本語メッセージ。
    var msg40_60Ja: String {
        get { messages.msg40_60Ja }
        set { messages.msg40_60Ja = newValue }
    }
    /// 貯水率 20-40% 時の顔文字。
    var state20_40: String {
        get { messages.state20_40 }
        set { messages.state20_40 = newValue }
    }
    /// 貯水率 20-40% 時のメッセージ。
    var msg20_40: String {
        get { messages.msg20_40 }
        set { messages.msg20_40 = newValue }
    }
    /// 貯水率 20-40% 時の日本語メッセージ。
    var msg20_40Ja: String {
        get { messages.msg20_40Ja }
        set { messages.msg20_40Ja = newValue }
    }
    /// 貯水率 0-20% 時の顔文字。
    var state0_20: String {
        get { messages.state0_20 }
        set { messages.state0_20 = newValue }
    }
    /// 貯水率 0-20% 時のメッセージ。
    var msg0_20: String {
        get { messages.msg0_20 }
        set { messages.msg0_20 = newValue }
    }
    /// 貯水率 0-20% 時の日本語メッセージ。
    var msg0_20Ja: String {
        get { messages.msg0_20Ja }
        set { messages.msg0_20Ja = newValue }
    }
    /// 貯水率 0% 時の顔文字。
    var state0: String {
        get { messages.state0 }
        set { messages.state0 = newValue }
    }
    /// 貯水率 0% 時のメッセージ。
    var msg0: String {
        get { messages.msg0 }
        set { messages.msg0 = newValue }
    }
    /// 貯水率 0% 時の日本語メッセージ。
    var msg0Ja: String {
        get { messages.msg0Ja }
        set { messages.msg0Ja = newValue }
    }
    /// 貯水率データ異常（欠測）時の顔文字。
    var stateAllAbnormal: String {
        get { messages.stateAllAbnormal }
        set { messages.stateAllAbnormal = newValue }
    }
    /// 貯水率データ異常（欠測）時のメッセージ。
    var msgAllAbnormal: String {
        get { messages.msgAllAbnormal }
        set { messages.msgAllAbnormal = newValue }
    }
    /// 貯水率データ異常（欠測）時の日本語メッセージ。
    var msgAllAbnormalJa: String {
        get { messages.msgAllAbnormalJa }
        set { messages.msgAllAbnormalJa = newValue }
    }
    /// すべてのリアルタイム観測データ (Real-time observation data) が無効な時の顔文字。
    var stateAllDataInvalid: String {
        get { messages.stateAllDataInvalid }
        set { messages.stateAllDataInvalid = newValue }
    }
    /// すべてのリアルタイム観測データ (Real-time observation data) が無効な時のメッセージ。
    var msgAllDataInvalid: String {
        get { messages.msgAllDataInvalid }
        set { messages.msgAllDataInvalid = newValue }
    }
    /// すべてのリアルタイム観測データ (Real-time observation data) が無効な時の日本語メッセージ。
    var msgAllDataInvalidJa: String {
        get { messages.msgAllDataInvalidJa }
        set { messages.msgAllDataInvalidJa = newValue }
    }
    /// 早明浦ダム以外の貯水率 80-100% 時の顔文字。
    var otherState80_100: String {
        get { messages.otherState80_100 }
        set { messages.otherState80_100 = newValue }
    }
    /// 早明浦ダム以外の貯水率 80-100% 時のメッセージ。
    var otherMsg80_100: String {
        get { messages.otherMsg80_100 }
        set { messages.otherMsg80_100 = newValue }
    }
    /// 早明浦ダム以外の貯水率 80-100% 時の日本語メッセージ。
    var otherMsg80_100Ja: String {
        get { messages.otherMsg80_100Ja }
        set { messages.otherMsg80_100Ja = newValue }
    }
    /// 早明浦ダム以外の貯水率 60-80% 時の顔文字。
    var otherState60_80: String {
        get { messages.otherState60_80 }
        set { messages.otherState60_80 = newValue }
    }
    /// 早明浦ダム以外の貯水率 60-80% 時のメッセージ。
    var otherMsg60_80: String {
        get { messages.otherMsg60_80 }
        set { messages.otherMsg60_80 = newValue }
    }
    /// 早明浦ダム以外の貯水率 60-80% 時の日本語メッセージ。
    var otherMsg60_80Ja: String {
        get { messages.otherMsg60_80Ja }
        set { messages.otherMsg60_80Ja = newValue }
    }
    /// 早明浦ダム以外の貯水率 40-60% 時の顔文字。
    var otherState40_60: String {
        get { messages.otherState40_60 }
        set { messages.otherState40_60 = newValue }
    }
    /// 早明浦ダム以外の貯水率 40-60% 時のメッセージ。
    var otherMsg40_60: String {
        get { messages.otherMsg40_60 }
        set { messages.otherMsg40_60 = newValue }
    }
    /// 早明浦ダム以外の貯水率 40-60% 時の日本語メッセージ。
    var otherMsg40_60Ja: String {
        get { messages.otherMsg40_60Ja }
        set { messages.otherMsg40_60Ja = newValue }
    }
    /// 早明浦ダム以外の貯水率 20-40% 時の顔文字。
    var otherState20_40: String {
        get { messages.otherState20_40 }
        set { messages.otherState20_40 = newValue }
    }
    /// 早明浦ダム以外の貯水率 20-40% 時のメッセージ。
    var otherMsg20_40: String {
        get { messages.otherMsg20_40 }
        set { messages.otherMsg20_40 = newValue }
    }
    /// 早明浦ダム以外の貯水率 20-40% 時の日本語メッセージ。
    var otherMsg20_40Ja: String {
        get { messages.otherMsg20_40Ja }
        set { messages.otherMsg20_40Ja = newValue }
    }
    /// 早明浦ダム以外の貯水率 0-20% 時の顔文字。
    var otherState0_20: String {
        get { messages.otherState0_20 }
        set { messages.otherState0_20 = newValue }
    }
    /// 早明浦ダム以外の貯水率 0-20% 時のメッセージ。
    var otherMsg0_20: String {
        get { messages.otherMsg0_20 }
        set { messages.otherMsg0_20 = newValue }
    }
    /// 早明浦ダム以外の貯水率 0-20% 時の日本語メッセージ。
    var otherMsg0_20Ja: String {
        get { messages.otherMsg0_20Ja }
        set { messages.otherMsg0_20Ja = newValue }
    }
    /// 早明浦ダム以外の貯水率 0% 時の顔文字。
    var otherState0: String {
        get { messages.otherState0 }
        set { messages.otherState0 = newValue }
    }
    /// 早明浦ダム以外の貯水率 0% 時のメッセージ。
    var otherMsg0: String {
        get { messages.otherMsg0 }
        set { messages.otherMsg0 = newValue }
    }
    /// 早明浦ダム以外の貯水率 0% 時の日本語メッセージ。
    var otherMsg0Ja: String {
        get { messages.otherMsg0Ja }
        set { messages.otherMsg0Ja = newValue }
    }
    /// 早明浦ダム以外の貯水率データ異常（欠測）時の顔文字。
    var otherStateAllAbnormal: String {
        get { messages.otherStateAllAbnormal }
        set { messages.otherStateAllAbnormal = newValue }
    }
    /// 早明浦ダム以外の貯水率データ異常（欠測）時のメッセージ。
    var otherMsgAllAbnormal: String {
        get { messages.otherMsgAllAbnormal }
        set { messages.otherMsgAllAbnormal = newValue }
    }
    /// 早明浦ダム以外の貯水率データ異常（欠測）時の日本語メッセージ。
    var otherMsgAllAbnormalJa: String {
        get { messages.otherMsgAllAbnormalJa }
        set { messages.otherMsgAllAbnormalJa = newValue }
    }
    /// 早明浦ダム以外のすべてのリアルタイム観測データ (Real-time observation data) が無効な時の顔文字。
    var otherStateAllDataInvalid: String {
        get { messages.otherStateAllDataInvalid }
        set { messages.otherStateAllDataInvalid = newValue }
    }
    /// 早明浦ダム以外のすべてのリアルタイム観測データ (Real-time observation data) が無効な時のメッセージ。
    var otherMsgAllDataInvalid: String {
        get { messages.otherMsgAllDataInvalid }
        set { messages.otherMsgAllDataInvalid = newValue }
    }
    /// 早明浦ダム以外のすべてのリアルタイム観測データ (Real-time observation data) が無効な時の日本語メッセージ。
    var otherMsgAllDataInvalidJa: String {
        get { messages.otherMsgAllDataInvalidJa }
        set { messages.otherMsgAllDataInvalidJa = newValue }
    }
    /// 初期表示時の顔文字。
    var stateInitialMessage: String {
        get { messages.stateInitialMessage }
        set { messages.stateInitialMessage = newValue }
    }
    /// 初期表示時のメッセージ。
    var msgInitialMessage: String {
        get { messages.msgInitialMessage }
        set { messages.msgInitialMessage = newValue }
    }
    /// 初期表示時の日本語メッセージ。
    var msgInitialMessageJa: String {
        get { messages.msgInitialMessageJa }
        set { messages.msgInitialMessageJa = newValue }
    }
    /// ネットワーク切断時の顔文字。
    var stateNetworkUnavailable: String {
        get { messages.stateNetworkUnavailable }
        set { messages.stateNetworkUnavailable = newValue }
    }
    /// ネットワーク切断時のメッセージ。
    var msgNetworkUnavailable: String {
        get { messages.msgNetworkUnavailable }
        set { messages.msgNetworkUnavailable = newValue }
    }
    /// ネットワーク切断時の日本語メッセージ。
    var msgNetworkUnavailableJa: String {
        get { messages.msgNetworkUnavailableJa }
        set { messages.msgNetworkUnavailableJa = newValue }
    }
    /// 読み込みエラー時の顔文字。
    var stateLoadingError: String {
        get { messages.stateLoadingError }
        set { messages.stateLoadingError = newValue }
    }
    /// 読み込みエラー時のメッセージ。
    var msgLoadingError: String {
        get { messages.msgLoadingError }
        set { messages.msgLoadingError = newValue }
    }
    /// 読み込みエラー時の日本語メッセージ。
    var msgLoadingErrorJa: String {
        get { messages.msgLoadingErrorJa }
        set { messages.msgLoadingErrorJa = newValue }
    }
    /// データ配信停止時の顔文字。
    var stateDataDistributionStopped: String {
        get { messages.stateDataDistributionStopped }
        set { messages.stateDataDistributionStopped = newValue }
    }
    /// データ配信停止時のメッセージ。
    var msgDataDistributionStopped: String {
        get { messages.msgDataDistributionStopped }
        set { messages.msgDataDistributionStopped = newValue }
    }
    /// データ配信停止時の日本語メッセージ。
    var msgDataDistributionStoppedJa: String {
        get { messages.msgDataDistributionStoppedJa }
        set { messages.msgDataDistributionStoppedJa = newValue }
    }
    /// データ配信再開時の顔文字。
    var stateDataDistributionResumed: String {
        get { messages.stateDataDistributionResumed }
        set { messages.stateDataDistributionResumed = newValue }
    }
    /// データ配信再開時のメッセージ。
    var msgDataDistributionResumed: String {
        get { messages.msgDataDistributionResumed }
        set { messages.msgDataDistributionResumed = newValue }
    }
    /// データ配信再開時の日本語メッセージ。
    var msgDataDistributionResumedJa: String {
        get { messages.msgDataDistributionResumedJa }
        set { messages.msgDataDistributionResumedJa = newValue }
    }
    /// 最後に取得されたデータがすべて無効値（異常値）だったかどうかのフラグ。
    var wasLastDataAllInvalid: Bool {
        get { runtime.wasLastDataAllInvalid }
        set { runtime.wasLastDataAllInvalid = newValue }
    }

    /// 貯水率 (Storage rate) のウィジェット表示用メッセージ記述子のリスト（早明浦ダム用）。
    ///
    /// タイトル表示用のローカライズキー（下記）は Localizable.xcstrings 未追加のため、
    /// `.localizedWithFallback` で未定義キー時のフォールバック文字列を指定しています。
    /// UI担当が下記キーを Localizable.xcstrings へ追加すると、自動でキーの文言へ切り替わります。
    /// - `settings.storageRate.sameura.80_100`: 「貯水率 80-100%」/ "Storage rate 80-100%"
    /// - `settings.storageRate.sameura.60_80`: 「貯水量 80,000×10³m³以上」/ "Volume ≥ 80,000×10³m³"
    /// - `settings.storageRate.sameura.40_60`: 「貯水量 60,000×10³m³以上80,000×10³m³未満」/ "Volume ≥ 60,000×10³m³ and < 80,000×10³m³"
    /// - `settings.storageRate.sameura.20_40`: 「貯水量 40,000×10³m³以上60,000×10³m³未満」/ "Volume ≥ 40,000×10³m³ and < 60,000×10³m³"
    /// - `settings.storageRate.sameura.0_20`: 「貯水量 40,000×10³m³未満」/ "Volume < 40,000×10³m³"
    /// - `settings.storageRate.sameura.0`: 「貯水率 0%」/ "Storage rate 0%"
    static var storageRateMessageDescriptors: [StorageRateMessageDescriptor] { [
        StorageRateMessageDescriptor(
            widgetKey: .storage80_100,
            title: .localizedWithFallback(
                "settings.storageRate.sameura.80_100",
                fallbackJa: "貯水率 80-100%",
                fallbackEn: "Storage rate 80-100%"
            ),
            state: \.state80_100,
            message: \.msg80_100,
            japaneseMessage: \.msg80_100Ja,
            defaultState: "😊",
            nonJapanesePreset: .nonJa80_100,
            japaneseDefault: { AppLocalized.text("storage.defaultMsg.ja.80_100", locale: $0) }
        ),
        StorageRateMessageDescriptor(
            widgetKey: .storage60_80,
            title: .localizedWithFallback(
                "settings.storageRate.sameura.60_80",
                fallbackJa: "貯水量 80,000×10³m³以上",
                fallbackEn: "Volume ≥ 80,000×10³m³"
            ),
            state: \.state60_80,
            message: \.msg60_80,
            japaneseMessage: \.msg60_80Ja,
            defaultState: "😌",
            nonJapanesePreset: .nonJa60_80,
            japaneseDefault: { AppLocalized.text("storage.defaultMsg.ja.60_80", locale: $0) }
        ),
        StorageRateMessageDescriptor(
            widgetKey: .storage40_60,
            title: .localizedWithFallback(
                "settings.storageRate.sameura.40_60",
                fallbackJa: "貯水量 60,000×10³m³以上80,000×10³m³未満",
                fallbackEn: "Volume ≥ 60,000×10³m³ and < 80,000×10³m³"
            ),
            state: \.state40_60,
            message: \.msg40_60,
            japaneseMessage: \.msg40_60Ja,
            defaultState: "😨",
            nonJapanesePreset: .nonJa40_60,
            japaneseDefault: { AppLocalized.text("storage.defaultMsg.ja.40_60", locale: $0) }
        ),
        StorageRateMessageDescriptor(
            widgetKey: .storage20_40,
            title: .localizedWithFallback(
                "settings.storageRate.sameura.20_40",
                fallbackJa: "貯水量 40,000×10³m³以上60,000×10³m³未満",
                fallbackEn: "Volume ≥ 40,000×10³m³ and < 60,000×10³m³"
            ),
            state: \.state20_40,
            message: \.msg20_40,
            japaneseMessage: \.msg20_40Ja,
            defaultState: "😰",
            nonJapanesePreset: .nonJa20_40,
            japaneseDefault: { AppLocalized.text("storage.defaultMsg.ja.20_40", locale: $0) }
        ),
        StorageRateMessageDescriptor(
            widgetKey: .storage0_20,
            title: .localizedWithFallback(
                "settings.storageRate.sameura.0_20",
                fallbackJa: "貯水量 40,000×10³m³未満",
                fallbackEn: "Volume < 40,000×10³m³"
            ),
            state: \.state0_20,
            message: \.msg0_20,
            japaneseMessage: \.msg0_20Ja,
            defaultState: "😱",
            nonJapanesePreset: .nonJa0_20,
            japaneseDefault: { AppLocalized.text("storage.defaultMsg.ja.0_20", locale: $0) }
        ),
        StorageRateMessageDescriptor(
            widgetKey: .storage0,
            title: .localizedWithFallback(
                "settings.storageRate.sameura.0",
                fallbackJa: "貯水率 0%",
                fallbackEn: "Storage rate 0%"
            ),
            state: \.state0,
            message: \.msg0,
            japaneseMessage: \.msg0Ja,
            defaultState: "😇",
            nonJapanesePreset: .nonJa0,
            japaneseDefault: { AppLocalized.text("storage.defaultMsg.ja.0", locale: $0) }
        ),
        StorageRateMessageDescriptor(
            widgetKey: .abnormal,
            title: .localized("settings.noStorageData"),
            state: \.stateAllAbnormal,
            message: \.msgAllAbnormal,
            japaneseMessage: \.msgAllAbnormalJa,
            defaultState: "😑",
            nonJapanesePreset: .allAbnormalNonJa,
            japaneseDefault: { StorageMessagePreset.allAbnormalJa.message(locale: $0) }
        ),
        StorageRateMessageDescriptor(
            widgetKey: .allDataInvalid,
            title: .localized("settings.allDataInvalidMessage"),
            state: \.stateAllDataInvalid,
            message: \.msgAllDataInvalid,
            japaneseMessage: \.msgAllDataInvalidJa,
            defaultState: "😴",
            nonJapanesePreset: .allDataInvalidNonJa,
            japaneseDefault: { StorageMessagePreset.allDataInvalidJa.message(locale: $0) }
        )
    ] }

    /// 貯水率 (Storage rate) のウィジェット表示用メッセージ記述子のリスト（早明浦ダム以外用）。
    ///
    /// タイトルは従来どおりの貯水率範囲表記、既定値は一般向け（日本語以外のプリセットとステータス顔文字）です。
    static var otherStorageRateMessageDescriptors: [StorageRateMessageDescriptor] { [
        StorageRateMessageDescriptor(
            widgetKey: .storage80_100,
            title: .literal("80-100%"),
            state: \.otherState80_100,
            message: \.otherMsg80_100,
            japaneseMessage: \.otherMsg80_100Ja,
            defaultState: "😊",
            nonJapanesePreset: .nonJa80_100,
            japaneseDefault: { StorageMessagePreset.nonJa80_100.message(locale: $0) }
        ),
        StorageRateMessageDescriptor(
            widgetKey: .storage60_80,
            title: .literal("60-80%"),
            state: \.otherState60_80,
            message: \.otherMsg60_80,
            japaneseMessage: \.otherMsg60_80Ja,
            defaultState: "😌",
            nonJapanesePreset: .nonJa60_80,
            japaneseDefault: { StorageMessagePreset.nonJa60_80.message(locale: $0) }
        ),
        StorageRateMessageDescriptor(
            widgetKey: .storage40_60,
            title: .literal("40-60%"),
            state: \.otherState40_60,
            message: \.otherMsg40_60,
            japaneseMessage: \.otherMsg40_60Ja,
            defaultState: "😨",
            nonJapanesePreset: .nonJa40_60,
            japaneseDefault: { StorageMessagePreset.nonJa40_60.message(locale: $0) }
        ),
        StorageRateMessageDescriptor(
            widgetKey: .storage20_40,
            title: .literal("20-40%"),
            state: \.otherState20_40,
            message: \.otherMsg20_40,
            japaneseMessage: \.otherMsg20_40Ja,
            defaultState: "😰",
            nonJapanesePreset: .nonJa20_40,
            japaneseDefault: { StorageMessagePreset.nonJa20_40.message(locale: $0) }
        ),
        StorageRateMessageDescriptor(
            widgetKey: .storage0_20,
            title: .literal("0-20%"),
            state: \.otherState0_20,
            message: \.otherMsg0_20,
            japaneseMessage: \.otherMsg0_20Ja,
            defaultState: "😱",
            nonJapanesePreset: .nonJa0_20,
            japaneseDefault: { StorageMessagePreset.nonJa0_20.message(locale: $0) }
        ),
        StorageRateMessageDescriptor(
            widgetKey: .storage0,
            title: .literal("0%"),
            state: \.otherState0,
            message: \.otherMsg0,
            japaneseMessage: \.otherMsg0Ja,
            defaultState: "😇",
            nonJapanesePreset: .nonJa0,
            japaneseDefault: { StorageMessagePreset.nonJa0.message(locale: $0) }
        ),
        StorageRateMessageDescriptor(
            widgetKey: .abnormal,
            title: .localized("settings.noStorageData"),
            state: \.otherStateAllAbnormal,
            message: \.otherMsgAllAbnormal,
            japaneseMessage: \.otherMsgAllAbnormalJa,
            defaultState: "😑",
            nonJapanesePreset: .allAbnormalNonJa,
            japaneseDefault: { StorageMessagePreset.allAbnormalJa.message(locale: $0) }
        ),
        StorageRateMessageDescriptor(
            widgetKey: .allDataInvalid,
            title: .localized("settings.allDataInvalidMessage"),
            state: \.otherStateAllDataInvalid,
            message: \.otherMsgAllDataInvalid,
            japaneseMessage: \.otherMsgAllDataInvalidJa,
            defaultState: "😴",
            nonJapanesePreset: .allDataInvalidNonJa,
            japaneseDefault: { StorageMessagePreset.allDataInvalidJa.message(locale: $0) }
        )
    ] }

    /// 貯水率以外の表示用メッセージ記述子のリスト。
    static var otherMessageDescriptors: [OtherMessageDescriptor] { [
        OtherMessageDescriptor(
            field: .initialMessage,
            widgetKey: .initial,
            title: .localized("settings.initialMessage"),
            state: \.stateInitialMessage,
            message: \.msgInitialMessage,
            japaneseMessage: \.msgInitialMessageJa,
            defaultState: "🥺",
            nonJapanesePreset: .initialNonJa,
            japanesePreset: .initialJa
        ),
        OtherMessageDescriptor(
            field: .networkUnavailable,
            widgetKey: nil,
            title: .localized("settings.networkUnavailableMessage"),
            state: \.stateNetworkUnavailable,
            message: \.msgNetworkUnavailable,
            japaneseMessage: \.msgNetworkUnavailableJa,
            defaultState: "😢",
            nonJapanesePreset: .networkUnavailableNonJa,
            japanesePreset: .networkUnavailableJa
        ),
        OtherMessageDescriptor(
            field: .loadingError,
            widgetKey: nil,
            title: .localized("settings.loadingErrorMessage"),
            state: \.stateLoadingError,
            message: \.msgLoadingError,
            japaneseMessage: \.msgLoadingErrorJa,
            defaultState: "😵",
            nonJapanesePreset: .loadingErrorNonJa,
            japanesePreset: .loadingErrorJa
        ),
        OtherMessageDescriptor(
            field: .dataDistributionStopped,
            widgetKey: .dataDistributionStopped,
            title: .localized("settings.dataDistributionStoppedMessage"),
            state: \.stateDataDistributionStopped,
            message: \.msgDataDistributionStopped,
            japaneseMessage: \.msgDataDistributionStoppedJa,
            defaultState: "😪",
            nonJapanesePreset: .dataDistributionStoppedNonJa,
            japanesePreset: .dataDistributionStoppedJa
        ),
        OtherMessageDescriptor(
            field: .dataDistributionResumed,
            widgetKey: .dataDistributionResumed,
            title: .localized("settings.dataDistributionResumedMessage"),
            state: \.stateDataDistributionResumed,
            message: \.msgDataDistributionResumed,
            japaneseMessage: \.msgDataDistributionResumedJa,
            defaultState: "🥱",
            nonJapanesePreset: .dataDistributionResumedNonJa,
            japanesePreset: .dataDistributionResumedJa
        )
    ] }

    /// デフォルト設定で設定インスタンスを初期化するイニシャライザ。
    ///
    /// - Parameter locale: 初期化時のロケール。
    init(locale: Locale = AppLocale.effectiveLocale) {
        let jaLocale = Locale(identifier: "ja")
        general = AppSettingsGeneral(
            theme: .system,
            showNotification: false,
            targetDamId: Self.defaultDamId,
            realtimeDataSource: nil
        )
        autoUpdate = AppSettingsAutoUpdate(
            enabled: false,
            interval: .oneWeek,
            initialDialogShown: false,
            initialAnchorMinuteOfDay: nil,
            updateOnBoot: true,
            nextRequestedUpdate: Date(),
            lastAutoUpdate: nil
        )
        debug = AppSettingsDebug(
            modeEnabled: false,
            settingsVisible: false,
            simulateMode: .none,
            realtimeDatSelectionMode: .bundled,
            realtimeDatFileName: nil,
            historicalDailyDatSelectionMode: .bundled,
            historicalDailyDatFileName: nil,
            realtimeDataEndDate: nil,
            realtimeDataPeriodAutoAdvanceEnabled: true
        )
        messages = AppSettingsMessages(
            showStorageRateMessage: true,
            state80_100: "😊",
            msg80_100: StorageMessagePreset.nonJa80_100.message(locale: locale),
            msg80_100Ja: AppLocalized.text("storage.defaultMsg.ja.80_100", locale: jaLocale),
            state60_80: "😌",
            msg60_80: StorageMessagePreset.nonJa60_80.message(locale: locale),
            msg60_80Ja: AppLocalized.text("storage.defaultMsg.ja.60_80", locale: jaLocale),
            state40_60: "😨",
            msg40_60: StorageMessagePreset.nonJa40_60.message(locale: locale),
            msg40_60Ja: AppLocalized.text("storage.defaultMsg.ja.40_60", locale: jaLocale),
            state20_40: "😰",
            msg20_40: StorageMessagePreset.nonJa20_40.message(locale: locale),
            msg20_40Ja: AppLocalized.text("storage.defaultMsg.ja.20_40", locale: jaLocale),
            state0_20: "😱",
            msg0_20: StorageMessagePreset.nonJa0_20.message(locale: locale),
            msg0_20Ja: AppLocalized.text("storage.defaultMsg.ja.0_20", locale: jaLocale),
            state0: "😇",
            msg0: StorageMessagePreset.nonJa0.message(locale: locale),
            msg0Ja: AppLocalized.text("storage.defaultMsg.ja.0", locale: jaLocale),
            stateAllAbnormal: "😑",
            msgAllAbnormal: StorageMessagePreset.allAbnormalNonJa.message(locale: locale),
            msgAllAbnormalJa: StorageMessagePreset.allAbnormalJa.message(locale: jaLocale),
            stateAllDataInvalid: "😴",
            msgAllDataInvalid: StorageMessagePreset.allDataInvalidNonJa.message(locale: locale),
            msgAllDataInvalidJa: StorageMessagePreset.allDataInvalidJa.message(locale: jaLocale),
            otherState80_100: "😊",
            otherMsg80_100: StorageMessagePreset.nonJa80_100.message(locale: locale),
            otherMsg80_100Ja: StorageMessagePreset.nonJa80_100.message(locale: locale),
            otherState60_80: "😌",
            otherMsg60_80: StorageMessagePreset.nonJa60_80.message(locale: locale),
            otherMsg60_80Ja: StorageMessagePreset.nonJa60_80.message(locale: locale),
            otherState40_60: "😨",
            otherMsg40_60: StorageMessagePreset.nonJa40_60.message(locale: locale),
            otherMsg40_60Ja: StorageMessagePreset.nonJa40_60.message(locale: locale),
            otherState20_40: "😰",
            otherMsg20_40: StorageMessagePreset.nonJa20_40.message(locale: locale),
            otherMsg20_40Ja: StorageMessagePreset.nonJa20_40.message(locale: locale),
            otherState0_20: "😱",
            otherMsg0_20: StorageMessagePreset.nonJa0_20.message(locale: locale),
            otherMsg0_20Ja: StorageMessagePreset.nonJa0_20.message(locale: locale),
            otherState0: "😇",
            otherMsg0: StorageMessagePreset.nonJa0.message(locale: locale),
            otherMsg0Ja: StorageMessagePreset.nonJa0.message(locale: locale),
            otherStateAllAbnormal: "😑",
            otherMsgAllAbnormal: StorageMessagePreset.allAbnormalNonJa.message(locale: locale),
            otherMsgAllAbnormalJa: StorageMessagePreset.allAbnormalJa.message(locale: jaLocale),
            otherStateAllDataInvalid: "😴",
            otherMsgAllDataInvalid: StorageMessagePreset.allDataInvalidNonJa.message(locale: locale),
            otherMsgAllDataInvalidJa: StorageMessagePreset.allDataInvalidJa.message(locale: jaLocale),
            stateInitialMessage: "🥺",
            msgInitialMessage: StorageMessagePreset.initialNonJa.message(locale: locale),
            msgInitialMessageJa: StorageMessagePreset.initialJa.message(locale: jaLocale),
            stateNetworkUnavailable: "😢",
            msgNetworkUnavailable: StorageMessagePreset.networkUnavailableNonJa.message(locale: locale),
            msgNetworkUnavailableJa: StorageMessagePreset.networkUnavailableJa.message(locale: jaLocale),
            stateLoadingError: "😵",
            msgLoadingError: StorageMessagePreset.loadingErrorNonJa.message(locale: locale),
            msgLoadingErrorJa: StorageMessagePreset.loadingErrorJa.message(locale: jaLocale),
            stateDataDistributionStopped: "😪",
            msgDataDistributionStopped: StorageMessagePreset.dataDistributionStoppedNonJa.message(locale: locale),
            msgDataDistributionStoppedJa: StorageMessagePreset.dataDistributionStoppedJa.message(locale: jaLocale),
            stateDataDistributionResumed: "🥱",
            msgDataDistributionResumed: StorageMessagePreset.dataDistributionResumedNonJa.message(locale: locale),
            msgDataDistributionResumedJa: StorageMessagePreset.dataDistributionResumedJa.message(locale: jaLocale)
        )
        runtime = AppSettingsRuntime(lastLoadResultMessage: "", wasLastDataAllInvalid: false, originFetchedAt: nil)
    }

    /// 指定された貯水率 (Storage rate) に基づき、ステータス顔文字とメッセージのタプルを返します。
    ///
    /// 早明浦ダム用（`isSameura == true`）は貯水率と貯水量（`storageVolumeForMessage`）で分類し、
    /// 早明浦ダム以外用は貯水率のみで分類します。フィールド取得元は早明浦ダム用が既存フィールド、
    /// 早明浦ダム以外用が other* フィールドです。
    ///
    /// - Parameters:
    ///   - percentage: 貯水率 (Storage rate) の値。
    ///   - isJapanese: 日本語メッセージを使用するかどうか。
    ///   - isSameura: 早明浦ダム用の分類を行うかどうか。
    ///   - storageVolumeForMessage: 欠測前の最新正常貯水量 (Storage volume)。null は不明扱い。
    /// - Returns: 顔文字とメッセージテキストのタプル。
    func stateMessage(
        for percentage: Float,
        isJapanese: Bool = AppLocale.isJapanese,
        isSameura: Bool = false,
        storageVolumeForMessage: Float? = nil
    ) -> (String, String) {
        if !showStorageRateMessage { return ("", "") }
        let level = storageRateMessageLevel(
            for: percentage,
            isSameura: isSameura,
            storageVolumeForMessage: storageVolumeForMessage
        )
        return (level.0, isJapanese ? level.2 : level.1)
    }

    /// 貯水率 (Storage rate) 値を考慮し、無効データや欠測の状態も含めて対応するステータスメッセージを返します。
    ///
    /// `percentage` が nil の場合は `isSameura` に関わらず既存の異常（all_abnormal / all_data_invalid）フィールドを使用します。
    ///
    /// - Parameters:
    ///   - percentage: 貯水率 (Storage rate) の値（nil の場合は欠測や無効データ扱い）。
    ///   - isJapanese: 日本語メッセージを使用するかどうか。
    ///   - isAllDataInvalid: すべてのリアルタイム観測データ (Real-time observation data) が無効かどうか。
    ///   - isSameura: 早明浦ダム用の分類を行うかどうか。
    ///   - storageVolumeForMessage: 欠測前の最新正常貯水量 (Storage volume)。null は不明扱い。
    /// - Returns: 顔文字とメッセージテキストのタプル。
    func storageRateMessage(
        for percentage: Float?,
        isJapanese: Bool = AppLocale.isJapanese,
        isAllDataInvalid: Bool = false,
        isSameura: Bool = false,
        storageVolumeForMessage: Float? = nil
    ) -> (String, String) {
        if !showStorageRateMessage { return ("", "") }
        guard let percentage else {
            if isAllDataInvalid {
                return (stateAllDataInvalid, isJapanese ? msgAllDataInvalidJa : msgAllDataInvalid)
            }
            return (stateAllAbnormal, isJapanese ? msgAllAbnormalJa : msgAllAbnormal)
        }
        return stateMessage(
            for: percentage,
            isJapanese: isJapanese,
            isSameura: isSameura,
            storageVolumeForMessage: storageVolumeForMessage
        )
    }

    /// 顔文字とメッセージテキストを結合して、整形された表示用文字列を作成します。
    ///
    /// - Parameters:
    ///   - state: 顔文字など。
    ///   - message: メッセージ本文。
    /// - Returns: 結合された文字列。
    func displayText(state: String, message: String) -> String {
        "\(state) \(message)".trimmingCharacters(in: .whitespaces)
    }

    /// 初期状態用の表示用テキストを取得します。
    ///
    /// - Parameter isJapanese: 日本語メッセージを使用するかどうか。
    /// - Returns: 整形された初期状態メッセージ。
    func initialMessageText(isJapanese: Bool = AppLocale.isJapanese) -> String {
        displayText(state: stateInitialMessage, message: isJapanese ? msgInitialMessageJa : msgInitialMessage)
    }

    /// ネットワーク切断時の表示用テキストを取得します。
    ///
    /// - Parameter isJapanese: 日本語メッセージを使用するかどうか。
    /// - Returns: 整形されたネットワーク切断メッセージ。
    func networkUnavailableText(isJapanese: Bool = AppLocale.isJapanese) -> String {
        displayText(state: stateNetworkUnavailable, message: isJapanese ? msgNetworkUnavailableJa : msgNetworkUnavailable)
    }

    /// データ読み込みエラー時の表示用テキストを取得します。
    ///
    /// - Parameter isJapanese: 日本語メッセージを使用するかどうか。
    /// - Returns: 整形された読み込みエラーメッセージ。
    func loadingErrorText(isJapanese: Bool = AppLocale.isJapanese) -> String {
        displayText(state: stateLoadingError, message: isJapanese ? msgLoadingErrorJa : msgLoadingError)
    }

    /// データ配信停止時の表示用テキストを取得します。
    ///
    /// - Parameter isJapanese: 日本語メッセージを使用するかどうか。
    /// - Returns: 整形されたデータ配信停止メッセージ。
    func dataDistributionStoppedText(isJapanese: Bool = AppLocale.isJapanese) -> String {
        displayText(state: stateDataDistributionStopped, message: isJapanese ? msgDataDistributionStoppedJa : msgDataDistributionStopped)
    }

    /// データ配信再開時の表示用テキストを取得します。
    ///
    /// - Parameter isJapanese: 日本語メッセージを使用するかどうか。
    /// - Returns: 整形されたデータ配信再開メッセージ。
    func dataDistributionResumedText(isJapanese: Bool = AppLocale.isJapanese) -> String {
        displayText(state: stateDataDistributionResumed, message: isJapanese ? msgDataDistributionResumedJa : msgDataDistributionResumed)
    }

    /// 貯水率 (Storage rate) メッセージの設定内容の一意の識別用配列を返します（ハッシュ比較など用）。
    ///
    /// - Returns: 各設定項目の顔文字とテキストを結合した文字列の配列。
    func storageRateMessageIdentity() -> [String] {
        Self.storageRateMessageDescriptors.flatMap {
            [
                self[keyPath: $0.state],
                self[keyPath: $0.message],
                self[keyPath: $0.japaneseMessage]
            ]
        }
    }

    /// 早明浦ダム以外の貯水率 (Storage rate) メッセージの設定内容の一意の識別用配列を返します。
    ///
    /// - Returns: 各設定項目の顔文字とテキストを結合した文字列の配列。
    func otherStorageRateMessageIdentity() -> [String] {
        Self.otherStorageRateMessageDescriptors.flatMap {
            [
                self[keyPath: $0.state],
                self[keyPath: $0.message],
                self[keyPath: $0.japaneseMessage]
            ]
        }
    }

    /// 貯水率以外のその他メッセージの設定内容の一意の識別用配列を返します。
    ///
    /// - Returns: 各設定項目の顔文字とテキストを結合した文字列の配列。
    func otherMessageIdentity() -> [String] {
        Self.otherMessageDescriptors.flatMap {
            [
                self[keyPath: $0.state],
                self[keyPath: $0.message],
                self[keyPath: $0.japaneseMessage]
            ]
        }
    }

    /// 貯水率メッセージが標準リセット後のいずれかの状態から変更されているかどうかを返します。
    func needsStorageRateMessagesResetConfirmation() -> Bool {
        !StorageRateMessageResetMode.allStandardModes.contains { mode in
            storageRateMessageIdentity() == storageRateMessageIdentity(afterReset: mode)
        }
    }

    /// 早明浦ダム以外の貯水率メッセージが既定値（一般向け）から変更されているかどうかを返します。
    func needsOtherStorageRateMessagesResetConfirmation() -> Bool {
        otherStorageRateMessageIdentity() != Self.defaultOtherStorageRateMessageIdentity
    }

    /// その他メッセージが既定値から変更されているかどうかを返します。
    func needsOtherMessagesResetConfirmation() -> Bool {
        otherMessageIdentity() != Self.defaultOtherMessageIdentity
    }

    /// 指定モードで貯水率メッセージをリセットした場合の識別用配列を返します。
    private func storageRateMessageIdentity(afterReset mode: StorageRateMessageResetMode) -> [String] {
        var copy = self
        copy.resetStorageRateMessages(mode: mode)
        return copy.storageRateMessageIdentity()
    }

    /// その他メッセージの標準状態を表す識別用配列。
    private static var defaultOtherMessageIdentity: [String] {
        AppSettings(locale: Locale(identifier: "en")).otherMessageIdentity()
    }

    /// 早明浦ダム以外の貯水率メッセージの標準状態（一般向け）を表す識別用配列。
    private static var defaultOtherStorageRateMessageIdentity: [String] {
        AppSettings(locale: Locale(identifier: "en")).otherStorageRateMessageIdentity()
    }

    /// ウィジェット表示用のすべてのローカライズメッセージを辞書形式で取得します。
    ///
    /// 既存 8 キー（早明浦ダム用）に加え、早明浦ダム以外用として
    /// `"other_" + widgetKey.rawValue` 形式のキー8件（例: `"other_80_100"`）を追加します。
    ///
    /// - Parameter isJapanese: 日本語のメッセージを使用するかどうか。
    /// - Returns: ウィジェットキーと整形されたメッセージ値のマップ。
    func widgetMessages(isJapanese: Bool) -> [String: String] {
        guard showStorageRateMessage else { return [:] }
        var messages = Dictionary(
            uniqueKeysWithValues: Self.storageRateMessageDescriptors.map {
                (
                    $0.widgetKey.rawValue,
                    displayText(
                        state: self[keyPath: $0.state],
                        message: isJapanese ? self[keyPath: $0.japaneseMessage] : self[keyPath: $0.message]
                    )
                )
            }
        )
        for descriptor in Self.otherStorageRateMessageDescriptors {
            messages["other_" + descriptor.widgetKey.rawValue] = displayText(
                state: self[keyPath: descriptor.state],
                message: isJapanese ? self[keyPath: descriptor.japaneseMessage] : self[keyPath: descriptor.message]
            )
        }
        for descriptor in Self.otherMessageDescriptors {
            guard let widgetKey = descriptor.widgetKey else { continue }
            messages[widgetKey.rawValue] = displayText(
                state: self[keyPath: descriptor.state],
                message: isJapanese ? self[keyPath: descriptor.japaneseMessage] : self[keyPath: descriptor.message]
            )
        }
        return messages
    }

    /// 指定されたフィールドの貯水率以外のその他メッセージをリセットします。
    ///
    /// - Parameter field: 対象のメッセージフィールド。
    mutating func resetOtherMessageItem(field: OtherMessageField) {
        guard let descriptor = Self.otherMessageDescriptors.first(where: { $0.field == field }) else { return }
        resetOtherMessage(descriptor)
    }

    /// すべての貯水率以外のその他メッセージをデフォルト値にリセットします。
    mutating func resetOtherMessages() {
        Self.otherMessageDescriptors.forEach { resetOtherMessage($0) }
    }

    /// デバッグ用の設定項目をすべてデフォルトにリセットした設定情報のコピーを返します。
    ///
    /// - Returns: デバッグ項目が初期化された新しい AppSettings。
    func resettingDebugSettings() -> AppSettings {
        var copy = self
        copy.debugSettingsVisible = false
        copy.debugModeEnabled = false
        copy.debugSimulateMode = .none
        copy.debugRealtimeDatSelectionMode = .bundled
        copy.debugRealtimeDatFileName = nil
        copy.debugHistoricalDailyDatSelectionMode = .bundled
        copy.debugHistoricalDailyDatFileName = nil
        copy.debugRealtimeDataEndDate = nil
        copy.debugRealtimeDataPeriodAutoAdvanceEnabled = true
        return copy
    }

    /// その他メッセージ記述子を指定してメッセージをデフォルトに初期化します。
    private mutating func resetOtherMessage(_ descriptor: OtherMessageDescriptor) {
        let jaLocale = Locale(identifier: "ja")
        self[keyPath: descriptor.state] = descriptor.defaultState
        self[keyPath: descriptor.message] = descriptor.nonJapanesePreset.message()
        self[keyPath: descriptor.japaneseMessage] = descriptor.japanesePreset.message(locale: jaLocale)
    }

    /// 指定されたリセットモードに応じて、すべての貯水率 (Storage rate) メッセージ（早明浦ダム用）をデフォルト値に初期化します。
    ///
    /// - Parameter mode: リセットモード（日本語、英語、または全クリア）。
    mutating func resetStorageRateMessages(mode: StorageRateMessageResetMode) {
        for descriptor in Self.storageRateMessageDescriptors {
            self[keyPath: descriptor.state] = descriptor.defaultState
            let messages = descriptor.resetMessages(mode: mode)
            self[keyPath: descriptor.message] = messages.0
            self[keyPath: descriptor.japaneseMessage] = messages.1
        }
    }

    /// 早明浦ダム以外のすべての貯水率 (Storage rate) メッセージを既定値（一般向け）に初期化します。
    ///
    /// `resetMessages(mode: .nonJapanese)` 相当（状態は既定の顔文字、本文は日本語以外のプリセット。
    /// 日本語本文は `all_abnormal` / `all_data_invalid` のみ日本語の既定メッセージ、それ以外は日本語以外と同じ）を適用します。
    mutating func resetOtherStorageRateMessages() {
        for descriptor in Self.otherStorageRateMessageDescriptors {
            self[keyPath: descriptor.state] = descriptor.defaultState
            let messages = descriptor.resetMessages(mode: .nonJapanese)
            self[keyPath: descriptor.message] = messages.0
            self[keyPath: descriptor.japaneseMessage] = messages.1
        }
    }

    /// 貯水率 (Storage rate) の値に対応するメッセージレベル情報を検索して返します。
    ///
    /// 早明浦ダム用（`isSameura == true`）は「貯水率 80% 以上（100% 超含む）→ 貯水率 0% 以下（負値含む）→
    /// 貯水量しきい値（80,000 / 60,000 / 40,000 ×10³m³）」の順で分類します。貯水量（`storageVolumeForMessage`）が
    /// nil の場合は貯水率しきい値（60 / 40 / 20%）で分類します。フィールド取得元は早明浦ダム用が既存フィールド、
    /// 早明浦ダム以外用が other* フィールドです。
    ///
    /// - Parameters:
    ///   - percentage: 貯水率 (Storage rate) の値。
    ///   - isSameura: 早明浦ダム用の分類を行うかどうか。
    ///   - storageVolumeForMessage: 欠測前の最新正常貯水量 (Storage volume)。nil は不明扱い。
    /// - Returns: 顔文字、日本語以外のメッセージ、日本語のメッセージのタプル。
    private func storageRateMessageLevel(
        for percentage: Float,
        isSameura: Bool,
        storageVolumeForMessage: Float?
    ) -> (String, String, String) {
        let descriptors = isSameura ? Self.storageRateMessageDescriptors : Self.otherStorageRateMessageDescriptors
        let key: DamCoreWidgetMessageKey
        if isSameura {
            if percentage >= 80 {
                key = .storage80_100
            } else if percentage <= 0 {
                key = .storage0
            } else if let storageVolumeForMessage {
                if storageVolumeForMessage >= 80000 {
                    key = .storage60_80
                } else if storageVolumeForMessage >= 60000 {
                    key = .storage40_60
                } else if storageVolumeForMessage >= 40000 {
                    key = .storage20_40
                } else {
                    key = .storage0_20
                }
            } else if percentage >= 60 {
                key = .storage60_80
            } else if percentage >= 40 {
                key = .storage40_60
            } else if percentage >= 20 {
                key = .storage20_40
            } else {
                key = .storage0_20
            }
        } else {
            key = percentage <= 0 ? DamCoreWidgetMessageKey.storage0 : DamCoreWidgetMessageKey.storageKey(for: percentage)
        }
        let descriptor = descriptors.first { $0.widgetKey == key } ?? descriptors[5]
        return (
            self[keyPath: descriptor.state],
            self[keyPath: descriptor.message],
            self[keyPath: descriptor.japaneseMessage]
        )
    }

    /// 自動更新の間隔設定および次回更新予定日時を考慮した、次のデータ取得実行日時を算出します。
    ///
    /// - Parameter now: 基準となる日時（通常は現在日時）。
    /// - Returns: 次回自動更新の実行日時。
    func nextRunTime(after now: Date = Date()) -> Date {
        let calendar = Calendar.jst
        if nextRequestedUpdate > now {
            return nextRequestedUpdate
        }
        var candidate = nextRequestedUpdate
        if candidate.timeIntervalSince1970 == 0 {
            candidate = defaultNextRunTime(after: now, calendar: calendar)
        }
        while candidate <= now {
            candidate = candidate.addingTimeInterval(autoUpdateInterval.interval)
        }
        return candidate
    }

    /// 最小実行前進時間（クールダウン）を保証した、次回自動更新の実行予定日時を算出します。
    ///
    /// - Parameter now: 基準となる日時（通常は現在日時）。
    /// - Returns: 次回自動更新の実行予定日時。
    func nextRunTimeWithMinAdvance(after now: Date = Date()) -> Date {
        var result = nextRunTime(after: now)
        while result.timeIntervalSince(now) < AppSettings.minScheduleAdvanceSeconds {
            result = result.addingTimeInterval(autoUpdateInterval.interval)
        }
        return result
    }

    /// 次回要求される自動更新日時を再計算して更新します。
    ///
    /// - Parameter now: 基準となる日時（通常は現在日時）。
    mutating func recalculateNextRequestedUpdate(after now: Date = Date()) {
        if let anchor = initialAutoUpdateAnchorMinuteOfDay {
            let hour = anchor / 60
            let minute = anchor % 60
            nextRequestedUpdate = defaultNextRunTime(after: now, calendar: Calendar.jst, hour: hour, minute: minute)
        } else {
            nextRequestedUpdate = defaultNextRunTime(after: now, calendar: Calendar.jst)
        }
    }

    /// カレンダー設定と自動更新の実行間隔に基づき、標準的な次回更新日時を返します。
    private func defaultNextRunTime(after now: Date, calendar: Calendar, hour: Int = Self.defaultAutoUpdateHour, minute: Int = Self.defaultAutoUpdateMinute) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0
        var target = calendar.date(from: components) ?? now.addingTimeInterval(60 * 60)
        switch autoUpdateInterval {
        case .oneWeek:
            while calendar.component(.weekday, from: target) != 2 || target <= now {
                target = calendar.date(byAdding: .day, value: 1, to: target) ?? target.addingTimeInterval(24 * 60 * 60)
            }
            return target
        case .oneDay:
            if target <= now {
                target = calendar.date(byAdding: .day, value: 1, to: target) ?? target.addingTimeInterval(24 * 60 * 60)
            }
            return target
        case .twelveHours:
            if target > now { return target }
            let evening = calendar.date(byAdding: .hour, value: 12, to: target) ?? target.addingTimeInterval(12 * 60 * 60)
            if evening > now { return evening }
            return calendar.date(byAdding: .day, value: 1, to: target) ?? target.addingTimeInterval(24 * 60 * 60)
        case .oneHour:
            var hourly = calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: now)) ?? now
            hourly = calendar.date(bySetting: .minute, value: minute, of: hourly) ?? hourly
            if hourly <= now {
                hourly = calendar.date(byAdding: .hour, value: 1, to: hourly) ?? hourly.addingTimeInterval(60 * 60)
            }
            return hourly
        }
    }

    /// 初回起動時の自動更新予定時刻をランダム（一定の時間範囲内）に決定し、次回予定日時として設定・算出します。
    ///
    /// - Parameters:
    ///   - now: 基準となる日時（通常は現在日時）。
    ///   - minuteOfDayProvider: 1日のうちの実行する分数を決定するための関数。
    mutating func recalculateInitialNextRequestedUpdate(
        after now: Date = Date(),
        minuteOfDayProvider: () -> Int = {
            Int.random(in: AppSettings.initialAutoUpdateStartMinuteOfDay...AppSettings.initialAutoUpdateEndMinuteOfDay)
        }
    ) {
        let calendar = Calendar.jst
        let minuteOfDay = min(
            Self.initialAutoUpdateEndMinuteOfDay,
            max(Self.initialAutoUpdateStartMinuteOfDay, minuteOfDayProvider())
        )
        initialAutoUpdateAnchorMinuteOfDay = minuteOfDay
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = minuteOfDay / 60
        components.minute = minuteOfDay % 60
        components.second = 0
        var target = calendar.date(from: components) ?? now.addingTimeInterval(60 * 60)
        while calendar.component(.weekday, from: target) != 2 {
            target = calendar.date(byAdding: .day, value: 1, to: target) ?? target.addingTimeInterval(24 * 60 * 60)
        }
        if target <= now || calendar.isDate(target, inSameDayAs: now) {
            target = calendar.date(byAdding: .day, value: 7, to: target) ?? target.addingTimeInterval(7 * 24 * 60 * 60)
        }
        nextRequestedUpdate = target
    }

}

/// ダムの過去履歴データ検索に関するメタ情報データを保持する構造体。
struct HistoricalSearchMeta: Identifiable, Codable, Hashable, Sendable {
    /// 検索の識別子 ID。
    let id: UUID
    /// 観測所のID。
    let observationStationId: String
    /// 観測所の名前。
    let observationStationName: String
    /// 水系名。
    let riverSystemName: String
    /// 河川名。
    let riverName: String
    /// ダム設定情報の識別ID。
    let damConfigId: String
    /// 検索開始日 (yyyyMMdd) の文字列。
    let searchBgnDate: String
    /// 検索終了日 (yyyyMMdd) の文字列。
    let searchEndDate: String
    /// 検索履歴データの取得日時。
    let fetchedAt: Date
    /// 表示時の並び順。
    var sortOrder: Int
    /// 履歴がピン留めされているかどうか。
    var isPinned: Bool
    /// 取得したデータの開始日時文字列（省略可能）。
    let dataStartTimeStr: String?
    /// 取得したデータの終了日時文字列（省略可能）。
    let dataEndTimeStr: String?
    /// データ開始時の貯水率 (Storage rate) (%)。
    let dataStartStoragePct: Float?
    /// データ終了時の貯水率 (Storage rate) (%)。
    let dataEndStoragePct: Float?
    /// 期間中の最小貯水率 (Storage rate) (%)。
    let dataMinStoragePct: Float?
    /// 期間中の最大貯水率 (Storage rate) (%)。
    let dataMaxStoragePct: Float?
}

/// アプリ開発および動作検証向けのデバッグログ行情報を表する構造体。
struct DebugLogEntry: Identifiable, Codable, Hashable, Sendable {
    /// ログの識別 ID。
    let id: UUID
    /// ログ発生時のタイムスタンプ。
    let timestamp: Date
    /// ログの要約メッセージ。
    let message: String
    /// ログの詳細情報。
    let details: String
}

/// 過去データ検索用のローカル .dat ファイルのエントリ情報を表する構造体。
nonisolated struct HistoricalDatFileEntry: Codable, Hashable, Sendable {
    /// 観測所のID。
    let stationId: String
    /// データ開始日時。
    let startDatetime: String
    /// データ終了日時。
    let endDatetime: String
    /// dat ファイルの配置先パス。
    let filePath: String
}

/// ダムデータの読み込み処理状況（ロードステータス）を定義する列挙型。
enum DamLoadStatus: Sendable {
    /// 初期状態。
    case initial
    /// データ読み込み成功。
    case success
    /// ネットワーク利用不可による失敗。
    case networkUnavailable
    /// その他の読み込み失敗。
    case loadingFailure
}

nonisolated extension Calendar {
    /// アプリケーション内で統一的に使用される日本標準時 (JST) 向けのカレンダーインスタンス。
    static let jst: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }()
}
