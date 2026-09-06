// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// 月次projectionをファイルパスをキーとしてLRUキャッシュし、同一キーの並行読込を1つのTaskへ集約するactor。
actor HistoricalComparisonCache {
    /// キャッシュの最大件数。
    private let maxCount: Int
    /// ファイルパスをキーとするprojectionキャッシュ。
    private var cache: [String: HistoricalComparisonMonthProjection] = [:]
    /// アクセス順(古い順)のキーの一覧。
    private var recency: [String] = []
    /// 読込中のTaskの一覧。
    private var inFlight: [String: Task<HistoricalComparisonMonthProjection, any Error>] = [:]

    /// キャッシュを初期化します。
    /// - Parameter maxCount: キャッシュの最大件数。デフォルトは128です。
    init(maxCount: Int = 128) {
        self.maxCount = maxCount
    }

    /// 指定されたエントリのprojectionを返します。
    ///
    /// キャッシュヒット時は即座に返し、同一キーの並行要求は同一の読込Taskを待ち合わせます。
    /// 成功時はLRUキャッシュへ格納し(最大`maxCount`件、超過分は最古から破棄)、
    /// 失敗時はキャッシュせずにエラーをそのまま伝播します(次回の再試行が可能)。
    /// - Parameters:
    ///   - entry: 月次エントリ。
    ///   - load: 未キャッシュ時に実行される読込クロージャ。
    /// - Returns: 月次projection。
    func projection(for entry: HistoricalDatFileEntry,
                    load: @escaping @Sendable (HistoricalDatFileEntry) async throws -> HistoricalComparisonMonthProjection) async throws -> HistoricalComparisonMonthProjection {
        let key = entry.filePath
        if let cached = cache[key] {
            touch(key)
            return cached
        }
        if let task = inFlight[key] {
            return try await task.value
        }
        let task = Task { try await load(entry) }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        let result = try await task.value
        insert(key, result)
        return result
    }

    /// キーの直近アクセス順を更新します。
    private func touch(_ key: String) {
        recency.removeAll { $0 == key }
        recency.append(key)
    }

    /// 成功したprojectionをLRUキャッシュへ格納します。
    private func insert(_ key: String, _ value: HistoricalComparisonMonthProjection) {
        if cache[key] != nil {
            touch(key)
            return
        }
        cache[key] = value
        recency.append(key)
        while recency.count > maxCount {
            let oldest = recency.removeFirst()
            cache[oldest] = nil
        }
    }
}
