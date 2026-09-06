// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Network

/// デバイスのネットワーク接続可用性状態を判定する機能を提供するプロトコル。
internal protocol NetworkAvailabilityProviding: Sendable {
    /// ネットワーク接続が現在利用可能であるかどうかを示すフラグ。
    nonisolated var isNetworkAvailable: Bool { get }
}

/// `NWPathMonitor` を用いて、リアルタイムにネットワーク接続状態の変更を監視し可用性を提供するモニタークラス。
internal final class NetworkAvailabilityMonitor: @unchecked Sendable, NetworkAvailabilityProviding {
    /// ネットワーク接続状態監視用モニター。
    private let monitor: NWPathMonitor
    /// 状態監視用キュー。
    private let queue = DispatchQueue(label: "net.tecogonaz.TCSameuraDamMonitor.networkAvailability")
    /// アトミックな読み書きを担保するための排他ロック。
    private let lock = NSLock()
    /// 直近で通知されたネットワーク接続状態。
    private nonisolated(unsafe) var latestStatus: NWPath.Status = .satisfied

    /// ネットワークモニターを初期化し、接続パスの監視を開始します。
    /// - Parameter monitor: 使用する `NWPathMonitor`。デフォルトは新規作成されます。
    internal init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            self?.update(status: path.status)
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    /// ネットワーク接続が現在利用可能であるかどうかを示すフラグ（プロトコル準拠）。
    internal nonisolated var isNetworkAvailable: Bool {
        lock.lock()
        defer { lock.unlock() }
        return latestStatus == .satisfied
    }

    /// 内部で検知した接続状態をロック保護のもとで更新します。
    private nonisolated func update(status: NWPath.Status) {
        lock.lock()
        latestStatus = status
        lock.unlock()
    }
}

