// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation
import SwiftData

/// 最新のリアルタイム観測データ (Real-time observation data) の状態および生のDATファイルをキャッシュ保存するための SwiftData モデルクラス。
@Model
internal final class DamDataRecord {
    /// キャッシュの一意なキー。通常は `"latest"`。
    internal var key: String
    /// エンコードされた `DamData` のJSONバイナリ。
    internal var encodedData: Data
    /// 最後にフェッチした日時。
    internal var lastFetchTime: Date
    /// 最新取得時の生のDATファイルバイナリデータ。
    internal var rawDatBytes: Data?
    /// 最新取得時の生のDATファイルの名前。
    internal var rawDatFileName: String?
    /// 手動更新クールダウンの終了時刻(`X-TCS-Next-Update-At` 由来。欠落時・MLIT 直接時は `lastFetchTime` + 10 分)。
    internal var manualRefreshAvailableAt: Date?

    /// キャッシュレコードを初期化します。
    /// - Parameters:
    ///   - key: キャッシュのキー（デフォルトは `"latest"`）。
    ///   - encodedData: JSONエンコードされたデータ。
    ///   - lastFetchTime: 最終フェッチ日時。
    ///   - rawDatBytes: 生のDATバイナリ。
    ///   - rawDatFileName: 生のDATファイル名。
    ///   - manualRefreshAvailableAt: 手動更新クールダウンの終了時刻。
    internal init(key: String = "latest", encodedData: Data, lastFetchTime: Date, rawDatBytes: Data?, rawDatFileName: String? = nil, manualRefreshAvailableAt: Date? = nil) {
        self.key = key
        self.encodedData = encodedData
        self.lastFetchTime = lastFetchTime
        self.rawDatBytes = rawDatBytes
        self.rawDatFileName = rawDatFileName
        self.manualRefreshAvailableAt = manualRefreshAvailableAt
    }

    /// デコードされた `DamData` オブジェクトを取得します。
    @MainActor
    internal var damData: DamData? {
        try? JSONDecoder().decode(DamData.self, from: encodedData)
    }
}

/// 過去データ検索 (Historical data search) の結果メタデータをデータベースに永続化保存するための SwiftData モデルクラス。
@Model
internal final class HistoricalSearchMetaRecord {
    /// 検索結果の一意なUUID。
    internal var id: UUID
    /// 観測所ID。
    internal var observationStationId: String
    /// 観測所名。
    internal var observationStationName: String
    /// 水系名。
    internal var riverSystemName: String
    /// 河川名。
    internal var riverName: String
    /// ダム構成設定ID。
    internal var damConfigId: String
    /// 検索開始日 (yyyyMMdd)。
    internal var searchBgnDate: String
    /// 検索終了日 (yyyyMMdd)。
    internal var searchEndDate: String
    /// 検索（取得）の実行日時。
    internal var fetchedAt: Date
    /// 一覧表示時のソート順順序インデックス。
    internal var sortOrder: Int
    /// 検索履歴がピン留めされているかどうかのフラグ。
    internal var isPinned: Bool
    /// データ内に記録されている最古のデータ日時文字列。
    internal var dataStartTimeStr: String?
    /// データ内に記録されている最新のデータ日時文字列。
    internal var dataEndTimeStr: String?
    /// 開始時の貯水率 (Storage rate) の値。
    internal var dataStartStoragePct: Float?
    /// 終了時の貯水率 (Storage rate) の値。
    internal var dataEndStoragePct: Float?
    /// 期間中の最小貯水率 (Storage rate) の値。
    internal var dataMinStoragePct: Float?
    /// 期間中の最大貯水率 (Storage rate) の値。
    internal var dataMaxStoragePct: Float?

    /// 過去データ検索結果メタデータから永続化レコードを初期化します。
    /// - Parameter meta: 変換元の `HistoricalSearchMeta`。
    internal init(meta: HistoricalSearchMeta) {
        id = meta.id
        observationStationId = meta.observationStationId
        observationStationName = meta.observationStationName
        riverSystemName = meta.riverSystemName
        riverName = meta.riverName
        damConfigId = meta.damConfigId
        searchBgnDate = meta.searchBgnDate
        searchEndDate = meta.searchEndDate
        fetchedAt = meta.fetchedAt
        sortOrder = meta.sortOrder
        isPinned = meta.isPinned
        dataStartTimeStr = meta.dataStartTimeStr
        dataEndTimeStr = meta.dataEndTimeStr
        dataStartStoragePct = meta.dataStartStoragePct
        dataEndStoragePct = meta.dataEndStoragePct
        dataMinStoragePct = meta.dataMinStoragePct
        dataMaxStoragePct = meta.dataMaxStoragePct
    }

    /// メモリ上で動作する `HistoricalSearchMeta` ドメインモデルオブジェクトに変換します。
    internal var domain: HistoricalSearchMeta {
        HistoricalSearchMeta(
            id: id,
            observationStationId: observationStationId,
            observationStationName: observationStationName,
            riverSystemName: riverSystemName,
            riverName: riverName,
            damConfigId: damConfigId,
            searchBgnDate: searchBgnDate,
            searchEndDate: searchEndDate,
            fetchedAt: fetchedAt,
            sortOrder: sortOrder,
            isPinned: isPinned,
            dataStartTimeStr: dataStartTimeStr,
            dataEndTimeStr: dataEndTimeStr,
            dataStartStoragePct: dataStartStoragePct,
            dataEndStoragePct: dataEndStoragePct,
            dataMinStoragePct: dataMinStoragePct,
            dataMaxStoragePct: dataMaxStoragePct
        )
    }
}

