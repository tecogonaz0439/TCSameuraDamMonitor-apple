// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation
import SwiftData

/// 過去データ検索 (Historical data search) の結果情報を保持する構造体。
internal struct HistoricalSearchResult: Sendable {
    /// 検索メタデータ情報。
    internal let meta: HistoricalSearchMeta
    /// 取得された履歴ダムデータの配列。
    internal let rows: [DamHistoricalData]
    /// データが最終的に充足されたデータソース。
    internal let source: HistoricalSearchSource
}

/// 過去データ検索が最終的にどのデータソースで充足されたか。
internal enum HistoricalSearchSource: Sendable {
    /// バンドルされたローカルアセットデータ。
    case bundled
    /// sudmonitor 中継サーバー。
    case sudmonitor
    /// 国土交通省 (MLIT) からの直接取得。
    case mlit
}

/// 過去データ検索 (Historical data search) の実行、キャッシュ判定、データベース保存を担当するサービス構造体。
@MainActor
internal struct HistoricalSearchService {
    /// HTMLおよびDATデータ解析用パーサー。
    internal let parser: MlitDamParser
    /// ネットワークアクセス用のデータソース。
    internal let network: MlitNetworkDataSource
    /// ローカルの過去データアセットストア。
    internal let historicalAssets: HistoricalAssetStore
    /// ネットワークの接続可能性を提供するプロバイダ。
    internal let networkAvailability: any NetworkAvailabilityProviding
    /// sudmonitor 履歴ファイル取得クライアント。
    internal let sudmonitorClient: SudmonitorHistoricalClient

    /// 過去検索サービスを初期化します。
    /// - Parameters:
    ///   - parser: 解析用パーサー。
    ///   - network: ネットワークデータソース。
    ///   - historicalAssets: ローカルアセットストア。
    ///   - networkAvailability: ネットワークの接続可能性プロバイダ。
    ///   - sudmonitorClient: sudmonitor 履歴ファイル取得クライアント。
    internal init(
        parser: MlitDamParser,
        network: MlitNetworkDataSource,
        historicalAssets: HistoricalAssetStore,
        networkAvailability: any NetworkAvailabilityProviding,
        sudmonitorClient: SudmonitorHistoricalClient
    ) {
        self.parser = parser
        self.network = network
        self.historicalAssets = historicalAssets
        self.networkAvailability = networkAvailability
        self.sudmonitorClient = sudmonitorClient
    }

    /// 指定されたダムおよび期間に対する過去データ検索 (Historical data search) を実行し、結果をデータベースへ保存して返します。
    /// - Parameters:
    ///   - damConfig: 対象のダム構成設定。
    ///   - startDate: 検索開始日。
    ///   - endDate: 検索終了日。
    ///   - historicalDataSource: 過去データ検索のデータソース設定。
    ///   - context: SwiftData のモデルコンテキスト。
    ///   - maxSearchCount: 許容する最大検索履歴保持件数。
    /// - Returns: 検索および永続化結果。
    /// - Throws: `AppError` 重複エラー、上限超過エラー、取得エラーなど。
    internal func search(
        damConfig: DamConfig,
        startDate: Date,
        endDate: Date,
        historicalDataSource: RealtimeDataSource,
        context: ModelContext,
        maxSearchCount: Int
    ) async throws -> HistoricalSearchResult {
        let start = TimeFormatters.jstDay.string(from: startDate)
        let end = TimeFormatters.jstDay.string(from: endDate)
        let existing = try context.fetch(FetchDescriptor<HistoricalSearchMetaRecord>())
        if existing.contains(where: { $0.damConfigId == damConfig.id && $0.searchBgnDate == start && $0.searchEndDate == end }) {
            throw AppError.duplicateHistoricalSearch
        }
        let loadedDaily: SudmonitorHistoryRecord?
        if historicalDataSource == .sudmonitor {
            loadedDaily = record(for: damConfig.id, context: context)
        } else {
            loadedDaily = nil
        }
        if let loadedDaily,
           loadedDaily.periodStartDay == start,
           loadedDaily.periodEndDay == end {
            throw AppError.historicalSearchMatchesLoadedDaily
        }
        if existing.count >= maxSearchCount {
            throw AppError.historicalSearchLimitExceeded
        }
        let dailyInterval = loadedDaily.flatMap { dailyCoverageInterval(record: $0) }
        let dailyFragment = loadedDaily?.rawDatBytes
        let result = try await fetchHistoricalData(
            damConfig: damConfig,
            start: start,
            end: end,
            historicalDataSource: historicalDataSource,
            dailyInterval: dailyInterval,
            dailyFragment: dailyFragment
        )
        try store(meta: result.meta, rows: result.rows, context: context)
        return result
    }

