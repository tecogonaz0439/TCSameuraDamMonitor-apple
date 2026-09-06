// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation
import CoreGraphics
import TCSameuraDamCore

/// DATファイルの書き出し形式を表す列挙型。
internal enum DatExportVariant: String, CaseIterable, Identifiable, Sendable {
    /// 生の（Shift_JISなどの元のエンコーディングの）形式。
    case raw
    /// UTF-8形式。
    case utf8

    /// 識別子。
    internal var id: String { rawValue }

    /// 指定されたベース名からエクスポート用のファイル名を生成します。
    /// - Parameter baseName: ベースとなるファイル名。
    /// - Returns: 生成されたエクスポートファイル名。
    internal func exportFilename(baseName: String?) -> String {
        let fallback = "export.dat"
        let normalized = baseName?.isEmpty == false ? baseName! : fallback
        switch self {
        case .raw:
            return normalized
        case .utf8:
            let stem = normalized.split(separator: ".", omittingEmptySubsequences: false).dropLast().joined(separator: ".")
            return "\(stem.isEmpty ? normalized : stem)_utf8.dat"
        }
    }
}

/// DATエクスポート用のデータ変換ユーティリティ。
internal enum DatExportConverter {
    /// 指定されたバイナリデータをUTF-8エンコーディングのデータに変換します。
    /// - Parameter data: 変換元のデータ。
    /// - Returns: UTF-8エンコーディングに変換されたデータ。
    /// - Throws: デコードまたはエンコードに失敗した場合のエラー。
    internal static func utf8Data(from data: Data) throws -> Data {
        try DamCoreTextDecoder.utf8Data(from: data)
    }
}

/// チャートのズーム倍率や表示期間を計算するユーティリティ。
internal enum ChartZoomCalculator {
    /// チャートに最小限表示すべき行数。
    internal static let minVisibleRows = 12

    /// 現在のスケールに基づいて、表示する時間の長さを計算します。
    /// - Parameters:
    ///   - totalLength: 全体の時間間隔。
    ///   - rowCount: 全体のデータ行数。
    ///   - scale: 現在のズームスケール。
    /// - Returns: 表示対象となる時間の長さ。
    internal static func visibleLength(totalLength: TimeInterval, rowCount: Int, scale: CGFloat) -> TimeInterval {
        guard totalLength > 0, rowCount > minVisibleRows, scale > 0 else {
            return max(totalLength, 0)
        }
        let minimum = totalLength * Double(minVisibleRows) / Double(rowCount)
        return min(max(totalLength / Double(scale), minimum), totalLength)
    }

    /// 現在のズームスケールとピンチ操作の拡大率から、次のズームスケールを計算します。
    /// - Parameters:
    ///   - currentScale: 現在のズームスケール。
    ///   - magnification: 拡大率。
    /// - Returns: 制限範囲内にクランプされた次のズームスケール。
    internal static func nextScale(currentScale: CGFloat, magnification: CGFloat) -> CGFloat {
        min(max(currentScale * magnification, 1), 16)
    }
}

/// 観測グラフの表示種類を表す列挙型。
internal enum ObservationGraphDisplayKind: String, CaseIterable, Identifiable, Sendable, Hashable {
    /// 流域平均雨量 (Basin average rainfall) と貯水率 (Storage rate)。
    case rainfallStorage
    /// 貯水量 (Storage volume) と流出入量（流入量: Inflow, 放流量: Outflow）。
    case volumeFlow
    /// 流域平均雨量 (Basin average rainfall) と貯水率 (Storage rate) の過去比較。
    case rainfallStorageHistory
    /// 貯水量 (Storage volume) と流出入量の過去比較。
    case volumeFlowHistory

    /// 識別子。
    internal var id: String { rawValue }
}

extension ObservationGraphDisplayKind {
    /// 過去比較モードの表示種類かどうか。
    internal var isHistory: Bool {
        switch self {
        case .rainfallStorageHistory, .volumeFlowHistory: true
        case .rainfallStorage, .volumeFlow: false
        }
    }

    /// 過去比較モードで比較対象となる測定値の種類。
    internal var comparisonMetric: HistoricalComparisonMetric? {
        switch self {
        case .rainfallStorageHistory: .storageRate
        case .volumeFlowHistory: .storageVolume
        case .rainfallStorage, .volumeFlow: nil
        }
    }
}

