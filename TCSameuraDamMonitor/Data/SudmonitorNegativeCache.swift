// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// sudmonitor 履歴取得の負の結果(404)を一時的に記録するプロセス内キャッシュ。
nonisolated final class SudmonitorNegativeCache: @unchecked Sendable {
    /// キャッシュ種別。
    internal enum Kind: Hashable, Sendable {
        /// 月次ファイル。
        case monthly
        /// 日次ファイル (latest.dat)。
        case latest
    }

    /// キャッシュキー。
    internal struct Key: Hashable, Sendable {
        /// 対象ダムの観測所ID。
        internal let damId: String
        /// キャッシュ種別。
        internal let kind: Kind
        /// 対象月の識別子(月次のみ。日次は nil)。
        internal let month: String?
    }

    private let lock = NSLock()
    private var entries: [Key: Date] = [:]
    /// 挿入順を保証するキー列(先頭が最古)。evict はこの先頭から行います。
    private var order: [Key] = []
    private let ttl: TimeInterval = 5 * 60
    private let maxCount = 128

    /// TTL が有効な負の結果が記録されているかどうかを判定します。TTL 超過分は削除して false を返します。
    /// - Parameters:
    ///   - key: 判定対象のキー。
    ///   - now: 現在日時。
    /// - Returns: 負の結果が有効に記録されている場合は `true`。
    internal func isCached(_ key: Key, now: Date) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let cachedAt = entries[key] else { return false }
        if now.timeIntervalSince(cachedAt) > ttl {
            entries.removeValue(forKey: key)
            order.removeAll { $0 == key }
            return false
        }
        return true
    }

    /// 負の結果を記録します。上限を超えた場合は挿入順の先頭(最古)から破棄します。
    /// - Parameters:
    ///   - key: 記録対象のキー。
    ///   - now: 現在日時。
    internal func put(_ key: Key, now: Date) {
        lock.lock()
        defer { lock.unlock() }
        if entries[key] == nil {
            order.append(key)
        }
        entries[key] = now
        while order.count > maxCount {
            let oldest = order.removeFirst()
            entries.removeValue(forKey: oldest)
        }
    }
}
