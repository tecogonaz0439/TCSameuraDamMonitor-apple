// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Testing
import Foundation
@testable import TCSameuraDamMonitor

/// 過去比較ローダーの画面ライフタイムbase再利用とmetric切替のテスト。
@Suite("Historical comparison loader")
@MainActor
struct HistoricalComparisonLoaderTests {
    private let sameuraId = "1368080700010"

    @Test("metric switch derives from the screen-lifetime base without reloading assets")
    func loaderReusesBaseAcrossMetricSwitchWithoutReload() async throws {
        let now2026 = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let counter = LoadCounter()
        let entries = (2002...2025).map { year in
            HistoricalDatFileEntry(stationId: sameuraId, startDatetime: "\(year)06010100",
                                   endDatetime: "\(year)06302400", filePath: "\(year)-june.dat")
        }
        let store = HistoricalComparisonAssetStore(entries: entries) { entry in
            counter.increment()
            guard let year = Int(entry.startDatetime.prefix(4)) else { return nil }
            return historicalDatData(rows: [
                historicalDatRow("\(year)/6/27", "12:00", storageVolume: 200000, storagePercentage: 50.0),
                historicalDatRow("\(year)/6/27", "13:00", storageVolume: 201000, storagePercentage: 51.0),
            ])
        }
        let service = HistoricalComparisonService(now: { now2026 }, assetStore: store)
        let loader = HistoricalComparisonLoader(service: service)
        let rows = [
            comparisonRow("2026/6/27 12:00"),
            comparisonRow("2026/6/27 13:00"),
        ]
        loader.load(metric: .storageRate, damConfigId: sameuraId, rows: rows)
        #expect(await waitUntilReady(loader, metric: .storageRate))
        let loadCountAfterRate = counter.count
        #expect(loadCountAfterRate == 24)
        loader.load(metric: .storageVolume, damConfigId: sameuraId, rows: rows)
        if case let .ready(payload) = loader.state(for: .storageVolume) {
            #expect(payload.metric == .storageVolume)
            #expect(payload.pastSeries[0].points[0].value == 200000.0)
            #expect(payload.pastSeries[0].points[1].value == 201000.0)
        } else {
            Issue.record("storageVolume must be ready synchronously from the shared base")
        }
        #expect(counter.count == loadCountAfterRate)
    }

    @Test("changing the daily rows fingerprint rebuilds the base for the next metric")
    func loaderRebuildsBaseWhenDailyRowsChange() async throws {
        let now2026 = try jstDate(year: 2026, month: 6, day: 27, hour: 12, minute: 0)
        let counter = LoadCounter()
        let entries = (2002...2026).map { year in
            HistoricalDatFileEntry(stationId: sameuraId, startDatetime: "\(year)06010100",
                                   endDatetime: "\(year)06302400", filePath: "\(year)-june.dat")
        }
        let store = HistoricalComparisonAssetStore(entries: entries) { entry in
            counter.increment()
            guard let year = Int(entry.startDatetime.prefix(4)) else { return nil }
            return historicalDatData(rows: [
                historicalDatRow("\(year)/6/27", "12:00", storageVolume: 200000, storagePercentage: 50.0),
                historicalDatRow("\(year)/6/27", "13:00", storageVolume: 201000, storagePercentage: 51.0),
            ])
        }
        let service = HistoricalComparisonService(now: { now2026 }, assetStore: store)
        let loader = HistoricalComparisonLoader(service: service)
        let rows = [
            comparisonRow("2018/6/27 12:00"),
            comparisonRow("2018/6/27 13:00"),
        ]
        let dailyA = [
            DamHistoricalData(time: "2026/6/27 13:00", catchmentAverageRainfall: nil,
                              storagePercentage: 55.0, storageVolume: 205000, inflow: nil, outflow: nil),
        ]
        let dailyB = [
            DamHistoricalData(time: "2026/6/27 13:00", catchmentAverageRainfall: nil,
                              storagePercentage: 55.0, storageVolume: 205000, inflow: nil, outflow: nil),
            DamHistoricalData(time: "2026/6/27 12:00", catchmentAverageRainfall: nil,
                              storagePercentage: 54.0, storageVolume: 204000, inflow: nil, outflow: nil),
        ]
        loader.load(metric: .storageRate, damConfigId: sameuraId, rows: rows, mainYear: 2018, dailyRows: dailyA)
        #expect(await waitUntilReady(loader, metric: .storageRate))
        let loadCountAfterRate = counter.count
        // 2002...2026 の25エントリから主系列年2018を除いた24年分を読む。
        #expect(loadCountAfterRate == 24)
        // 日次行の時刻fingerprintが異なるため、storageVolume側はbaseを再構築してdailyBを合成する。
        let generationBefore = loader.generation
        loader.load(metric: .storageVolume, damConfigId: sameuraId, rows: rows, mainYear: 2018, dailyRows: dailyB)
        #expect(loader.generation > generationBefore)
        #expect(await waitUntilReady(loader, metric: .storageVolume))
        // 同一ストアのLRUキャッシュが月次projectionを返すため、dataLoaderは再呼出されない。
        #expect(counter.count == loadCountAfterRate)
        if case let .ready(volume) = loader.state(for: .storageVolume) {
            let volume2026 = volume.pastSeries.first { $0.year == 2026 }
            // dailyBは12:00も上書きする(dailyAのbaseではバンドル値200000のまま)。
            #expect(volume2026?.points[0].value == 204000.0)
            #expect(volume2026?.points[1].value == 205000.0)
        } else {
            Issue.record("storageVolume must be ready with the rebuilt base")
        }
        if case let .ready(rate) = loader.state(for: .storageRate) {
            let rate2026 = rate.pastSeries.first { $0.year == 2026 }
            // dailyAは12:00を上書きしないためバンドル値(50.0)のまま(別base由来であることの確認)。
            #expect(rate2026?.points[0].value == 50.0)
            #expect(rate2026?.points[1].value == 55.0)
        } else {
            Issue.record("storageRate must stay ready from the first base")
        }
    }

    /// 指定Metricが `.ready` になるまで待ち合わせます。
    private func waitUntilReady(_ loader: HistoricalComparisonLoader,
                                metric: HistoricalComparisonMetric,
                                timeout: Duration = .seconds(5)) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if case .ready = loader.state(for: metric) { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return false
    }
}

/// データローダ呼出回数を数えるためのスレッドセーフなカウンタ。
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

private func utf8BOMData(_ text: String) -> Data {
    var data = Data([0xEF, 0xBB, 0xBF])
    data.append(Data(text.utf8))
    return data
}

private func historicalDatData(rows: [String]) -> Data {
    utf8BOMData("""
    水系名,吉野川
    河川名,吉野川
    観測所名,早明浦ダム
    観測所記号,1368080700010
    \(rows.joined(separator: "\n"))
    """)
}

private func historicalDatRow(_ date: String, _ time: String,
                              storageVolume: Float, storagePercentage: Float,
                              volumeQuality: String = " ", pctQuality: String = " ") -> String {
    "\(date),\(time),0, ,\(storageVolume),\(volumeQuality),0, ,0, ,\(storagePercentage),\(pctQuality)"
}

private func jstDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) throws -> Date {
    try #require(Calendar.jst.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)))
}

private func comparisonRow(_ time: String) -> DamHistoricalData {
    DamHistoricalData(time: time, catchmentAverageRainfall: nil, storagePercentage: 50,
                      storageVolume: 200000, inflow: nil, outflow: nil)
}
