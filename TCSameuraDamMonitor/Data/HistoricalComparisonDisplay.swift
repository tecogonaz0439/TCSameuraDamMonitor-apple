// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// 過去比較グラフのTooltip行の表示計算を担う純粋関数群。
nonisolated enum HistoricalComparisonDisplay {
    /// 測定値を表示文字列へ整形します。
    /// - Parameters:
    ///   - value: 測定値。
    ///   - metric: 測定値の種類。
    /// - Returns: 整形された文字列 (貯水率: "%.2f%%"、貯水量: "%.0f×10³m³")。
    static func formatValue(_ value: Float, metric: HistoricalComparisonMetric) -> String {
        switch metric {
        case .storageRate: return String(format: "%.2f%%", value)
        case .storageVolume: return String(format: "%.0f×10³m³", value)
        }
    }

    /// 欠測時の表示文字列を返します。
    /// - Parameter metric: 測定値の種類。
    /// - Returns: 欠測時の文字列 ("--%" / "--×10³m³")。
    static func missingValueText(metric: HistoricalComparisonMetric) -> String {
        switch metric {
        case .storageRate: return "--%"
        case .storageVolume: return "--×10³m³"
        }
    }

    /// 年の表示ラベルを返します。
    /// - Parameters:
    ///   - year: 年。
    ///   - isJapanese: 日本語ラベルを使うかどうか。
    /// - Returns: ラベル (日本語: "\(year)年"、英語: "\(year)")。
    static func yearLabel(_ year: Int, isJapanese: Bool) -> String {
        isJapanese ? "\(year)年" : "\(year)"
    }

    /// 表示domain内の系列点のみを返します(境界は両端含む)。
    ///
    /// 期間選択でX軸domainが縮小された場合に、domain外の毎時点を描画対象から除き、
    /// Swift Chartsがプロット領域外へ線をはみ出させないために使います。
    /// - Parameters:
    ///   - points: 系列点の一覧。
    ///   - domain: 表示domain。
    /// - Returns: domain内の系列点の一覧。
    static func visiblePoints(_ points: [HistoricalComparisonSeriesPoint],
                              in domain: ClosedRange<Date>) -> [HistoricalComparisonSeriesPoint] {
        points.filter { $0.date >= domain.lowerBound && $0.date <= domain.upperBound }
    }

    /// domain内の系列点に、左右端まで線を延長するためのクランプ点を加えて返します。
    ///
    /// 毎時00分の観測点のみで構成される過去年の線が、domainの両端(例: 最新リアルタイム時刻や
    /// それからN時間前の中間時刻)で欠けて見えるのを防ぎます。左端はdomain直前の毎時観測値を
    /// `lowerBound` へクランプした点を先頭に加え、右端は末尾の毎時観測値を `upperBound` へ
    /// クランプした点を末尾に加えます。明示欠測(値nil)は跨がず、domain外の点は描画しません。
    /// - Parameters:
    ///   - points: 系列点の一覧。
    ///   - domain: 表示domain。
    /// - Returns: domain内の点と左右端のクランプ点の一覧。
    static func edgeExtendedPoints(_ points: [HistoricalComparisonSeriesPoint],
                                   in domain: ClosedRange<Date>) -> [HistoricalComparisonSeriesPoint] {
        let inDomain = visiblePoints(points, in: domain)
        guard let first = inDomain.first, let last = inDomain.last else { return inDomain }
        var result = inDomain
        if first.date > domain.lowerBound,
           let pre = points.last(where: { $0.date < domain.lowerBound }),
           pre.value != nil, first.value != nil {
            result.insert(
                HistoricalComparisonSeriesPoint(
                    id: "\(first.id)-edgeLower",
                    date: domain.lowerBound,
                    value: pre.value,
                    rawTime: pre.rawTime
                ),
                at: 0
            )
        }
        if last.date < domain.upperBound, last.value != nil {
            result.append(
                HistoricalComparisonSeriesPoint(
                    id: "\(last.id)-edgeUpper",
                    date: domain.upperBound,
                    value: last.value,
                    rawTime: last.rawTime
                )
            )
        }
        return result
    }

    /// 履歴mode Tooltipの年別行を返します(1行目のJST日時は呼び出し側で付与)。
    ///
    /// 比較年の値は `selectedDate` をJSTの時単位へfloorし、各seriesの該当時刻と一致する点を使います。
    /// 比較年行はホバー時刻に値がある年のみ表示します(値nilの年は行自体を出しません)。
    /// 主系列年(`mainYear`)行は値がnilでも常時表示します。
    /// 順位は数値降順、同値は主系列年優先、その後年降順です(欠測は主系列年のみ末尾候補)。
    /// `pastSeries.count <= 8` は主系列年+比較年を全行表示し、9以上は top3・":"・主系列年・":"・worst3 へ圧縮します
    /// (top/worstの重複年はworst側から除外。主系列年がtop/worst入りなら区切り1個のみ)。
    /// - Parameters:
    ///   - selectedDate: Tooltip対象の選択日時。
    ///   - currentYearValue: 主系列年の値(nil=欠測)。
    ///   - pastSeries: 選択年のみのseries(表示対象)。
    ///   - metric: 測定値の種類。
    ///   - isJapanese: 日本語ラベルを使うかどうか。
    ///   - calendar: JSTの時単位floorに使うカレンダー。
    ///   - mainYear: 主系列の年(通常の過去データ表示では表示対象データの年、他はJST現在年)。
    /// - Returns: 年別行の一覧。
    static func yearValueLines(selectedDate: Date,
                               currentYearValue: Float?,
                               pastSeries: [HistoricalComparisonSeries],
                               metric: HistoricalComparisonMetric,
                               isJapanese: Bool,
                               calendar: Calendar,
                               mainYear: Int) -> [String] {
        guard let floored = floorJstHour(selectedDate, calendar: calendar) else { return [] }
        let pastRows: [TooltipRow] = pastSeries.compactMap { series in
            let index = binarySearchFirstIndex(of: floored, in: series.points)
            guard let value = index.flatMap({ series.points[$0].value }) else { return nil }
            return TooltipRow(year: series.year, current: false, value: value)
        }
        let rows = pastRows + [TooltipRow(year: mainYear, current: true, value: currentYearValue)]
        let displayed = pastSeries.count <= 8 ? sorted(rows) : compressed(rows, currentYear: mainYear)
        return displayed.map { row in
            guard !row.isSeparator else { return ":" }
            let valueText = row.value.map { formatValue($0, metric: metric) } ?? missingValueText(metric: metric)
            return "\(yearLabel(row.year, isJapanese: isJapanese)): \(valueText)"
        }
    }

    /// 表示domain内で線が実際に描かれる過去年の集合を返します。
    ///
    /// 過去年の線は表示domain内に正常観測値(値nilでない点)が1つでもあれば描画され
    /// (左右端のクランプ点も正常観測値を起点とする)、全点nilの空系列は線が描かれません。
    /// mode 3/4のツールチップ比較対象を「選択中かつ線が表示されている年」へ絞るために使います。
    /// - Parameters:
    ///   - pastSeries: 過去年の系列一覧。
    ///   - domain: 表示domain。
    /// - Returns: domain内で線が描かれる年の集合。
    static func drawnPastYears(_ pastSeries: [HistoricalComparisonSeries],
                               in domain: ClosedRange<Date>) -> Set<Int> {
        Set(pastSeries.filter { series in
            series.points.contains {
                $0.date >= domain.lowerBound && $0.date <= domain.upperBound && $0.value != nil
            }
        }.map(\.year))
    }

    /// ツールチップの年別行の比較対象となる過去年の系列を返します。
    ///
    /// 「選択中(年チップ)かつ線が実際に描かれる年」のみを対象にします。
    /// 主系列年行はここに含めず、常に `yearValueLines` 側で追加されます。
    /// - Parameters:
    ///   - selectedYears: 選択中の年集合(今年を含む)。
    ///   - drawnYears: 表示domain内で線が描かれる年の集合。
    ///   - pastSeries: 過去年の系列一覧。
    /// - Returns: ツールチップ比較対象の過去年の系列。
    static func tooltipPastSeries(selectedYears: Set<Int>,
                                  drawnYears: Set<Int>,
                                  pastSeries: [HistoricalComparisonSeries]) -> [HistoricalComparisonSeries] {
        pastSeries.filter { selectedYears.contains($0.year) && drawnYears.contains($0.year) }
    }

    /// 昇順ソート済みの系列点から、指定日時に一致する最初のindexを二分探索で求めます。
    /// 一致する点が無い場合はnilを返します。
    /// - Parameters:
    ///   - date: 探索対象の日時。
    ///   - points: 日時で昇順ソートされた系列点。
    /// - Returns: 一致する最初の系列点のindex。一致しない場合は `nil`。
    private static func binarySearchFirstIndex(of date: Date, in points: [HistoricalComparisonSeriesPoint]) -> Int? {
        var low = 0
        var high = points.count
        while low < high {
            let mid = (low + high) / 2
            if points[mid].date < date {
                low = mid + 1
            } else {
                high = mid
            }
        }
        guard low < points.count, points[low].date == date else { return nil }
        return low
    }

    /// 順位付けの対象となる1行分の情報を表す構造体。
    private struct TooltipRow {
        let year: Int
        let current: Bool
        let value: Float?
        /// 区切り行かどうか。
        let isSeparator: Bool

        init(year: Int, current: Bool, value: Float?) {
            self.year = year
            self.current = current
            self.value = value
            self.isSeparator = false
        }

        init(isSeparator: Bool) {
            self.year = 0
            self.current = false
            self.value = nil
            self.isSeparator = isSeparator
        }
    }

    /// 行を数値降順 → 主系列年優先 → 年降順 → 欠測末尾(年降順)で並べ替えます。
    private static func sorted(_ rows: [TooltipRow]) -> [TooltipRow] {
        rows.sorted { left, right in
            switch (left.value, right.value) {
            case (nil, nil): return left.year > right.year
            case (nil, _): return false
            case (_, nil): return true
            case let (leftValue?, rightValue?):
                if leftValue != rightValue { return leftValue > rightValue }
                if left.current != right.current { return left.current }
                return left.year > right.year
            }
        }
    }

    /// 行を top3・":"・主系列年・":"・worst3 へ圧縮します。
    private static func compressed(_ rows: [TooltipRow], currentYear: Int) -> [TooltipRow] {
        let numeric = sorted(rows.filter { $0.value != nil })
        let top = Array(numeric.prefix(3))
        let topYears = Set(top.map(\.year))
        let worst = numeric.suffix(3).filter { !topYears.contains($0.year) }
        let current = rows.first { $0.current && $0.year == currentYear }
            ?? TooltipRow(year: currentYear, current: true, value: nil)
        let currentRanked = topYears.contains(currentYear) || worst.contains { $0.year == currentYear }
        let separator = TooltipRow(isSeparator: true)
        if currentRanked {
            return top + [separator] + Array(worst)
        }
        return top + [separator] + [current] + [separator] + Array(worst)
    }

    /// 日時をJSTの時単位へfloorします。
    private static func floorJstHour(_ date: Date, calendar: Calendar) -> Date? {
        let comps = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        var floored = DateComponents()
        floored.calendar = calendar
        floored.timeZone = calendar.timeZone
        floored.year = comps.year
        floored.month = comps.month
        floored.day = comps.day
        floored.hour = comps.hour
        floored.minute = 0
        return calendar.date(from: floored)
    }
}