/// リアルタイム観測データ (Real-time observation data) の表示対象期間範囲を表す列挙型。
internal enum RealtimeGraphRange: String, CaseIterable, Identifiable, Sendable {
    /// すべての期間。
    case all
    /// 過去72時間。
    case past72Hours
    /// 過去48時間。
    case past48Hours
    /// 過去24時間。
    case past24Hours

    /// 識別子。
    internal var id: String { rawValue }

    /// 時間数換算値。全期間の場合は `nil`。
    internal var hours: Int? {
        switch self {
        case .all: nil
        case .past72Hours: 72
        case .past48Hours: 48
        case .past24Hours: 24
        }
    }
}

/// リアルタイム観測データ (Real-time observation data) のグラフ表示用データを保持する構造体。
internal struct RealtimeGraphDisplayData: Sendable {
    /// グラフに表示するダム履歴データの配列。
    internal let rows: [DamHistoricalData]
    /// グラフ表示ウィンドウの開始日時。
    internal let windowStart: Date?
    /// グラフ表示ウィンドウの終了日時。
    internal let windowEnd: Date?
}

/// 貯水率 (Storage rate) グラフ表示用データを保持する構造体。
internal struct RealtimeStorageGraphDisplayData: Sendable {
    /// グラフに表示するダム履歴データの配列。
    internal let rows: [DamHistoricalData]
    /// グラフ表示ウィンドウの開始日時。
    internal let windowStart: Date?
    /// グラフ表示ウィンドウの終了日時。
    internal let windowEnd: Date?
}

/// チャートのX軸目盛りに関するデータを保持する構造体。
internal struct ChartXAxisTickData: Equatable, Sendable {
    /// グリッド線の描画対象となる日付リスト。
    internal let gridDates: [Date]
    /// 目盛り線の描画対象となる日付リスト。
    internal let tickDates: [Date]
    /// 各日付に対応する表示用ラベルの辞書。
    internal let labels: [Date: String]
}

/// チャートの軸グリッド線の位置情報を表す構造体。
internal struct ChartAxisGridLineSegment: Equatable, Sendable {
    /// X座標位置。
    internal let x: CGFloat
    /// Y軸の最小位置。
    internal let minY: CGFloat
    /// Y軸の最大位置。
    internal let maxY: CGFloat
}

/// 観測グラフの各種計算やデータ生成を行うユーティリティ。
internal enum ObservationGraphCalculator {
    /// チャートの最小アスペクト比（高さ/幅）。
    internal static let minimumHeightRatio: CGFloat = 0.5
    /// チャートの最小の高さ。
    internal static let minimumChartHeight: CGFloat = 250
    /// チャートの最大の高さ。
    internal static let maximumChartHeight: CGFloat = 420
    /// チャートの標準スケール最大値。
    internal static let chartScaleMaximum = 100.0
    /// macOS の Chart 描画境界で上端の線や軸ラベルが欠けないようにするための上側余白。
    internal static let macOSChartScaleTopPadding = 2.0
    /// プラットフォームごとのチャートY軸上限。
    internal static var chartYScaleUpperBound: Double {
        #if os(macOS)
        chartScaleMaximum + macOSChartScaleTopPadding
        #else
        chartScaleMaximum
        #endif
    }
    /// 雨量軸のデフォルト最大値（ミリ）。
    internal static let rainfallAxisMaxDefault = 10.0
    /// チャートラベル表示時の衝突防止用パディング。
    internal static let chartLabelWidthSafetyPadding: CGFloat = 12
    /// 前後のデータ間で補間を許容する時間制限（1時間）。
    private static let lineFillLimit: TimeInterval = 60 * 60

    /// チャート幅に対応した高さを計算します。
    /// - Parameter width: チャートの表示幅。
    /// - Returns: 計算されたチャートの高さ。
    internal static func chartHeight(for width: CGFloat) -> CGFloat {
        min(maximumChartHeight, max(minimumChartHeight, width * minimumHeightRatio))
    }

    /// チャート高さの基準にする幅を決定します。
    /// - Parameters:
    ///   - plotWidth: Swift Charts の実プロット領域幅。
    ///   - containerWidth: プロット幅をまだ取得できない場合の外側コンテナ幅。
    /// - Returns: 高さ計算に使う幅。
    internal static func chartLayoutWidth(plotWidth: CGFloat, containerWidth: CGFloat) -> CGFloat {
        plotWidth > 0 ? plotWidth : containerWidth
    }

