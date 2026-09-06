// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// 過去比較グラフで比較する測定値の種類を表す列挙型。
nonisolated enum HistoricalComparisonMetric: String, CaseIterable, Sendable, Hashable {
    /// 貯水率 (%)
    case storageRate
    /// 貯水量 (万立方メートル)
    case storageVolume
}

/// 過去比較グラフにおける1年分の系列を表す構造体。
nonisolated struct HistoricalComparisonSeries: Identifiable, Sendable, Hashable {
    /// 比較年。
    let year: Int
    /// 系列の点の一覧(今年のJST軸に対応)。
    let points: [HistoricalComparisonSeriesPoint]
    /// 識別子としての年。
    var id: Int { year }
}

/// 過去比較グラフの1時間単位の系列点を表す構造体。
nonisolated struct HistoricalComparisonSeriesPoint: Identifiable, Sendable, Hashable {
    /// 識別子 ("\(year)-\(index)")。
    let id: String
    /// 今年のJST軸へ写像済みの日時(毎時00分)。
    let date: Date
    /// 値。nilは明示欠測(異常値・未収録)。
    let value: Float?
    /// 元の観測日時文字列。
    let rawTime: String
}

/// 過去比較グラフの読み込み結果全体を保持する構造体。
nonisolated struct HistoricalComparisonPayload: Sendable, Hashable {
    /// 比較対象の測定値の種類。
    let metric: HistoricalComparisonMetric
    /// JST現在年。
    let currentYear: Int
    /// 主系列の年(通常の過去データ表示では表示対象データの年、リアルタイム・日次ではJST現在年)。
    let mainYear: Int
    /// 比較可能な比較年の一覧 (2002...currentYear から mainYear を除いた年。mainYearがJST現在年の場合は 2002...(currentYear-1))。
    let availablePastYears: [Int]
    /// 毎時axisの先頭(今年のJST時刻)。
    let periodStart: Date?
    /// 毎時axisの末尾(今年のJST時刻)。
    let periodEnd: Date?
    /// 過去年の系列(年昇順、全available年を含む。空系列可)。
    let pastSeries: [HistoricalComparisonSeries]
}

/// 過去比較グラフの読み込み状態を表す列挙型。
nonisolated enum HistoricalComparisonLoadState: Sendable, Equatable {
    /// 初期状態。
    case idle
    /// 読み込み中。
    case loading
    /// 読み込み完了。
    case ready(HistoricalComparisonPayload)
    /// 読み込み失敗。
    case failed
}

/// metric非依存の過去比較データ基底。assetsの読込と系列組立を一度だけ行い、metric別payloadはここから派生します。
nonisolated struct HistoricalComparisonBase: Sendable, Hashable {
    /// JST現在年。
    let currentYear: Int
    /// 主系列の年(通常の過去データ表示では表示対象データの年、リアルタイム・日次ではJST現在年)。
    let mainYear: Int
    /// 比較可能な比較年の一覧 (2002...currentYear から mainYear を除いた年)。
    let availablePastYears: [Int]
    /// 毎時axisの先頭(今年のJST時刻)。
    let periodStart: Date?
    /// 毎時axisの末尾(今年のJST時刻)。
    let periodEnd: Date?
    /// 毎時axis。
    let axis: [Date]
    /// 年ごとの毎時axis写像結果(axisと同数要素。写像不能はnil)。エントリが無い年はキー無し。
    let yearMappings: [Int: [Date?]]
    /// 年ごとの読込点lookup(正規化日時→点、初出優先)。エントリが無い年はキー無し。
    let yearLookups: [Int: [Date: HistoricalComparisonMonthProjection.Point]]
}

/// 過去比較グラフの読み込み中に発生するエラーを表す列挙型。
nonisolated enum HistoricalComparisonServiceError: Error, Equatable, Sendable {
    /// 対象外のダム。
    case unsupportedDam
    /// データ行が空。
    case noRows
    /// 索引に存在するassetの欠落・parse失敗。
    case assetLoadFailed(String)
}