/// 過去比較グラフの過去年の選択状態遷移を担う純粋関数群。
nonisolated enum HistoricalYearSelection {
    /// Allチップのトグル遷移を返します。
    ///
    /// 全選択中なら全解除(空集合)へ、それ以外は全選択へ遷移します。Allの状態は集合から導出します。
    /// - Parameters:
    ///   - current: 現在の選択年集合。
    ///   - allYears: 全選択対象の年集合。
    /// - Returns: 遷移後の選択年集合。
    static func togglingAll(_ current: Set<Int>, allYears: Set<Int>) -> Set<Int> {
        isAllSelected(current, allYears: allYears) ? [] : allYears
    }

    /// 個別年のトグル遷移を返します。
    ///
    /// 最後の未選択年を選択すると自動的に全選択集合になります(全選択状態は集合から導出)。
    /// - Parameters:
    ///   - year: トグル対象の年。
    ///   - current: 現在の選択年集合。
    /// - Returns: 遷移後の選択年集合。
    static func togglingYear(_ year: Int, current: Set<Int>) -> Set<Int> {
        var next = current
        if next.contains(year) {
            next.remove(year)
        } else {
            next.insert(year)
        }
        return next
    }

    /// 現在の選択集合が全選択かどうかを返します。
    /// - Parameters:
    ///   - current: 現在の選択年集合。
    ///   - allYears: 全選択対象の年集合。
    /// - Returns: 全選択なら `true`。
    static func isAllSelected(_ current: Set<Int>, allYears: Set<Int>) -> Bool {
        !allYears.isEmpty && current.isSuperset(of: allYears)
    }
}
