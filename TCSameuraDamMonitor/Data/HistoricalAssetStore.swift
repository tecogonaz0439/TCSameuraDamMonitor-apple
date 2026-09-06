// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// アプリにバンドルされている過去データアセットの管理およびロードを担う構造体。
internal struct HistoricalAssetStore: Sendable {
    /// データ解析用パーサー。
    internal let parser = MlitDamParser()
    /// アセットのインデックスエントリー一覧。
    private let entries: [HistoricalDatFileEntry]
    /// 該当アセットのバイナリデータをロードするためのクロージャ。
    private let dataLoader: @Sendable (HistoricalDatFileEntry) throws -> Data?

    /// アセットストアを初期化します。
    /// - Parameters:
    ///   - entries: アセットエントリーのリスト。デフォルト値は `HistoricalDatFileTable.entries` です。
    ///   - dataLoader: データロード用クロージャ。指定がない場合はデフォルトのバンドルリソースローダーが使用されます。
    internal init(
        entries: [HistoricalDatFileEntry] = HistoricalDatFileTable.entries,
        dataLoader: (@Sendable (HistoricalDatFileEntry) throws -> Data?)? = nil
    ) {
        self.entries = entries
        self.dataLoader = dataLoader ?? { entry in
            let fileName = URL(fileURLWithPath: entry.filePath).lastPathComponent
            guard let url = Bundle.main.url(forResource: fileName, withExtension: nil, subdirectory: "Resources/history")
                ?? Bundle.main.url(forResource: fileName, withExtension: nil) else {
                return nil
            }
            return try Data(contentsOf: url)
        }
    }

    /// 指定されたダムの特定期間の過去データ検索 (Historical data search) について、ローカルアセットでカバー（補完）可能かどうかを判定します。
    /// - Parameters:
    ///   - stationId: 観測所ID。
    ///   - startDate: 開始日 (yyyyMMdd)。
    ///   - endDate: 終了日 (yyyyMMdd)。
    /// - Returns: ローカルアセットで完全にカバー可能な場合は `true`、それ以外は `false`。
    internal func canCover(stationId: String, startDate: String, endDate: String) -> Bool {
        guard let requiredStart = TimeFormatters.jstDay.date(from: startDate),
              let requiredEnd = TimeFormatters.jstDay.date(from: endDate) else {
            return false
        }
        let intervals = entries
            .filter { $0.stationId == stationId }
            .compactMap { entry -> (Date, Date)? in
                guard let start = TimeFormatters.jstDay.date(from: String(entry.startDatetime.prefix(8))),
                      let end = TimeFormatters.jstDay.date(from: String(entry.endDatetime.prefix(8))) else {
                    return nil
                }
                return (start, end)
            }
            .filter { $0.0 <= requiredEnd && $0.1 >= requiredStart }
            .sorted { $0.0 < $1.0 }
        guard !intervals.isEmpty else { return false }

        var coveredUntil = Calendar.jst.date(byAdding: .day, value: -1, to: requiredStart) ?? requiredStart
        for interval in intervals {
            let nextDay = Calendar.jst.date(byAdding: .day, value: 1, to: coveredUntil) ?? coveredUntil
            if interval.0 > nextDay {
                return false
            }
            if interval.1 > coveredUntil {
                coveredUntil = interval.1
            }
        }
        return coveredUntil >= requiredEnd
    }

    /// ローカルアセットから指定されたダムおよび期間に対応する過去データ検索 (Historical data search) データをロードして結合します。
    /// - Parameters:
    ///   - damConfig: ダム構成設定。
    ///   - startDate: 開始日 (yyyyMMdd)。
    ///   - endDate: 終了日 (yyyyMMdd)。
    /// - Returns: 検索結果メタデータと、履歴詳細データの配列のタプル。
    /// - Throws: `AppError` 該当データが存在しないか、ロードに失敗した場合のエラー。
    internal func load(damConfig: DamConfig, startDate: String, endDate: String) throws -> (HistoricalSearchMeta, [DamHistoricalData]) {
        guard let requiredStart = TimeFormatters.jstDay.date(from: startDate),
              let requiredEnd = TimeFormatters.jstDay.date(from: endDate) else {
            throw AppError.noHistoricalData
        }
        let entries = self.entries
            .filter { $0.stationId == damConfig.id }
            .filter {
                guard let start = TimeFormatters.jstDay.date(from: String($0.startDatetime.prefix(8))),
                      let end = TimeFormatters.jstDay.date(from: String($0.endDatetime.prefix(8))) else {
                    return false
                }
                return start <= requiredEnd && end >= requiredStart
            }
            .sorted { $0.startDatetime < $1.startDatetime }

        var mergedMeta: HistoricalSearchMeta?
        var mergedRows: [DamHistoricalData] = []

        for entry in entries {
            guard let data = try dataLoader(entry) else { continue }
            let (meta, rows) = try parser.parseHistoricalDat(data, damConfigId: damConfig.id, startDate: startDate, endDate: endDate)
            if mergedMeta == nil {
                mergedMeta = meta
            }
            mergedRows += rows.filter { row in
                let datePart = String(row.time.split(separator: " ").first ?? "")
                guard let date = looseDayDate(datePart) else { return false }
                return date >= requiredStart && date <= requiredEnd
            }
        }

        var unique: [String: DamHistoricalData] = [:]
        for row in mergedRows {
            unique[row.time] = row
        }
        let sortedRows = unique.values.sorted {
            TimeFormatters.millis(fromDamTime: $0.time) < TimeFormatters.millis(fromDamTime: $1.time)
        }
        guard let meta = mergedMeta, !sortedRows.isEmpty else {
            throw AppError.noHistoricalData
        }
        let percentages = sortedRows.compactMap(\.storagePercentage)
        let finalMeta = HistoricalSearchMeta(
            id: meta.id,
            observationStationId: meta.observationStationId,
            observationStationName: meta.observationStationName,
            riverSystemName: meta.riverSystemName,
            riverName: meta.riverName,
            damConfigId: meta.damConfigId,
            searchBgnDate: meta.searchBgnDate,
            searchEndDate: meta.searchEndDate,
            fetchedAt: meta.fetchedAt,
            sortOrder: 0,
            isPinned: false,
            dataStartTimeStr: sortedRows.first?.time,
            dataEndTimeStr: sortedRows.last?.time,
            dataStartStoragePct: sortedRows.first?.storagePercentage,
            dataEndStoragePct: sortedRows.last?.storagePercentage,
            dataMinStoragePct: percentages.min(),
            dataMaxStoragePct: percentages.max()
        )
        return (finalMeta, sortedRows)
    }