    /// プロット領域幅を優先してチャート高さを計算します。
    /// - Parameters:
    ///   - plotWidth: Swift Charts の実プロット領域幅。
    ///   - containerWidth: プロット幅をまだ取得できない場合の外側コンテナ幅。
    /// - Returns: 計算されたチャートの高さ。
    internal static func chartHeight(plotWidth: CGFloat, containerWidth: CGFloat) -> CGFloat {
        chartHeight(for: chartLayoutWidth(plotWidth: plotWidth, containerWidth: containerWidth))
    }

    /// 与えられた履歴データから、選択可能なリアルタイム観測データ (Real-time observation data) の表示範囲オプションのリストを生成します。
    /// - Parameter rows: ダム履歴データの配列。
    /// - Returns: 選択可能な `RealtimeGraphRange` の配列。
    internal static func realtimeGraphRangeOptions(rows: [DamHistoricalData]) -> [RealtimeGraphRange] {
        let timedRows = sortedTimedRows(rows)
        guard let first = timedRows.first?.date, let latest = timedRows.last?.date else {
            return [.all]
        }
        let period = latest.timeIntervalSince(first)
        return RealtimeGraphRange.allCases.filter { range in
            guard let hours = range.hours else { return true }
            return period > TimeInterval(hours * 60 * 60)
        }
    }

    /// 与えられた履歴データと表示範囲設定から、表示用データを構築します。
    /// - Parameters:
    ///   - rows: ダム履歴データの配列。
    ///   - range: 指定する表示範囲。
    /// - Returns: 構築された表示用データ。
    internal static func buildRealtimeGraphDisplayData(
        rows: [DamHistoricalData],
        range: RealtimeGraphRange
    ) -> RealtimeGraphDisplayData {
        guard let hours = range.hours else {
            return RealtimeGraphDisplayData(rows: rows, windowStart: nil, windowEnd: nil)
        }
        let timedRows = sortedTimedRows(rows)
        guard let latest = timedRows.last?.date else {
            return RealtimeGraphDisplayData(rows: rows, windowStart: nil, windowEnd: nil)
        }
        let start = latest.addingTimeInterval(TimeInterval(-hours * 60 * 60))
        let inWindow = timedRows
            .filter { $0.date >= start && $0.date <= latest }
            .map(\.row)
        return RealtimeGraphDisplayData(rows: inWindow, windowStart: start, windowEnd: latest)
    }

    /// 与えられた履歴データと表示範囲設定から、貯水率 (Storage rate) の欠損値を補間した表示用データを構築します。
    /// - Parameters:
    ///   - rows: ダム履歴データの配列。
    ///   - range: 指定する表示範囲。
    /// - Returns: 構築された貯水率グラフ用の表示データ。
    internal static func buildRealtimeStorageGraphDisplayData(
        rows: [DamHistoricalData],
        range: RealtimeGraphRange
    ) -> RealtimeStorageGraphDisplayData {
        let timedRows = sortedTimedRows(rows)
        guard let latest = timedRows.last?.date else {
            return RealtimeStorageGraphDisplayData(rows: rows, windowStart: nil, windowEnd: nil)
        }
        guard let hours = range.hours else {
            return RealtimeStorageGraphDisplayData(
                rows: completeStoragePercentage(timedRows),
                windowStart: nil,
                windowEnd: nil
            )
        }

        let start = latest.addingTimeInterval(TimeInterval(-hours * 60 * 60))
        let inWindow = timedRows.filter { $0.date >= start && $0.date <= latest }
        let previousValid = timedRows.reversed().first {
            $0.date < start &&
                start.timeIntervalSince($0.date) <= lineFillLimit &&
                $0.row.storagePercentage != nil
        }

        var result: [DamHistoricalData] = []
        let initialStorage = previousValid?.row.storagePercentage
        var initialDate = previousValid?.date
        if let initialStorage, inWindow.first?.date != start {
            result.append(DamHistoricalData(
                time: TimeFormatters.jstDisplay.string(from: start),
                catchmentAverageRainfall: nil,
                storagePercentage: initialStorage,
                storageVolume: nil,
                inflow: nil,
                outflow: nil
            ))
            initialDate = start
        }
        result += completeStoragePercentage(inWindow, initialStorage: initialStorage, initialDate: initialDate)
        return RealtimeStorageGraphDisplayData(rows: result, windowStart: start, windowEnd: latest)
    }

