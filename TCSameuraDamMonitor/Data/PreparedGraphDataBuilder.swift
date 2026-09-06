// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation
import TCSameuraDamCore

/// `GraphBaseSnapshot` / `GraphDisplaySnapshot` を構築する純粋ビルダー。
///
/// 日時変換は必ず `ObservationGraphCalculator.date(fromDamTime:)`（既存の24:00対応を含む
/// 単一の純粋な変換境界）を通します。プロジェクトの既定isolatedがMainActorであり、
/// DateFormatterを複数executorから共有しない方針に従い、本ビルダーもMainActor上で
/// 実行します（表示条件変更時のみ呼ばれ、pointer操作ごとの再実行はありません）。
internal enum PreparedGraphDataBuilder {
    /// 生の履歴行からbase snapshotを構築します。
    ///
    /// 日付変換と昇順ソート（`DashboardRowCache.ascending`）を一度だけ行い、
    /// 二分探索用のtimestampsと、表示可能な範囲オプションを併せて保持します。
    /// - Parameters:
    ///   - rows: 生の履歴行。
    ///   - rangeOptions: 選択可能なグラフ範囲オプション。
    /// - Returns: 構築されたbase snapshot。
    internal static func base(from rows: [DamHistoricalData], rangeOptions: [RealtimeGraphRange]) -> GraphBaseSnapshot {
        let datedRows = DashboardRowCache.ascending(rows)
        return GraphBaseSnapshot(
            rows: datedRows,
            timestamps: datedRows.map(\.date),
            rangeOptions: rangeOptions
        )
    }

