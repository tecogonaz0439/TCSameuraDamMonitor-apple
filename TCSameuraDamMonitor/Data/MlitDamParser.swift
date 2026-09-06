// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation
import TCSameuraDamCore

/// 国土交通省（MLIT）のデータ解析中に発生するエラーを表す列挙型。
internal enum MlitParserError: LocalizedError, Equatable, Sendable {
    /// DATファイルのURLが見つからなかった場合のエラー。
    case datURLNotFound
    /// DATファイル内に有効なデータ行が見つからなかった場合のエラー。
    case noDataRows
    /// サポートされていないエンコーディング形式であるため、テキストの復号に失敗した場合のエラー。
    case unsupportedEncoding
    /// 履歴データ行が見つからなかった場合のエラー。
    case noHistoricalRows

    /// エラーの説明。
    internal var errorDescription: String? {
        switch self {
        case .datURLNotFound: return "dat file URL was not found."
        case .noDataRows: return "No data rows were found in the dat file."
        case .unsupportedEncoding: return "The file encoding could not be decoded."
        case .noHistoricalRows: return "No historical data rows were found."
        }
    }
}

/// 国土交通省（MLIT）が提供するHTMLやDATファイルからダム諸量データを抽出・解析する構造体。
internal struct MlitDamParser: Sendable {
    /// 雨量データの列インデックス。
    nonisolated private static let rainfallColumn = 2
    /// 貯水量 (Storage volume) データの列インデックス。
    nonisolated private static let storageVolumeColumn = 4
    /// 流入量 (Inflow) データの列インデックス。
    nonisolated private static let inflowColumn = 6
    /// 放流量 (Outflow) データの列インデックス。
    nonisolated private static let outflowColumn = 8
    /// 貯水率 (Storage rate) データの列インデックス。
    nonisolated private static let storagePercentageColumn = 10
    /// 1時間あたりの行数（10分ごとのデータ）。
    nonisolated private static let rowsPerHour = 6
    /// 1日あたりの行数（10分ごとのデータ）。
    nonisolated private static let rowsPerDay = 144
    /// トレンド（変化方向）判定の微小閾値。
    nonisolated private static let trendEpsilon: Float = 0.0001

    /// パーサーを初期化します。
    internal nonisolated init() {}

    /// ダム諸量トップHTMLデータを解析し、DATファイルのURL文字列を抽出します。
    /// - Parameter data: HTMLページのバイナリデータ。
    /// - Returns: DATファイルの絶対URL文字列。
    /// - Throws: `MlitParserError` パースエラー。
    internal nonisolated func parseHTMLForDatURL(_ data: Data) throws(MlitParserError) -> String {
        guard let html = String(data: data, encoding: DamCoreTextDecoder.eucJP) else {
            throw MlitParserError.unsupportedEncoding
        }
        guard let regex = try? NSRegularExpression(pattern: #"href="([^"]+\.dat)""#) else {
            throw MlitParserError.datURLNotFound
        }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              let hrefRange = Range(match.range(at: 1), in: html) else {
            throw MlitParserError.datURLNotFound
        }
        let href = String(html[hrefRange])
        let resolved = MlitURLPolicy.resolvedDatURL(from: href)
        guard let resolved, isAllowedDatURL(resolved) else {
            throw MlitParserError.datURLNotFound
        }
        return resolved.absoluteString
    }