    /// 表示domainをwindow/行範囲から解決します。
    /// - Parameters:
    ///   - start: 表示ウィンドウの開始日時。
    ///   - end: 表示ウィンドウの終了日時。
    ///   - firstDate: 表示行の先頭日時。
    ///   - lastDate: 表示行の末尾日時。
    /// - Returns: 解決された表示domain。解決できない場合は `nil`。
    internal static func graphDomain(start: Date?, end: Date?, firstDate: Date?, lastDate: Date?) -> ClosedRange<Date>? {
        if let start, let end { return start...end }
        if let first = firstDate, let last = lastDate, last > first { return first...last }
        return nil
    }

    /// グラフの描画に使用するスケール値を決定します。
    /// - Parameters:
    ///   - allRangeValues: 全期間のデータに対するスケール値。
    ///   - selectedRangeValues: 選択された表示期間のデータに対するスケール値。
    ///   - isHistorical: 過去データ検索 (Historical data search) モードかどうかのフラグ。
    /// - Returns: 描画に使用するスケール値。
    internal static func realtimeGraphScaleValues(
        allRangeValues: [Float],
        selectedRangeValues: [Float],
        isHistorical: Bool
    ) -> [Float] {
        isHistorical ? selectedRangeValues : allRangeValues
    }

    /// 与えられた降水量リストから、雨量軸の最大表示値を計算します。
    /// - Parameter values: 雨量のリスト。
    /// - Returns: 計算された雨量軸の最大値。
    internal static func rainfallAxisMax(values: [Float]) -> Double {
        let maxValue = Double(values.max() ?? 0)
        return maxValue > rainfallAxisMaxDefault ? ceil(maxValue / 10.0) * 10.0 : rainfallAxisMaxDefault
    }

    /// 与えられた数値リストの最大値にパディングを加えた値を計算します。
    /// - Parameter values: 数値リスト。
    /// - Returns: パディング適用後の最大値。
    internal static func paddedMax(values: [Float]) -> Double {
        let maxValue = Double(values.max() ?? 0)
        return max(maxValue + max(maxValue, 1) * 0.1, 1)
    }

    /// 与えられた表示範囲サイズに適した「きれいな」目盛り間隔のステップ幅を算出します。
    /// - Parameter range: 表示軸の全範囲。
    /// - Returns: 推奨されるステップ幅。
    internal static func computeNiceStep(range: Double) -> Double {
        guard range > 0 else { return 1 }
        let rawStep = range / 5.0
        let magnitude = pow(10.0, floor(log10(rawStep)))
        let fraction = rawStep / magnitude
        if fraction <= 1 { return magnitude }
        if fraction <= 2 { return 2 * magnitude }
        if fraction <= 5 { return 5 * magnitude }
        return 10 * magnitude
    }

    /// 最大値に基づいて、軸に配置すべき目盛り値のリストを生成します。
    /// - Parameter maxValue: 軸の最大値。
    /// - Returns: 目盛り値のリスト。
    internal static func axisTickValues(maxValue: Double) -> [Double] {
        guard maxValue > 0 else { return [0, 1] }
        let step = computeNiceStep(range: maxValue)
        var values: [Double] = []
        var current = 0.0
        while current <= maxValue + step * 0.01 {
            values.append(current)
            current += step
        }
        return values
    }

    /// 目盛り値を文字列ラベルにフォーマットします。
    /// - Parameters:
    ///   - value: フォーマット対象の目盛り値。
    ///   - fractionDigits: 小数点以下の表示桁数。
    /// - Returns: フォーマットされたラベル文字列。
    internal static func axisTickLabel(_ value: Double, fractionDigits: Int) -> String {
        if fractionDigits <= 0 {
            return "\(Int(value.rounded()))"
        }
        return String(format: "%.\(fractionDigits)f", value)
    }

    /// 昇順ソート済みの日時配列から、指定日時に最も近い要素のindexを二分探索で求めます。
    /// 等距離の場合は先頭側(より過去)を優先します。空配列の場合はnilを返します。
    /// - Parameters:
    ///   - timestamps: 昇順ソート済みの日時配列。
    ///   - date: 最近傍を探す対象の日時。
    /// - Returns: 最も近い要素のindex。空配列の場合は `nil`。
    internal static func nearestIndex(in timestamps: [Date], to date: Date) -> Int? {
        guard !timestamps.isEmpty else { return nil }
        var low = 0
        var high = timestamps.count
        while low < high {
            let mid = (low + high) / 2
            if timestamps[mid] < date {
                low = mid + 1
            } else {
                high = mid
            }
        }
        if low == 0 { return 0 }
        if low == timestamps.count { return timestamps.count - 1 }
        let later = low
        let distanceToEarlier = date.timeIntervalSince(timestamps[low - 1])
        let distanceToLater = timestamps[later].timeIntervalSince(date)
        if distanceToEarlier <= distanceToLater {
            var earlier = low - 1
            while earlier > 0, timestamps[earlier - 1] == timestamps[earlier] {
                earlier -= 1
            }
            return earlier
        }
        return later
    }