    /// base snapshotと表示条件からdisplay snapshotを構築します。
    ///
    /// 表示行・domain・summary・scale値・軸最大値・線分マーカー・目盛り値を、
    /// 変更前のCard body内計算と同一の手順で導出します（出力はbyte同一）。
    /// - Parameters:
    ///   - base: 基底snapshot。
    ///   - kind: 表示種類。
    ///   - range: 選択されたグラフ範囲。
    ///   - selectedYears: 過去比較で選択された過去年の集合。
    ///   - isHistorical: 過去データ検索結果を表示しているかどうか。
    ///   - comparisonPayload: 過去比較の読み込み結果ペイロード。
    ///   - rangeStartDate: 表示開始日のフィルター文字列。
    ///   - rangeEndDate: 表示終了日のフィルター文字列。
    ///   - meta: 過去データ検索設定のメタデータ。
    ///   - localeFingerprint: summary等のlocale依存出力を区別するfingerprint。
    /// - Returns: 構築されたdisplay snapshot。
    internal static func display(
        base: GraphBaseSnapshot,
        kind: ObservationGraphDisplayKind,
        range: RealtimeGraphRange,
        selectedYears: Set<Int>,
        isHistorical: Bool,
        comparisonPayload: HistoricalComparisonPayload?,
        rangeStartDate: String?,
        rangeEndDate: String?,
        meta: HistoricalSearchMeta?,
        localeFingerprint: String
    ) -> GraphDisplaySnapshot {
        let (rows, chartRange) = {
            if isHistorical {
                let chartRange = historicalAxisRange(meta: meta, rangeStartDate: rangeStartDate, rangeEndDate: rangeEndDate)
                return (domainFilteredRows(base.rows, range: chartRange), chartRange)
            }
            let display: (rows: [DamHistoricalData], windowStart: Date?, windowEnd: Date?)
            switch kind {
            case .rainfallStorage, .rainfallStorageHistory:
                let data = ObservationGraphCalculator.buildRealtimeStorageGraphDisplayData(rows: base.rows.map(\.row), range: range)
                display = (data.rows, data.windowStart, data.windowEnd)
            case .volumeFlow, .volumeFlowHistory:
                let data = ObservationGraphCalculator.buildRealtimeGraphDisplayData(rows: base.rows.map(\.row), range: range)
                display = (data.rows, data.windowStart, data.windowEnd)
            }
            let rows = display.rows.map { DatedHistoricalRow(row: $0, date: ObservationGraphCalculator.date(fromDamTime: $0.time) ?? .distantPast) }
            let chartRange = ObservationGraphCalculator.graphDomain(
                start: display.windowStart, end: display.windowEnd,
                firstDate: rows.first?.date, lastDate: rows.last?.date
            )
            return (rows, chartRange)
        }()
        let summary = summaryText(
            kind: kind,
            rows: rows,
            range: chartRange,
            isHistorical: isHistorical,
            rangeStartDate: rangeStartDate,
            rangeEndDate: rangeEndDate,
            meta: meta
        )
        let domain = chartDomain(rows, range: chartRange)

        switch kind {
        case .rainfallStorage, .rainfallStorageHistory:
            let scaleRainfallValues = scaleValues(
                allRangeValues: base.rows.compactMap(\.row.catchmentAverageRainfall),
                selectedRangeValues: rows.compactMap(\.row.catchmentAverageRainfall),
                isHistorical: isHistorical
            )
            let rainfallAxisMax = ObservationGraphCalculator.rainfallAxisMax(values: scaleRainfallValues)
            return GraphDisplaySnapshot(
                rows: rows,
                timestamps: rows.map(\.date),
                domain: domain,
                summary: summary,
                storageScaleValues: [],
                rainfallScaleValues: scaleRainfallValues.map(Double.init),
                volumeScaleValues: [],
                inflowScaleValues: [],
                outflowScaleValues: [],
                volumeMax: nil,
                flowMax: nil,
                rainfallAxisMax: rainfallAxisMax,
                hasFlowScaleData: false,
                volumeTickValues: [],
                flowTickValues: [],
                storageSegments: storageSegments(rows),
                rainfallSegments: rainfallSegments(rows, rainfallAxisMax: rainfallAxisMax),
                volumeSegments: [],
                inflowSegments: [],
                outflowSegments: [],
                pastStorageSeries: pastYearSeries(
                    payload: comparisonPayload,
                    selectedYears: selectedYears,
                    domain: domain,
                    transform: { $0.map(Double.init) }
                ),
                pastVolumeSeries: [],
                drawnPastYears: drawnPastYears(payload: comparisonPayload, domain: domain)
            )
        case .volumeFlow, .volumeFlowHistory:
            let scaleVolumeValues = scaleValues(
                allRangeValues: base.rows.compactMap(\.row.storageVolume),
                selectedRangeValues: rows.compactMap(\.row.storageVolume),
                isHistorical: isHistorical
            )
            let displayedPastSeries = comparisonPayload.map {
                $0.pastSeries.filter { selectedYears.contains($0.year) }
            } ?? []
            let volumeMax = ObservationGraphCalculator.paddedMax(
                values: scaleVolumeValues + displayedPastSeries.flatMap(\.points).compactMap(\.value)
            )
            let scaleInflowValues = scaleValues(
                allRangeValues: base.rows.compactMap(\.row.inflow),
                selectedRangeValues: rows.compactMap(\.row.inflow),
                isHistorical: isHistorical
            )
            let scaleOutflowValues = scaleValues(
                allRangeValues: base.rows.compactMap(\.row.outflow),
                selectedRangeValues: rows.compactMap(\.row.outflow),
                isHistorical: isHistorical
            )
            let flowScaleValues = scaleInflowValues + scaleOutflowValues
            let hasFlowScaleData = !flowScaleValues.isEmpty
            let flowMax = ObservationGraphCalculator.paddedMax(values: flowScaleValues)
            return GraphDisplaySnapshot(
                rows: rows,
                timestamps: rows.map(\.date),
                domain: domain,
                summary: summary,
                storageScaleValues: [],
                rainfallScaleValues: [],
                volumeScaleValues: scaleVolumeValues.map(Double.init),
                inflowScaleValues: scaleInflowValues.map(Double.init),
                outflowScaleValues: scaleOutflowValues.map(Double.init),
                volumeMax: volumeMax,
                flowMax: flowMax,
                rainfallAxisMax: nil,
                hasFlowScaleData: hasFlowScaleData,
                volumeTickValues: scaledAxisTickValues(maxValue: volumeMax),
                flowTickValues: hasFlowScaleData ? scaledAxisTickValues(maxValue: flowMax) : [],
                storageSegments: [],
                rainfallSegments: [],
                volumeSegments: volumeSegments(rows, volumeMax: volumeMax),
                inflowSegments: inflowSegments(rows, flowMax: flowMax),
                outflowSegments: outflowSegments(rows, flowMax: flowMax),
                pastStorageSeries: [],
                pastVolumeSeries: pastYearSeries(
                    payload: comparisonPayload,
                    selectedYears: selectedYears,
                    domain: domain,
                    transform: { $0.map { scaled(Double($0), max: volumeMax) } }
                ),
                drawnPastYears: drawnPastYears(payload: comparisonPayload, domain: domain)
            )
        }
    }

