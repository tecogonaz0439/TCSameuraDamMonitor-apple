// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Testing
import Foundation
import TCSameuraDamCore
@testable import TCSameuraDamMonitor

/// sudmonitor 履歴ファイル取得クライアント [SudmonitorHistoricalClient] のテスト。
///
/// 注入フェッチャ ([HeaderFixtureFetcher]) を使うため、URL ポリシー検証・サイズ上限のテストは対象外です。
/// 404 はフェッチャが `DamCoreMlitURLPolicyError.badHTTPStatus(404)` を throw して表現し、
/// その他ステータス(5xx 等)も `DamCoreMlitURLPolicyError.badHTTPStatus` で表現します。
@Suite("Sudmonitor historical client")
struct SudmonitorHistoricalClientTests {
    private let damId = "1368080700010"
    private let unsupportedDamId = "9999999999999"
    private let historyBase = "https://sudmonitor.kusugami-lab.net/v1/history"

    private func makeClient(fetcher: HeaderFixtureFetcher, clock: TestClock) -> SudmonitorHistoricalClient {
        SudmonitorHistoricalClient(
            network: MlitNetworkDataSource(headerFetcher: fetcher.fetch),
            now: { clock.current }
        )
    }

    private func month(_ offset: Int, from base: SudmonitorHistoryMonth) -> SudmonitorHistoryMonth {
        let total = base.year * 12 + (base.month - 1) + offset
        return SudmonitorHistoryMonth(year: total / 12, month: total % 12 + 1)
    }