    /// 指定されたプロット上のX座標から、最も近い観測行のindexを求めます。
    ///
    /// Swift Chartsの`chartOverlay`はプロット領域の外側（Y軸目盛り、X軸目盛り、
    /// ラベル領域など）から開始したドラッグも通知します。この関数ではY座標を使わず、
    /// X座標だけをプロット領域の左右端へクランプしてから時間へ変換するため、
    /// その領域をドラッグしても選択中のTooltipを維持できます。
    /// - Parameters:
    ///   - x: オーバーレイ座標系のX座標。
    ///   - plotFrame: オーバーレイ座標系のプロット領域。
    ///   - start: X軸表示domainの開始日時。
    ///   - end: X軸表示domainの終了日時。
    ///   - timestamps: 昇順ソート済みの観測日時配列。
    /// - Returns: 最も近い観測行のindex。入力が空または無効な場合は`nil`。
    internal static func nearestIndex(
        atX x: CGFloat,
        plotFrame: CGRect,
        start: Date,
        end: Date,
        timestamps: [Date]
    ) -> Int? {
        guard !timestamps.isEmpty,
              x.isFinite,
              plotFrame.minX.isFinite,
              plotFrame.maxX.isFinite,
              plotFrame.minY.isFinite,
              plotFrame.maxY.isFinite,
              plotFrame.width > 0,
              plotFrame.height > 0 else {
            return nil
        }
        let duration = end.timeIntervalSince(start)
        guard duration.isFinite, duration > 0 else { return nil }

        let clampedX = min(max(x, plotFrame.minX), plotFrame.maxX)
        let fraction = (clampedX - plotFrame.minX) / plotFrame.width
        guard fraction.isFinite else { return nil }
        let date = start.addingTimeInterval(duration * Double(fraction))
        return nearestIndex(in: timestamps, to: date)
    }

    /// 開始時間、終了時間、およびプロット幅から、X軸の目盛りデータを算出します。
    /// - Parameters:
    ///   - start: 開始時間。
    ///   - end: 終了時間。
    ///   - plotWidth: プロットの物理描画幅。
    /// - Returns: 算出された `ChartXAxisTickData`。
    internal static func xAxisTickData(start: Date, end: Date, plotWidth: CGFloat) -> ChartXAxisTickData {
        guard end > start else {
            return ChartXAxisTickData(gridDates: [], tickDates: [], labels: [:])
        }
        let period = end.timeIntervalSince(start)
        let config = xAxisConfig(period: period)
        let gridDates = axisDates(start: start, end: end, granularity: config.gridGranularity)
        let tickDates = axisDates(start: start, end: end, granularity: config.tickGranularity)
        let candidateLabels = tickDates.compactMap { date -> (Date, String)? in
            guard matchesLabel(date, granularity: config.labelGranularity) else { return nil }
            return (date, label(for: date, granularity: config.labelGranularity))
        }
        return ChartXAxisTickData(
            gridDates: gridDates,
            tickDates: tickDates,
            labels: filteredLabels(candidateLabels, start: start, end: end, plotWidth: plotWidth)
        )
    }

    /// 開始時間、終了時間、および各種表示フレーム設定から、X軸グリッド線セグメントのリストを計算します。
    /// - Parameters:
    ///   - start: 開始時間。
    ///   - end: 終了時間。
    ///   - plotFrame: プロットの表示矩形フレーム。
    ///   - plotWidth: プロットの物理描画幅。
    /// - Returns: 軸グリッド線セグメントのリスト。
    internal static func xAxisGridLineSegments(
        start: Date,
        end: Date,
        plotFrame: CGRect,
        plotWidth: CGFloat
    ) -> [ChartAxisGridLineSegment] {
        guard end > start, plotFrame.width > 0, plotFrame.height > 0 else { return [] }
        let ticks = xAxisTickData(start: start, end: end, plotWidth: max(plotWidth, 1))
        return ticks.gridDates.compactMap { date in
            verticalPlotLineSegment(for: date, start: start, end: end, plotFrame: plotFrame)
        }
    }