    /// アセットキャッシュまたはネットワークから過去データを取得します。
    ///
    /// 検索プランナは次の優先順位でデータソースを選択します。
    /// 1. アセット内の静的ファイルで検索期間全体がカバーできる場合は通信を行わずアセットから高速ロードします。
    /// 2. アセットでカバーできない場合は、設定が sudmonitor ならば
    ///    「バンドル → 読込済み日次過去データ → sudmonitor(月次 → 日次)→ MLIT」の順にカスケード検索します。
    /// 3. カスケードで網羅できない場合(404・5xx・タイムアウト・ヘッダ欠落・カバレッジ不足等)、
    ///    または設定が MLIT 直結の場合は、検索区間全体を国土交通省 (MLIT) から取得します。
    private func fetchHistoricalData(
        damConfig: DamConfig,
        start: String,
        end: String,
        historicalDataSource: RealtimeDataSource,
        dailyInterval: DateInterval? = nil,
        dailyFragment: Data? = nil
    ) async throws -> HistoricalSearchResult {
        if historicalAssets.canCover(stationId: damConfig.id, startDate: start, endDate: end) {
            let (meta, rows) = try historicalAssets.load(damConfig: damConfig, startDate: start, endDate: end)
            return HistoricalSearchResult(meta: meta, rows: rows, source: .bundled)
        }
        if historicalDataSource == .mlitDirect {
            let (meta, rows) = try await fetchFromMlit(damConfig: damConfig, start: start, end: end)
            return HistoricalSearchResult(meta: meta, rows: rows, source: .mlit)
        }
        return try await fetchFromSudmonitorCascade(
            damConfig: damConfig,
            start: start,
            end: end,
            dailyInterval: dailyInterval,
            dailyFragment: dailyFragment
        )
    }

    /// 検索区間全体を国土交通省 (MLIT) の過去データ検索画面から取得します(HTML → DAT の 2 段階取得)。
    private func fetchFromMlit(damConfig: DamConfig, start: String, end: String) async throws -> (HistoricalSearchMeta, [DamHistoricalData]) {
        let url = damConfig.historicalSearchUrl(startDate: start, endDate: end)
        guard !url.isEmpty else { throw AppError.historicalSearchNotSupported }
        let html = try await network.fetchBytes(url)
        let datURL = try parser.parseHTMLForDatURL(html)
        let datBytes = try await network.fetchBytes(datURL)
        return try parser.parseHistoricalDat(datBytes, damConfigId: damConfig.id, startDate: start, endDate: end)
    }