    /// リアルタイム観測データ (Real-time observation data) のDATファイルを解析し、`DamData` を生成します。
    ///
    /// 貯水率メッセージ分類用の `storageVolumeForMessage` には、貯水量列の欠測前の最新正常値を設定します
    /// （最新行が正常なら `storageVolume` と同じ値。全属性欠測の `isClosed` 時は nil）。
    /// - Parameters:
    ///   - data: DATファイルのバイナリデータ。
    ///   - stationId: 観測所IDのデフォルト値。
    ///   - stationName: 観測所名のデフォルト値。
    ///   - debugDataEndDate: デバッグ用に指定されたデータ終了日時。指定がない場合は全データ。
    /// - Returns: 解析・構築された `DamData` オブジェクト。
    /// - Throws: `MlitParserError` パースエラー。
    internal nonisolated func parseRealtimeDat(
        _ data: Data,
        stationId: String,
        stationName: String,
        debugDataEndDate: Date? = nil
    ) throws(MlitParserError) -> DamData {
        let rows = try decodedRows(from: data)
        var riverSystem = ""
        var riverName = ""
        var parsedStationName = stationName
        var parsedStationId = stationId

        for line in rows {
            let parts = line.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 2 else { continue }
            switch parts[0] {
            case "水系名": riverSystem = parts[1]
            case "河川名": riverName = parts[1]
            case "観測所名": parsedStationName = parts[1]
            case "観測所記号": parsedStationId = parts[1]
            default: break
            }
        }

        let dataRows = rows
            .filter { !$0.hasPrefix("#") && $0.split(separator: ",", omittingEmptySubsequences: false).count > 5 }
            .map { $0.split(separator: ",", omittingEmptySubsequences: false).map(String.init) }
            .filter { row in
                guard let debugDataEndDate else { return true }
                guard let rowDate = realtimeRowDate(row) else { return true }
                return rowDate <= debugDataEndDate
            }
        guard !dataRows.isEmpty else { throw MlitParserError.noDataRows }

        let reversed = dataRows.reversed()
        let latestRow = reversed[reversed.startIndex]
        let updatedAt = "\(latestRow[safe: 0] ?? "") \(latestRow[safe: 1] ?? "")"
        let latestHour = normalizedRowHourString(latestRow)
        let isClosed = !isAttributeNormal(latestRow, Self.rainfallColumn)
            && !isAttributeNormal(latestRow, Self.storageVolumeColumn)
            && !isAttributeNormal(latestRow, Self.inflowColumn)
            && !isAttributeNormal(latestRow, Self.outflowColumn)
            && !isAttributeNormal(latestRow, Self.storagePercentageColumn)

        func latestInfo(_ column: Int) -> (Float?, Int?) {
            guard !isClosed, let row = reversed.first else { return (nil, nil) }
            guard isAttributeNormal(row, column) else { return (nil, nil) }
            return (floatValue(row, column), 0)
        }

        func storagePercentageInfo() -> (Float?, Int?) {
            guard !isClosed else { return (nil, nil) }
            for (index, row) in reversed.enumerated() where isAttributeNormal(row, Self.storagePercentageColumn) {
                let rowHour = normalizedRowHourString(row)
                guard rowHour == latestHour else { continue }
                if let value = floatValue(row, Self.storagePercentageColumn) {
                    return (value, index)
                }
            }
            return (nil, nil)
        }

        /// 貯水率メッセージ分類用に、欠測前の最新正常貯水量 (Storage volume) を新しい順で遡って返します。
        ///
        /// `isClosed`（最新行が全属性欠測）の場合は nil を返します。
        /// 最新行が正常なら従来の `latestInfo`（`storageVolume`）と同じ値になります。
        func storageVolumeForMessageInfo() -> Float? {
            guard !isClosed else { return nil }
            for row in reversed where isAttributeNormal(row, Self.storageVolumeColumn) {
                if let value = floatValue(row, Self.storageVolumeColumn) {
                    return value
                }
            }
            return nil
        }

        let rainfall = latestInfo(Self.rainfallColumn)
        let storageVolume = latestInfo(Self.storageVolumeColumn)
        let inflow = latestInfo(Self.inflowColumn)
        let outflow = latestInfo(Self.outflowColumn)
        let storagePercentage = storagePercentageInfo()
        let dayChange = change(Self.storagePercentageColumn, rows: Array(reversed), latestValidRowIndex: storagePercentage.1, offset: Self.rowsPerDay)
        let weekChange = change(Self.storagePercentageColumn, rows: Array(reversed), latestValidRowIndex: storagePercentage.1, offset: nil)

        let historical = dataRows.map {
            DamHistoricalData(
                time: "\($0[safe: 0] ?? "") \($0[safe: 1] ?? "")",
                catchmentAverageRainfall: isAttributeNormal($0, Self.rainfallColumn) ? floatValue($0, Self.rainfallColumn) : nil,
                storagePercentage: isAttributeNormal($0, Self.storagePercentageColumn) ? floatValue($0, Self.storagePercentageColumn) : nil,
                storageVolume: isAttributeNormal($0, Self.storageVolumeColumn) ? floatValue($0, Self.storageVolumeColumn) : nil,
                inflow: isAttributeNormal($0, Self.inflowColumn) ? floatValue($0, Self.inflowColumn) : nil,
                outflow: isAttributeNormal($0, Self.outflowColumn) ? floatValue($0, Self.outflowColumn) : nil
            )
        }

        return DamData(
            observationStationId: parsedStationId,
            observationStationName: parsedStationName,
            riverSystemName: riverSystem,
            riverName: riverName,
            updatedAt: updatedAt,
            catchmentAverageRainfall: rainfall.0,
            storageVolume: storageVolume.0,
            storageVolumeForMessage: storageVolumeForMessageInfo(),
            storageVolumeTrend: trend(Self.storageVolumeColumn, rows: Array(reversed), latestValidRowIndex: storageVolume.1),
            inflow: inflow.0,
            inflowTrend: trend(Self.inflowColumn, rows: Array(reversed), latestValidRowIndex: inflow.1, offsetRows: Self.rowsPerHour),
            outflow: outflow.0,
            outflowTrend: trend(Self.outflowColumn, rows: Array(reversed), latestValidRowIndex: outflow.1, offsetRows: Self.rowsPerHour),
            storagePercentage: storagePercentage.0,
            storagePercentageTrend: trend(Self.storagePercentageColumn, rows: Array(reversed), latestValidRowIndex: storagePercentage.1, offsetRows: Self.rowsPerHour),
            storagePercentageTime: timestamp(Array(reversed), storagePercentage.1),
            storagePercentageDayChange: dayChange.0,
            storagePercentageDayChangeTrend: dayChange.1,
            storagePercentageWeekChange: weekChange.0,
            storagePercentageWeekChangeTrend: weekChange.1,
            historicalData: historical
        )
    }

