// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation
import TCSameuraDamCore
import WidgetKit

/// アプリとウィジェット拡張機能の間で設定、リアルタイム観測データ (Real-time observation data) のスナップショット、および同期状態を共有するためのブリッジサービス。
@MainActor
internal struct WidgetBridgeService {
    /// 共有されるユーザーデフォルトストレージ。
    internal let defaults: WidgetBridgeDefaults

    /// 指定されたキーに対応する値を保存します。
    /// - Parameters:
    ///   - value: 保存する値。
    ///   - key: 保存キー。
    internal func set(_ value: Any, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    /// 指定されたキーに対応する値を削除します。
    /// - Parameter key: 削除対象のキー。
    internal func removeValue(forKey key: String) {
        defaults.removeValue(forKey: key)
    }

    /// 指定されたキーに対応するデータをバイナリ形式で取得します。
    /// - Parameter key: 取得対象のキー。
    /// - Returns: バイナリデータ。存在しない場合は `nil`。
    internal func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    /// 指定されたキーに対応する文字列を取得します。
    /// - Parameter key: 取得対象のキー。
    /// - Returns: 文字列。存在しない場合は `nil`。
    internal func string(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    /// 指定されたキーに対応する浮動小数点数値を取得します。
    /// - Parameter key: 取得対象のキー。
    /// - Returns: 取得した数値。存在しない場合は `0.0`。
    internal func double(forKey key: String) -> Double {
        defaults.double(forKey: key)
    }

    /// 指定されたキーに対応する日付を取得します。
    /// - Parameter key: 取得対象のキー。
    /// - Returns: 日付オブジェクト。存在しない場合は `nil`。
    internal func date(forKey key: String) -> Date? {
        defaults.date(forKey: key)
    }

    /// アプリの設定と現在のダム設定情報を共有用のデフォルトに書き込みます。
    /// - Parameters:
    ///   - settings: アプリ設定。
    ///   - config: 対象のダム設定。
    ///   - damDisplayName: 表示用のダム名。
    ///   - initialLoadDone: 初回読み込み完了フラグ。
    internal func saveSettingsBridge(settings: AppSettings, config: DamConfig, damDisplayName: String, initialLoadDone: Bool) {
        set(settings.autoUpdateEnabled, forKey: WidgetDefaultsKey.autoUpdateEnabled)
        set(settings.showNotification, forKey: WidgetDefaultsKey.showNotification)
        set(settings.nextRequestedUpdate.timeIntervalSinceReferenceDate, forKey: WidgetDefaultsKey.nextRequestedUpdate)
        set(settings.autoUpdateInterval.interval, forKey: WidgetDefaultsKey.autoUpdateIntervalSeconds)
        set(damDisplayName, forKey: WidgetDefaultsKey.damDisplayName)
        set(config.dataUrl, forKey: WidgetDefaultsKey.dataUrl)
        set(config.id, forKey: WidgetDefaultsKey.stationId)
        set(config.nameJa, forKey: WidgetDefaultsKey.stationName)
        set(settings.realtimeDataSource.rawValue, forKey: WidgetDefaultsKey.realtimeSource)
        set(settings.historicalDataSource.rawValue, forKey: WidgetDefaultsKey.historicalDataSource)
        set(RealtimeDataSource.sudmonitorLatestDatURL(damId: config.id), forKey: WidgetDefaultsKey.realtimeDatUrl)
        set(true, forKey: WidgetDefaultsKey.appConfigured)
        set(settings.debugModeEnabled, forKey: WidgetDefaultsKey.debugModeEnabled)
        set(settings.debugSimulateMode.rawValue, forKey: WidgetDefaultsKey.debugSimulateMode)
        set(initialLoadDone, forKey: WidgetDefaultsKey.initialLoadDone)
        saveMessages(settings: settings)
    }

    /// 最新の観測データをスナップショットとして保存し、ウィジェットのタイムラインを更新します。
    /// - Parameters:
    ///   - data: パースされたダム観測データ。
    ///   - message: 画面に表示する状態説明テキスト。
    ///   - config: 該当するダム設定。
    ///   - isNetworkError: ネットワークエラー状態でのスナップショット作成かどうかのフラグ。
    internal func saveSnapshot(data: DamData, message: String, config: DamConfig?, isNetworkError: Bool) {
        let damDisplayName = config?.localizedName ?? data.observationStationName
        let snapshot = DamCoreWidgetSnapshot(
            damName: damDisplayName,
            updatedAt: data.updatedAt,
            observedAt: data.storagePercentageTime ?? data.updatedAt,
            storagePercentage: data.storagePercentage,
            trend: data.storagePercentageTrend.rawValue,
            storageVolume: data.storageVolume,
            storageVolumeTrend: data.storageVolumeTrend.rawValue,
            storagePercentageDayChange: data.storagePercentageDayChange,
            dayChangeTrend: data.storagePercentageDayChangeTrend.rawValue,
            storagePercentageWeekChange: data.storagePercentageWeekChange,
            weekChangeTrend: data.storagePercentageWeekChangeTrend.rawValue,
            message: message,
            isNetworkError: isNetworkError,
            isAllDataInvalid: data.isAllObservationDataInvalid,
            isSameura: data.observationStationId == AppSettings.defaultDamId,
            storageVolumeForMessage: data.storageVolumeForMessage,
            lastUpdatedAt: Date()
        )
        save(snapshot: snapshot)
        set(Date().timeIntervalSinceReferenceDate, forKey: WidgetDefaultsKey.appLastFetchAt)
        reloadTimeline()
    }

    /// エラー発生時の暫定スナップショットを保存し、ウィジェットの表示を更新します。
    /// - Parameters:
    ///   - message: 表示するエラーメッセージ。
    ///   - config: 該当するダム設定。
    internal func saveErrorSnapshot(message: String, config: DamConfig?) {
        if let existingData = data(forKey: WidgetDefaultsKey.snapshotV1),
           let existingSnapshot = try? JSONDecoder().decode(DamCoreWidgetSnapshot.self, from: existingData),
           !existingSnapshot.isNetworkError {
            return
        }
        let snapshot = DamCoreWidgetSnapshot(
            damName: config?.localizedName ?? "",
            updatedAt: "",
            observedAt: "",
            storagePercentage: nil,
            trend: Trend.unknown.rawValue,
            storageVolume: nil,
            storageVolumeTrend: nil,
            storagePercentageDayChange: nil,
            dayChangeTrend: nil,
            storagePercentageWeekChange: nil,
            weekChangeTrend: nil,
            message: message,
            isNetworkError: true,
            isAllDataInvalid: false,
            isSameura: config?.id == AppSettings.defaultDamId,
            storageVolumeForMessage: nil,
            lastUpdatedAt: Date()
        )
        save(snapshot: snapshot)
        set(Date().timeIntervalSinceReferenceDate, forKey: WidgetDefaultsKey.appLastFetchAt)
        reloadTimeline()
    }

    /// アプリ設定からウィジェットメッセージの一覧を抽出し、ブリッジに保存します。
    /// - Parameter settings: アプリ設定。
    internal func saveMessages(settings: AppSettings) {
        let messages = settings.widgetMessages(isJapanese: AppLocale.isJapanese)
        if let encoded = try? JSONEncoder().encode(messages) {
            set(encoded, forKey: WidgetDefaultsKey.messages)
        }
        updateExistingSnapshotMessage(settings: settings)
    }

    /// 現在保存されているスナップショット内の表示メッセージを、最新の設定に基づいて更新します。
    /// - Parameter settings: 最新のアプリ設定。
    internal func updateExistingSnapshotMessage(settings: AppSettings) {
        let isSameura = settings.targetDamId == AppSettings.defaultDamId
        for key in [WidgetDefaultsKey.snapshotV1, WidgetDefaultsKey.appSnapshot] {
            guard let data = data(forKey: key),
                  var snapshot = try? JSONDecoder().decode(DamCoreWidgetSnapshot.self, from: data) else { continue }
            let newMessage: String
            if let percentage = snapshot.storagePercentage {
                // スナップショットには欠測前の最新正常貯水量が無いため、最新の正常貯水量（storageVolume）を代用する。
                let state = settings.stateMessage(
                    for: percentage,
                    isJapanese: AppLocale.isJapanese,
                    isSameura: isSameura,
                    storageVolumeForMessage: snapshot.storageVolume
                )
                newMessage = "\(state.0) \(state.1)".trimmingCharacters(in: .whitespaces)
            } else if !snapshot.observedAt.isEmpty {
                let pair = settings.storageRateMessage(
                    for: nil,
                    isJapanese: AppLocale.isJapanese,
                    isAllDataInvalid: snapshot.isAllDataInvalid,
                    isSameura: isSameura
                )
                newMessage = "\(pair.0) \(pair.1)".trimmingCharacters(in: .whitespaces)
            } else {
                continue
            }
            guard snapshot.message != newMessage else { continue }
            snapshot = DamCoreWidgetSnapshot(
                damName: snapshot.damName,
                updatedAt: snapshot.updatedAt,
                observedAt: snapshot.observedAt,
                storagePercentage: snapshot.storagePercentage,
                trend: snapshot.trend,
                storageVolume: snapshot.storageVolume,
                storageVolumeTrend: snapshot.storageVolumeTrend,
                storagePercentageDayChange: snapshot.storagePercentageDayChange,
                dayChangeTrend: snapshot.dayChangeTrend,
                storagePercentageWeekChange: snapshot.storagePercentageWeekChange,
                weekChangeTrend: snapshot.weekChangeTrend,
                message: newMessage,
                isNetworkError: snapshot.isNetworkError,
                isAllDataInvalid: snapshot.isAllDataInvalid,
                lastUpdatedAt: snapshot.lastUpdatedAt
            )
            guard let encoded = try? JSONEncoder().encode(snapshot) else { continue }
            set(encoded, forKey: key)
        }
    }

    /// ブリッジ共有領域から、リアルタイム観測データ (Real-time observation data) 関連のスナップショットおよび取得履歴データを消去します。
    internal func clearRealtimeData() {
        [
            WidgetDefaultsKey.appSnapshot,
            WidgetDefaultsKey.snapshotV1,
            WidgetDefaultsKey.rawDatBridgeV1,
            WidgetDefaultsKey.appLastFetchAt,
            WidgetDefaultsKey.widgetLastFetchAt
        ].forEach(removeValue(forKey:))
    }

    /// 生のDATファイルデータと関連情報をブリッジキャッシュに保存します。
    /// - Parameters:
    ///   - rawBytes: 生のバイナリデータ。
    ///   - rawDatFileName: DATファイル名。
    ///   - config: 該当するダム設定。
    ///   - nextUpdateAt: 次回更新予定時刻（`X-TCS-Next-Update-At` ヘッダー由来。存在しない場合は nil）。
    internal func saveRawDatBridge(rawBytes: Data, rawDatFileName: String?, config: DamConfig, nextUpdateAt: Date? = nil) {
        let bridge = DamCoreRawDatBridge(
            stationId: config.id,
            dataUrl: config.dataUrl,
            fetchedAt: Date(),
            nextUpdateAt: nextUpdateAt,
            rawBytes: rawBytes,
            rawDatFileName: rawDatFileName
        )
        guard let encoded = try? JSONEncoder().encode(bridge) else { return }
        set(encoded, forKey: WidgetDefaultsKey.rawDatBridgeV1)
    }

    /// 指定されたダム設定に対応する、キャッシュされた生のDATブリッジ情報を取得します。
    ///
    /// `dataUrl` は、リアルタイムデータソース設定に応じてウィジェット側が MLIT 直接取得の URL
    /// （`config.dataUrl`）と sudmonitor 中継の `.dat` URL のいずれかで書き込むため、どちらか一方が一致していれば受け入れます。
    /// - Parameter config: 該当するダム設定。
    /// - Returns: キャッシュされた `DamCoreRawDatBridge`。存在しない、または不一致の場合は `nil`。
    internal func rawDatBridge(for config: DamConfig) -> DamCoreRawDatBridge? {
        let acceptedDataUrls: Set<String> = [
            config.dataUrl,
            RealtimeDataSource.sudmonitorLatestDatURL(damId: config.id)
        ]
        if let data = data(forKey: WidgetDefaultsKey.rawDatBridgeV1),
           let bridge = try? JSONDecoder().decode(DamCoreRawDatBridge.self, from: data),
           bridge.version == DamCoreRawDatBridge.currentVersion,
           bridge.stationId == config.id,
           acceptedDataUrls.contains(bridge.dataUrl) {
            return bridge
        }
        return nil
    }

    /// ウィジェットセンターに対して、すべてのウィジェットのタイムラインを再ロードするようシグナルを送信します。
    internal func reloadTimeline() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// スナップショットをブリッジの保存領域に書き込みます。
    private func save(snapshot: DamCoreWidgetSnapshot) {
        guard let encoded = try? JSONEncoder().encode(snapshot) else { return }
        set(encoded, forKey: WidgetDefaultsKey.appSnapshot)
        set(encoded, forKey: WidgetDefaultsKey.snapshotV1)
    }
}