    /// 「バンドル → 読込済み日次過去データ → sudmonitor(月次 → 日次)」のカスケード検索プランナです。
    ///
    /// バンドルと読込済み日次過去データのカバー区間の補集合(ギャップ)を求め、ギャップと交差する月の月次ファイルを
    /// [SudmonitorHistoricalClient.fetchMonthly] で取得し、それでも残るギャップを
    /// [SudmonitorHistoricalClient.fetchLatest] で補完します。各レスポンスの since/until ヘッダーを
    /// 解釈して日単位 (JST) のカバー区間を累積し、残ギャップが空になった場合のみ、
    /// バンドル・日次過去データ・sudmonitor の全フラグメントをマージして返します。
    ///
    /// カバレッジ計算では、until が `00:00`(24:00 表記)の場合は前日までをカバーとみなします。
    /// ヘッダ欠落・パース失敗は「カバレッジ不明」としてカバーなし扱いにし、過剰なカバレッジ主張は行いません。
    /// ギャップが残った場合やフラグメントのパース失敗時は、部分取得を破棄して検索区間全体を
    /// [fetchFromMlit] で取得します。
    private func fetchFromSudmonitorCascade(
        damConfig: DamConfig,
        start: String,
        end: String,
        dailyInterval: DateInterval? = nil,
        dailyFragment: Data? = nil
    ) async throws -> HistoricalSearchResult {
        guard networkAvailability.isNetworkAvailable else {
            throw AppError.networkUnavailable
        }
        guard let requiredStart = TimeFormatters.jstDay.date(from: start),
              let requiredEndDay = TimeFormatters.jstDay.date(from: end),
              let requiredEnd = Calendar.jst.date(byAdding: .day, value: 1, to: requiredEndDay) else {
            throw AppError.noHistoricalData
        }
        let requiredInterval = DateInterval(start: requiredStart, end: requiredEnd)

        // バンドルフラグメント(dedupe 優先度: ローカル > 月次 > latest)
        let bundleFragments: [HistoricalAssetStore.HistoricalAssetFragment]
        do {
            bundleFragments = try historicalAssets.loadCoveringFragments(stationId: damConfig.id, startDate: start, endDate: end)
        } catch {
            return try await fallbackToMlit(damConfig: damConfig, start: start, end: end)
        }

        // 初期カバー区間(バンドル + 読込済み日次過去データ)と残ギャップ
        var covered = historicalAssets.coverageIntervals(stationId: damConfig.id, startDate: start, endDate: end)
        if let dailyInterval {
            let start = max(dailyInterval.start, requiredStart)
            let end = min(dailyInterval.end, requiredEnd)
            if start < end {
                covered = Self.mergedIntervals(covered + [DateInterval(start: start, end: end)])
            }
        }
        var gaps = Self.complementIntervals(covered, requiredInterval)

        // ギャップと交差する月の月次ファイルを取得(失敗・404 は無視して継続)
        var sudmonitorFragments: [Data] = []
        for month in Self.monthsIntersecting(gaps) {
            if gaps.isEmpty { break }
            switch await sudmonitorClient.fetchMonthly(damId: damConfig.id, month: month) {
            case .success(let response):
                guard let coverage = Self.coverageInterval(
                    from: response,
                    requiredStart: requiredStart,
                    requiredEnd: requiredEnd
                ) else { continue }
                covered = Self.mergedIntervals(covered + [coverage])
                gaps = Self.complementIntervals(covered, requiredInterval)
                sudmonitorFragments.append(response.bytes)
            case .notFound, .failure:
                continue
            }
        }

        // 残ギャップがあれば日次(latest)で補完
        if !gaps.isEmpty {
            switch await sudmonitorClient.fetchLatest(damId: damConfig.id) {
            case .success(let response):
                if let coverage = Self.coverageInterval(
                    from: response,
                    requiredStart: requiredStart,
                    requiredEnd: requiredEnd
                ) {
                    covered = Self.mergedIntervals(covered + [coverage])
                    gaps = Self.complementIntervals(covered, requiredInterval)
                    sudmonitorFragments.append(response.bytes)
                }
            case .notFound, .failure:
                break
            }
        }

        // 残ギャップが空になった場合のみ成功(部分取得は破棄して MLIT へ委譲)
        if !gaps.isEmpty {
            return try await fallbackToMlit(damConfig: damConfig, start: start, end: end)
        }

        // 全フラグメントを優先度順(バンドル → ローカル → 月次 → latest)でパース・マージ
        let fragments = bundleFragments.map(\.bytes) + (dailyFragment.map { [$0] } ?? []) + sudmonitorFragments
        guard !fragments.isEmpty else {
            return try await fallbackToMlit(damConfig: damConfig, start: start, end: end)
        }
        var parsedFragments: [(meta: HistoricalSearchMeta, rows: [DamHistoricalData])] = []
        for bytes in fragments {
            do {
                parsedFragments.append(try parser.parseHistoricalDat(bytes, damConfigId: damConfig.id, startDate: start, endDate: end))
            } catch {
                return try await fallbackToMlit(damConfig: damConfig, start: start, end: end)
            }
        }
        let (meta, rows) = mergeFragments(parsedFragments, requiredStart: requiredStart, requiredEnd: requiredEndDay)
        guard !rows.isEmpty else {
            return try await fallbackToMlit(damConfig: damConfig, start: start, end: end)
        }
        return HistoricalSearchResult(meta: meta, rows: rows, source: .sudmonitor)
    }