    /// 重複を避けるためにラベルを間引き、整理したラベル辞書を生成します。
    /// - Parameters:
    ///   - labels: 候補となる（日付、ラベル文字列）のリスト。
    ///   - start: 開始時間。
    ///   - end: 終了時間。
    ///   - plotWidth: プロットの物理描画幅。
    /// - Returns: 間引かれたラベルの辞書。
    internal static func filteredLabels(
        _ labels: [(Date, String)],
        start: Date,
        end: Date,
        plotWidth: CGFloat
    ) -> [Date: String] {
        guard labels.count > 1, end > start, plotWidth > 0 else {
            return Dictionary(uniqueKeysWithValues: labels)
        }
        let period = end.timeIntervalSince(start)
        var accepted: [(Date, String, CGFloat, CGFloat)] = []
        var lastRight = -CGFloat.infinity
        for (date, label) in labels {
            let center = CGFloat(date.timeIntervalSince(start) / period) * plotWidth
            let halfWidth = estimatedLabelWidth(label) / 2
            let left = center - halfWidth
            let right = center + halfWidth
            if accepted.isEmpty || left > lastRight + chartLabelWidthSafetyPadding {
                accepted.append((date, label, left, right))
                lastRight = right
            }
        }
        return Dictionary(uniqueKeysWithValues: accepted.map { ($0.0, $0.1) })
    }

    /// 国土交通省のデータ仕様に基づく日時文字列を日付オブジェクトに変換します。
    /// - Parameter text: ダム時間文字列（例: "2026/06/17 00:00"）。
    /// - Returns: 変換された日付。フォーマットエラーの場合は `nil`。
    internal static func date(fromDamTime text: String) -> Date? {
        TimeFormatters.jstDisplay.date(from: TimeFormatters.normalizeDamTime(text))
    }

    /// 指定された日付に対するプロット上のX座標位置を計算します。
    /// - Parameters:
    ///   - date: 対象の日付。
    ///   - start: 開始時間。
    ///   - end: 終了時間。
    ///   - plotFrame: プロットの表示矩形フレーム。
    /// - Returns: 計算されたX座標。表示範囲外の場合は `nil`。
    internal static func xPosition(for date: Date, start: Date, end: Date, plotFrame: CGRect) -> CGFloat? {
        let period = end.timeIntervalSince(start)
        guard period > 0 else { return nil }
        let fraction = date.timeIntervalSince(start) / period
        guard fraction >= 0, fraction <= 1 else { return nil }
        return plotFrame.minX + CGFloat(fraction) * plotFrame.width
    }

    /// スケール済みY値をプロット領域内のY座標に変換します。
    /// - Parameters:
    ///   - value: スケール済みのY値。
    ///   - plotFrame: プロット領域。
    ///   - upperBound: Y軸の上限。
    /// - Returns: プロット領域内のY座標。
    internal static func yPosition(forScaledValue value: Double, in plotFrame: CGRect, upperBound: Double = chartYScaleUpperBound) -> CGFloat {
        let effectiveUpperBound = max(upperBound, chartScaleMaximum)
        let normalized = min(max(value, 0), effectiveUpperBound) / effectiveUpperBound
        return plotFrame.maxY - CGFloat(normalized) * plotFrame.height
    }

    /// 指定された日付に対する垂直グリッド線セグメントを計算します。
    /// - Parameters:
    ///   - date: 対象の日付。
    ///   - start: 開始時間。
    ///   - end: 終了時間。
    ///   - plotFrame: プロットの表示矩形フレーム。
    /// - Returns: 算出された `ChartAxisGridLineSegment`。計算できなかった場合は `nil`。
    internal static func verticalPlotLineSegment(
        for date: Date,
        start: Date,
        end: Date,
        plotFrame: CGRect
    ) -> ChartAxisGridLineSegment? {
        guard plotFrame.width > 0, plotFrame.height > 0,
              let x = xPosition(for: date, start: start, end: end, plotFrame: plotFrame) else {
            return nil
        }
        return ChartAxisGridLineSegment(x: x, minY: plotFrame.minY, maxY: plotFrame.maxY)
    }

