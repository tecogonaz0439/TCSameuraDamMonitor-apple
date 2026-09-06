// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation
import TCSameuraDamCore

/// リアルタイム観測データ (Real-time observation data) のフェッチおよび解析処理の結果を保持する構造体。
nonisolated internal struct RealtimeFetchResult: Sendable {
    /// 解析済みのダム諸量データ。
    internal let data: DamData
    /// 取得したDATファイルの生のバイナリデータ。
    internal let rawBytes: Data
    /// 取得したDATファイルのファイル名。
    internal let rawDatFileName: String?
    /// デバッグ用に自動進行された、次回のデータ終了日時。
    internal let nextDebugDataEndDate: Date?
    /// sudmonitor 中継サーバーが記録した MLIT データ取得時刻（`X-TCS-Fetched-At` ヘッダー由来）。
    internal let originFetchedAt: Date?
    /// sudmonitor 中継サーバーが通知する次回更新予定時刻（`X-TCS-Next-Update-At` ヘッダー由来。欠落・不正時・MLIT 直接時は nil）。
    internal let nextUpdateAt: Date?
}

/// 国土交通省（MLIT）のWebサイトからリアルタイム観測データ (Real-time observation data) を取得・解析するサービス構造体。
nonisolated
internal struct RealtimeDataService {
    /// HTMLおよびDATファイル解析用パーサー。
    internal let parser: MlitDamParser
    /// ネットワークアクセス用のデータソース。
    internal let network: MlitNetworkDataSource
    /// ネットワークの接続可能性状態を提供するプロバイダ。
    internal let networkAvailability: any NetworkAvailabilityProviding

    /// 指定されたダム設定とアプリ設定に基づいて、最新のリアルタイム観測データ (Real-time observation data) をフェッチ・パースして取得します。
    /// - Parameters:
    ///   - config: 取得対象のダム構成設定。
    ///   - settings: アプリ設定。
    ///   - debugDatBytes: デバッグモード時にデバッグ用DATデータを生成するためのクロージャ。
    ///   - nextAutoAdvancedDebugDataEndDate: デバッグモード時に次のデバッグ用データ終了日時を算出するためのクロージャ。
    /// - Returns: フェッチおよび解析結果を格納した `RealtimeFetchResult`。
    /// - Throws: 通信エラー、パースエラー、シミュレートされたエラーなど。
    internal func fetchLatestData(
        config: DamConfig,
        settings: AppSettings,
        debugDatBytes: (AppSettings) throws -> Data,
        nextAutoAdvancedDebugDataEndDate: (Data, AppSettings) -> Date?
    ) async throws -> RealtimeFetchResult {
        try Task.checkCancellation()
        #if DEBUG
        if settings.debugModeEnabled && settings.debugSimulateMode == .networkUnavailable {
            throw AppError.simulatedNetworkUnavailable
        }
        if settings.debugModeEnabled && settings.debugSimulateMode == .loadingFailure {
            throw AppError.simulatedLoadingFailure
        }
        let datBytes: Data
        let rawDatFileName: String?
        let nextDebugDataEndDate: Date?
        let originFetchedAt: Date?
        let nextUpdateAt: Date?
        if settings.debugModeEnabled {
            datBytes = try debugDatBytes(settings)
            rawDatFileName = nil
            nextDebugDataEndDate = nextAutoAdvancedDebugDataEndDate(datBytes, settings)
            originFetchedAt = nil
            nextUpdateAt = nil
        } else {
            let fetched = try await fetchRealtimeDat(config: config, settings: settings)
            datBytes = fetched.bytes
            rawDatFileName = fetched.fileName
            nextDebugDataEndDate = nil
            originFetchedAt = fetched.originFetchedAt
            nextUpdateAt = fetched.nextUpdateAt
        }
        #else
        let fetched = try await fetchRealtimeDat(config: config, settings: settings)
        let datBytes = fetched.bytes
        let rawDatFileName = fetched.fileName
        let nextDebugDataEndDate: Date? = nil
        let originFetchedAt = fetched.originFetchedAt
        let nextUpdateAt = fetched.nextUpdateAt
        #endif

        let stationId = config.id
        let stationName = config.nameJa
        let debugDataEndDate = settings.debugModeEnabled ? settings.debugRealtimeDataEndDate : nil
        let parsed = try await Task.detached(priority: .userInitiated) {
            try MlitDamParser().parseRealtimeDat(
                datBytes,
                stationId: stationId,
                stationName: stationName,
                debugDataEndDate: debugDataEndDate
            )
        }.value
        try Task.checkCancellation()
        return RealtimeFetchResult(
            data: parsed,
            rawBytes: datBytes,
            rawDatFileName: rawDatFileName,
            nextDebugDataEndDate: nextDebugDataEndDate,
            originFetchedAt: originFetchedAt,
            nextUpdateAt: nextUpdateAt
        )
    }

