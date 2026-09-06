// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation
import SwiftData
import TCSameuraDamCore

/// sudmonitor 日次過去データ(latest.dat)の取得・保存・クールダウン判定の結果を表す列挙型。
internal enum SudmonitorHistoryFetchOutcome: Sendable {
    /// 保存に成功した。
    case stored
    /// 404(未蓄積)または非対応ダムのため何も保存しなかった。
    case skippedNotFound
    /// since/until ヘッダーが欠落・不正で期間を確定できないため何も保存しなかった。
    case skippedInvalidPeriod
    /// 自動更新間隔(1時間/12時間)のクールダウンが明けていないため何も取得しなかった。
    case skippedByCooldown
    /// 機能ゲート(過去データの取得ソース設定)が無効のため何も行わなかった。
    case gateDisabled
    /// その他の失敗。
    case failure(Error)
}

/// デバッグ用の日次過去DATが満たすべき構造の検証エラー。
internal enum SudmonitorHistoryDebugDatError: Error, Equatable, Sendable {
    /// DATに観測行がない、またはパースできない。
    case invalidData
    /// DATの観測所記号が対象ダムと一致しない。
    case stationMismatch
    /// 先頭行が01:00、または末尾行が24:00ではない。
    case invalidBoundary
    /// 不正な日時、重複日時、または時系列の逆転がある。
    case invalidChronology
}

/// 検証済みデバッグ用日次過去DATの保存情報。
internal struct ValidatedSudmonitorHistoryDebugDat: Sendable {
    /// DATから導出した期間開始日(yyyyMMdd)。
    internal let periodStartDay: String
    /// DATから導出した期間終了日(yyyyMMdd)。
    internal let periodEndDay: String
    /// パース済みの全観測行。
    internal let rows: [DamHistoricalData]
}

/// sudmonitor の日次過去データ(latest.dat)の取得・保存・クールダウン判定を担うサービス構造体。
@MainActor
internal struct SudmonitorHistoryService {
    /// sudmonitor 履歴ファイル取得クライアント。
    internal let sudmonitorClient: SudmonitorHistoricalClient

    /// 日次過去データサービスを初期化します。
    /// - Parameter sudmonitorClient: sudmonitor 履歴ファイル取得クライアント。
    internal init(sudmonitorClient: SudmonitorHistoricalClient) {
        self.sudmonitorClient = sudmonitorClient
    }

    /// 対象ダムの保存済み日次過去データレコードを取得します。
    /// - Parameters:
    ///   - damId: 対象ダムの観測所ID。
    ///   - context: SwiftData のモデルコンテキスト。
    /// - Returns: 保存済みレコード。未保存の場合は nil。
    internal func record(damId: String, context: ModelContext) -> SudmonitorHistoryRecord? {
        ((try? context.fetch(FetchDescriptor<SudmonitorHistoryRecord>())) ?? [])
            .first { $0.damId == damId }
    }

    /// 対象ダムの日次過去データを取得し、damId ごとに1件へ上書き保存します。
    ///
    /// 機能ゲート(`historicalDataSource == .sudmonitor`)が無効の場合は何も行いません。
    /// 404(未蓄積)・非対応ダムは静かにスキップし、期間ヘッダー(since/until)の欠落・不正も
    /// レコードを作成せずスキップします。保存は damId で fetch → delete → insert +
    /// `context.save()` の all-or-nothing で行います。
    /// - Parameters:
    ///   - damId: 対象ダムの観測所ID。
    ///   - context: SwiftData のモデルコンテキスト。
    ///   - historicalDataSource: 過去データ検索のデータソース設定(機能ゲート判定)。
    ///   - now: 取得・保存日時(既定は現在日時)。
    /// - Returns: 取得・保存結果。
    internal func fetchAndStore(
        damId: String,
        context: ModelContext,
        historicalDataSource: RealtimeDataSource,
        now: Date = Date()
    ) async -> SudmonitorHistoryFetchOutcome {
        guard Self.isGateEnabled(historicalDataSource: historicalDataSource) else {
            return .gateDisabled
        }
        switch await sudmonitorClient.fetchLatest(damId: damId) {
        case .notFound:
            return .skippedNotFound
        case .failure(let error):
            return .failure(error)
        case .success(let response):
            guard let (startDay, endDay) = HistoricalSearchService.historyDayRange(from: response) else {
                return .skippedInvalidPeriod
            }
            let nextUpdateAt = response.nextUpdateAt ?? Self.fallbackNextUpdateAt(from: now)
            do {
                let existing = try context.fetch(FetchDescriptor<SudmonitorHistoryRecord>())
                existing.filter { $0.damId == damId }.forEach { context.delete($0) }
                context.insert(SudmonitorHistoryRecord(
                    damId: damId,
                    periodStartDay: startDay,
                    periodEndDay: endDay,
                    fetchedAt: now,
                    nextUpdateAt: nextUpdateAt,
                    rawDatBytes: response.bytes
                ))
                try context.save()
                return .stored
            } catch {
                return .failure(error)
            }
        }
    }

