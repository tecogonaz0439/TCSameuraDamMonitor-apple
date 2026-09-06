// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// 国土交通省 (MLIT) のダム諸量データを解析するためのパーサー構造体。
public struct DamCoreWidgetParser: Sendable {
    /// 既定のイニシャライザ。
    public nonisolated init() {}

    /// 解析されたスナップショット用の各フィールドデータを保持する構造体。
    public struct SnapshotFields: Sendable, Equatable {
        /// データ更新日時の文字列。
        public let updatedAt: String
        /// 観測日時の文字列（省略可能）。
        public let observedAt: String?
        /// 貯水率 (Storage rate)。
        public let storagePercentage: Float?
        /// 貯水率 (Storage rate) の増減傾向を表す文字列。
        public let trend: String
        /// 貯水量 (Storage volume)。
        public let storageVolume: Float?
        /// 貯水量 (Storage volume) の増減傾向を表す文字列。
        public let storageVolumeTrend: String?
        /// 前日比の貯水率 (Storage rate) 変化量。
        public let storagePercentageDayChange: Float?
        /// 前日比の変化傾向を表す文字列。
        public let dayChangeTrend: String?
        /// 前週比の貯水率 (Storage rate) 変化量。
        public let storagePercentageWeekChange: Float?
        /// 前週比の変化傾向を表す文字列。
        public let weekChangeTrend: String?
        /// すべてのリアルタイム観測データ (Real-time observation data) が無効かどうかを示すフラグ。
        public let isAllDataInvalid: Bool
        /// 貯水率メッセージ分類用の貯水量 (Storage volume)（×10³m³）。
        ///
        /// 貯水量 (Storage volume) 欠測時は欠測前の最新正常値。全く無い場合は nil。
        public let storageVolumeForMessage: Float?

        /// イニシャライザ。
        ///
        /// - Parameters:
        ///   - updatedAt: データ更新日時。
        ///   - observedAt: 観測日時。
        ///   - storagePercentage: 貯水率 (Storage rate)。
        ///   - trend: 貯水率 (Storage rate) の増減傾向。
        ///   - storageVolume: 貯水量 (Storage volume)。
        ///   - storageVolumeTrend: 貯水量 (Storage volume) の増減傾向。
        ///   - storagePercentageDayChange: 前日比の貯水率 (Storage rate) 変化量。
        ///   - dayChangeTrend: 前日比の変化傾向。
        ///   - storagePercentageWeekChange: 前週比の貯水率 (Storage rate) 変化量。
        ///   - weekChangeTrend: 前週比の変化傾向。
        ///   - isAllDataInvalid: すべてのリアルタイム観測データ (Real-time observation data) が無効かどうか。
        ///   - storageVolumeForMessage: 貯水率メッセージ分類用の貯水量 (Storage volume)（×10³m³）。欠測時は欠測前の最新正常値。
        public init(
            updatedAt: String,
            observedAt: String?,
            storagePercentage: Float?,
            trend: String,
            storageVolume: Float?,
            storageVolumeTrend: String?,
            storagePercentageDayChange: Float?,
            dayChangeTrend: String?,
            storagePercentageWeekChange: Float?,
            weekChangeTrend: String?,
            isAllDataInvalid: Bool,
            storageVolumeForMessage: Float? = nil
        ) {
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
            self.isAllDataInvalid = isAllDataInvalid
            self.storageVolumeForMessage = storageVolumeForMessage
        }
    }

    /// 解析された 1行のデータを表す構造体。
    public struct ParsedRow: Sendable {
        /// 日付文字列。
        public let date: String
        /// 時間文字列。
        public let time: String
        /// カンマで区切られた各列の配列。
        public let columns: [String]
        /// 列数。
        public let columnCount: Int

        /// イニシャライザ。
        ///
        /// - Parameters:
        ///   - date: 日付。
        ///   - time: 時間。
        ///   - columns: 列データ配列。
        public init(date: String, time: String, columns: [String]) {
            self.date = date
            self.time = time
            self.columns = columns
            self.columnCount = columns.count
        }
    }

