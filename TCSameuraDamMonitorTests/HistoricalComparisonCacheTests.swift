// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Testing
import Foundation
@testable import TCSameuraDamMonitor

/// 月次projectionキャッシュactorのヒット・in-flight dedup・LRU evict・失敗非cacheのテスト。
@Suite("Historical comparison cache")
struct HistoricalComparisonCacheTests {
    @Test("a cached projection returns without reloading")
    func hit() async throws {
        let cache = HistoricalComparisonCache()
        let counter = LoadCounter()
        let entry = Self.entry("a.dat")
        let load: @Sendable (HistoricalDatFileEntry) async throws -> HistoricalComparisonMonthProjection = { entry in
            counter.increment()
            return Self.projection(entry.filePath)
        }
        let first = try await cache.projection(for: entry, load: load)
        #expect(first.filePath == "a.dat")
        let second = try await cache.projection(for: entry, load: load)
        #expect(second.filePath == "a.dat")
        #expect(counter.count == 1)
    }

    @Test("concurrent requests for the same key share a single load task")
    func inFlightDedup() async throws {
        let cache = HistoricalComparisonCache()
        let counter = LoadCounter()
        let entry = Self.entry("a.dat")
        let load: @Sendable (HistoricalDatFileEntry) async throws -> HistoricalComparisonMonthProjection = { entry in
            counter.increment()
            try await Task.sleep(for: .milliseconds(50))
            return Self.projection(entry.filePath)
        }
        async let first: HistoricalComparisonMonthProjection = cache.projection(for: entry, load: load)
        async let second: HistoricalComparisonMonthProjection = cache.projection(for: entry, load: load)
        let results = try await (first, second)
        #expect(results.0.filePath == "a.dat")
        #expect(results.1.filePath == "a.dat")
        #expect(counter.count == 1)
    }

    @Test("LRU evicts the oldest entry beyond maxCount")
    func lruEvictsOldest() async throws {
        let cache = HistoricalComparisonCache(maxCount: 2)
        let counter = LoadCounter()
        let load: @Sendable (HistoricalDatFileEntry) async throws -> HistoricalComparisonMonthProjection = { entry in
            counter.increment()
            return Self.projection(entry.filePath)
        }
        let a = Self.entry("a.dat")
        let b = Self.entry("b.dat")
        let c = Self.entry("c.dat")
        _ = try await cache.projection(for: a, load: load)
        _ = try await cache.projection(for: b, load: load)
        _ = try await cache.projection(for: c, load: load)
        #expect(counter.count == 3)
        _ = try await cache.projection(for: a, load: load)
        #expect(counter.count == 4)
        _ = try await cache.projection(for: b, load: load)
        #expect(counter.count == 5)
        _ = try await cache.projection(for: c, load: load)
        #expect(counter.count == 6)
    }

    @Test("a failed load is not cached and can be retried")
    func failureNotCached() async throws {
        let cache = HistoricalComparisonCache()
        let counter = LoadCounter()
        let entry = Self.entry("a.dat")
        let load: @Sendable (HistoricalDatFileEntry) async throws -> HistoricalComparisonMonthProjection = { entry in
            counter.increment()
            if counter.count == 1 {
                throw HistoricalComparisonServiceError.assetLoadFailed(entry.filePath)
            }
            return Self.projection(entry.filePath)
        }
        await #expect(throws: HistoricalComparisonServiceError.assetLoadFailed("a.dat")) {
            _ = try await cache.projection(for: entry, load: load)
        }
        let result = try await cache.projection(for: entry, load: load)
        #expect(result.filePath == "a.dat")
        #expect(counter.count == 2)
    }

    @Test("different keys load and cache independently")
    func distinctKeysIndependent() async throws {
        let cache = HistoricalComparisonCache()
        let counter = LoadCounter()
        let load: @Sendable (HistoricalDatFileEntry) async throws -> HistoricalComparisonMonthProjection = { entry in
            counter.increment()
            return Self.projection(entry.filePath)
        }
        let a = Self.entry("a.dat")
        let b = Self.entry("b.dat")
        _ = try await cache.projection(for: a, load: load)
        _ = try await cache.projection(for: b, load: load)
        _ = try await cache.projection(for: a, load: load)
        _ = try await cache.projection(for: b, load: load)
        #expect(counter.count == 2)
    }

    // MARK: - fixture helpers

    private static func entry(_ filePath: String) -> HistoricalDatFileEntry {
        HistoricalDatFileEntry(stationId: "1368080700010", startDatetime: "202606010100",
                               endDatetime: "202606302400", filePath: filePath)
    }

    private static func projection(_ filePath: String) -> HistoricalComparisonMonthProjection {
        HistoricalComparisonMonthProjection(filePath: filePath, year: 2026, month: 6, points: [])
    }
}

/// ロードクロージャ呼出回数を数えるためのスレッドセーフなカウンタ。
private final class LoadCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func increment() {
        lock.lock()
        value += 1
        lock.unlock()
    }
}
