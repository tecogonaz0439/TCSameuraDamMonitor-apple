// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// ウィジェットに表示するためのダム情報のスナップショット構造体。
///
/// 早明浦ダム (Sameura Dam) を含むダムの貯水率 (Storage rate) や貯水量 (Storage volume) などのリアルタイム観測データ (Real-time observation data) を保持します。
public struct DamCoreWidgetSnapshot: Codable, Sendable, Equatable {
    /// ダムの名前。
    public let damName: String
    /// データ更新日時の文字列。
    public let updatedAt: String
    /// データの観測日時の文字列。
    public let observedAt: String
    /// 貯水率 (Storage rate)。
    public let storagePercentage: Float?
    /// 貯水率 (Storage rate) の増減傾向を表すシンボルまたは文字列。
    public let trend: String
    /// 貯水量 (Storage volume)。
    public let storageVolume: Float?
    /// 貯水量 (Storage volume) の増減傾向。
    public let storageVolumeTrend: String?
    /// 前日比の貯水率 (Storage rate) 変化量。
    public let storagePercentageDayChange: Float?
    /// 前日比の変化傾向。
    public let dayChangeTrend: String?
    /// 前週比の貯水率 (Storage rate) 変化量。
    public let storagePercentageWeekChange: Float?
    /// 前週比の変化傾向。
    public let weekChangeTrend: String?
    /// ウィジェットに表示するメッセージ。
    public let message: String
    /// ネットワークエラーが発生したかどうかのフラグ。
    public let isNetworkError: Bool
    /// すべてのリアルタイム観測データ (Real-time observation data) が無効かどうかのフラグ。
    public let isAllDataInvalid: Bool
    /// 早明浦ダム用の貯水率メッセージ分類を行うかどうかのフラグ。
    public let isSameura: Bool
    /// 貯水率メッセージ分類用の貯水量 (Storage volume)（×10³m³）。
    ///
    /// 貯水量 (Storage volume) 欠測時は欠測前の最新正常値。全く無い場合は nil。
    public let storageVolumeForMessage: Float?
    /// データの最終更新日時。
    public let lastUpdatedAt: Date

    /// Codableデコードおよびエンコードに使用するコーディングキー。
    enum CodingKeys: String, CodingKey {
        case damName, updatedAt, observedAt, storagePercentage, trend, storageVolume, storageVolumeTrend
        case storagePercentageDayChange, dayChangeTrend, storagePercentageWeekChange, weekChangeTrend
        case message, isNetworkError, isAllDataInvalid, isSameura, storageVolumeForMessage, lastUpdatedAt
    }

    /// 各プロパティを指定してスナップショットを初期化するイニシャライザ。
    ///
    /// - Parameters:
    ///   - damName: ダムの名前。
    ///   - updatedAt: データ更新日時。
    ///   - observedAt: データの観測日時。
    ///   - storagePercentage: 貯水率 (Storage rate)。
    ///   - trend: 貯水率 (Storage rate) の増減傾向。
    ///   - storageVolume: 貯水量 (Storage volume)。
    ///   - storageVolumeTrend: 貯水量 (Storage volume) の増減傾向。
    ///   - storagePercentageDayChange: 前日比の貯水率 (Storage rate) 変化量。
    ///   - dayChangeTrend: 前日比の変化傾向。
    ///   - storagePercentageWeekChange: 前週比の貯水率 (Storage rate) 変化量。
    ///   - weekChangeTrend: 前週比の変化傾向。
    ///   - message: 表示用メッセージ。
    ///   - isNetworkError: ネットワークエラーが発生したかどうか。
    ///   - isAllDataInvalid: すべてのリアルタイム観測データ (Real-time observation data) が無効かどうか。
    ///   - isSameura: 早明浦ダム用の貯水率メッセージ分類を行うかどうか。
    ///   - storageVolumeForMessage: 貯水率メッセージ分類用の貯水量 (Storage volume)（×10³m³）。欠測時は欠測前の最新正常値。
    ///   - lastUpdatedAt: 最終更新日時。
    public init(damName: String, updatedAt: String, observedAt: String, storagePercentage: Float?, trend: String, storageVolume: Float?, storageVolumeTrend: String?, storagePercentageDayChange: Float?, dayChangeTrend: String?, storagePercentageWeekChange: Float?, weekChangeTrend: String?, message: String, isNetworkError: Bool, isAllDataInvalid: Bool, isSameura: Bool = false, storageVolumeForMessage: Float? = nil, lastUpdatedAt: Date) {
        self.damName = damName
        self.updatedAt = updatedAt
        self.observedAt = observedAt
        self.storagePercentage = storagePercentage
        self.trend = trend
        self.storageVolume = storageVolume
        self.storageVolumeTrend = storageVolumeTrend
        self.storagePercentageDayChange = storagePercentageDayChange
        self.dayChangeTrend = dayChangeTrend
        self.storagePercentageWeekChange = storagePercentageWeekChange
        self.weekChangeTrend = weekChangeTrend
        self.message = message
        self.isNetworkError = isNetworkError
        self.isAllDataInvalid = isAllDataInvalid
        self.isSameura = isSameura
        self.storageVolumeForMessage = storageVolumeForMessage
        self.lastUpdatedAt = lastUpdatedAt
    }