    /// 履歴モードの検索範囲domainを解決します。
    /// - Parameters:
    ///   - meta: 過去データ検索設定のメタデータ。
    ///   - rangeStartDate: 表示開始日のフィルター文字列。
    ///   - rangeEndDate: 表示終了日のフィルター文字列。
    /// - Returns: 検索範囲domain。解決できない場合は `nil`。
    private static func historicalAxisRange(
        meta: HistoricalSearchMeta?,
        rangeStartDate: String?,
        rangeEndDate: String?
    ) -> ClosedRange<Date>? {
        if let startDate = rangeStartDate, let endDate = rangeEndDate,
           let start = historicalStartDate(from: startDate),
           let end = historicalEndDate(from: endDate) {
            return start...end
        }
        if let meta,
           let start = historicalStartDate(meta),
           let end = historicalEndDate(meta) {
            return start...end
        }
        return nil
    }

    /// ドメイン範囲外の履歴行を描画対象から除外して取得します。
    ///
    /// 範囲指定でX軸domainが縮小された場合に、domain外の行がSwift Chartsのプロット領域外へ
    /// 線をはみ出させないための防御的フィルタです（過去年系列は別経路のため影響しません）。
    /// - Parameters:
    ///   - rows: 日付付き履歴レコード。
    ///   - range: チャートのドメイン軸にわたるカレンダーの範囲制限。
    /// - Returns: 範囲内の行。範囲が `nil` の場合は全行。
    private static func domainFilteredRows(_ rows: [DatedHistoricalRow], range: ClosedRange<Date>?) -> [DatedHistoricalRow] {
        guard let range else { return rows }
        return rows.filter { $0.date >= range.lowerBound && $0.date <= range.upperBound }
    }

    /// メタデータクエリの制約から開始範囲の制限を解決します。
    /// - Parameter meta: 検索の制約メタデータ。
    /// - Returns: 開始日。
    private static func historicalStartDate(_ meta: HistoricalSearchMeta) -> Date? {
        historicalStartDate(from: meta.searchBgnDate)
    }

    /// メタデータクエリの制約から終了範囲の制限を解決します。
    /// - Parameter meta: 検索の制約メタデータ。
    /// - Returns: 終了日。
    private static func historicalEndDate(_ meta: HistoricalSearchMeta) -> Date? {
        historicalEndDate(from: meta.searchEndDate)
    }

    /// 履歴の開始時刻パラメータを解析します。
    /// - Parameter yyyymmdd: カレンダーの日付文字列。
    /// - Returns: 解析された日付オフセット。
    private static func historicalStartDate(from yyyymmdd: String) -> Date? {
        guard let day = TimeFormatters.jstDay.date(from: yyyymmdd) else { return nil }
        return Calendar.jst.date(byAdding: .hour, value: 1, to: day)
    }