    /// 欠損している貯水率 (Storage rate) のデータを補完します。
    private static func completeStoragePercentage(
        _ timedRows: [(row: DamHistoricalData, date: Date)],
        initialStorage: Float? = nil,
        initialDate: Date? = nil
    ) -> [DamHistoricalData] {
        var lastStorage = initialStorage
        var lastDate = initialDate
        return timedRows.map { item in
            let row = item.row
            let shouldFill = row.storagePercentage == nil &&
                hasAnyObservationValueExceptStoragePercentage(row) &&
                lastStorage != nil &&
                lastDate != nil &&
                item.date.timeIntervalSince(lastDate!) <= lineFillLimit
            let displayRow: DamHistoricalData
            if shouldFill {
                displayRow = DamHistoricalData(
                    time: row.time,
                    catchmentAverageRainfall: row.catchmentAverageRainfall,
                    storagePercentage: lastStorage,
                    storageVolume: row.storageVolume,
                    inflow: row.inflow,
                    outflow: row.outflow
                )
            } else {
                displayRow = row
            }
            if let storage = displayRow.storagePercentage {
                lastStorage = storage
                lastDate = item.date
            }
            return displayRow
        }
    }

    /// 履歴データ配列を日付順にソートします。
    private static func sortedTimedRows(_ rows: [DamHistoricalData]) -> [(row: DamHistoricalData, date: Date)] {
        return rows.compactMap { row in
            date(fromDamTime: row.time).map { (row, $0) }
        }
        .sorted { $0.date < $1.date }
    }

    /// 貯水率 (Storage rate) 以外の観測値が存在するかどうかをチェックします。
    private static func hasAnyObservationValueExceptStoragePercentage(_ row: DamHistoricalData) -> Bool {
        row.catchmentAverageRainfall != nil ||
            row.storageVolume != nil ||
            row.inflow != nil ||
            row.outflow != nil
    }

    /// X軸の細かさを表現する列挙型。
    private enum XAxisGranularity {
        case hourly
        case sixHourly
        case twelveHourly
        case daily
        case weekly
    }

    /// X軸のラベル表示基準を表現する列挙型。
    private enum XAxisLabelGranularity {
        case daily
        case weeklyMonday
    }

    /// X軸の描画設定。
    private struct XAxisConfig {
        let gridGranularity: XAxisGranularity
        let tickGranularity: XAxisGranularity
        let labelGranularity: XAxisLabelGranularity
    }

    /// 時間間隔に応じて最適なX軸の描画構成を決定します。
    private static func xAxisConfig(period: TimeInterval) -> XAxisConfig {
        let day: TimeInterval = 24 * 60 * 60
        if period <= day {
            return XAxisConfig(gridGranularity: .hourly, tickGranularity: .hourly, labelGranularity: .daily)
        }
        if period <= 2 * day {
            return XAxisConfig(gridGranularity: .sixHourly, tickGranularity: .sixHourly, labelGranularity: .daily)
        }
        if period <= 7 * day {
            return XAxisConfig(gridGranularity: .twelveHourly, tickGranularity: .twelveHourly, labelGranularity: .daily)
        }
        if period <= 14 * day {
            return XAxisConfig(gridGranularity: .daily, tickGranularity: .daily, labelGranularity: .daily)
        }
        return XAxisConfig(gridGranularity: .weekly, tickGranularity: .daily, labelGranularity: .weeklyMonday)
    }

    /// 開始日時から終了日時までの、特定粒度の目盛り用日付リストを生成します。
    private static func axisDates(start: Date, end: Date, granularity: XAxisGranularity) -> [Date] {
        let calendar = Calendar.jst
        var current = alignedDate(start, granularity: granularity, calendar: calendar)
        if current < start {
            current = calendar.date(byAdding: component(for: granularity), value: stepValue(for: granularity), to: current) ?? start
        }
        var dates: [Date] = []
        while current <= end {
            dates.append(current)
            current = calendar.date(byAdding: component(for: granularity), value: stepValue(for: granularity), to: current) ?? end.addingTimeInterval(1)
        }
        return dates
    }

    /// 日付をX軸の細かさのグリッド境界に揃えます。
    private static func alignedDate(
        _ date: Date,
        granularity: XAxisGranularity,
        calendar: Calendar
    ) -> Date {
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        components.minute = 0
        components.second = 0
        components.nanosecond = 0
        switch granularity {
        case .hourly:
            break
        case .sixHourly:
            components.hour = ((components.hour ?? 0) / 6) * 6
        case .twelveHourly:
            components.hour = ((components.hour ?? 0) / 12) * 12
        case .daily:
            components.hour = 0
        case .weekly:
            components.hour = 0
            let base = calendar.date(from: components) ?? date
            let weekday = calendar.component(.weekday, from: base)
            let delta = (weekday + 5) % 7
            return calendar.date(byAdding: .day, value: -delta, to: base) ?? base
        }
        return calendar.date(from: components) ?? date
    }