    /// デコーダーからスナップショットを初期化するイニシャライザ。
    ///
    /// - Parameter decoder: デコードに使用するデコーダー。
    /// - Throws: デコードエラーが発生した場合。
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        damName = try container.decode(String.self, forKey: .damName)
        updatedAt = (try? container.decode(String.self, forKey: .updatedAt)) ?? ""
        observedAt = try container.decode(String.self, forKey: .observedAt)
        storagePercentage = try container.decodeIfPresent(Float.self, forKey: .storagePercentage)
        trend = try container.decode(String.self, forKey: .trend)
        storageVolume = try container.decodeIfPresent(Float.self, forKey: .storageVolume)
        storageVolumeTrend = try container.decodeIfPresent(String.self, forKey: .storageVolumeTrend)
        storagePercentageDayChange = try container.decodeIfPresent(Float.self, forKey: .storagePercentageDayChange)
        dayChangeTrend = try container.decodeIfPresent(String.self, forKey: .dayChangeTrend)
        storagePercentageWeekChange = try container.decodeIfPresent(Float.self, forKey: .storagePercentageWeekChange)
        weekChangeTrend = try container.decodeIfPresent(String.self, forKey: .weekChangeTrend)
        message = try container.decode(String.self, forKey: .message)
        isNetworkError = try container.decode(Bool.self, forKey: .isNetworkError)
        isAllDataInvalid = (try? container.decode(Bool.self, forKey: .isAllDataInvalid)) ?? false
        isSameura = (try? container.decode(Bool.self, forKey: .isSameura)) ?? false
        storageVolumeForMessage = try container.decodeIfPresent(Float.self, forKey: .storageVolumeForMessage)
        lastUpdatedAt = try container.decode(Date.self, forKey: .lastUpdatedAt)
    }
}

/// ウィジェット等に表示するメッセージを検索・フォールバックするための構造体。
public struct DamCoreWidgetMessageLookup: Sendable {
    /// キーに対応するメッセージの辞書。
    public let messages: [String: String]?
    /// 貯水率 (Storage rate) に応じたデフォルトメッセージを生成するフォールバック関数。
    public let storageFallback: @Sendable (Float) -> String
    /// 特殊なメッセージキーに対応するデフォルトメッセージを生成するフォールバック関数。
    public let specialFallback: @Sendable (DamCoreWidgetMessageKey) -> String
    /// 早明浦ダム用のメッセージキーに対応するデフォルトメッセージを生成するフォールバック関数。
    public let sameuraStorageFallback: @Sendable (DamCoreWidgetMessageKey) -> String
    /// 早明浦ダム以外用のメッセージキーに対応するデフォルトメッセージを生成するフォールバック関数。
    public let otherStorageFallback: @Sendable (DamCoreWidgetMessageKey) -> String

    /// イニシャライザ。
    ///
    /// - Parameters:
    ///   - messages: メッセージ辞書。
    ///   - storageFallback: 貯水率 (Storage rate) 用フォールバック関数。
    ///   - specialFallback: 特殊状態用フォールバック関数。
    ///   - sameuraStorageFallback: 早明浦ダム用メッセージキー用フォールバック関数。
    ///   - otherStorageFallback: 早明浦ダム以外用メッセージキー用フォールバック関数。
    public init(
        messages: [String: String]?,
        storageFallback: @escaping @Sendable (Float) -> String,
        specialFallback: @escaping @Sendable (DamCoreWidgetMessageKey) -> String,
        sameuraStorageFallback: @escaping @Sendable (DamCoreWidgetMessageKey) -> String,
        otherStorageFallback: @escaping @Sendable (DamCoreWidgetMessageKey) -> String
    ) {
        self.messages = messages
        self.storageFallback = storageFallback
        self.specialFallback = specialFallback
        self.sameuraStorageFallback = sameuraStorageFallback
        self.otherStorageFallback = otherStorageFallback
    }