    /// 履歴の終了時刻パラメータを解析します。
    /// - Parameter yyyymmdd: カレンダーの日付文字列。
    /// - Returns: 解析された日付オフセット。
    private static func historicalEndDate(from yyyymmdd: String) -> Date? {
        guard let day = TimeFormatters.jstDay.date(from: yyyymmdd),
              let nextDay = Calendar.jst.date(byAdding: .day, value: 1, to: day) else {
            return nil
        }
        return nextDay
    }

    /// 表示種類に応じたサマリーテキストを構築します。
    /// - Parameters:
    ///   - kind: 表示種類。
    ///   - rows: 表示対象の日付付き履歴レコード。
    ///   - range: チャートのドメイン軸にわたるカレンダーの範囲制限。
    ///   - isHistorical: 過去データ検索結果を表示しているかどうか。
    ///   - rangeStartDate: 表示開始日のフィルター文字列。
    ///   - rangeEndDate: 表示終了日のフィルター文字列。
    ///   - meta: 過去データ検索設定のメタデータ。
    /// - Returns: サマリーテキスト。
    private static func summaryText(
        kind: ObservationGraphDisplayKind,
        rows: [DatedHistoricalRow],
        range: ClosedRange<Date>?,
        isHistorical: Bool,
        rangeStartDate: String?,
        rangeEndDate: String?,
        meta: HistoricalSearchMeta?
    ) -> String {
        var lines = [
            "\(AppText.graphLabelPeriod) \(periodText(rows: rows, range: range, isHistorical: isHistorical, rangeStartDate: rangeStartDate, rangeEndDate: rangeEndDate, meta: meta))"
        ]
        switch kind {
        case .rainfallStorage, .rainfallStorageHistory:
            let storageRows = rows.filter { $0.row.storagePercentage != nil }
            if let maxItem = storageRows.max(by: { ($0.row.storagePercentage ?? 0) < ($1.row.storagePercentage ?? 0) }),
               let minItem = storageRows.min(by: { ($0.row.storagePercentage ?? 0) < ($1.row.storagePercentage ?? 0) }),
               let maxValue = maxItem.row.storagePercentage,
               let minValue = minItem.row.storagePercentage {
                lines.append("\(AppText.graphLabelStorageRateMax) \(DisplayFormatters.damDateTime(maxItem.row.time)) \(String(format: "%.2f", maxValue))%")
                lines.append("\(AppText.graphLabelStorageRateMin) \(DisplayFormatters.damDateTime(minItem.row.time)) \(String(format: "%.2f", minValue))%")
            }
            let rainfalls = rows.compactMap(\.row.catchmentAverageRainfall)
            if !rainfalls.isEmpty {
                lines.append("\(AppText.graphLabelRainfallTotal) \(String(format: "%.1f", rainfalls.reduce(0, +)))mm")
                if let maxRainfall = rainfalls.max(), maxRainfall != 0 {
                    lines.append("\(AppText.graphLabelRainfallMax) \(String(format: "%.1f", maxRainfall))\(rainfallUnitLabel(isHistorical: isHistorical).trimmedUnit)")
                }
            }
        case .volumeFlow, .volumeFlowHistory:
            appendSummary(to: &lines, rows: rows, value: \.storageVolume, maxLabel: AppText.graphLabelStorageVolumeMax, minLabel: AppText.graphLabelStorageVolumeMin, unit: AppText.graphUnitStorageVolume, decimals: 0)
            appendSummary(to: &lines, rows: rows, value: \.inflow, maxLabel: AppText.graphLabelInflowMax, minLabel: AppText.graphLabelInflowMin, unit: AppText.graphUnitFlow, decimals: 2)
            appendSummary(to: &lines, rows: rows, value: \.outflow, maxLabel: AppText.graphLabelOutflowMax, minLabel: AppText.graphLabelOutflowMin, unit: AppText.graphUnitFlow, decimals: 2)
        }
        return lines.joined(separator: "\n")
    }