    /// DATファイルデータを解析し、記録されているすべての一意な日付リストを返します。
    /// - Parameter data: DATファイルのバイナリデータ。
    /// - Returns: DATファイル内のデータが存在する日付リスト。
    /// - Throws: `MlitParserError` パースエラー。
    internal nonisolated func realtimeDataTimes(_ data: Data) throws(MlitParserError) -> [Date] {
        let rows = try decodedRows(from: data)
        let dates = rows
            .filter { !$0.hasPrefix("#") && $0.split(separator: ",", omittingEmptySubsequences: false).count > 5 }
            .map { $0.split(separator: ",", omittingEmptySubsequences: false).map(String.init) }
            .compactMap(realtimeRowDate)
        return Array(Set(dates)).sorted()
    }

    /// 過去データ検索 (Historical data search) 用のDATファイルをパースします。
    /// - Parameters:
    ///   - data: DATファイルのバイナリデータ。
    ///   - damConfigId: 関連付けられたダム構成設定ID。
    ///   - startDate: 検索開始日。
    ///   - endDate: 検索終了日。
    /// - Returns: 検索結果メタデータと、履歴詳細データの配列のタプル。
    /// - Throws: `MlitParserError` パースエラー。
    internal nonisolated func parseHistoricalDat(_ data: Data, damConfigId: String, startDate: String, endDate: String) throws(MlitParserError) -> (HistoricalSearchMeta, [DamHistoricalData]) {
        let rows = try decodedRows(from: data)
        var riverSystem = ""
        var riverName = ""
        var stationName = ""
        var stationId = ""

        for line in rows {
            let parts = line.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 2 else { continue }
            switch parts[0] {
            case "水系名": riverSystem = parts[1]
            case "河川名": riverName = parts[1]
            case "観測所名": stationName = parts[1]
            case "観測所記号": stationId = parts[1]
            default: break
            }
        }

        let dataRows = rows
            .filter { !$0.hasPrefix("#") && $0.split(separator: ",", omittingEmptySubsequences: false).count > Self.storagePercentageColumn }
            .map { $0.split(separator: ",", omittingEmptySubsequences: false).map(String.init) }
        let dataList = dataRows.map { row in
            DamHistoricalData(
                time: "\(row[safe: 0]?.trimmingCharacters(in: .whitespaces) ?? "") \(row[safe: 1]?.trimmingCharacters(in: .whitespaces) ?? "")",
                catchmentAverageRainfall: isAttributeNormal(row, Self.rainfallColumn) ? floatValue(row, Self.rainfallColumn) : nil,
                storagePercentage: isAttributeNormal(row, Self.storagePercentageColumn) ? floatValue(row, Self.storagePercentageColumn) : nil,
                storageVolume: isAttributeNormal(row, Self.storageVolumeColumn) ? floatValue(row, Self.storageVolumeColumn) : nil,
                inflow: isAttributeNormal(row, Self.inflowColumn) ? floatValue(row, Self.inflowColumn) : nil,
                outflow: isAttributeNormal(row, Self.outflowColumn) ? floatValue(row, Self.outflowColumn) : nil
            )
        }
        guard !dataList.isEmpty else { throw MlitParserError.noHistoricalRows }

        let percentages = dataList.compactMap(\.storagePercentage)
        let meta = HistoricalSearchMeta(
            id: UUID(),
            observationStationId: stationId,
            observationStationName: stationName,
            riverSystemName: riverSystem,
            riverName: riverName,
            damConfigId: damConfigId,
            searchBgnDate: startDate,
            searchEndDate: endDate,
            fetchedAt: Date(),
            sortOrder: 0,
            isPinned: false,
            dataStartTimeStr: dataList.first?.time,
            dataEndTimeStr: dataList.last?.time,
            dataStartStoragePct: dataList.first?.storagePercentage,
            dataEndStoragePct: dataList.last?.storagePercentage,
            dataMinStoragePct: percentages.min(),
            dataMaxStoragePct: percentages.max()
        )
        return (meta, dataList)
    }