    /// イニシャライザ（早明浦ダム用・早明浦ダム以外用のフォールバックには空文字を返す関数を使用）。
    ///
    /// - Parameters:
    ///   - messages: メッセージ辞書。
    ///   - storageFallback: 貯水率 (Storage rate) 用フォールバック関数。
    ///   - specialFallback: 特殊状態用フォールバック関数。
    public init(
        messages: [String: String]?,
        storageFallback: @escaping @Sendable (Float) -> String,
        specialFallback: @escaping @Sendable (DamCoreWidgetMessageKey) -> String
    ) {
        self.init(
            messages: messages,
            storageFallback: storageFallback,
            specialFallback: specialFallback,
            sameuraStorageFallback: { _ in "" },
            otherStorageFallback: { _ in "" }
        )
    }

    /// 指定された貯水率 (Storage rate) に対応するメッセージを取得します。
    ///
    /// - Parameter percentage: 貯水率 (Storage rate)。
    /// - Returns: 対応するメッセージ文字列。
    public func message(for percentage: Float) -> String {
        if let messages {
            if messages.isEmpty { return "" }
            let key = DamCoreWidgetMessageKey.storageKey(for: percentage)
            if let message = messages[key.rawValue], !message.isEmpty {
                return message
            }
        }
        return storageFallback(percentage)
    }

    /// 指定された特殊なメッセージキーに対応するメッセージを取得します。
    ///
    /// - Parameter key: 特殊メッセージキー。
    /// - Returns: 対応するメッセージ文字列。
    public func specialMessage(for key: DamCoreWidgetMessageKey) -> String {
        if let messages {
            if messages.isEmpty { return "" }
            if let message = messages[key.rawValue] {
                return message
            }
        }
        return specialFallback(key)
    }

    /// 早明浦ダム用の貯水率 (Storage rate) と貯水量 (Storage volume) に応じたメッセージを取得します。
    ///
    /// 貯水率 80%以上（100%超含む）→ 貯水率 0%以下（負値含む）→ 貯水量しきい値（80,000 / 60,000 / 40,000×10³m³）
    /// の組み合わせで分類します。貯水量 (Storage volume) 欠測時は欠測前の最新正常値で判定し、
    /// 全く無い場合のみ貯水率しきい値（60% / 40% / 20%）へフォールバックします。
    ///
    /// - Parameters:
    ///   - percentage: 貯水率 (Storage rate)。
    ///   - storageVolumeForMessage: 貯水率メッセージ分類用の貯水量 (Storage volume)（×10³m³）。
    /// - Returns: 対応するメッセージ文字列。
    public func sameuraMessage(for percentage: Float, storageVolumeForMessage: Float?) -> String {
        let key = DamCoreWidgetMessageKey.sameuraStorageKey(for: percentage, storageVolumeForMessage: storageVolumeForMessage)
        if let messages {
            if messages.isEmpty { return "" }
            if let message = messages[key.rawValue], !message.isEmpty {
                return message
            }
        }
        return sameuraStorageFallback(key)
    }

    /// 早明浦ダム以外用の貯水率 (Storage rate) に応じたメッセージを取得します。
    ///
    /// 貯水率のみで分類し、辞書は `"other_" + キー名` 形式（例: "other_80_100"）で解決します。
    /// 貯水率 0% 以下（負値含む）は 0% メッセージ（`"other_0"`）として扱います。
    ///
    /// - Parameter percentage: 貯水率 (Storage rate)。
    /// - Returns: 対応するメッセージ文字列。
    public func otherMessage(for percentage: Float) -> String {
        let key = percentage <= 0 ? DamCoreWidgetMessageKey.storage0 : DamCoreWidgetMessageKey.storageKey(for: percentage)
        if let messages {
            if messages.isEmpty { return "" }
            if let message = messages["other_" + key.rawValue], !message.isEmpty {
                return message
            }
        }
        return otherStorageFallback(key)
    }
}

