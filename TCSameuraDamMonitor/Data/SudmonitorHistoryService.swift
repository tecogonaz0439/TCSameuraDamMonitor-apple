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
    /// 保存済みデータの最終行が当日 00:00 の有効値のため取得不要と判定し、何も取得しなかった。
    case skippedUpToDate
    /// 機能ゲート(過去データの取得ソース設定)が無効のため何も行わなかった。
    case gateDisabled
    /// その他の失敗。
    case failure(Error)
}

/// 日次過去データの保存に必要な取得結果。
internal struct SudmonitorHistoryFetchedDat: Sendable {
    /// 期間開始日(yyyyMMdd)。
    internal let periodStartDay: String
    /// 期間終了日(yyyyMMdd)。
    internal let periodEndDay: String
    /// 次回更新予定時刻(ヘッダー欠落時はフォールバック値)。
    internal let nextUpdateAt: Date?
    /// 取得したDATファイルの全バイト。
    internal let rawDatBytes: Data
}

/// 日次過去データの取得段階の結果(SwiftData 保存前)。
internal enum SudmonitorHistoryFetchPreparation: Sendable {
    /// 機能ゲート(過去データの取得ソース設定)が無効のため何も行わなかった。
    case gateDisabled
    /// 404(未蓄積)または非対応ダムのため何も保存しなかった。
    case skippedNotFound
    /// since/until ヘッダーが欠落・不正で期間を確定できないため何も保存しなかった。
    case skippedInvalidPeriod
    /// その他の失敗。
    case failure(Error)
    /// 保存可能な取得結果。
    case ready(SudmonitorHistoryFetchedDat)
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

    /// 対象ダムの日次過去データを取得し、保存前段階の結果を返します。
    ///
    /// 機能ゲート(`historicalDataSource == .sudmonitor`)が無効の場合は何も行いません。
    /// 404(未蓄積)・非対応ダムは静かにスキップし、期間ヘッダー(since/until)の欠落・不正も
    /// 保存対象にしません。通信・期間解析のみを非隔離で行い、SwiftData 保存は
    /// `store(_:damId:context:now:)` を MainActor 上で呼び出して行います。
    /// - Parameters:
    ///   - damId: 対象ダムの観測所ID。
    ///   - historicalDataSource: 過去データ検索のデータソース設定(機能ゲート判定)。
    ///   - now: 取得日時(既定は現在日時)。
    /// - Returns: 取得段階の結果。
    nonisolated internal func fetchLatest(
        damId: String,
        historicalDataSource: RealtimeDataSource,
        now: Date = Date()
    ) async -> SudmonitorHistoryFetchPreparation {
        guard Self.isGateEnabled(historicalDataSource: historicalDataSource) else {
            return .gateDisabled
        }
        switch await sudmonitorClient.fetchLatest(damId: damId) {
        case .notFound:
            return .skippedNotFound
        case .failure(let error):
            return .failure(error)
        case .success(let response):
            let validated = await MainActor.run {
                (
                    range: HistoricalSearchService.historyDayRange(from: response),
                    fallbackNextUpdateAt: Self.fallbackNextUpdateAt(from: now)
                )
            }
            guard let range = validated.range else {
                return .skippedInvalidPeriod
            }
            return .ready(SudmonitorHistoryFetchedDat(
                periodStartDay: range.start,
                periodEndDay: range.end,
                nextUpdateAt: response.nextUpdateAt ?? validated.fallbackNextUpdateAt,
                rawDatBytes: response.bytes
            ))
        }
    }

    /// 取得段階の結果を damId ごとに1件へ上書き保存します。
    ///
    /// 保存は damId で fetch → delete → insert + `context.save()` の all-or-nothing で行います。
    /// メインキューに紐づく `ModelContext` を扱うため MainActor 上でのみ呼び出します。
    /// - Parameters:
    ///   - preparation: 取得段階の結果。
    ///   - damId: 対象ダムの観測所ID。
    ///   - context: SwiftData のモデルコンテキスト。
    ///   - now: 保存日時。
    /// - Returns: 取得・保存結果。
    internal func store(
        _ preparation: SudmonitorHistoryFetchPreparation,
        damId: String,
        context: ModelContext,
        now: Date
    ) -> SudmonitorHistoryFetchOutcome {
        switch preparation {
        case .gateDisabled:
            return .gateDisabled
        case .skippedNotFound:
            return .skippedNotFound
        case .skippedInvalidPeriod:
            return .skippedInvalidPeriod
        case .failure(let error):
            return .failure(error)
        case .ready(let fetched):
            do {
                let existing = try context.fetch(FetchDescriptor<SudmonitorHistoryRecord>())
                existing.filter { $0.damId == damId }.forEach { context.delete($0) }
                context.insert(SudmonitorHistoryRecord(
                    damId: damId,
                    periodStartDay: fetched.periodStartDay,
                    periodEndDay: fetched.periodEndDay,
                    fetchedAt: now,
                    nextUpdateAt: fetched.nextUpdateAt,
                    rawDatBytes: fetched.rawDatBytes
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

    /// 保存済みデータの状態から日次過去データの自動取得が必要かどうかを判定します。
    ///
    /// 保存済みレコードの最終観測行が JST 当日 00:00(前日 `24:00`)へ正規化でき、かつ
    /// 貯水率が有効な場合のみ取得不要(`false`)を返します。行未保存・最終行が当日 00:00 でない・
    /// 貯水率欠測(性状欄異常を含む)・パース不能の場合は取得が必要(`true`)です。
    /// - Parameters:
    ///   - damId: 対象ダムの観測所ID。
    ///   - context: SwiftData のモデルコンテキスト。
    ///   - now: 基準日時。
    /// - Returns: 取得が必要な場合は `true`。
    internal func shouldAutoFetch(damId: String, context: ModelContext, now: Date) -> Bool {
        guard let saved = record(damId: damId, context: context) else { return true }
        guard let rows = try? MlitDamParser().parseHistoricalDat(
            saved.rawDatBytes,
            damConfigId: damId,
            startDate: "",
            endDate: ""
        ).1,
            let last = rows.last,
            let millis = TimeFormatters.millisIfValid(fromDamTime: last.time) else {
            return true
        }
        let lastDate = Date(timeIntervalSince1970: millis / 1000)
        let calendar = Calendar.jst
        guard calendar.isDate(lastDate, inSameDayAs: now),
              calendar.component(.hour, from: lastDate) == 0,
              calendar.component(.minute, from: lastDate) == 0 else {
            return true
        }
        return last.storagePercentage == nil
    }

    /// 手動更新のクールダウン終了時刻(最終成功取得時刻 + 1時間)を取得します。
    /// - Parameters:
    ///   - damId: 対象ダムの観測所ID。
    ///   - context: SwiftData のモデルコンテキスト。
    /// - Returns: クールダウン終了時刻。レコード未保存の場合は nil(= いつでも更新可能)。
    internal func manualRefreshAvailableAt(damId: String, context: ModelContext) -> Date? {
        record(damId: damId, context: context)?.fetchedAt.addingTimeInterval(3600)
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
    internal nonisolated static func isGateEnabled(historicalDataSource: RealtimeDataSource) -> Bool {
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