    @Test func monthlyFileNameDeterministicNames() {
        #expect(SudmonitorHistoricalClient.monthlyFileName(
            damId: damId,
            month: SudmonitorHistoryMonth(year: 2026, month: 7)
        ) == "1368080700010_202607010100_202607312400.dat")
        #expect(SudmonitorHistoricalClient.monthlyFileName(
            damId: damId,
            month: SudmonitorHistoryMonth(year: 2024, month: 2)
        ) == "1368080700010_202402010100_202402292400.dat")
        #expect(SudmonitorHistoricalClient.monthlyFileName(
            damId: damId,
            month: SudmonitorHistoryMonth(year: 2023, month: 2)
        ) == "1368080700010_202302010100_202302282400.dat")
    }

    @Test func fetchMonthlySingleGetParsesStartEndHeaders() async {
        let bytes = Data("sample dat bytes".utf8)
        let url = "\(historyBase)/\(damId)/1368080700010_202607010100_202607312400.dat"
        let fetcher = HeaderFixtureFetcher(responses: [
            url: (bytes, [
                "X-TCS-Dam-Id": damId,
                "X-TCS-History-Start": "2026-07-01T01:00:00+09:00",
                "X-TCS-History-End": "2026-07-31T24:00:00+09:00",
            ]),
        ])
        let client = makeClient(fetcher: fetcher, clock: TestClock(now: Date(timeIntervalSince1970: 0)))

        let result = await client.fetchMonthly(damId: damId, month: SudmonitorHistoryMonth(year: 2026, month: 7))

        guard case .success(let response) = result else {
            Issue.record("Expected success but got \(result)")
            return
        }
        #expect(fetcher.requestedURLs == [url])
        #expect(response.bytes == bytes)
        #expect(response.damIdHeader == damId)
        #expect(response.since == "2026-07-01T01:00:00+09:00")
        #expect(response.until == "2026-07-31T24:00:00+09:00")
    }

    @Test func fetchLatestUsesLatestPathWithSinceUntilHeaders() async {
        let bytes = Data("sample dat bytes".utf8)
        let url = "\(historyBase)/\(damId)/latest.dat"
        let fetcher = HeaderFixtureFetcher(responses: [
            url: (bytes, [
                "X-TCS-Dam-Id": damId,
                "X-TCS-History-Since": "2026-07-31T00:00:00+09:00",
                "X-TCS-History-Until": "2026-08-02T00:00:00+09:00",
            ]),
        ])
        let client = makeClient(fetcher: fetcher, clock: TestClock(now: Date(timeIntervalSince1970: 0)))

        let result = await client.fetchLatest(damId: damId)

        guard case .success(let response) = result else {
            Issue.record("Expected success but got \(result)")
            return
        }
        #expect(fetcher.requestedURLs == [url])
        #expect(response.bytes == bytes)
        #expect(response.since == "2026-07-31T00:00:00+09:00")
        #expect(response.until == "2026-08-02T00:00:00+09:00")
    }

    @Test func fetchLatestParsesNextUpdateAtHeader() async throws {
        let bytes = Data("sample dat bytes".utf8)
        let url = "\(historyBase)/\(damId)/latest.dat"
        let fetcher = HeaderFixtureFetcher(responses: [
            url: (bytes, [
                "X-TCS-Dam-Id": damId,
                "X-TCS-History-Since": "2026-07-31T00:00:00+09:00",
                "X-TCS-History-Until": "2026-08-02T00:00:00+09:00",
                "X-TCS-Next-Update-At": "2026-07-31T15:13:00Z",
            ]),
        ])
        let client = makeClient(fetcher: fetcher, clock: TestClock(now: Date(timeIntervalSince1970: 0)))

        let result = await client.fetchLatest(damId: damId)

        guard case .success(let response) = result else {
            Issue.record("Expected success but got \(result)")
            return
        }
        #expect(fetcher.requestedURLs == [url])
        #expect(response.since == "2026-07-31T00:00:00+09:00")
        #expect(response.until == "2026-08-02T00:00:00+09:00")
        // 2026-07-31T15:13:00Z = 2026-08-01 00:13 JST
        let base = try #require(Calendar.jst.date(
            from: DateComponents(year: 2026, month: 8, day: 1, hour: 0, minute: 13)
        ))
        #expect(response.nextUpdateAt == base)
    }

    @Test func fetchLatestParsesNextUpdateAtHeaderWithFractionalSeconds() async throws {
        let bytes = Data("sample dat bytes".utf8)
        let url = "\(historyBase)/\(damId)/latest.dat"
        let fetcher = HeaderFixtureFetcher(responses: [
            url: (bytes, [
                "X-TCS-Dam-Id": damId,
                "X-TCS-History-Since": "2026-07-31T00:00:00+09:00",
                "X-TCS-History-Until": "2026-08-02T00:00:00+09:00",
                "X-TCS-Next-Update-At": "2026-07-31T15:13:00.500Z",
            ]),
        ])
        let client = makeClient(fetcher: fetcher, clock: TestClock(now: Date(timeIntervalSince1970: 0)))

        let result = await client.fetchLatest(damId: damId)

        guard case .success(let response) = result else {
            Issue.record("Expected success but got \(result)")
            return
        }
        let base = try #require(Calendar.jst.date(
            from: DateComponents(year: 2026, month: 8, day: 1, hour: 0, minute: 13)
        ))
        #expect(response.nextUpdateAt == base.addingTimeInterval(0.5))
    }

    @Test func fetchLatestMissingNextUpdateAtHeaderReturnsNil() async throws {
        let bytes = Data("sample dat bytes".utf8)
        let url = "\(historyBase)/\(damId)/latest.dat"
        let fetcher = HeaderFixtureFetcher(responses: [
            url: (bytes, [
                "X-TCS-Dam-Id": damId,
                "X-TCS-History-Since": "2026-07-31T00:00:00+09:00",
                "X-TCS-History-Until": "2026-08-02T00:00:00+09:00",
            ]),
        ])
        let client = makeClient(fetcher: fetcher, clock: TestClock(now: Date(timeIntervalSince1970: 0)))

        let result = await client.fetchLatest(damId: damId)

        guard case .success(let response) = result else {
            Issue.record("Expected success but got \(result)")
            return
        }
        #expect(response.nextUpdateAt == nil)
    }

    @Test func fetchLatestInvalidNextUpdateAtHeaderReturnsNil() async throws {
        let bytes = Data("sample dat bytes".utf8)
        let url = "\(historyBase)/\(damId)/latest.dat"
        let fetcher = HeaderFixtureFetcher(responses: [
            url: (bytes, [
                "X-TCS-Dam-Id": damId,
                "X-TCS-History-Since": "2026-07-31T00:00:00+09:00",
                "X-TCS-History-Until": "2026-08-02T00:00:00+09:00",
                "X-TCS-Next-Update-At": "not-a-date",
            ]),
        ])
        let client = makeClient(fetcher: fetcher, clock: TestClock(now: Date(timeIntervalSince1970: 0)))

        let result = await client.fetchLatest(damId: damId)

        guard case .success(let response) = result else {
            Issue.record("Expected success but got \(result)")
            return
        }
        #expect(response.nextUpdateAt == nil)
    }

    @Test func fetchMonthlyNotFoundReturnsNotFoundAndCaches() async {
        let fetcher = HeaderFixtureFetcher(responses: [:])
        let client = makeClient(fetcher: fetcher, clock: TestClock(now: Date(timeIntervalSince1970: 1000)))
        let month = SudmonitorHistoryMonth(year: 2026, month: 7)

        let first = await client.fetchMonthly(damId: damId, month: month)
        guard case .notFound = first else {
            Issue.record("Expected notFound but got \(first)")
            return
        }
        #expect(fetcher.requestedURLs.count == 1)

        let second = await client.fetchMonthly(damId: damId, month: month)
        guard case .notFound = second else {
            Issue.record("Expected notFound but got \(second)")
            return
        }
        #expect(fetcher.requestedURLs.count == 1, "2 回目は負の結果キャッシュでフェッチしない")
    }

    @Test func fetchLatestServerErrorReturnsFailure() async {
        let url = "\(historyBase)/\(damId)/latest.dat"
        let fetcher = HeaderFixtureFetcher(failures: [
            url: DamCoreMlitURLPolicyError.badHTTPStatus(503),
        ])
        let client = makeClient(fetcher: fetcher, clock: TestClock(now: Date(timeIntervalSince1970: 0)))

        let result = await client.fetchLatest(damId: damId)

        guard case .failure = result else {
            Issue.record("Expected failure but got \(result)")
            return
        }
        #expect(fetcher.requestedURLs == [url])
    }

    @Test func fetchMonthlyDamIdMismatchReturnsFailure() async {
        let bytes = Data("sample dat bytes".utf8)
        let url = "\(historyBase)/\(damId)/1368080700010_202607010100_202607312400.dat"
        let fetcher = HeaderFixtureFetcher(responses: [
            url: (bytes, ["X-TCS-Dam-Id": "9999999999999"]),
        ])
        let client = makeClient(fetcher: fetcher, clock: TestClock(now: Date(timeIntervalSince1970: 0)))

        let result = await client.fetchMonthly(damId: damId, month: SudmonitorHistoryMonth(year: 2026, month: 7))

        guard case .failure = result else {
            Issue.record("Expected failure but got \(result)")
            return
        }
    }

    @Test func fetchMonthlyWithoutDamIdHeaderSucceeds() async {
        let bytes = Data("sample dat bytes".utf8)
        let url = "\(historyBase)/\(damId)/1368080700010_202607010100_202607312400.dat"
        let fetcher = HeaderFixtureFetcher(responses: [
            url: (bytes, ["X-TCS-History-Start": "2026-07-01T01:00:00+09:00"]),
        ])
        let client = makeClient(fetcher: fetcher, clock: TestClock(now: Date(timeIntervalSince1970: 0)))

        let result = await client.fetchMonthly(damId: damId, month: SudmonitorHistoryMonth(year: 2026, month: 7))

        guard case .success(let response) = result else {
            Issue.record("Expected success but got \(result)")
            return
        }
        #expect(response.bytes == bytes)
        #expect(response.damIdHeader == nil)
        #expect(response.since == "2026-07-01T01:00:00+09:00")
        #expect(response.until == nil)
    }

    @Test func negativeCacheExpiredAfterTtlRefetches() async {
        let url = "\(historyBase)/\(damId)/latest.dat"
        let fetcher = HeaderFixtureFetcher(failures: [
            url: DamCoreMlitURLPolicyError.badHTTPStatus(404),
        ])
        let clock = TestClock(now: Date(timeIntervalSince1970: 1000))
        let client = makeClient(fetcher: fetcher, clock: clock)

        let first = await client.fetchLatest(damId: damId)
        guard case .notFound = first else {
            Issue.record("Expected notFound but got \(first)")
            return
        }
        #expect(fetcher.requestedURLs.count == 1)

        // TTL(5 分)を超えてから再アクセス → 再フェッチされる
        clock.current = clock.current.addingTimeInterval(5 * 60 + 1)
        let second = await client.fetchLatest(damId: damId)
        guard case .notFound = second else {
            Issue.record("Expected notFound but got \(second)")
            return
        }
        #expect(fetcher.requestedURLs.count == 2)
    }

    @Test func negativeCacheExceedingMaxSizeEvicts() async {
        // 129 キー(2020-01 〜 2030-09)を挿入して 128 上限を超えさせると、
        // 挿入順の先頭(最古 = 2020-01)が破棄され、再アクセス時に再フェッチされる。
        // 2 番目以降のキーはキャッシュに残っているため再アクセスは発生しない。
        let fetcher = HeaderFixtureFetcher(responses: [:])
        let clock = TestClock(now: Date(timeIntervalSince1970: 1000))
        let client = makeClient(fetcher: fetcher, clock: clock)
        let base = SudmonitorHistoryMonth(year: 2020, month: 1)
        let months = (0..<129).map { month($0, from: base) }

        for month in months {
            let result = await client.fetchMonthly(damId: damId, month: month)
            guard case .notFound = result else {
                Issue.record("Expected notFound for \(month.identifier) but got \(result)")
                return
            }
        }
        #expect(fetcher.requestedURLs.count == 129)

        // 最古(先頭)のキーは evict されているため再フェッチされる
        _ = await client.fetchMonthly(damId: damId, month: months[0])
        #expect(fetcher.requestedURLs.count == 130, "最古のキーは evict され再フェッチされる")

        // 容量満杯のため、再 put によって次の最古キーも連鎖 evict され再フェッチされる
        _ = await client.fetchMonthly(damId: damId, month: months[1])
        #expect(fetcher.requestedURLs.count == 131, "再 put で次の最古キーも連鎖 evict される")

        // 最新のキーはキャッシュに残っており再アクセスされない
        _ = await client.fetchMonthly(damId: damId, month: months[128])
        #expect(fetcher.requestedURLs.count == 131, "最新のキーはキャッシュヒットし再アクセスされない")
    }

    @Test func negativeCacheKeepsCapacityWithinLimit() {
        // 129 キーを put してもキャッシュは 128 件以下に維持される(決定的)
        let cache = SudmonitorNegativeCache()
        let now = Date(timeIntervalSince1970: 1000)
        for index in 0..<129 {
            let month = month(index, from: SudmonitorHistoryMonth(year: 2020, month: 1))
            cache.put(SudmonitorNegativeCache.Key(damId: damId, kind: .monthly, month: month.identifier), now: now)
        }
        let hits = (0..<129).filter { index in
            let month = month(index, from: SudmonitorHistoryMonth(year: 2020, month: 1))
            return cache.isCached(SudmonitorNegativeCache.Key(damId: damId, kind: .monthly, month: month.identifier), now: now)
        }
        #expect(hits.count <= 128)
        #expect(hits.count >= 127, "上限超過時は少なくとも 1 件破棄される")
    }

    @Test func unsupportedDamIdReturnsNotFoundWithoutNetworkAccess() async {
        let fetcher = HeaderFixtureFetcher(responses: [:])
        let client = makeClient(fetcher: fetcher, clock: TestClock(now: Date(timeIntervalSince1970: 0)))

        let monthly = await client.fetchMonthly(damId: unsupportedDamId, month: SudmonitorHistoryMonth(year: 2026, month: 7))
        guard case .notFound = monthly else {
            Issue.record("Expected notFound but got \(monthly)")
            return
        }
        let latest = await client.fetchLatest(damId: unsupportedDamId)
        guard case .notFound = latest else {
            Issue.record("Expected notFound but got \(latest)")
            return
        }
        #expect(fetcher.requestedURLs.isEmpty)
    }

    @Test func fetchMonthlyRealFixtureServesSameBytes() async {
        let fixtureBytes = sudmonitorFixtureData(named: "202607_monthly.dat")
        let url = "\(historyBase)/\(damId)/1368080700010_202607010100_202607312400.dat"
        let fetcher = HeaderFixtureFetcher(responses: [
            url: (fixtureBytes, [
                "X-TCS-Dam-Id": damId,
                "X-TCS-History-Start": "2026-07-01T01:00:00+09:00",
                "X-TCS-History-End": "2026-07-31T24:00:00+09:00",
            ]),
        ])
        let client = makeClient(fetcher: fetcher, clock: TestClock(now: Date(timeIntervalSince1970: 0)))

        let result = await client.fetchMonthly(damId: damId, month: SudmonitorHistoryMonth(year: 2026, month: 7))

        guard case .success(let response) = result else {
            Issue.record("Expected success but got \(result)")
            return
        }
        #expect(response.bytes == fixtureBytes)
    }
}