/// ダム情報のウィジェット用スナップショットを生成するファクトリ。
public enum DamCoreWidgetSnapshotFactory {
    /// リアルタイム観測データ (Real-time observation data) のフィールド情報からスナップショットを生成します。
    ///
    /// - Parameters:
    ///   - damName: ダムの名前。
    ///   - fields: 解析されたリアルタイム観測データ (Real-time observation data) のフィールド。
    ///   - messageLookup: 表示メッセージの検索ルックアップ。
    ///   - isSameura: 早明浦ダム用の貯水率メッセージ分類を行うかどうか。true の場合は貯水量 (Storage volume) ベースの分類、false の場合は `"other_"` 接頭辞キーで解決します。
    ///   - storageVolumeForMessage: 貯水率メッセージ分類用の貯水量 (Storage volume)（×10³m³）。欠測時は欠測前の最新正常値。
    ///   - lastUpdatedAt: 最終更新日時（デフォルトは現在日時）。
    /// - Returns: 生成されたウィジェット用スナップショット。
    public static func makeSnapshot(
        damName: String,
        fields: DamCoreWidgetParser.SnapshotFields,
        messageLookup: DamCoreWidgetMessageLookup,
        isSameura: Bool = false,
        storageVolumeForMessage: Float? = nil,
        lastUpdatedAt: Date = Date()
    ) -> DamCoreWidgetSnapshot {
        let message: String
        if let percentage = fields.storagePercentage {
            message = isSameura
                ? messageLookup.sameuraMessage(for: percentage, storageVolumeForMessage: storageVolumeForMessage)
                : messageLookup.otherMessage(for: percentage)
        } else if fields.isAllDataInvalid {
            message = messageLookup.specialMessage(for: .allDataInvalid)
        } else {
            message = messageLookup.specialMessage(for: .abnormal)
        }

        return DamCoreWidgetSnapshot(
            damName: damName,
            updatedAt: fields.updatedAt,
            observedAt: fields.observedAt ?? "",
            storagePercentage: fields.storagePercentage,
            trend: fields.trend,
            storageVolume: fields.storageVolume,
            storageVolumeTrend: fields.storageVolumeTrend,
            storagePercentageDayChange: fields.storagePercentageDayChange,
            dayChangeTrend: fields.dayChangeTrend,
            storagePercentageWeekChange: fields.storagePercentageWeekChange,
            weekChangeTrend: fields.weekChangeTrend,
            message: message,
            isNetworkError: false,
            isAllDataInvalid: fields.isAllDataInvalid,
            isSameura: isSameura,
            storageVolumeForMessage: storageVolumeForMessage,
            lastUpdatedAt: lastUpdatedAt
        )
    }
}

/// ウィジェットのデータ取得判定結果を保持する構造体。
public struct DamCoreWidgetFetchDecision: Equatable, Sendable {
    /// データ取得が許可されたかどうか。
    public let allowed: Bool
    /// 取得判定の理由。
    public let reason: String

    /// イニシャライザ。
    ///
    /// - Parameters:
    ///   - allowed: 取得が許可されたかどうか。
    ///   - reason: 取得判定の理由。
    public init(allowed: Bool, reason: String) {
        self.allowed = allowed
        self.reason = reason
    }
}

/// ウィジェットのデータ取得制限（ゲート）を管理する列挙型。
public enum DamCoreWidgetFetchGate {
    /// 最小データ取得間隔。
    public nonisolated static let minimumFetchInterval: TimeInterval = 15 * 60

    /// データ取得を行うかどうかの意思決定を行います。
    ///
    /// - Parameters:
    ///   - initialLoadDone: 初回読み込みが完了しているかどうか。
    ///   - autoUpdateEnabled: 自動更新が有効かどうか。
    ///   - debugSimulationActive: デバッグ用のシミュレーションがアクティブかどうか。
    ///   - hasUsableCache: 利用可能なキャッシュが存在するかどうか。
    ///   - lastFetchAt: 最終取得日時。
    ///   - nextRefresh: 次回更新予定日時。
    ///   - now: 現在日時。
    /// - Returns: データ取得の判定結果。
    public nonisolated static func decision(
        initialLoadDone: Bool,
        autoUpdateEnabled: Bool,
        debugSimulationActive: Bool,
        hasUsableCache: Bool,
        lastFetchAt: Date?,
        nextRefresh: Date?,
        now: Date
    ) -> DamCoreWidgetFetchDecision {
        if let lastFetchAt, now.timeIntervalSince(lastFetchAt) < minimumFetchInterval {
            return DamCoreWidgetFetchDecision(allowed: false, reason: "throttled")
        }
        if !initialLoadDone {
            return DamCoreWidgetFetchDecision(allowed: false, reason: "initialLoadNotDone")
        }
        if debugSimulationActive {
            return DamCoreWidgetFetchDecision(allowed: false, reason: "debugSimulationActive")
        }
        if !autoUpdateEnabled {
            return DamCoreWidgetFetchDecision(allowed: false, reason: "autoUpdateDisabled")
        }
        if !hasUsableCache {
            return DamCoreWidgetFetchDecision(allowed: true, reason: "noUsableCache")
        }
        guard let nextRefresh else {
            return DamCoreWidgetFetchDecision(allowed: false, reason: "nextRefreshMissing")
        }
        return now >= nextRefresh
            ? DamCoreWidgetFetchDecision(allowed: true, reason: "due")
            : DamCoreWidgetFetchDecision(allowed: false, reason: "notDue")
    }
}