    /// 指定されたキーパスの最大/最小サマリーテキスト記述を追加します。
    /// - Parameters:
    ///   - lines: 追加先の行配列。
    ///   - rows: 日付付きの履歴レコード。
    ///   - value: 対象の観測値キーパス。
    ///   - maxLabel: 最大値ラベル。
    ///   - minLabel: 最小値ラベル。
    ///   - unit: 単位表記。
    ///   - decimals: 表示する小数点以下の桁数。
    private static func appendSummary(
        to lines: inout [String],
        rows: [DatedHistoricalRow],
        value: KeyPath<DamHistoricalData, Float?>,
        maxLabel: String,
        minLabel: String,
        unit: String,
        decimals: Int
    ) {
        let validRows = rows.filter { $0.row[keyPath: value] != nil }
        guard let maxItem = validRows.max(by: { ($0.row[keyPath: value] ?? 0) < ($1.row[keyPath: value] ?? 0) }),
              let minItem = validRows.min(by: { ($0.row[keyPath: value] ?? 0) < ($1.row[keyPath: value] ?? 0) }),
              let maxValue = maxItem.row[keyPath: value],
              let minValue = minItem.row[keyPath: value] else {
            return
        }
        if maxValue != 0 {
            lines.append("\(maxLabel) \(DisplayFormatters.damDateTime(maxItem.row.time)) \(formatValue(maxValue, decimals: decimals))\(unit.trimmedUnit)")
        }
        if minValue != 0 {
            lines.append("\(minLabel) \(DisplayFormatters.damDateTime(minItem.row.time)) \(formatValue(minValue, decimals: decimals))\(unit.trimmedUnit)")
        }
    }

    /// float値から double 表現文字列をフォーマットします。
    /// - Parameters:
    ///   - value: フォーマット対象の値。
    ///   - decimals: 表示する小数点以下の桁数。
    /// - Returns: フォーマットされた文字列。
    private static func formatValue(_ value: Float, decimals: Int) -> String {
        decimals == 0 ? "\(Int(value))" : String(format: "%.\(decimals)f", value)
    }

    /// 雨量単位を定義するヘッダーテキストを返します。
    /// - Parameter isHistorical: 過去データ検索結果を表示しているかどうか。
    /// - Returns: 雨量単位ラベル。
    private static func rainfallUnitLabel(isHistorical: Bool) -> String {
        isHistorical ? AppText.graphUnitRainfallPerHour : AppText.graphUnitRainfall
    }

    /// フォーマットされた範囲カレンダーのタイミングを評価します。
    /// - Parameters:
    ///   - rows: 表示対象の日付付き履歴レコード。
    ///   - range: チャートのドメイン軸にわたるカレンダーの範囲制限。
    ///   - isHistorical: 過去データ検索結果を表示しているかどうか。
    ///   - rangeStartDate: 表示開始日のフィルター文字列。
    ///   - rangeEndDate: 表示終了日のフィルター文字列。
    ///   - meta: 過去データ検索設定のメタデータ。
    /// - Returns: 期間テキスト。
    private static func periodText(
        rows: [DatedHistoricalRow],
        range: ClosedRange<Date>?,
        isHistorical: Bool,
        rangeStartDate: String?,
        rangeEndDate: String?,
        meta: HistoricalSearchMeta?
    ) -> String {
        periodText(rows: rows, range: range, isHistorical: isHistorical, rangeStartDate: rangeStartDate, rangeEndDate: rangeEndDate, meta: meta, isLocalJst: DisplayFormatters.isJST)
    }