    /// 細かさに応じたカレンダーコンポーネントを返します。
    private static func component(for granularity: XAxisGranularity) -> Calendar.Component {
        switch granularity {
        case .hourly, .sixHourly, .twelveHourly: .hour
        case .daily, .weekly: .day
        }
    }

    /// 細かさに応じたインクリメントのステップ値を返します。
    private static func stepValue(for granularity: XAxisGranularity) -> Int {
        switch granularity {
        case .hourly: 1
        case .sixHourly: 6
        case .twelveHourly: 12
        case .daily: 1
        case .weekly: 7
        }
    }

    /// 指定された日付が、表示ラベル条件に合致するか判定します。
    private static func matchesLabel(_ date: Date, granularity: XAxisLabelGranularity) -> Bool {
        let calendar = Calendar.jst
        let components = calendar.dateComponents([.hour, .minute, .weekday], from: date)
        switch granularity {
        case .daily:
            return components.hour == 0 && components.minute == 0
        case .weeklyMonday:
            return components.hour == 0 && components.minute == 0 && components.weekday == 2
        }
    }

    /// ラベル表記用の文字列を生成します。
    private static func label(for date: Date, granularity: XAxisLabelGranularity) -> String {
        switch granularity {
        case .daily, .weeklyMonday:
            let full = TimeFormatters.jstDateSlash.string(from: date)
            return full.split(separator: "/").suffix(2).joined(separator: "/")
        }
    }

    /// ラベルの推定表示幅をピクセル単位で計算します。
    private static func estimatedLabelWidth(_ label: String) -> CGFloat {
        CGFloat(label.count) * 8 + chartLabelWidthSafetyPadding
    }
}

/// 履歴表示時の開始・終了日時のウィンドウを決定するユーティリティ。
internal enum ObservationHistoryWindow {
    /// 最後に受信した日時データから初期表示すべき開始日時を算出します。
    /// - Parameters:
    ///   - latest: 最新データの受信日時。
    ///   - isHistorical: 過去データ検索 (Historical data search) モードであるかどうかのフラグ。
    /// - Returns: 初期表示ウィンドウの開始日時。
    internal static func initialDisplayFrom(latest: Date?, isHistorical: Bool) -> Date {
        guard let latest else { return .distantFuture }
        if isHistorical {
            return jstCalendar().date(byAdding: .hour, value: -6, to: latest) ?? latest
        }
        let calendar = jstCalendar()
        let flooredHour = calendar.dateInterval(of: .hour, for: latest)?.start ?? latest
        return calendar.date(byAdding: .hour, value: -1, to: flooredHour) ?? flooredHour
    }

    /// 与えられた最古の日付と検索開始文字から、検索開始日時を決定します。
    /// - Parameters:
    ///   - oldest: システム上の最古の日付。
    ///   - searchBgnDate: 検索開始日時を表す文字列 (yyyyMMdd形式など)。
    /// - Returns: 決定された検索開始日時。
    internal static func searchStartDate(oldest: Date?, searchBgnDate: String?) -> Date {
        let oldestDate = oldest ?? .distantFuture
        guard let searchBgnDate,
              let start = jstDayFormatter().date(from: searchBgnDate) else {
            return oldestDate
        }
        return max(start, oldestDate)
    }

    /// 次の表示範囲への切り替え（ページ送りなど）に必要な開始日時を算出します。
    /// - Parameters:
    ///   - currentFrom: 現在表示中の開始日時。
    ///   - searchStart: 検索の限界開始日時。
    ///   - isHistorical: 過去データ検索 (Historical data search) モードであるかどうかのフラグ。
    /// - Returns: 切り替え後の開始日時。
    internal static func nextDisplayFrom(currentFrom: Date, searchStart: Date, isHistorical: Bool) -> Date {
        let days = isHistorical ? -7 : -1
        let next = jstCalendar().date(byAdding: .day, value: days, to: currentFrom) ?? currentFrom
        return max(next, searchStart)
    }

    /// 日本標準時のカレンダーを取得します。
    private static func jstCalendar() -> Calendar {
        Calendar.jst
    }

    /// 日付フォーマッタを取得します。
    private static func jstDayFormatter() -> DateFormatter {
        TimeFormatters.jstDay
    }
}