    /// ローカルのデバッグ用日次過去DATを検証し、damIdごとに1件へ上書き保存します。
    ///
    /// ネットワーク取得、データソースの機能ゲート、クールダウン判定は行いません。
    /// DATの全rawバイトを保持し、ローカルデータにはレスポンスヘッダーがないため
    /// `nextUpdateAt` は常にnilで保存します。
    /// - Parameters:
    ///   - datBytes: デバッグ用日次過去DATの全バイト。
    ///   - rawDatFileName: DATの表示・エクスポート用ファイル名。
    ///   - damId: 対象ダムの観測所ID。
    ///   - context: SwiftDataのモデルコンテキスト。
    ///   - now: 保存日時。
    /// - Returns: 検証・保存結果。
    internal func storeDebugDat(
        _ datBytes: Data,
        rawDatFileName: String?,
        damId: String,
        context: ModelContext,
        now: Date = Date()
    ) -> SudmonitorHistoryFetchOutcome {
        do {
            let validated = try Self.validateDebugDat(datBytes, damId: damId)
            let existing = try context.fetch(FetchDescriptor<SudmonitorHistoryRecord>())
            existing.filter { $0.damId == damId }.forEach { context.delete($0) }
            context.insert(SudmonitorHistoryRecord(
                damId: damId,
                periodStartDay: validated.periodStartDay,
                periodEndDay: validated.periodEndDay,
                fetchedAt: now,
                nextUpdateAt: nil,
                rawDatBytes: datBytes,
                rawDatFileName: rawDatFileName
            ))
            try context.save()
            return .stored
        } catch {
            return .failure(error)
        }
    }

    /// デバッグ用日次過去DATの観測所、期間境界、全行日時と時系列順を検証します。
    /// - Parameters:
    ///   - datBytes: 検証するDATの全バイト。
    ///   - damId: 対象ダムの観測所ID。
    /// - Returns: DATから導出した期間と全観測行。
    /// - Throws: DATが日次過去データとして不正な場合は `SudmonitorHistoryDebugDatError`。
    internal nonisolated static func validateDebugDat(
        _ datBytes: Data,
        damId: String
    ) throws -> ValidatedSudmonitorHistoryDebugDat {
        let parsed: (HistoricalSearchMeta, [DamHistoricalData])
        do {
            parsed = try MlitDamParser().parseHistoricalDat(
                datBytes,
                damConfigId: damId,
                startDate: "",
                endDate: ""
            )
        } catch {
            throw SudmonitorHistoryDebugDatError.invalidData
        }
        guard parsed.0.observationStationId == damId else {
            throw SudmonitorHistoryDebugDatError.stationMismatch
        }
        let rows = parsed.1
        guard let first = rows.first, let last = rows.last else {
            throw SudmonitorHistoryDebugDatError.invalidData
        }
        guard Self.timeComponent(from: first.time) == "01:00",
              Self.timeComponent(from: last.time) == "24:00",
              let startDay = Self.rawDay(from: first.time),
              let endDay = Self.rawDay(from: last.time) else {
            throw SudmonitorHistoryDebugDatError.invalidBoundary
        }

        var previousMillis: Double?
        for row in rows {
            guard let millis = TimeFormatters.millisIfValid(fromDamTime: row.time) else {
                throw SudmonitorHistoryDebugDatError.invalidChronology
            }
            if let previousMillis, millis <= previousMillis {
                throw SudmonitorHistoryDebugDatError.invalidChronology
            }
            previousMillis = millis
        }
        return ValidatedSudmonitorHistoryDebugDat(
            periodStartDay: startDay,
            periodEndDay: endDay,
            rows: rows
        )
    }

    /// DAT観測行の生日時から時刻部分を返します。
    private nonisolated static func timeComponent(from damTime: String) -> String? {
        let components = damTime.split(whereSeparator: { $0.isWhitespace })
        guard components.count == 2 else { return nil }
        return String(components[1])
    }

    /// DAT観測行の生日時からyyyyMMdd形式の日付を返します。
    ///
    /// 末尾24:00は翌日へ正規化せず、生の行に記録された日を期間終了日とします。
    private nonisolated static func rawDay(from damTime: String) -> String? {
        guard let rawDate = damTime.split(whereSeparator: { $0.isWhitespace }).first else { return nil }
        let components = rawDate.split(separator: "/")
        guard components.count == 3,
              let year = Int(components[0]),
              let month = Int(components[1]),
              let day = Int(components[2]),
              (1...12).contains(month),
              (1...31).contains(day),
              Calendar(identifier: .gregorian).date(from: DateComponents(
                timeZone: TimeZone(secondsFromGMT: 9 * 60 * 60),
                year: year,
                month: month,
                day: day
              )) != nil else {
            return nil
        }
        return String(format: "%04d%02d%02d", year, month, day)
    }

