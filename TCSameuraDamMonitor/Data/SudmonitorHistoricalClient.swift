// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation
import TCSameuraDamCore

/// sudmonitor 履歴応答(月次 / latest.dat)の情報。
nonisolated struct SudmonitorHistoricalResponse: Sendable {
    /// 取得したDATファイルのバイナリデータ。
    internal let bytes: Data
    /// `X-TCS-Dam-Id` レスポンスヘッダーの値(存在しない場合は nil)。
    internal let damIdHeader: String?
    /// `X-TCS-History-Start` または `X-TCS-History-Since` の値(存在しない場合は nil)。
    internal let since: String?
    /// `X-TCS-History-End` または `X-TCS-History-Until` の値(存在しない場合は nil)。
    internal let until: String?
    /// `X-TCS-Next-Update-At` レスポンスヘッダーの値(存在しない・不正な場合は nil)。
    internal let nextUpdateAt: Date?

    /// 履歴応答を初期化します。
    /// - Parameters:
    ///   - bytes: 取得したDATファイルのバイナリデータ。
    ///   - damIdHeader: `X-TCS-Dam-Id` レスポンスヘッダーの値。
    ///   - since: `X-TCS-History-Start` または `X-TCS-History-Since` の値。
    ///   - until: `X-TCS-History-End` または `X-TCS-History-Until` の値。
    ///   - nextUpdateAt: `X-TCS-Next-Update-At` レスポンスヘッダーの値。
    internal init(bytes: Data, damIdHeader: String?, since: String?, until: String?, nextUpdateAt: Date? = nil) {
        self.bytes = bytes
        self.damIdHeader = damIdHeader
        self.since = since
        self.until = until
        self.nextUpdateAt = nextUpdateAt
    }
}

/// 履歴フェッチ結果。
nonisolated enum SudmonitorHistoricalFetchOutcome: Sendable {
    /// 取得成功(バイト列と期間ヘッダー情報)。
    case success(SudmonitorHistoricalResponse)
    /// 404 または非対応ダム(対象ファイルが存在しない)。
    case notFound
    /// その他の失敗(ネットワークエラー等)。
    case failure(Error)
}

/// 月(YearMonth)の単純表現。
nonisolated struct SudmonitorHistoryMonth: Hashable, Comparable, Sendable {
    /// 年。
    internal let year: Int
    /// 月(1-12)。
    internal let month: Int

    /// "yyyy-MM" 形式の識別子(例: "2026-07")。
    internal var identifier: String { String(format: "%04d-%02d", year, month) }

    /// (year, month) の辞書順。
    internal static func < (lhs: SudmonitorHistoryMonth, rhs: SudmonitorHistoryMonth) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }
}