/// 過去比較グラフ用の年写像・月次asset読込・系列組立を担うサービス。
nonisolated struct HistoricalComparisonService: Sendable {
    /// 比較可能な最古年。
    static let firstComparisonYear = 2002
    /// 早明浦ダムの観測所ID。
    static let sameuraDamId = "1368080700010"

    /// 年写像・JST時刻計算に使うカレンダー(既定 Calendar.jst)。
    let calendar: Calendar
    /// 現在日時を返すクロージャ(注入可能)。
    let now: @Sendable () -> Date
    /// 月次projectionの読込ストア。
    let assetStore: HistoricalComparisonAssetStore

    /// サービスを初期化します。
    /// - Parameters:
    ///   - calendar: 使用するカレンダー。デフォルトは `Calendar.jst` です。
    ///   - now: 現在日時を返すクロージャ。デフォルトは `Date()` です。
    ///   - assetStore: 月次projectionの読込ストア。デフォルトはバンドルアセットを使うストアです。
    init(calendar: Calendar = Calendar.jst,
         now: @escaping @Sendable () -> Date = { Date() },
         assetStore: HistoricalComparisonAssetStore = HistoricalComparisonAssetStore()) {
        self.calendar = calendar
        self.now = now
        self.assetStore = assetStore
    }

    /// JST現在年を返します。端末のタイムゾーンには依存しません。
    /// - Returns: JST現在年。
    func currentJstYear() -> Int {
        calendar.component(.year, from: now())
    }

    /// 比較可能な過去年の一覧 (2002...(JST現在年-1)) を返します。端末のタイムゾーンには依存しません。
    /// 今年は `currentJstYear()` で取得します(年チップの対象年は過去年+今年で組み立てる)。
    /// 通常の過去データ表示の比較年とは異なり、この一覧はチップ表示用で、主系列年・最新年は含みません。
    /// - Returns: 過去年の一覧。JST現在年が2002以下なら空配列。
    func availablePastYears() -> [Int] {
        let currentYear = currentJstYear()
        guard currentYear > Self.firstComparisonYear else { return [] }
        return Array(Self.firstComparisonYear..<currentYear)
    }

    /// 早明浦ダムの現在の観測行を比較年の系列へ写像して過去比較ペイロードを組み立てます。
    ///
    /// metric非依存の比較基底を読み込み(`loadBase`)、そこから指定Metricのペイロードを同期派生します。
    /// - Parameters:
    ///   - damConfigId: ダム構成設定ID。早明浦以外は `unsupportedDam` で失敗します。
    ///   - rows: 現在の観測行。
    ///   - metric: 比較対象の測定値の種類。
    ///   - mainYear: 主系列の年。未指定時はJST現在年(リアルタイム・日次の従来挙動)。
    ///   - dailyRows: 読込済み日次過去データの行(通常の過去データ表示で最新年の比較系列へ合成する)。
    /// - Returns: 過去比較ペイロード。
    /// - Throws: `HistoricalComparisonServiceError` 対象外ダム・データなし・asset読込失敗。
    func load(damConfigId: String, rows: [DamHistoricalData],
              metric: HistoricalComparisonMetric,
              mainYear: Int? = nil,
              dailyRows: [DamHistoricalData] = []) async throws -> HistoricalComparisonPayload {
        let base = try await loadBase(damConfigId: damConfigId, rows: rows,
                                      mainYear: mainYear, dailyRows: dailyRows)
        return payload(from: base, metric: metric)
    }

    /// metric非依存の過去比較データ基底を読み込みます。
    ///
    /// 全比較年の必要month entryをまとめて列挙し、filePathで重複排除した上で
    /// 一度の`projections(for:)`呼び出しへ渡します(ストア内部で全体最大4並列)。
    /// 年ごとの毎時写像と読込点lookupはmetric非依存で保持し、metric別payloadは
    /// `payload(from:metric:)`から同期派生します。写像できない年(2/29等)や
    /// 交差するmonth entryが無い年は、基底から除外し派生時に空系列とします。
    ///
    /// 主系列年(`mainYear`)がJST現在年と異なる通常の過去データ表示では、比較年は
    /// 2002〜JST現在年から主系列年を除いた全て(最新年=JST現在年を含む)とし、
    /// 最新年の比較系列はバンドル月次値の上に `dailyRows` を合成します
    /// (日次行はJST時floorで軸へ写像し、非null値のみ上書き。両方に無い期間はnull)。
    /// `mainYear` 未指定時は主系列年=JST現在年となり、従来挙動(2002..<JST現在年)と同一です。
    /// - Parameters:
    ///   - damConfigId: ダム構成設定ID。早明浦以外は `unsupportedDam` で失敗します。
    ///   - rows: 現在の観測行。
    ///   - mainYear: 主系列の年。未指定時はJST現在年。
    ///   - dailyRows: 読込済み日次過去データの行(最新年の比較系列への合成用)。
    /// - Returns: metric非依存の過去比較データ基底。
    /// - Throws: `HistoricalComparisonServiceError` 対象外ダム・データなし・asset読込失敗。
    func loadBase(damConfigId: String, rows: [DamHistoricalData],
                  mainYear: Int? = nil,
                  dailyRows: [DamHistoricalData] = []) async throws -> HistoricalComparisonBase {
        guard damConfigId == Self.sameuraDamId else { throw HistoricalComparisonServiceError.unsupportedDam }
        guard !rows.isEmpty else { throw HistoricalComparisonServiceError.noRows }
        let baseYear = mainYear ?? currentJstYear()
        let clockYear = currentJstYear()
        let datedRows = rows
            .compactMap { row -> (Date, DamHistoricalData)? in
                guard let millis = TimeFormatters.millisIfValid(fromDamTime: row.time) else { return nil }
                return (Date(timeIntervalSince1970: millis / 1000), row)
            }
            .sorted { $0.0 < $1.0 }
        guard let firstRow = datedRows.first, let lastRow = datedRows.last else {
            throw HistoricalComparisonServiceError.noRows
        }
        let axis = Self.hourlyAxis(from: firstRow.0, to: lastRow.0, calendar: calendar)
        let pastYears = Self.comparisonYears(forBaseYear: baseYear, clockYear: clockYear)
        var yearMappings: [Int: [Date?]] = [:]
        var unionEntries: [(entry: HistoricalDatFileEntry, year: Int)] = []
        var seenPaths: Set<String> = []
        for year in pastYears {
            let mapped = axis.map { Self.mapDate($0, from: baseYear, to: year, calendar: calendar) }
            let valid = axis.indices.compactMap { index in mapped[index].map { (index, $0) } }
            guard let readStart = valid.first?.1, let readEnd = valid.last?.1 else { continue }
            let entries = Self.monthEntries(entries: assetStore.entries, stationId: Self.sameuraDamId,
                                            start: readStart, end: readEnd, calendar: calendar)
            guard !entries.isEmpty else { continue }
            yearMappings[year] = mapped
            for entry in entries where !seenPaths.contains(entry.filePath) {
                seenPaths.insert(entry.filePath)
                unionEntries.append((entry, year))
            }
        }
        let projections = try await assetStore.projections(for: unionEntries.map(\.entry))
        var yearLookups: [Int: [Date: HistoricalComparisonMonthProjection.Point]] = [:]
        for (projection, pair) in zip(projections, unionEntries) {
            var lookup = yearLookups[pair.year] ?? [:]
            for point in projection.points where lookup[point.date] == nil {
                lookup[point.date] = point
            }
            yearLookups[pair.year] = lookup
        }
        if baseYear != clockYear, pastYears.contains(clockYear) {
            if yearMappings[clockYear] == nil {
                yearMappings[clockYear] = axis.map { Self.mapDate($0, from: baseYear, to: clockYear, calendar: calendar) }
            }
            var merged = yearLookups[clockYear] ?? [:]
            for row in dailyRows {
                guard let millis = TimeFormatters.millisIfValid(fromDamTime: row.time) else { continue }
                let rowDate = Date(timeIntervalSince1970: millis / 1000)
                guard let floored = Self.floorHour(rowDate, calendar: calendar),
                      let baseAxisDate = Self.mapDate(floored, from: clockYear, to: baseYear, calendar: calendar),
                      let index = axis.firstIndex(of: baseAxisDate),
                      let mappedForClock = yearMappings[clockYear],
                      let key = mappedForClock[index] else { continue }
                guard row.storagePercentage != nil || row.storageVolume != nil else { continue }
                let existing = merged[key]
                merged[key] = HistoricalComparisonMonthProjection.Point(
                    date: key,
                    storagePercentage: row.storagePercentage ?? existing?.storagePercentage,
                    storageVolume: row.storageVolume ?? existing?.storageVolume,
                    rawTime: row.time
                )
            }
            if !merged.isEmpty {
                yearLookups[clockYear] = merged
            }
        }
        return HistoricalComparisonBase(
            currentYear: clockYear,
            mainYear: baseYear,
            availablePastYears: pastYears,
            periodStart: axis.first,
            periodEnd: axis.last,
            axis: axis,
            yearMappings: yearMappings,
            yearLookups: yearLookups
        )
    }

    /// metric非依存の過去比較データ基底から指定Metricのペイロードを同期派生します。
    ///
    /// I/Oを行いません。`yearMappings`/`yearLookups`にエントリが無い年は、
    /// 全点nil・rawTime空文字の空系列(従来の`emptySeries`相当)になります。
    /// - Parameters:
    ///   - base: `loadBase(damConfigId:rows:)`が返したmetric非依存の比較基底。
    ///   - metric: 比較対象の測定値の種類。
    /// - Returns: 過去比較ペイロード。
    func payload(from base: HistoricalComparisonBase, metric: HistoricalComparisonMetric) -> HistoricalComparisonPayload {
        let series = base.availablePastYears.map { year -> HistoricalComparisonSeries in
            guard let mapped = base.yearMappings[year] else {
                return emptySeries(year: year, axis: base.axis)
            }
            return HistoricalComparisonSeries(
                year: year,
                points: base.axis.indices.map { index -> HistoricalComparisonSeriesPoint in
                    let point = mapped[index].flatMap { base.yearLookups[year]?[$0] }
                    return HistoricalComparisonSeriesPoint(
                        id: "\(year)-\(index)",
                        date: base.axis[index],
                        value: point.flatMap { value(from: $0, metric: metric) },
                        rawTime: point?.rawTime ?? ""
                    )
                }
            )
        }
        return HistoricalComparisonPayload(
            metric: metric,
            currentYear: base.currentYear,
            mainYear: base.mainYear,
            availablePastYears: base.availablePastYears,
            periodStart: base.periodStart,
            periodEnd: base.periodEnd,
            pastSeries: series
        )
    }

    /// 比較年の一覧 (2002...clockYear から baseYear を除いた年) を返します。
    ///
    /// `baseYear == clockYear`(リアルタイム・日次の従来挙動)の場合は 2002..<clockYear と同一です。
    /// clockYear が 2002 未満の場合は空配列です。
    /// - Parameters:
    ///   - baseYear: 主系列の年。
    ///   - clockYear: JST現在年。
    /// - Returns: 比較年の一覧(昇順)。
    static func comparisonYears(forBaseYear baseYear: Int, clockYear: Int) -> [Int] {
        guard clockYear >= Self.firstComparisonYear else { return [] }
        return (Self.firstComparisonYear...clockYear).filter { $0 != baseYear }
    }

    /// 今年の日時を比較年へ写像します。
    ///
    /// 月日時分を保持したまま年だけを `targetYear + (元の年 - baseYear)` へ移します。
    /// 非うるう年の2/29は `nil` を返します(2/28・3/1へ丸めません)。
    /// Foundationの `Calendar.date(from:)` は不正な日付を正規化して返すことがあるため、
    /// 写像結果を日付要素で照合して丸めを検出します。
    /// - Parameters:
    ///   - date: 写像元の日時。
    ///   - baseYear: 写像元の基準年。
    ///   - targetYear: 写像先の年。
    ///   - calendar: 使用するカレンダー。
    /// - Returns: 写像後の日時。写像できない場合は `nil`。
    static func mapDate(_ date: Date, from baseYear: Int, to targetYear: Int,
                        calendar: Calendar) -> Date? {
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard let year = comps.year else { return nil }
        var mapped = DateComponents()
        mapped.calendar = calendar
        mapped.timeZone = calendar.timeZone
        mapped.year = targetYear + (year - baseYear)
        mapped.month = comps.month
        mapped.day = comps.day
        mapped.hour = comps.hour
        mapped.minute = comps.minute
        let requestedYear = mapped.year
        let requestedMonth = mapped.month
        let requestedDay = mapped.day
        let requestedHour = mapped.hour
        let requestedMinute = mapped.minute
        guard let result = calendar.date(from: mapped) else { return nil }
        let roundTrip = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: result)
        guard roundTrip.year == requestedYear, roundTrip.month == requestedMonth,
              roundTrip.day == requestedDay, roundTrip.hour == requestedHour,
              roundTrip.minute == requestedMinute else {
            return nil
        }
        return result
    }

    /// JSTの時単位へfloorした毎時axisを返します。
    ///
    /// start/endを時単位へfloorし、両端を含む1時間刻みのリストを返します。endがstartより前の場合は空配列です。
    /// - Parameters:
    ///   - start: 開始日時。
    ///   - end: 終了日時。
    ///   - calendar: 使用するカレンダー。
    /// - Returns: 毎時axisのリスト。
    static func hourlyAxis(from start: Date, to end: Date, calendar: Calendar) -> [Date] {
        guard end >= start else { return [] }
        guard let first = floorHour(start, calendar: calendar),
              let last = floorHour(end, calendar: calendar) else { return [] }
        var axis: [Date] = []
        var current = first
        while current <= last {
            axis.append(current)
            guard let next = calendar.date(byAdding: .hour, value: 1, to: current) else { break }
            current = next
        }
        return axis
    }

    /// 期間(開始前日まで拡張)と交差する月次エントリを開始順で返します。
    ///
    /// 各エントリの月区間 `[月初00:00, 翌月初00:00)` と `[start-1日, end]` の交差判定を行います。
    /// 開始前日まで拡張することで、6/1 00:00の点を5月ファイルの24:00行から読めるようにします。
    /// - Parameters:
    ///   - entries: 月次エントリの一覧。
    ///   - stationId: 観測所ID。
    ///   - start: 開始日時。
    ///   - end: 終了日時。
    ///   - calendar: 使用するカレンダー。
    /// - Returns: 交差するエントリの開始順の一覧。
    static func monthEntries(entries: [HistoricalDatFileEntry], stationId: String,
                             start: Date, end: Date, calendar: Calendar) -> [HistoricalDatFileEntry] {
        let extendedStart = calendar.date(byAdding: .day, value: -1, to: start) ?? start
        return entries
            .filter { $0.stationId == stationId }
            .filter { entry in
                guard let monthStart = monthStart(of: entry, calendar: calendar),
                      let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
                    return false
                }
                return monthStart <= end && nextMonth > extendedStart
            }
            .sorted { $0.startDatetime < $1.startDatetime }
    }

    /// 全欠測の空系列を組み立てます。
    private func emptySeries(year: Int, axis: [Date]) -> HistoricalComparisonSeries {
        HistoricalComparisonSeries(
            year: year,
            points: axis.indices.map { index in
                HistoricalComparisonSeriesPoint(id: "\(year)-\(index)", date: axis[index], value: nil, rawTime: "")
            }
        )
    }

    /// 指定された測定値の種類に応じてprojectionの点から値を取り出します。
    private func value(from point: HistoricalComparisonMonthProjection.Point,
                       metric: HistoricalComparisonMetric) -> Float? {
        switch metric {
        case .storageRate: return point.storagePercentage
        case .storageVolume: return point.storageVolume
        }
    }

    /// 日時を時単位へfloorします。
    private static func floorHour(_ date: Date, calendar: Calendar) -> Date? {
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

    /// エントリの月の月初00:00(JST)を返します。
    private static func monthStart(of entry: HistoricalDatFileEntry, calendar: Calendar) -> Date? {
        let prefix = entry.startDatetime.prefix(6)
        guard prefix.count == 6, let year = Int(prefix.prefix(4)), let month = Int(prefix.suffix(2)) else {
            return nil
        }
        var comps = DateComponents()
        comps.calendar = calendar
        comps.timeZone = calendar.timeZone
        comps.year = year
        comps.month = month
        comps.day = 1
        comps.hour = 0
        comps.minute = 0
        return calendar.date(from: comps)
    }
}
