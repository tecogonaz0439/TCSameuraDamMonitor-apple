// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// 1か月分のDATファイルを軽量なprojectionへ変換した結果を表す構造体。
nonisolated struct HistoricalComparisonMonthProjection: Sendable, Hashable {
    /// 元のファイルパス。
    let filePath: String
    /// データの年。
    let year: Int
    /// データの月。
    let month: Int
    /// 毎時00分の観測点の一覧(日付昇順、日付dedup済み)。
    let points: [Point]

    /// 1時間単位の観測点を表す構造体。
    nonisolated struct Point: Sendable, Hashable {
        /// 正規化済みJSTの日時(24:00は翌日00:00へ正規化)。
        let date: Date
        /// 貯水率 (%)。nilは異常値・欠測。
        let storagePercentage: Float?
        /// 貯水量 (万立方メートル)。nilは異常値・欠測。
        let storageVolume: Float?
        /// 元の観測日時文字列。
        let rawTime: String
    }
}

/// 過去比較グラフ用に月次DATアセットを読み込み、軽量なprojectionを返すストア。
nonisolated struct HistoricalComparisonAssetStore: Sendable {
    /// アセットのインデックスエントリー一覧。
    let entries: [HistoricalDatFileEntry]
    /// 該当アセットのバイナリデータをロードするためのクロージャ。
    private let dataLoader: @Sendable (HistoricalDatFileEntry) throws -> Data?
    /// 月次projectionのキャッシュ。
    private let cache: HistoricalComparisonCache
    /// データ解析用パーサー。
    private let parser = MlitDamParser()

    /// アセットストアを初期化します。
    /// - Parameters:
    ///   - entries: アセットエントリーのリスト。デフォルト値は `HistoricalDatFileTable.entries` です。
    ///   - dataLoader: データロード用クロージャ。指定がない場合はデフォルトのバンドルリソースローダーが使用されます。
    ///   - cache: 月次projectionのキャッシュ。
    init(entries: [HistoricalDatFileEntry] = HistoricalDatFileTable.entries,
         dataLoader: (@Sendable (HistoricalDatFileEntry) throws -> Data?)? = nil,
         cache: HistoricalComparisonCache = HistoricalComparisonCache()) {
        self.entries = entries
        self.dataLoader = dataLoader ?? { entry in
            let fileName = URL(fileURLWithPath: entry.filePath).lastPathComponent
            guard let url = Bundle.main.url(forResource: fileName, withExtension: nil, subdirectory: "Resources/history")
                ?? Bundle.main.url(forResource: fileName, withExtension: nil) else {
                return nil
            }
            return try Data(contentsOf: url)
        }
        self.cache = cache
    }

    /// 指定された月次エントリのprojectionを同時読込数4で読み込みます。
    ///
    /// 1件でも読み込みに失敗した場合は全体として失敗します(黙って部分成功しません)。
    /// - Parameter entries: 月次エントリの一覧。
    /// - Returns: projectionの一覧(入力と同じ順序)。
    /// - Throws: `HistoricalComparisonServiceError.assetLoadFailed` assetの欠落・parse失敗。
    func projections(for entries: [HistoricalDatFileEntry]) async throws -> [HistoricalComparisonMonthProjection] {
        guard !entries.isEmpty else { return [] }
        var results: [HistoricalComparisonMonthProjection] = []
        results.reserveCapacity(entries.count)
        let chunkSize = 4
        var offset = 0
        while offset < entries.count {
            try Task.checkCancellation()
            let chunk = Array(entries[offset..<min(offset + chunkSize, entries.count)])
            offset += chunkSize
            let chunkResults = try await withThrowingTaskGroup(
                of: (Int, HistoricalComparisonMonthProjection).self
            ) { group in
                for (index, entry) in chunk.enumerated() {
                    group.addTask {
                        let projection = try await self.cache.projection(for: entry) { entry in
                            try await self.loadProjection(for: entry)
                        }
                        return (index, projection)
                    }
                }
                var ordered: [(Int, HistoricalComparisonMonthProjection)] = []
                ordered.reserveCapacity(chunk.count)
                for try await pair in group {
                    ordered.append(pair)
                }
                return ordered
            }
            results.append(contentsOf: chunkResults.sorted { $0.0 < $1.0 }.map(\.1))
        }
        try Task.checkCancellation()
        return results
    }

    /// 単一の月次エントリを読み込み、軽量なprojectionへ変換します。
    ///
    /// 既存 `MlitDamParser.parseHistoricalDat` を再利用し、毎時00分の行だけを日付昇順・初出優先で採用します。
    /// - Parameter entry: 月次エントリ。
    /// - Returns: 月次projection。
    /// - Throws: `HistoricalComparisonServiceError.assetLoadFailed` assetの欠落・parse失敗。
    private func loadProjection(for entry: HistoricalDatFileEntry) async throws -> HistoricalComparisonMonthProjection {
        guard let data = try dataLoader(entry) else {
            throw HistoricalComparisonServiceError.assetLoadFailed(entry.filePath)
        }
        let startDate = String(entry.startDatetime.prefix(8))
        let endDate = String(entry.endDatetime.prefix(8))
        let rows: [DamHistoricalData]
        do {
            rows = try parser.parseHistoricalDat(data, damConfigId: entry.stationId,
                                                 startDate: startDate, endDate: endDate).1
        } catch {
            throw HistoricalComparisonServiceError.assetLoadFailed(entry.filePath)
        }
        var unique: [Date: HistoricalComparisonMonthProjection.Point] = [:]
        for row in rows {
            guard let millis = TimeFormatters.millisIfValid(fromDamTime: row.time) else { continue }
            let date = Date(timeIntervalSince1970: millis / 1000)
            guard Calendar.jst.component(.minute, from: date) == 0 else { continue }
            if unique[date] == nil {
                unique[date] = HistoricalComparisonMonthProjection.Point(
                    date: date,
                    storagePercentage: row.storagePercentage,
                    storageVolume: row.storageVolume,
                    rawTime: row.time
                )
            }
        }
        let points = unique.values.sorted { $0.date < $1.date }
        let year = Int(entry.startDatetime.prefix(4)) ?? 0
        let month = Int(entry.startDatetime.prefix(6).suffix(2)) ?? 0
        return HistoricalComparisonMonthProjection(filePath: entry.filePath, year: year, month: month, points: points)
    }
}