    /// 自動更新設定の間隔に連動して日次過去データを取得します。
    ///
    /// 間隔が 1時間/12時間 の場合は、保存済み `nextUpdateAt` が明けていない限り skip します
    /// (結果的に最大 1 日 1 回の更新になります)。間隔が 1日/1週間 の場合は設定どおり実行します。
    /// - Parameters:
    ///   - interval: 自動更新の間隔設定。
    ///   - damId: 対象ダムの観測所ID。
    ///   - context: SwiftData のモデルコンテキスト。
    ///   - historicalDataSource: 過去データ検索のデータソース設定(機能ゲート判定)。
    ///   - now: 基準日時(既定は現在日時)。
    /// - Returns: 取得・保存結果。
    internal func autoFetch(
        interval: AutoUpdateInterval,
        damId: String,
        context: ModelContext,
        historicalDataSource: RealtimeDataSource,
        now: Date = Date()
    ) async -> SudmonitorHistoryFetchOutcome {
        guard Self.isGateEnabled(historicalDataSource: historicalDataSource) else {
            return .gateDisabled
        }
        switch interval {
        case .oneHour, .twelveHours:
            if let saved = record(damId: damId, context: context),
               let nextUpdateAt = saved.nextUpdateAt,
               nextUpdateAt > now {
                return .skippedByCooldown
            }
        case .oneDay, .oneWeek:
            break
        }
        return await fetchAndStore(
            damId: damId,
            context: context,
            historicalDataSource: historicalDataSource,
            now: now
        )
    }

    /// 手動更新のクールダウン終了時刻(保存済み `nextUpdateAt`)を取得します。
    /// - Parameters:
    ///   - damId: 対象ダムの観測所ID。
    ///   - context: SwiftData のモデルコンテキスト。
    /// - Returns: クールダウン終了時刻。レコード未保存の場合は nil(= いつでも更新可能)。
    internal func manualRefreshAvailableAt(damId: String, context: ModelContext) -> Date? {
        record(damId: damId, context: context)?.nextUpdateAt
    }

    /// ウィジェット側がバックグラウンドで取得した日次過去データブリッジを、アプリの SwiftData レコードへ取り込みます。
    ///
    /// 期間ヘッダー(since/until)が欠落・不正の場合は取り込まず `.skippedInvalidPeriod` を返します。
    /// 保存は damId で fetch → delete → insert + `context.save()` の all-or-nothing で行います。
    /// - Parameters:
    ///   - bridge: ウィジェット側が保存した日次過去データブリッジ。
    ///   - context: SwiftData のモデルコンテキスト。
    /// - Returns: 取り込み結果。
    internal func importBridge(_ bridge: DamCoreDailyHistoryBridge, context: ModelContext) -> SudmonitorHistoryFetchOutcome {
        guard let (startDay, endDay) = HistoricalSearchService.historyDayRange(since: bridge.since, until: bridge.until) else {
            return .skippedInvalidPeriod
        }
        do {
            let existing = try context.fetch(FetchDescriptor<SudmonitorHistoryRecord>())
            existing.filter { $0.damId == bridge.stationId }.forEach { context.delete($0) }
            context.insert(SudmonitorHistoryRecord(
                damId: bridge.stationId,
                periodStartDay: startDay,
                periodEndDay: endDay,
                fetchedAt: bridge.fetchedAt,
                nextUpdateAt: bridge.nextUpdateAt,
                rawDatBytes: bridge.rawBytes,
                rawDatFileName: bridge.rawDatFileName
            ))
            try context.save()
            return .stored
        } catch {
            return .failure(error)
        }
    }

    /// 機能ゲート(過去データの取得ソースが sudmonitor)が有効かどうかを判定します。
    /// - Parameter historicalDataSource: 過去データ検索のデータソース設定。
    /// - Returns: 有効な場合は `true`。
    internal static func isGateEnabled(historicalDataSource: RealtimeDataSource) -> Bool {
        historicalDataSource == .sudmonitor
    }

    /// `X-TCS-Next-Update-At` ヘッダー欠落時のフォールバック時刻(翌日 00:13 JST)を算出します。
    /// - Parameter date: 基準日時(通常は取得日時)。
    /// - Returns: 翌日 00:13 JST。算出できない場合は nil。
    internal static func fallbackNextUpdateAt(from date: Date) -> Date? {
        let startOfDay = Calendar.jst.startOfDay(for: date)
        guard let tomorrow = Calendar.jst.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }
        return Calendar.jst.date(byAdding: .minute, value: 13, to: tomorrow)
    }
}