    /// 1日あたりのデータ行数（10分ごとの観測データを想定: 24時間 × 6行 = 144行）。
    public nonisolated static let rowsPerDay = 144
    /// 傾向判定（増減なし）の閾値。
    public nonisolated static let trendEpsilon: Float = 0.0001
    /// 流域平均雨量 (Basin average rainfall) データの列インデックス。
    public nonisolated static let rainfallColumn = 2
    /// 貯水量 (Storage volume) データの列インデックス。
    public nonisolated static let storageVolumeColumn = 4
    /// 流入量 (Inflow) データの列インデックス。
    public nonisolated static let inflowColumn = 6
    /// 放流量 (Outflow) データの列インデックス。
    public nonisolated static let outflowColumn = 8
    /// 貯水率 (Storage rate) データの列インデックス。
    public nonisolated static let storagePercentageColumn = 10

    /// 生のテキストデータからカンマ区切りの行配列を解析して返します。
    ///
    /// - Parameter data: .dat ファイル等の生バイナリデータ。
    /// - Returns: 解析された `ParsedRow` の配列。デコードできないか空の場合は nil を返します。
    public static func parseRows(from data: Data) -> [ParsedRow]? {
        guard let text = DamCoreTextDecoder.decodeMLITText(data), !text.isEmpty else { return nil }
        let rows = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return rows
            .filter { !$0.hasPrefix("#") && $0.split(separator: ",", omittingEmptySubsequences: false).count > 5 }
            .map { line in
                let parts = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
                return ParsedRow(date: parts[safe: 0] ?? "", time: parts[safe: 1] ?? "", columns: parts)
            }
    }

    /// 指定された行の特定の列から Float 値を取得します。
    ///
    /// - Parameters:
    ///   - row: 解析された行データ。
    ///   - index: 列インデックス。
    /// - Returns: 変換された Float 値。存在しないかパースできない場合は nil を返します。
    public static func floatValue(_ row: ParsedRow, _ index: Int) -> Float? {
        guard let value = row.columns[safe: index]?.trimmingCharacters(in: .whitespaces) else { return nil }
        return Float(value)
    }