    /// バンドルアセットの断片(エントリ情報と読み込んだバイナリデータ)を保持する構造体。
    internal struct HistoricalAssetFragment: Sendable {
        /// 元のアセットエントリ。
        internal let entry: HistoricalDatFileEntry
        /// 読み込んだバイナリデータ。
        internal let bytes: Data
    }

    /// 要求期間と交差するアセットエントリの断片を読み込みます。
    ///
    /// 1 つでも読み込みに失敗した場合は `AppError.noHistoricalData` をスローします
    /// (Android 版の「バンドルフラグメント読込失敗 → 即 MLIT 委譲」に対応)。
    /// - Parameters:
    ///   - stationId: 観測所ID。
    ///   - startDate: 開始日 (yyyyMMdd)。
    ///   - endDate: 終了日 (yyyyMMdd)。
    /// - Returns: 読み込みに成功した断片のリスト(開始日時の昇順)。
    /// - Throws: `AppError.noHistoricalData` 期間のパース失敗、または断片の読み込み失敗。
    internal func loadCoveringFragments(stationId: String, startDate: String, endDate: String) throws -> [HistoricalAssetFragment] {
        guard let requiredStart = TimeFormatters.jstDay.date(from: startDate),
              let requiredEnd = TimeFormatters.jstDay.date(from: endDate) else {
            throw AppError.noHistoricalData
        }
        let entries = self.entries
            .filter { $0.stationId == stationId }
            .filter {
                guard let start = TimeFormatters.jstDay.date(from: String($0.startDatetime.prefix(8))),
                      let end = TimeFormatters.jstDay.date(from: String($0.endDatetime.prefix(8))) else {
                    return false
                }
                return start <= requiredEnd && end >= requiredStart
            }
            .sorted { $0.startDatetime < $1.startDatetime }
        return try entries.map { entry in
            guard let bytes = try dataLoader(entry) else { throw AppError.noHistoricalData }
            return HistoricalAssetFragment(entry: entry, bytes: bytes)
        }
    }

    /// 要求期間と交差するアセットエントリを日単位のカバー区間に変換して返します。
    ///
    /// 各エントリは「開始日 00:00 JST から 終了日 + 1 日 00:00 JST」の排他境界
    /// `DateInterval` へ変換し、要求期間にクリップしたうえで重複・隣接をマージします。
    /// - Parameters:
    ///   - stationId: 観測所ID。
    ///   - startDate: 開始日 (yyyyMMdd)。
    ///   - endDate: 終了日 (yyyyMMdd)。
    /// - Returns: カバー区間のリスト(開始日時昇順)。期間をパースできない場合は `[]`。
    internal func coverageIntervals(stationId: String, startDate: String, endDate: String) -> [DateInterval] {
        guard let requiredStart = TimeFormatters.jstDay.date(from: startDate),
              let requiredEnd = TimeFormatters.jstDay.date(from: endDate),
              let requiredEndExclusive = Calendar.jst.date(byAdding: .day, value: 1, to: requiredEnd) else {
            return []
        }
        let intervals = entries
            .filter { $0.stationId == stationId }
            .compactMap { entry -> DateInterval? in
                guard let start = TimeFormatters.jstDay.date(from: String(entry.startDatetime.prefix(8))),
                      let end = TimeFormatters.jstDay.date(from: String(entry.endDatetime.prefix(8))),
                      let endExclusive = Calendar.jst.date(byAdding: .day, value: 1, to: end) else {
                    return nil
                }
                return DateInterval(start: start, end: endExclusive)
            }
            .filter { $0.start <= requiredEnd && $0.end > requiredStart }
            .sorted { $0.start < $1.start }
        let clipped = intervals.compactMap { interval -> DateInterval? in
            let start = max(interval.start, requiredStart)
            let end = min(interval.end, requiredEndExclusive)
            guard start < end else { return nil }
            return DateInterval(start: start, end: end)
        }
        return HistoricalSearchService.mergedIntervals(clipped)
    }

    /// スラッシュ区切り形式の日付文字列を日付オブジェクトに変換します。
    private func looseDayDate(_ text: String) -> Date? {
        let parts = text.split(separator: "/").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.calendar = .jst
        components.timeZone = TimeZone(identifier: "Asia/Tokyo")
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        return components.date
    }
}