    /// 期間行テキストを構築します。非JST環境では終端側（B）にのみ "(JST)" サフィックスを付与します。
    /// - Parameters:
    ///   - rows: 表示対象の日付付き履歴レコード。
    ///   - range: チャートのドメイン軸にわたるカレンダーの範囲制限。
    ///   - isHistorical: 過去データ検索結果を表示しているかどうか。
    ///   - rangeStartDate: 表示開始日のフィルター文字列。
    ///   - rangeEndDate: 表示終了日のフィルター文字列。
    ///   - meta: 過去データ検索設定のメタデータ。
    ///   - isLocalJst: 端末タイムゾーンがJSTかどうか（テスト注入用。通常は `DisplayFormatters.isJST`）。
    /// - Returns: 期間テキスト。
    internal static func periodText(
        rows: [DatedHistoricalRow],
        range: ClosedRange<Date>?,
        isHistorical: Bool,
        rangeStartDate: String?,
        rangeEndDate: String?,
        meta: HistoricalSearchMeta?,
        isLocalJst: Bool
    ) -> String {
        if isHistorical {
            if let startDate = rangeStartDate, let endDate = rangeEndDate {
                return DamCoreJSTSupport.appendingJstSuffix("\(DisplayFormatters.slashDate(startDate)) 01:00 - \(DisplayFormatters.nextDaySlashDate(endDate)) 00:00", isLocalJst: isLocalJst)
            }
            if let meta {
                return DamCoreJSTSupport.appendingJstSuffix("\(DisplayFormatters.slashDate(meta.searchBgnDate)) 01:00 - \(DisplayFormatters.nextDaySlashDate(meta.searchEndDate)) 00:00", isLocalJst: isLocalJst)
            }
        }
        if let range, !isHistorical {
            let startText = TimeFormatters.jstDisplay.string(from: range.lowerBound)
            let endText = TimeFormatters.jstDisplay.string(from: range.upperBound)
            return "\(startText) - \(DamCoreJSTSupport.appendingJstSuffix(endText, isLocalJst: isLocalJst))"
        }
        guard let first = rows.first?.row, let last = rows.last?.row else { return "--" }
        let startText = DisplayFormatters.damDateTime(first.time, withJSTSuffix: false)
        let endText = DisplayFormatters.damDateTime(last.time, withJSTSuffix: false)
        return "\(startText) - \(DamCoreJSTSupport.appendingJstSuffix(endText, isLocalJst: isLocalJst))"
    }

    /// カレンダーの開始/終了座標制限を評価します。
    /// - Parameters:
    ///   - rows: 表示対象の日付付き履歴レコード。
    ///   - range: チャートのドメイン軸にわたるカレンダーの範囲制限。
    /// - Returns: 表示domain。
    private static func chartDomain(_ rows: [DatedHistoricalRow], range: ClosedRange<Date>?) -> ClosedRange<Date> {
        if let range { return range }
        let start = rows.first?.date ?? Date()
        let end = rows.last?.date ?? start.addingTimeInterval(1)
        return start < end ? start...end : start...start.addingTimeInterval(1)
    }

    /// グラフの描画に使用するスケール値を決定します。
    /// - Parameters:
    ///   - allRangeValues: 全期間のデータに対するスケール値。
    ///   - selectedRangeValues: 選択された表示期間のデータに対するスケール値。
    ///   - isHistorical: 過去データ検索モードかどうかのフラグ。
    /// - Returns: 描画に使用するスケール値。
    private static func scaleValues(
        allRangeValues: [Float],
        selectedRangeValues: [Float],
        isHistorical: Bool
    ) -> [Float] {
        return ObservationGraphCalculator.realtimeGraphScaleValues(
            allRangeValues: allRangeValues,
            selectedRangeValues: selectedRangeValues,
            isHistorical: isHistorical
        )
    }

    /// 貯水率の値を表す線分マーカーを作成します。
    /// - Parameter rows: 表示対象の日付付き履歴レコード。
    /// - Returns: 線分マーカーの一覧。
    private static func storageSegments(_ rows: [DatedHistoricalRow]) -> [DamChartSegment] {
        return lineSegments(rows: rows, idPrefix: "storage") { item in
            item.row.storagePercentage.map(Double.init)
        }
    }