/// 過去データ検索 (Historical data search) の結果に含まれる、各時間単位のダム詳細観測データを保存するための SwiftData モデルクラス。
@Model
internal final class HistoricalDamDataRecord {
    /// レコードの一意なID。
    internal var id: UUID
    /// 紐付け先となる `HistoricalSearchMetaRecord` のUUID。
    internal var searchMetaId: UUID
    /// 時刻のエポックミリ秒。グラフのソートおよび描画描画位置に用いられます。
    internal var timeMillis: Double
    /// 時刻の表示テキスト（ダム時間形式）。
    internal var time: String
    /// 流域平均雨量 (Basin average rainfall) の値。
    internal var catchmentAverageRainfall: Float?
    /// 貯水率 (Storage rate) の値。
    internal var storagePercentage: Float?
    /// 貯水量 (Storage volume) の値。
    internal var storageVolume: Float?
    /// 流入量 (Inflow) の値。
    internal var inflow: Float?
    /// 放流量 (Outflow) の値。
    internal var outflow: Float?

    /// 過去詳細レコードを初期化します。
    /// - Parameters:
    ///   - searchMetaId: メタデータID。
    ///   - data: 履歴詳細データ。
    ///   - timeMillis: ミリ秒換算された日時。
    internal init(searchMetaId: UUID, data: DamHistoricalData, timeMillis: Double) {
        id = UUID()
        self.searchMetaId = searchMetaId
        self.timeMillis = timeMillis
        time = data.time
        catchmentAverageRainfall = data.catchmentAverageRainfall
        storagePercentage = data.storagePercentage
        storageVolume = data.storageVolume
        inflow = data.inflow
        outflow = data.outflow
    }

    /// メモリ上で動作する `DamHistoricalData` ドメインモデルオブジェクトに変換します。
    internal var domain: DamHistoricalData {
        DamHistoricalData(
            time: time,
            catchmentAverageRainfall: catchmentAverageRainfall,
            storagePercentage: storagePercentage,
            storageVolume: storageVolume,
            inflow: inflow,
            outflow: outflow
        )
    }
}

/// sudmonitor の日次過去データ(latest.dat)をダムごとに1件保存するための SwiftData モデルクラス。
@Model
internal final class SudmonitorHistoryRecord {
    /// 対象ダムの観測所ID(ダムごとに1件。D3: ダム変更時は上書き)。
    internal var damId: String
    /// データ期間の開始日 (yyyyMMdd、JST 日単位。`X-TCS-History-Since` 由来)。
    internal var periodStartDay: String
    /// データ期間の終了日 (yyyyMMdd、JST 日単位。`X-TCS-History-Until` 由来)。
    internal var periodEndDay: String
    /// 最後に取得・保存した日時。
    internal var fetchedAt: Date
    /// 次回更新予定時刻(`X-TCS-Next-Update-At` 由来。欠落時は「翌日 00:13 JST」のフォールバックを保存)。
    internal var nextUpdateAt: Date?
    /// 取得したDATファイルの生のバイナリデータ(ローカルカバレッジ提供用、D8)。
    internal var rawDatBytes: Data
    /// 取得したDATファイルの名前(既定は `"latest.dat"`)。
    internal var rawDatFileName: String?

    /// 日次過去データレコードを初期化します。
    /// - Parameters:
    ///   - damId: 対象ダムの観測所ID。
    ///   - periodStartDay: データ期間の開始日 (yyyyMMdd)。
    ///   - periodEndDay: データ期間の終了日 (yyyyMMdd)。
    ///   - fetchedAt: 取得日時。
    ///   - nextUpdateAt: 次回更新予定時刻。
    ///   - rawDatBytes: 生のDATバイナリ。
    ///   - rawDatFileName: 生のDATファイル名。
    internal init(
        damId: String,
        periodStartDay: String,
        periodEndDay: String,
        fetchedAt: Date,
        nextUpdateAt: Date?,
        rawDatBytes: Data,
        rawDatFileName: String? = "latest.dat"
    ) {
        self.damId = damId
        self.periodStartDay = periodStartDay
        self.periodEndDay = periodEndDay
        self.fetchedAt = fetchedAt
        self.nextUpdateAt = nextUpdateAt
        self.rawDatBytes = rawDatBytes
        self.rawDatFileName = rawDatFileName
    }
}

/// アプリの動作およびデバッグ用のシステムログを保存するための SwiftData モデルクラス。
@Model
internal final class DebugLogRecord {
    /// ログの一意なID。
    internal var id: UUID
    /// ログの発生日時。
    internal var timestamp: Date
    /// ログの簡略説明メッセージ。
    internal var message: String
    /// ログの詳細情報。
    internal var details: String

    /// ログレコードを初期化します。
    /// - Parameter entry: デバッグログエントリー。
    internal init(entry: DebugLogEntry) {
        id = entry.id
        timestamp = entry.timestamp
        message = entry.message
        details = entry.details
    }

    /// メモリ上で動作する `DebugLogEntry` ドメインモデルオブジェクトに変換します。
    internal var domain: DebugLogEntry {
        DebugLogEntry(id: id, timestamp: timestamp, message: message, details: details)
    }
}