    /// データファイルをデコードし、トリミングされた行の配列を返します。
    nonisolated private func decodedRows(from data: Data) throws(MlitParserError) -> [String] {
        let text = DamCoreTextDecoder.decodeMLITText(data)
        guard let text else { throw MlitParserError.unsupportedEncoding }
        return text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// 指定されたURLがDATファイル用の許可されたURLか判定します。
    nonisolated private func isAllowedDatURL(_ url: URL) -> Bool {
        MlitURLPolicy.isAllowedDatURL(url)
    }

    /// 指定された列の観測状態が正常（欠測や異常値ではない）であるか判定します。
    nonisolated private func isAttributeNormal(_ row: [String], _ dataColumn: Int) -> Bool {
        let attr = row[safe: dataColumn + 1] ?? ""
        return attr == " " || attr.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// 行情報から日時をパースします。
    nonisolated private func realtimeRowDate(_ row: [String]) -> Date? {
        let date = row[safe: 0]?.trimmingCharacters(in: .whitespaces) ?? ""
        let time = row[safe: 1]?.trimmingCharacters(in: .whitespaces) ?? ""
        return DamCoreDamTime.date(from: "\(date) \(time)")
    }

    /// 行情報から、トレンド比較用の一意な1時間単位のキー文字列を生成します。
    nonisolated private func normalizedRowHourString(_ row: [String]) -> String {
        let date = row[safe: 0]?.trimmingCharacters(in: .whitespaces) ?? ""
        let time = row[safe: 1]?.trimmingCharacters(in: .whitespaces) ?? ""
        return DamCoreDamTime.hourKey(date: date, time: time) ?? "\(date) \(time.prefix(2))"
    }

    /// 行のインデックス指定列の数値を `Float` として抽出します。
    nonisolated private func floatValue(_ row: [String], _ index: Int) -> Float? {
        guard let value = row[safe: index]?.trimmingCharacters(in: .whitespaces) else { return nil }
        return Float(value)
    }

    /// 前回の値と比較してトレンド（上昇・下降・横ばい）を判定します。
    nonisolated private func trend(_ column: Int, rows: [[String]], latestValidRowIndex: Int?, offsetRows: Int = 1) -> Trend {
        guard let latestValidRowIndex, let latestValue = floatValue(rows[latestValidRowIndex], column) else { return .unknown }
        let startIndex = latestValidRowIndex + offsetRows
        guard startIndex < rows.count else { return .unknown }
        for index in startIndex..<rows.count where isAttributeNormal(rows[index], column) {
            guard let previous = floatValue(rows[index], column) else { continue }
            if latestValue > previous { return .up }
            if latestValue < previous { return .down }
            return .flat
        }
        return .unknown
    }

    /// 指定した期間（オフセット）との比較を行い、変化量とトレンドを算出します。
    nonisolated private func change(_ column: Int, rows: [[String]], latestValidRowIndex: Int?, offset: Int?) -> (Float?, Trend) {
        guard let latestValidRowIndex, let latestValue = floatValue(rows[latestValidRowIndex], column) else { return (nil, .unknown) }
        let compareIndex: Int?
        if let offset {
            let target = latestValidRowIndex + offset
            if target >= rows.count {
                compareIndex = rows.indices.reversed().first { isAttributeNormal(rows[$0], column) && floatValue(rows[$0], column) != nil }
            } else {
                compareIndex = (target..<rows.count).first { isAttributeNormal(rows[$0], column) && floatValue(rows[$0], column) != nil }
            }
        } else {
            compareIndex = rows.indices.reversed().first { isAttributeNormal(rows[$0], column) && floatValue(rows[$0], column) != nil }
        }
        guard let compareIndex, compareIndex != latestValidRowIndex, let compareValue = floatValue(rows[compareIndex], column) else {
            return (nil, .unknown)
        }
        let diff = latestValue - compareValue
        let diffTrend: Trend
        if diff > Self.trendEpsilon {
            diffTrend = .up
        } else if diff < -Self.trendEpsilon {
            diffTrend = .down
        } else {
            diffTrend = .flat
        }
        return (diff, diffTrend)
    }

    /// 行インデックスから日時文字列を取得します。
    nonisolated private func timestamp(_ rows: [[String]], _ index: Int?) -> String? {
        guard let index, rows.indices.contains(index) else { return nil }
        return "\(rows[index][safe: 0] ?? "") \(rows[index][safe: 1] ?? "")"
    }
}