    /// 検索区間全体を国土交通省 (MLIT) から取得して `.mlit` の結果を返します。
    private func fallbackToMlit(damConfig: DamConfig, start: String, end: String) async throws -> HistoricalSearchResult {
        let (meta, rows) = try await fetchFromMlit(damConfig: damConfig, start: start, end: end)
        return HistoricalSearchResult(meta: meta, rows: rows, source: .mlit)
    }

    /// 優先度順のパース済みフラグメントをマージして、epoch キーで重複排除・昇順ソートします。
    ///
    /// 各データ行の epoch キーは `TimeFormatters.millis(fromDamTime:)`(24:00 対応)で計算し、
    /// 同一 epoch は先に出現した高優先度ソースの行を採用します。メタデータは最初のフラグメントのものを使用します。
    /// 検索期間外の行は除外します。
    /// - Parameters:
    ///   - fragments: 優先度順に並んだパース済みフラグメントのリスト。
    ///   - requiredStart: 検索期間の開始日 (JST 00:00)。
    ///   - requiredEnd: 検索期間の終了日 (JST 00:00、終了日を含む)。
    /// - Returns: マージ・重複排除・ソート済みのメタデータとデータのペア。
    private func mergeFragments(
        _ fragments: [(meta: HistoricalSearchMeta, rows: [DamHistoricalData])],
        requiredStart: Date,
        requiredEnd: Date
    ) -> (meta: HistoricalSearchMeta, rows: [DamHistoricalData]) {
        let meta = fragments[0].meta
        var mergedRows: [Double: DamHistoricalData] = [:]
        for fragment in fragments {
            for row in fragment.rows {
                let datePart = String(row.time.split(separator: " ").first ?? "")
                guard let day = looseDayDate(datePart),
                      day >= requiredStart,
                      day <= requiredEnd else { continue }
                let epoch = TimeFormatters.millis(fromDamTime: row.time)
                guard epoch.isFinite else { continue }
                if mergedRows[epoch] == nil {
                    mergedRows[epoch] = row
                }
            }
        }
        let rows = mergedRows.sorted { $0.key < $1.key }.map(\.value)
        return (meta, rows)
    }