/// 応答ヘッダー付きフェッチ用の注入フェッチャ。
/// 登録 URL は `(Data, [String: String])` を返し、`failures` に登録された URL は指定エラーを throw します。
/// 未登録 URL は 404(`DamCoreMlitURLPolicyError.badHTTPStatus(404)`) として扱います。
private final class HeaderFixtureFetcher: @unchecked Sendable {
    private let responses: [String: (Data, [String: String])]
    private let failures: [String: any Error]
    private nonisolated(unsafe) var urls: [String] = []

    init(
        responses: [String: (Data, [String: String])] = [:],
        failures: [String: any Error] = [:]
    ) {
        self.responses = responses
        self.failures = failures
    }

    var requestedURLs: [String] {
        urls
    }

    func fetch(urlString: String) async throws -> (Data, [String: String]) {
        urls.append(urlString)
        if let error = failures[urlString] {
            throw error
        }
        guard let entry = responses[urlString] else {
            throw DamCoreMlitURLPolicyError.badHTTPStatus(404)
        }
        return entry
    }
}

/// テスト用に現在日時を制御するクロック。
private final class TestClock: @unchecked Sendable {
    nonisolated(unsafe) var current: Date

    init(now: Date) {
        current = now
    }
}

/// sudmonitor フィクスチャを `#filePath` 相対で読み込みます。
private func sudmonitorFixtureData(named name: String) -> Data {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appending(path: "Fixtures/sudmonitor/\(name)")
    return try! Data(contentsOf: url)
}