    /// 雨量の値を表す線分マーカーを作成します。
    /// - Parameters:
    ///   - rows: 表示対象の日付付き履歴レコード。
    ///   - rainfallAxisMax: 雨量軸の最大値。
    /// - Returns: 線分マーカーの一覧。
    private static func rainfallSegments(_ rows: [DatedHistoricalRow], rainfallAxisMax: Double) -> [DamChartSegment] {
        return lineSegments(rows: rows, idPrefix: "rainfall") { item in
            item.row.catchmentAverageRainfall.map { scaled(Double($0), max: rainfallAxisMax) }
        }
    }

    /// 貯水量を表す線分マーカーを作成します。
    /// - Parameters:
    ///   - rows: 表示対象の日付付き履歴レコード。
    ///   - volumeMax: 貯水量軸の最大値。
    /// - Returns: 線分マーカーの一覧。
    private static func volumeSegments(_ rows: [DatedHistoricalRow], volumeMax: Double) -> [DamChartSegment] {
        return lineSegments(rows: rows, idPrefix: "volume") { item in
            item.row.storageVolume.map { scaled(Double($0), max: volumeMax) }
        }
    }

    /// 流入量を表す線分マーカーを作成します。
    /// - Parameters:
    ///   - rows: 表示対象の日付付き履歴レコード。
    ///   - flowMax: 流量軸の最大値。
    /// - Returns: 線分マーカーの一覧。
    private static func inflowSegments(_ rows: [DatedHistoricalRow], flowMax: Double) -> [DamChartSegment] {
        return lineSegments(rows: rows, idPrefix: "inflow") { item in
            item.row.inflow.map { scaled(Double($0), max: flowMax) }
        }
    }

    /// 放流量を表す線分マーカーを作成します。
    /// - Parameters:
    ///   - rows: 表示対象の日付付き履歴レコード。
    ///   - flowMax: 流量軸の最大値。
    /// - Returns: 線分マーカーの一覧。
    private static func outflowSegments(_ rows: [DatedHistoricalRow], flowMax: Double) -> [DamChartSegment] {
        return lineSegments(rows: rows, idPrefix: "outflow") { item in
            item.row.outflow.map { scaled(Double($0), max: flowMax) }
        }
    }

    /// 連続するデータポイントをセグメントにグループ化し、大きなギャップで分割します。
    /// - Parameters:
    ///   - rows: 日付付きの履歴レコード。
    ///   - idPrefix: 識別プレフィックス。
    ///   - value: 値リゾルバーブロック。
    /// - Returns: セグメント項目のリスト。
    private static func lineSegments(
        rows: [DatedHistoricalRow],
        idPrefix: String,
        value: (DatedHistoricalRow) -> Double?
    ) -> [DamChartSegment] {
        var segments: [DamChartSegment] = []
        var current: [DamChartPoint] = []
        var lastDate: Date?
        var segmentIndex = 0

        func flush() {
            if !current.isEmpty {
                segments.append(DamChartSegment(id: "\(idPrefix)-segment-\(segmentIndex)", points: decimatedChartPoints(current)))
                segmentIndex += 1
                current = []
            }
        }

        for item in rows {
            guard let pointValue = value(item) else {
                flush()
                lastDate = nil
                continue
            }
            if let lastDate, item.date.timeIntervalSince(lastDate) > damChartLineBreakGap {
                flush()
            }
            current.append(DamChartPoint(id: "\(item.id)-\(idPrefix)", date: item.date, value: pointValue))
            lastDate = item.date
        }

        flush()
        return segments
    }