/// sudmonitor の履歴ファイル(月次 / latest.dat)を取得するクライアント。
///
/// 月次ファイル(`{damId}_{YYYYMMDDHHMM}_{YYYYMMDDHHMM}.dat`)と日次ファイル(`latest.dat`)を
/// sudmonitor から取得し、バイト列と応答ヘッダー(X-TCS-Dam-Id / X-TCS-History-*)を返します。
/// 404 は「取得対象外(ファイルが存在しない)」を意味するため [SudmonitorHistoricalFetchOutcome.notFound] として扱い、
/// その結果は TTL 付きのプロセス内キャッシュ(負の結果キャッシュ)に保存されます。
nonisolated struct SudmonitorHistoricalClient: Sendable {
    /// ネットワークアクセス用のデータソース。
    internal let network: MlitNetworkDataSource
    /// 現在日時を供給するクロージャ。
    private let now: @Sendable () -> Date
    /// 負の結果(404)のプロセス内キャッシュ。
    private let negativeCache: SudmonitorNegativeCache

    /// sudmonitor 履歴クライアントを初期化します。
    /// - Parameters:
    ///   - network: ネットワークデータソース。
    ///   - now: 現在日時を供給するクロージャ(既定は `Date()`)。
    internal init(
        network: MlitNetworkDataSource,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.network = network
        self.now = now
        self.negativeCache = SudmonitorNegativeCache()
    }

    /// 指定されたダムの月次履歴ファイルを取得します。
    ///
    /// [RealtimeDataSource.sudmonitorSupportedDamIds] に含まれない damId はネットワークアクセスせず
    /// `.notFound` を返します。404(ファイル無し)も `.notFound` となり、
    /// その結果は TTL の間プロセス内キャッシュされます。
    /// - Parameters:
    ///   - damId: 対象ダムの観測所ID。
    ///   - month: 取得対象月。
    /// - Returns: フェッチ結果。
    internal func fetchMonthly(damId: String, month: SudmonitorHistoryMonth) async -> SudmonitorHistoricalFetchOutcome {
        guard RealtimeDataSource.sudmonitorSupportedDamIds.contains(damId) else { return .notFound }
        let key = SudmonitorNegativeCache.Key(damId: damId, kind: .monthly, month: month.identifier)
        if negativeCache.isCached(key, now: now()) { return .notFound }
        let urlString = "\(RealtimeDataSource.sudmonitorBaseURL)/v1/history/\(damId)/\(Self.monthlyFileName(damId: damId, month: month))"
        return await fetchFile(urlString: urlString, requestedDamId: damId, key: key)
    }

    /// 指定されたダムの日次履歴ファイル(latest.dat)を取得します。
    ///
    /// [RealtimeDataSource.sudmonitorSupportedDamIds] に含まれない damId はネットワークアクセスせず
    /// `.notFound` を返します。404(ファイル無し)も `.notFound` となり、
    /// その結果は TTL の間プロセス内キャッシュされます。
    /// - Parameter damId: 対象ダムの観測所ID。
    /// - Returns: フェッチ結果。
    internal func fetchLatest(damId: String) async -> SudmonitorHistoricalFetchOutcome {
        guard RealtimeDataSource.sudmonitorSupportedDamIds.contains(damId) else { return .notFound }
        let key = SudmonitorNegativeCache.Key(damId: damId, kind: .latest, month: nil)
        if negativeCache.isCached(key, now: now()) { return .notFound }
        let urlString = "\(RealtimeDataSource.sudmonitorBaseURL)/v1/history/\(damId)/latest.dat"
        return await fetchFile(urlString: urlString, requestedDamId: damId, key: key)
    }

    /// 履歴ファイルを1回のGETで取得し、成功時はバイト列とヘッダー情報を返します。
    /// - Parameters:
    ///   - urlString: 取得対象のURL文字列。
    ///   - requestedDamId: 要求した観測所ID。
    ///   - key: 負の結果キャッシュ用のキー。
    /// - Returns: フェッチ結果。
    private func fetchFile(urlString: String, requestedDamId: String, key: SudmonitorNegativeCache.Key) async -> SudmonitorHistoricalFetchOutcome {
        do {
            let (bytes, headers) = try await network.fetchHistoryBytes(urlString)
            let damIdHeader = DamCoreHTTPHeaders.value(headers, forField: Self.headerDamId)
            if let damIdHeader, damIdHeader != requestedDamId {
                return .failure(MlitNetworkError.transport)
            }
            let since = DamCoreHTTPHeaders.value(headers, forField: Self.headerHistoryStart)
                ?? DamCoreHTTPHeaders.value(headers, forField: Self.headerHistorySince)
            let until = DamCoreHTTPHeaders.value(headers, forField: Self.headerHistoryEnd)
                ?? DamCoreHTTPHeaders.value(headers, forField: Self.headerHistoryUntil)
            let nextUpdateAt = DamCoreHTTPHeaders.value(headers, forField: Self.headerNextUpdateAt)
                .flatMap { ISO8601UTCDateParser.parse($0) }
            return .success(SudmonitorHistoricalResponse(
                bytes: bytes,
                damIdHeader: damIdHeader,
                since: since,
                until: until,
                nextUpdateAt: nextUpdateAt
            ))
        } catch MlitNetworkError.notFound {
            negativeCache.put(key, now: now())
            return .notFound
        } catch {
            return .failure(error)
        }
    }

    /// 月次履歴ファイル名を決定的に生成します。
    ///
    /// 開始は当月1日01:00、終了は末日24:00(2400表記)です。
    /// 例: 2026-07 → `1368080700010_202607010100_202607312400.dat`(うるう年2月は `202402292400.dat` になります)。
    /// - Parameters:
    ///   - damId: 対象ダムの観測所ID。
    ///   - month: 取得対象月。
    /// - Returns: 月次履歴ファイル名。
    internal static func monthlyFileName(damId: String, month: SudmonitorHistoryMonth) -> String {
        let lastDay = Calendar.jst.date(from: DateComponents(year: month.year, month: month.month))
            .flatMap { Calendar.jst.range(of: .day, in: .month, for: $0)?.count } ?? 0
        return String(
            format: "%@_%04d%02d010100_%04d%02d%02d2400.dat",
            damId, month.year, month.month, month.year, month.month, lastDay
        )
    }

    /// `X-TCS-Dam-Id` レスポンスヘッダー名。
    internal static let headerDamId = "X-TCS-Dam-Id"
    /// `X-TCS-History-Start` レスポンスヘッダー名(月次)。
    internal static let headerHistoryStart = "X-TCS-History-Start"
    /// `X-TCS-History-End` レスポンスヘッダー名(月次)。
    internal static let headerHistoryEnd = "X-TCS-History-End"
    /// `X-TCS-History-Since` レスポンスヘッダー名(日次)。
    internal static let headerHistorySince = "X-TCS-History-Since"
    /// `X-TCS-History-Until` レスポンスヘッダー名(日次)。
    internal static let headerHistoryUntil = "X-TCS-History-Until"
    /// `X-TCS-Next-Update-At` レスポンスヘッダー名(日次 / リアルタイム共通)。
    internal static let headerNextUpdateAt = "X-TCS-Next-Update-At"
}