/// ウィジェットの表示メッセージに対応するキーを定義する列挙型。
public enum DamCoreWidgetMessageKey: String, Sendable, CaseIterable {
    /// 貯水率 (Storage rate) が80%〜100%の時のキー。
    case storage80_100 = "80_100"
    /// 貯水率 (Storage rate) が60%〜80%の時のキー。
    case storage60_80 = "60_80"
    /// 貯水率 (Storage rate) が40%〜60%の時のキー。
    case storage40_60 = "40_60"
    /// 貯水率 (Storage rate) が20%〜40%の時のキー。
    case storage20_40 = "20_40"
    /// 貯水率 (Storage rate) が0%〜20%の時のキー.
    case storage0_20 = "0_20"
    /// 貯水率 (Storage rate) が0%の時のキー。
    case storage0 = "0"
    /// 異常値または貯水率 (Storage rate) データがない時のキー。
    case abnormal = "abnormal"
    /// すべてのリアルタイム観測データ (Real-time observation data) が無効な時のキー。
    case allDataInvalid = "all_data_invalid"
    /// 初期状態のメッセージキー。
    case initial = "initial"
    /// データ配信停止時のメッセージキー。
    case dataDistributionStopped = "data_distribution_stopped"
    /// データ配信再開時のメッセージキー。
    case dataDistributionResumed = "data_distribution_resumed"

    /// 指定された貯水率 (Storage rate) に応じたメッセージキーを返します。
    ///
    /// - Parameter percentage: 貯水率 (Storage rate)。
    /// - Returns: 対応するメッセージキー。
    public static func storageKey(for percentage: Float) -> DamCoreWidgetMessageKey {
        switch percentage {
        case 80...: return .storage80_100
        case 60..<80: return .storage60_80
        case 40..<60: return .storage40_60
        case 20..<40: return .storage20_40
        case 0: return .storage0
        case 0..<20: return .storage0_20
        default: return .abnormal
        }
    }

    /// 早明浦ダム用の貯水率しきい値（%）: 貯水率 80% 以上。
    public nonisolated static let sameuraRateAtLeast80: Float = 80
    /// 早明浦ダム用の貯水量 (Storage volume) しきい値（×10³m³）: 貯水率 60%〜80% 相当。
    public nonisolated static let sameuraAtLeast60VolumeThreshold: Float = 80_000
    /// 早明浦ダム用の貯水量 (Storage volume) しきい値（×10³m³）: 貯水率 40%〜60% 相当。
    public nonisolated static let sameuraAtLeast40VolumeThreshold: Float = 60_000
    /// 早明浦ダム用の貯水量 (Storage volume) しきい値（×10³m³）: 貯水率 20%〜40% 相当。
    public nonisolated static let sameuraAtLeast20VolumeThreshold: Float = 40_000

    /// 早明浦ダム用の貯水率 (Storage rate) と貯水量 (Storage volume) に応じたメッセージキーを返します。
    ///
    /// 貯水率 80%以上（100%超含む）は `80_100`、貯水率 0%以下（負値含む）は `0` を返します。
    /// 貯水率 0%超 80%未満は貯水量しきい値（80,000 / 60,000 / 40,000×10³m³）で `60_80` / `40_60` / `20_40` / `0_20` を返し、
    /// 貯水量 (Storage volume) が nil の場合は貯水率しきい値（60% / 40% / 20%）でフォールバックします。
    ///
    /// - Parameters:
    ///   - percentage: 貯水率 (Storage rate)。
    ///   - storageVolumeForMessage: 貯水率メッセージ分類用の貯水量 (Storage volume)（×10³m³）。欠測時は欠測前の最新正常値。
    /// - Returns: 対応するメッセージキー。
    public static func sameuraStorageKey(for percentage: Float, storageVolumeForMessage: Float?) -> DamCoreWidgetMessageKey {
        switch percentage {
        case 80...: return .storage80_100
        case ...0: return .storage0
        default:
            if let storageVolumeForMessage {
                switch storageVolumeForMessage {
                case 80_000...: return .storage60_80
                case 60_000...: return .storage40_60
                case 40_000...: return .storage20_40
                default: return .storage0_20
                }
            }
            switch percentage {
            case 60..<80: return .storage60_80
            case 40..<60: return .storage40_60
            case 20..<40: return .storage20_40
            default: return .storage0_20
            }
        }
    }
}