    /// 実際にネットワークから最新のDATファイルをフェッチします。
    private func fetchRealtimeDat(config: DamConfig, settings: AppSettings) async throws -> (bytes: Data, fileName: String?, originFetchedAt: Date?, nextUpdateAt: Date?) {
        guard networkAvailability.isNetworkAvailable else {
            throw AppError.networkUnavailable
        }
        try Task.checkCancellation()
        switch settings.realtimeDataSource {
        case .sudmonitor:
            return try await fetchSudmonitorDat(config: config)
        case .mlitDirect:
            let html = try await network.fetchBytes(config.dataUrl)
            try Task.checkCancellation()
            let datURL = try parser.parseHTMLForDatURL(html)
            let datBytes = try await network.fetchBytes(datURL)
            try Task.checkCancellation()
            return (datBytes, Self.datFileName(from: datURL), nil, nil)
        }
    }

    /// sudmonitor 中継サーバーから最新のDATファイルを単一GETでフェッチします。
    private func fetchSudmonitorDat(config: DamConfig) async throws -> (bytes: Data, fileName: String?, originFetchedAt: Date?, nextUpdateAt: Date?) {
        let damId = RealtimeDataSource.sudmonitorSupportedDamIds.contains(config.id) ? config.id : AppSettings.defaultDamId
        let urlString = RealtimeDataSource.sudmonitorLatestDatURL(damId: damId)
        let (bytes, headers) = try await network.fetchBytesWithHeaders(urlString)
        try Task.checkCancellation()
        if let headerDamId = DamCoreHTTPHeaders.value(headers, forField: "X-TCS-Dam-Id"), headerDamId != damId {
            throw MlitNetworkError.transport
        }
        let originFetchedAt = DamCoreHTTPHeaders.value(headers, forField: "X-TCS-Fetched-At")
            .flatMap { ISO8601UTCDateParser.parse($0) }
        let nextUpdateAt = DamCoreHTTPHeaders.value(headers, forField: "X-TCS-Next-Update-At")
            .flatMap { ISO8601UTCDateParser.parse($0) }
        return (bytes, "latest.dat", originFetchedAt, nextUpdateAt)
    }

    /// URL文字列からDATファイルのファイル名を抽出します。
    private static func datFileName(from urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed) {
            let lastPathComponent = url.lastPathComponent
            if !lastPathComponent.isEmpty {
                return lastPathComponent
            }
        }
        let lastComponent = trimmed.split(separator: "/").last.map(String.init)
        return lastComponent?.isEmpty == false ? lastComponent : nil
    }
}

/// ISO8601 (UTC) 形式の日時文字列を解析するユーティリティ（小数秒の有無を許容）。
nonisolated internal enum ISO8601UTCDateParser {
    /// 小数秒ありの ISO8601 フォーマッター。
    nonisolated(unsafe) private static let fractionalSecondsFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// 小数秒なしの ISO8601 フォーマッター。
    nonisolated(unsafe) private static let fallbackFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// 日時文字列を ISO8601 (UTC) として解析します（小数秒の有無を許容）。
    /// - Parameter value: 解析対象の日時文字列。
    /// - Returns: 解析された日時。解析できない場合は nil。
    internal nonisolated static func parse(_ value: String) -> Date? {
        if let date = fractionalSecondsFormatter.date(from: value) {
            return date
        }
        return fallbackFormatter.date(from: value)
    }
}