    /// 過去比較ペイロードから選択年の描画セグメント一覧を構築します。
    ///
    /// domain外の点の除外・左右端クランプ・欠測/gap分割・デシメーションまでを
    /// display snapshot構築時に一度だけ行い、Card body評価ごとの再計算を回避します。
    /// - Parameters:
    ///   - payload: 過去比較の読み込み結果ペイロード。
    ///   - selectedYears: 選択された過去年（今年を含む）。
    ///   - domain: 表示domain。
    ///   - transform: 系列点から描画値（%スケール）を解決するブロック。
    /// - Returns: 年ごとの描画セグメント一覧。payloadがnilの場合は空。
    private static func pastYearSeries(
        payload: HistoricalComparisonPayload?,
        selectedYears: Set<Int>,
        domain: ClosedRange<Date>,
        transform: @escaping (Float?) -> Double?
    ) -> [PastYearChartSeries] {
        guard let payload else { return [] }
        return payload.pastSeries
            .filter { selectedYears.contains($0.year) }
            .map { series in
                PastYearChartSeries(
                    year: series.year,
                    axisLabel: HistoricalComparisonDisplay.yearLabel(series.year, isJapanese: AppLocale.isJapanese),
                    segments: pastYearSegments(
                        points: HistoricalComparisonDisplay.edgeExtendedPoints(series.points, in: domain),
                        year: series.year,
                        value: { transform($0.value) }
                    )
                )
            }
    }

    /// 過去年の系列点を欠測・大きなギャップで分割したセグメントへグループ化します。
    /// - Parameters:
    ///   - points: domain内＋端点クランプ済みの系列点。
    ///   - year: 系列の年(segment idへ含める)。
    ///   - value: 系列点から描画値を解決するブロック。
    /// - Returns: セグメント項目のリスト。
    private static func pastYearSegments(
        points: [HistoricalComparisonSeriesPoint],
        year: Int,
        value: @escaping (HistoricalComparisonSeriesPoint) -> Double?
    ) -> [DamChartSegment] {
        var segments: [DamChartSegment] = []
        var current: [DamChartPoint] = []
        var lastDate: Date?
        var segmentIndex = 0

        func flush() {
            if !current.isEmpty {
                segments.append(DamChartSegment(id: "\(year)-segment-\(segmentIndex)", points: decimatedChartPoints(current)))
                segmentIndex += 1
                current = []
            }
        }

        for point in points {
            guard let pointValue = value(point) else {
                flush()
                lastDate = nil
                continue
            }
            if let lastDate, point.date.timeIntervalSince(lastDate) > damChartLineBreakGap {
                flush()
            }
            current.append(DamChartPoint(id: "\(point.id)-\(year)", date: point.date, value: pointValue))
            lastDate = point.date
        }

        flush()
        return segments
    }

    /// 表示domain内で線が実際に描かれる過去年の集合を返します。
    /// - Parameters:
    ///   - payload: 過去比較の読み込み結果ペイロード。
    ///   - domain: 表示domain。
    /// - Returns: 描画される年の集合。payloadがnilの場合は空。
    private static func drawnPastYears(payload: HistoricalComparisonPayload?, domain: ClosedRange<Date>) -> Set<Int> {
        guard let payload else { return [] }
        return HistoricalComparisonDisplay.drawnPastYears(payload.pastSeries, in: domain)
    }

    /// パーセンテージ境界にスケーリングされた目盛り値のしきい値を計算します。
    /// - Parameter maxValue: 最大制限値。
    /// - Returns: スケールされた値のリスト。
    internal static func scaledAxisTickValues(maxValue: Double) -> [Double] {
        ObservationGraphCalculator.axisTickValues(maxValue: maxValue).map { scaled($0, max: maxValue) }
    }
}

/// 元のパラメータ値をチャートのパーセンテージ範囲にスケーリングします。
/// - Parameters:
///   - value: 生のメトリック値。
///   - maxValue: 最大スケール制限値。
/// - Returns: パーセンテージ表現。
func scaled(_ value: Double, max maxValue: Double) -> Double {
    guard maxValue > 0 else { return 0 }
    return min(max(value / maxValue * 100, 0), 100)
}