    /// 特定の属性（列）の観測ステータスが正常かどうか判定します。
    ///
    /// データ値の直後の列（属性マーク列）が空文字または空白であれば正常とみなします。
    ///
    /// - Parameters:
    ///   - row: 解析された行データ。
    ///   - dataColumn: データの列インデックス。
    /// - Returns: 正常値であれば true、欠測や閉局などの属性マークがある場合は false。
    public static func isAttributeNormal(_ row: ParsedRow, _ dataColumn: Int) -> Bool {
        let attr = row.columns[safe: dataColumn + 1] ?? ""
        return attr == " " || attr.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// 行配列から最新の有効な貯水率 (Storage rate) 情報を取得します。
    ///
    /// - Parameter rows: 解析された行配列。
    /// - Returns: 最新の貯水率 (Storage rate) の値、観測日時文字列、および行配列におけるインデックス（末尾から逆算）のタプル。
    public static func storagePercentage(from rows: [ParsedRow]) -> (percentage: Float?, observedAt: String?, index: Int?) {
        let reversed = Array(rows.reversed())
        guard let latestRow = reversed[safe: 0] else { return (nil, nil, nil) }
        let latestHour = DamCoreDamTime.hourKey(date: latestRow.date, time: latestRow.time)
            ?? "\(latestRow.date) \(String(latestRow.time.prefix(2)))"

        let isAllDataInvalid = !isAttributeNormal(latestRow, rainfallColumn)
            && !isAttributeNormal(latestRow, storageVolumeColumn)
            && !isAttributeNormal(latestRow, inflowColumn)
            && !isAttributeNormal(latestRow, outflowColumn)
            && !isAttributeNormal(latestRow, storagePercentageColumn)

        if isAllDataInvalid { return (nil, nil, nil) }

        for (index, row) in reversed.enumerated() where isAttributeNormal(row, storagePercentageColumn) {
            let rowHour = DamCoreDamTime.hourKey(date: row.date, time: row.time)
                ?? "\(row.date) \(String(row.time.prefix(2)))"
            guard rowHour == latestHour else { continue }
            if let value = floatValue(row, storagePercentageColumn) {
                return (value, "\(row.date) \(row.time)", index)
            }
        }
        return (nil, nil, nil)
    }

    /// 過去のデータと比較して、貯水率 (Storage rate) の増減傾向を判定します。
    ///
    /// - Parameters:
    ///   - rows: 解析された行配列。
    ///   - latestPercentage: 最新の貯水率 (Storage rate)。
    ///   - latestIndex: 最新の有効なデータの逆順インデックス。
    /// - Returns: 傾向を表す文字列 ("up", "down", "flat", "unknown")。
    public static func trend(from rows: [ParsedRow], latestPercentage: Float, latestIndex: Int) -> String {
        let reversed = Array(rows.reversed())
        for index in (latestIndex + 1)..<reversed.count where isAttributeNormal(reversed[index], storagePercentageColumn) {
            if let previous = floatValue(reversed[index], storagePercentageColumn) {
                if latestPercentage > previous { return "up" }
                if latestPercentage < previous { return "down" }
                return "flat"
            }
        }
        return "unknown"
    }

    /// 特定の列について、最新の有効なデータと過去（指定オフセット）の有効なデータとの差分を計算します。
    ///
    /// - Parameters:
    ///   - rows: 解析された行配列。
    ///   - column: データの列インデックス。
    ///   - latestValidRowIndex: 最新の有効なデータの逆順インデックス。
    ///   - offset: 比較対象の過去データのオフセット行数。nil の場合は最初期データと比較します。
    /// - Returns: 差分値と、過去の比較対象値のタプル。
    public static func pctChange(rows: [ParsedRow], column: Int, latestValidRowIndex: Int, offset: Int?) -> (Float?, Float?) {
        let reversed = Array(rows.reversed())
        guard let latestValue = floatValue(reversed[latestValidRowIndex], column) else { return (nil, nil) }
        let compareIndex: Int?
        if let offset {
            let target = latestValidRowIndex + offset
            if target >= reversed.count {
                compareIndex = (0..<reversed.count).reversed().first { isAttributeNormal(reversed[$0], column) && floatValue(reversed[$0], column) != nil }
            } else {
                compareIndex = (target..<reversed.count).first { isAttributeNormal(reversed[$0], column) && floatValue(reversed[$0], column) != nil }
            }
        } else {
            compareIndex = (0..<reversed.count).reversed().first { isAttributeNormal(reversed[$0], column) && floatValue(reversed[$0], column) != nil }
        }
        guard let compareIndex, compareIndex != latestValidRowIndex, let compareValue = floatValue(reversed[compareIndex], column) else {
            return (nil, nil)
        }
        let diff = latestValue - compareValue
        return (diff, compareValue)
    }

    /// 差分の値に基づいて傾向文字列を返します。
    ///
    /// - Parameter diff: 差分値。
    /// - Returns: 傾向を表す文字列 ("up", "down", "flat", "unknown")。
    public static func trendString(for diff: Float?) -> String {
        guard let diff else { return "unknown" }
        if diff > trendEpsilon { return "up" }
        if diff < -trendEpsilon { return "down" }
        return "flat"
    }

    /// 生データからスナップショット用の全フィールドを抽出・解析して返します。
    ///
    /// - Parameter data: .dat ファイル等の生バイナリデータ。
    /// - Returns: 解析されたスナップショットフィールドデータ。無効なデータ形式の場合は nil を返します。
    public static func snapshotFields(from data: Data) -> SnapshotFields? {
        guard let rows = parseRows(from: data), !rows.isEmpty else { return nil }
        return snapshotFields(from: rows)
    }

    /// 行配列からスナップショット用の全フィールドを抽出・解析して返します。
    ///
    /// - Parameter rows: 解析された行配列。
    /// - Returns: 解析されたスナップショットフィールドデータ。空配列の場合は nil を返します。
    public static func snapshotFields(from rows: [ParsedRow]) -> SnapshotFields? {
        let reversed = Array(rows.reversed())
        guard let latestRow = reversed.first else { return nil }
        let updatedAt = "\(latestRow.date) \(latestRow.time)"
        let isAllDataInvalid = !isAttributeNormal(latestRow, rainfallColumn)
            && !isAttributeNormal(latestRow, storageVolumeColumn)
            && !isAttributeNormal(latestRow, inflowColumn)
            && !isAttributeNormal(latestRow, outflowColumn)
            && !isAttributeNormal(latestRow, storagePercentageColumn)

        let (latestPercentage, observedAt, latestPercentageIndex) = storagePercentage(from: rows)
        let percentageTrend: String
        if let latestPercentage, let latestPercentageIndex {
            percentageTrend = trend(from: rows, latestPercentage: latestPercentage, latestIndex: latestPercentageIndex)
        } else {
            percentageTrend = "unknown"
        }

        var dayChange: Float?
        var dayChangeTrend: String?
        var weekChange: Float?
        var weekChangeTrend: String?
        if let latestPercentageIndex, latestPercentage != nil {
            let dayResult = pctChange(rows: rows, column: storagePercentageColumn, latestValidRowIndex: latestPercentageIndex, offset: rowsPerDay)
            dayChange = dayResult.0
            dayChangeTrend = trendString(for: dayResult.0)

            let weekResult = pctChange(rows: rows, column: storagePercentageColumn, latestValidRowIndex: latestPercentageIndex, offset: nil)
            weekChange = weekResult.0
            weekChangeTrend = trendString(for: weekResult.0)
        }

        var storageVolume: Float?
        var storageVolumeTrend: String?
        if !isAllDataInvalid, isAttributeNormal(latestRow, storageVolumeColumn) {
            storageVolume = floatValue(latestRow, storageVolumeColumn)
            storageVolumeTrend = "unknown"
            for index in 1..<reversed.count where isAttributeNormal(reversed[index], storageVolumeColumn) {
                if let previous = floatValue(reversed[index], storageVolumeColumn),
                   let current = storageVolume {
                    if current > previous { storageVolumeTrend = "up" }
                    else if current < previous { storageVolumeTrend = "down" }
                    else { storageVolumeTrend = "flat" }
                    break
                }
            }
        }

        var storageVolumeForMessage: Float?
        for row in reversed where isAttributeNormal(row, storageVolumeColumn) {
            if let value = floatValue(row, storageVolumeColumn) {
                storageVolumeForMessage = value
                break
            }
        }

        return SnapshotFields(
            updatedAt: updatedAt,
            observedAt: observedAt,
            storagePercentage: latestPercentage,
            trend: percentageTrend,
            storageVolume: storageVolume,
            storageVolumeTrend: storageVolumeTrend,
            storagePercentageDayChange: dayChange,
            dayChangeTrend: dayChangeTrend,
            storagePercentageWeekChange: weekChange,
            weekChangeTrend: weekChangeTrend,
            isAllDataInvalid: isAllDataInvalid,
            storageVolumeForMessage: storageVolumeForMessage
        )
    }
}

/// 配列の要素安全アクセス用エクステンション。
extension Array {
    /// 範囲外アクセスの際、クラッシュせずに nil を返すための安全なサブスクリプト。
    ///
    /// - Parameter index: アクセス対象のインデックス。
    /// - Returns: インデックスが範囲内の場合はその要素、範囲外の場合は nil。
    public subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