    /// 日単位(排他境界)の区間リストを昇順にマージし、重複・隣接(前区間の end == 次区間の start も含む)を統合します。
    /// - Parameter intervals: マージ対象の区間リスト。
    /// - Returns: マージ済みの区間リスト(開始日時の昇順)。
    internal nonisolated static func mergedIntervals(_ intervals: [DateInterval]) -> [DateInterval] {
        let sorted = intervals.sorted { $0.start < $1.start }
        var merged: [DateInterval] = []
        for interval in sorted {
            guard let last = merged.last else {
                merged.append(interval)
                continue
            }
            if interval.start <= last.end {
                merged[merged.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
            } else {
                merged.append(interval)
            }
        }
        return merged
    }

    /// カバー区間の補集合(ギャップ)を要求区間の範囲内で列挙します。
    /// - Parameters:
    ///   - covered: カバー区間のリスト(マージ済み・昇順)。
    ///   - required: 要求区間(排他境界)。
    /// - Returns: カバーされていない区間のリスト(昇順)。カバーが空の場合は要求区間全体。
    internal nonisolated static func complementIntervals(_ covered: [DateInterval], _ required: DateInterval) -> [DateInterval] {
        guard !covered.isEmpty else { return [required] }
        var gaps: [DateInterval] = []
        var cursor = required.start
        for interval in covered {
            if interval.start > cursor {
                gaps.append(DateInterval(start: cursor, end: interval.start))
            }
            cursor = max(cursor, interval.end)
        }
        if cursor < required.end {
            gaps.append(DateInterval(start: cursor, end: required.end))
        }
        return gaps
    }

    /// ギャップ区間と交差する月を昇順(重複なし)で列挙します。
    ///
    /// ギャップは日単位の区間で、終端は排他境界(`gap.end` は含まない)です。
    /// そのため終了月は「最後に含まれる日(= `gap.end` の前日)」から計算します。
    /// 例: 2026-07-15〜2026-08-01(排他)のギャップ → 2026-07、2026-07-31〜2026-08-02(排他) → 2026-07, 2026-08。
    /// - Parameter gaps: 日単位のギャップ区間リスト。
    /// - Returns: ギャップと交差する月のリスト(昇順・重複なし)。
    internal nonisolated static func monthsIntersecting(_ gaps: [DateInterval]) -> [SudmonitorHistoryMonth] {
        var months: Set<SudmonitorHistoryMonth> = []
        for gap in gaps {
            let startComponents = Calendar.jst.dateComponents([.year, .month], from: gap.start)
            let lastIncludedDay = Calendar.jst.date(byAdding: .day, value: -1, to: gap.end) ?? gap.start
            let endComponents = Calendar.jst.dateComponents([.year, .month], from: lastIncludedDay)
            guard let startYear = startComponents.year,
                  let startMonth = startComponents.month,
                  let endYear = endComponents.year,
                  let endMonth = endComponents.month else { continue }
            let end = SudmonitorHistoryMonth(year: endYear, month: endMonth)
            var current = SudmonitorHistoryMonth(year: startYear, month: startMonth)
            while current <= end {
                months.insert(current)
                current = nextMonth(current)
            }
        }
        return months.sorted()
    }

    /// sudmonitor の履歴レスポンスの since/until ヘッダーを解釈して、日単位 (JST・排他境界) のカバー区間を計算します。
    ///
    /// since/until は `parseHistoryPeriod` で解釈し、ヘッダ欠落・パース失敗は「カバレッジ不明」として
    /// nil(カバーなし扱い)を返します。until が JST で `00:00`(24:00 表記)の場合は前日までをカバーとみなします。
    /// 計算結果は [requiredStart, requiredEnd) にクリップして返します。
    /// - Parameters:
    ///   - response: sudmonitor の履歴レスポンス。
    ///   - requiredStart: 要求期間の開始日 (JST 00:00、含む)。
    ///   - requiredEnd: 要求期間の終了日 (JST 00:00、含まない排他境界)。
    /// - Returns: カバー区間。ヘッダ欠落・パース失敗・要求期間と交差しない場合は nil。
    internal static func coverageInterval(
        from response: SudmonitorHistoricalResponse,
        requiredStart: Date,
        requiredEnd: Date
    ) -> DateInterval? {
        guard let sinceValue = response.since,
              let untilValue = response.until,
              let since = parseHistoryPeriod(sinceValue),
              let until = parseHistoryPeriod(untilValue) else {
            return nil
        }
        let sinceDay = Calendar.jst.startOfDay(for: since)
        var untilDay = Calendar.jst.startOfDay(for: until)
        let untilComponents = Calendar.jst.dateComponents([.hour, .minute], from: until)
        if untilComponents.hour == 0, untilComponents.minute == 0,
           let previousDay = Calendar.jst.date(byAdding: .day, value: -1, to: untilDay) {
            untilDay = previousDay
        }
        let start = max(sinceDay, requiredStart)
        guard let untilEnd = Calendar.jst.date(byAdding: .day, value: 1, to: untilDay) else { return nil }
        let end = min(untilEnd, requiredEnd)
        guard start < end else { return nil }
        return DateInterval(start: start, end: end)
    }

    /// sudmonitor の since/until ヘッダー値を解釈して、JST 日単位 (yyyyMMdd) の期間へ正規化します。
    ///
    /// until が JST で `00:00`(24:00 表記)の場合は前日までを期間終了とみなします(既存 `coverageInterval` と同じ終端処理)。
    /// - Parameters:
    ///   - since: 期間開始のヘッダー値。
    ///   - until: 期間終了のヘッダー値。
    /// - Returns: 期間開始日・終了日 (yyyyMMdd)。ヘッダー欠落・パース失敗の場合は nil。
    internal static func historyDayRange(since: String?, until: String?) -> (start: String, end: String)? {
        guard let sinceValue = since,
              let untilValue = until,
              let sinceDate = parseHistoryPeriod(sinceValue),
              let untilDate = parseHistoryPeriod(untilValue) else {
            return nil
        }
        let sinceDay = Calendar.jst.startOfDay(for: sinceDate)
        var untilDay = Calendar.jst.startOfDay(for: untilDate)
        let untilComponents = Calendar.jst.dateComponents([.hour, .minute], from: untilDate)
        if untilComponents.hour == 0, untilComponents.minute == 0,
           let previousDay = Calendar.jst.date(byAdding: .day, value: -1, to: untilDay) {
            untilDay = previousDay
        }
        return (
            TimeFormatters.jstDay.string(from: sinceDay),
            TimeFormatters.jstDay.string(from: untilDay)
        )
    }

    /// sudmonitor の履歴レスポンスの since/until ヘッダーを解釈して、JST 日単位 (yyyyMMdd) の期間へ正規化します。
    /// - Parameter response: sudmonitor の履歴レスポンス。
    /// - Returns: 期間開始日・終了日 (yyyyMMdd)。ヘッダー欠落・パース失敗の場合は nil。
    internal static func historyDayRange(from response: SudmonitorHistoricalResponse) -> (start: String, end: String)? {
        historyDayRange(since: response.since, until: response.until)
    }

    /// 指定ダムの読込済み sudmonitor 日次過去データレコードを取得します。
    /// - Parameters:
    ///   - damId: 対象ダムの観測所ID。
    ///   - context: SwiftData のモデルコンテキスト。
    /// - Returns: 保存済みレコード。未保存の場合は nil。
    private func record(for damId: String, context: ModelContext) -> SudmonitorHistoryRecord? {
        ((try? context.fetch(FetchDescriptor<SudmonitorHistoryRecord>())) ?? [])
            .first { $0.damId == damId }
    }

    /// 読込済み sudmonitor 日次過去データの実カバー区間(日単位・排他境界)を算出します。
    /// - Parameter record: 読込済みの日次過去データレコード。
    /// - Returns: カバー区間。期間がパースできない場合は nil。
    private func dailyCoverageInterval(record: SudmonitorHistoryRecord) -> DateInterval? {
        guard let start = TimeFormatters.jstDay.date(from: record.periodStartDay),
              let endDay = TimeFormatters.jstDay.date(from: record.periodEndDay),
              let end = Calendar.jst.date(byAdding: .day, value: 1, to: endDay) else {
            return nil
        }
        return DateInterval(start: start, end: end)
    }

    /// 月次履歴ファイル名の月を1つ進めます。
    private nonisolated static func nextMonth(_ month: SudmonitorHistoryMonth) -> SudmonitorHistoryMonth {
        month.month == 12
            ? SudmonitorHistoryMonth(year: month.year + 1, month: 1)
            : SudmonitorHistoryMonth(year: month.year, month: month.month + 1)
    }

    /// sudmonitor の期間ヘッダー値(ISO8601・JST)をパースします。
    ///
    /// `T24:` 表記(例: `2026-07-31T24:00:00+09:00`)は日付を翌日に進めて `T00:` へ正規化してからパースします。
    /// パース失敗は nil を返します(小数秒ありの ISO8601 形式もフォールバックで試します)。
    private static func parseHistoryPeriod(_ value: String) -> Date? {
        let normalized: String
        if value.contains("T24:") {
            let parts = value.split(separator: "T24:", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2,
                  let day = historyPeriodDayFormatter.date(from: String(parts[0])),
                  let nextDay = Calendar.jst.date(byAdding: .day, value: 1, to: day) else {
                return nil
            }
            normalized = "\(historyPeriodDayFormatter.string(from: nextDay))T00:\(parts[1])"
        } else {
            normalized = value
        }
        if let date = TimeFormatters.iso8601JST.date(from: normalized) {
            return date
        }
        return iso8601FractionalSeconds.date(from: normalized)
    }

    /// 期間ヘッダーの日付部分 (yyyy-MM-dd) 用フォーマッタ。
    private static let historyPeriodDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// 小数秒ありの ISO8601 日時用フォーマッタ(フォールバック用)。
    private static let iso8601FractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

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

    /// 取得した過去データ検索結果をデータベースに保存します。既存の検索履歴のソート順序をデクリメント（押し下げ）します。
    private func store(
        meta: HistoricalSearchMeta,
        rows: [DamHistoricalData],
        context: ModelContext
    ) throws {
        let existing = try context.fetch(FetchDescriptor<HistoricalSearchMetaRecord>())
        for record in existing {
            record.sortOrder += 1
        }
        context.insert(HistoricalSearchMetaRecord(meta: meta))
        for row in rows {
            context.insert(HistoricalDamDataRecord(
                searchMetaId: meta.id,
                data: row,
                timeMillis: TimeFormatters.millis(fromDamTime: row.time)
            ))
        }
        try context.save()
    }
}
