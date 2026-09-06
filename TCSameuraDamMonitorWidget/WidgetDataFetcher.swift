// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation
import TCSameuraDamCore

/// 早明浦ダムウィジェット用のリアルタイム観測データの取得および解析時に発生し得るエラー。
enum WidgetFetchError: Error, Equatable, Sendable {
    /// URLが無効です。
    case invalidURL
    /// ネットワークのレスポンスが許容サイズを超えています。
    case responseTooLarge
    /// サーバが予期しないHTTPステータスコードを返しました。
    case badHTTPStatus(Int)
    /// リアルタイム観測データの解析に失敗しました。
    case parseFailed
    /// 一般的なネットワークエラーが発生しました。
    case network
}

/// 早明浦ダムウィジェット用のリアルタイム観測データの取得および解析を調整するフェッチャー。
struct WidgetDataFetcher: Sendable {
    /// 早明浦ダムの観測所 ID。
    nonisolated static let sameuraStationId = "1368080700010"

    nonisolated static let sudmonitorBaseURL = "https://sudmonitor.kusugami-lab.net"

    /// リアルタイム観測データを取得・解析して、ウィジェットのスナップショットを取得します。
    /// - Returns: スナップショット（`DamWidgetSnapshot`）と生データブリッジ（`DamCoreRawDatBridge`）を含むタプル。
    /// - Throws: 取得または解析に失敗した場合のエラー。
    nonisolated static func fetchSnapshot() async throws -> (DamWidgetSnapshot, DamCoreRawDatBridge) {
        let source = storedString(forKey: WidgetDefaultsKey.realtimeSource)
        if source == WidgetDefaultsKey.realtimeSourceSudmonitor {
            return try await fetchSudmonitorSnapshot()
        }
        return try await fetchMlitSnapshot()
    }

    /// sudmonitor 中継サーバーから単一GETでリアルタイム観測データを取得・解析します。
    /// - Returns: スナップショットと生データブリッジを含むタプル。
    /// - Throws: 取得または解析に失敗した場合のエラー。
    nonisolated private static func fetchSudmonitorSnapshot() async throws -> (DamWidgetSnapshot, DamCoreRawDatBridge) {
        let stationId = storedString(forKey: WidgetDefaultsKey.stationId) ?? "1368080700010"
        let stationName = storedString(forKey: WidgetDefaultsKey.stationName) ?? "早明浦ダム"
        let datUrl = storedString(forKey: WidgetDefaultsKey.realtimeDatUrl)
            ?? "\(Self.sudmonitorBaseURL)/v1/realtime/1368080700010/latest.dat"

        let (datBytes, headers) = try await fetchSudmonitorBytes(datUrl)
        if let headerDamId = DamCoreHTTPHeaders.value(headers, forField: "X-TCS-Dam-Id"), headerDamId != stationId {
            throw WidgetFetchError.network
        }
        let snapshot = try parseRealtimeDat(datBytes, stationId: stationId, stationName: stationName)
        let bridge = DamCoreRawDatBridge(stationId: stationId, dataUrl: datUrl, fetchedAt: Date(), rawBytes: datBytes, rawDatFileName: "latest.dat")
        return (snapshot, bridge)
    }

    /// 国土交通省 (MLIT) から2段階取得でリアルタイム観測データを取得・解析します。
    /// - Returns: スナップショットと生データブリッジを含むタプル。
    /// - Throws: 取得または解析に失敗した場合のエラー。
    nonisolated private static func fetchMlitSnapshot() async throws -> (DamWidgetSnapshot, DamCoreRawDatBridge) {
        let dataUrl = storedString(forKey: WidgetDefaultsKey.dataUrl) ?? "https://www1.river.go.jp/cgi-bin/DspDamData.exe?ID=1368080700010&KIND=3&PAGE=0"
        let stationId = storedString(forKey: WidgetDefaultsKey.stationId) ?? "1368080700010"
        let stationName = storedString(forKey: WidgetDefaultsKey.stationName) ?? "早明浦ダム"

        let html = try await fetchBytes(dataUrl)
        let datURL = try parseHTMLForDatURL(html)
        let datBytes = try await fetchBytes(datURL)
        let snapshot = try parseRealtimeDat(datBytes, stationId: stationId, stationName: stationName)
        let bridge = DamCoreRawDatBridge(stationId: stationId, dataUrl: dataUrl, fetchedAt: Date(), rawBytes: datBytes, rawDatFileName: URL(string: datURL)?.lastPathComponent)
        return (snapshot, bridge)
    }

    /// sudmonitor 中継サーバーから生のバイトデータとレスポンスヘッダーを取得します。
    /// - Parameter urlString: 取得対象のURL文字列。
    /// - Returns: 取得された生データとレスポンスヘッダーの辞書。
    /// - Throws: ネットワークリクエストが失敗した場合は `WidgetFetchError`。
    nonisolated private static func fetchSudmonitorBytes(_ urlString: String) async throws -> (Data, [String: String]) {
        do {
            return try await DamCoreMlitNetwork.fetch(urlString, policy: sudmonitorPolicy)
        } catch DamCoreMlitURLPolicyError.invalidMLITURL {
            throw WidgetFetchError.invalidURL
        } catch DamCoreMlitURLPolicyError.responseTooLarge {
            throw WidgetFetchError.responseTooLarge
        } catch DamCoreMlitURLPolicyError.badHTTPStatus(let status) {
            throw WidgetFetchError.badHTTPStatus(status)
        } catch {
            throw WidgetFetchError.network
        }
    }

    nonisolated static func fetchDailyHistory(damId: String) async throws -> DamCoreDailyHistoryBridge {
        let urlString = "\(Self.sudmonitorBaseURL)/v1/history/\(damId)/latest.dat"
        let (datBytes, headers) = try await fetchSudmonitorBytes(urlString)
        if let headerDamId = DamCoreHTTPHeaders.value(headers, forField: "X-TCS-Dam-Id"), headerDamId != damId {
            throw WidgetFetchError.network
        }
        let since = DamCoreHTTPHeaders.value(headers, forField: "X-TCS-History-Since")
        let until = DamCoreHTTPHeaders.value(headers, forField: "X-TCS-History-Until")
        let nextUpdateAt = DamCoreHTTPHeaders.value(headers, forField: "X-TCS-Next-Update-At")
            .flatMap { parseISO8601Date($0) } ?? nextDay0013JST()
        return DamCoreDailyHistoryBridge(
            stationId: damId,
            dataUrl: urlString,
            fetchedAt: Date(),
            nextUpdateAt: nextUpdateAt,
            since: since,
            until: until,
            rawBytes: datBytes,
            rawDatFileName: "latest.dat"
        )
    }

    nonisolated private static func parseISO8601Date(_ value: String) -> Date? {
        if let date = nextUpdateAtFormatter.date(from: value) {
            return date
        }
        return nextUpdateAtFallbackFormatter.date(from: value)
    }

    nonisolated(unsafe) private static let nextUpdateAtFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) private static let nextUpdateAtFallbackFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    nonisolated private static func nextDay0013JST(now: Date = Date()) -> Date {
        let calendar = jstCalendar
        let startOfToday = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
            return now.addingTimeInterval(24 * 60 * 60)
        }
        let components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        return calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: TimeZone(identifier: "Asia/Tokyo"),
            year: components.year,
            month: components.month,
            day: components.day,
            hour: 0,
            minute: 13
        )) ?? tomorrow
    }

    nonisolated private static let jstCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }()

    /// sudmonitor 中継取得で送信するアプリ識別の User-Agent を用いた URL ポリシー。
    ///
    /// バージョンはウィジェット拡張のバンドル版本（アプリと同一の MARKETING_VERSION）を使用します。
    nonisolated private static var sudmonitorPolicy: DamCoreURLPolicy {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        return DamCoreURLPolicy.sudmonitor(userAgent: "TCSameuraDamMonitor-Apple/\(version)")
    }

    /// 指定されたURLから生のバイトデータを取得します。
    /// - Parameter urlString: 取得対象のURL文字列。
    /// - Returns: 取得された生データ。
    /// - Throws: ネットワークリクエストが失敗した場合は `WidgetFetchError`。
    nonisolated private static func fetchBytes(_ urlString: String) async throws -> Data {
        do {
            return try await DamCoreMlitNetwork.fetchBytes(urlString)
        } catch DamCoreMlitURLPolicyError.invalidMLITURL {
            throw WidgetFetchError.invalidURL
        } catch DamCoreMlitURLPolicyError.responseTooLarge {
            throw WidgetFetchError.responseTooLarge
        } catch DamCoreMlitURLPolicyError.badHTTPStatus(let status) {
            throw WidgetFetchError.badHTTPStatus(status)
        } catch {
            throw WidgetFetchError.network
        }
    }

    /// HTMLレスポンスを解析して、生のリアルタイム観測データ（DATファイル）のURLを特定します。
    /// - Parameter data: HTMLデータ。
    /// - Returns: DATファイルの絶対URL文字列。
    /// - Throws: DATファイルへのリンクが見つからない場合は `WidgetFetchError.parseFailed`。
    nonisolated private static func parseHTMLForDatURL(_ data: Data) throws(WidgetFetchError) -> String {
        guard let html = String(data: data, encoding: DamCoreTextDecoder.eucJP) else {
            throw WidgetFetchError.parseFailed
        }
        guard let regex = try? NSRegularExpression(pattern: #"href="([^"]+\.dat)""#) else {
            throw WidgetFetchError.parseFailed
        }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              let hrefRange = Range(match.range(at: 1), in: html) else {
            throw WidgetFetchError.parseFailed
        }
        let href = String(html[hrefRange])
        guard let resolved = DamCoreMlitURLPolicy.resolvedDatURL(from: href) else {
            throw WidgetFetchError.invalidURL
        }
        return resolved.absoluteString
    }

    /// リアルタイム観測データを表す生のDATデータを解析します。
    /// - Parameters:
    ///   - data: 生のDATファイルデータ。
    ///   - stationId: 観測所識別子。
    ///   - stationName: 観測所名。
    /// - Returns: 解析された値（貯水率や貯水量を含む）を表す `DamWidgetSnapshot`。
    nonisolated private static func parseRealtimeDat(_ data: Data, stationId: String, stationName: String) throws(WidgetFetchError) -> DamWidgetSnapshot {
        guard let rows = DamCoreWidgetParser.parseRows(from: data), !rows.isEmpty else {
            return DamWidgetSnapshot(
                damName: damDisplayName(for: stationName),
                updatedAt: "",
                observedAt: "",
                storagePercentage: nil,
                trend: "unknown",
                storageVolume: nil,
                storageVolumeTrend: nil,
                storagePercentageDayChange: nil,
                dayChangeTrend: nil,
                storagePercentageWeekChange: nil,
                weekChangeTrend: nil,
                message: WidgetLocalized.text("widget.noStorageMessage"),
                isNetworkError: true,
                isAllDataInvalid: false,
                isSameura: stationId == Self.sameuraStationId,
                storageVolumeForMessage: nil,
                lastUpdatedAt: Date()
            )
        }

        guard let fields = DamCoreWidgetParser.snapshotFields(from: rows) else {
            throw WidgetFetchError.parseFailed
        }

        return DamCoreWidgetSnapshotFactory.makeSnapshot(
            damName: damDisplayName(for: stationName),
            fields: fields,
            messageLookup: messageLookup(),
            isSameura: stationId == Self.sameuraStationId,
            storageVolumeForMessage: fields.storageVolumeForMessage
        )
    }

    /// 貯水率のしきい値に基づいて、早明浦ダムと早明浦ダム以外のメッセージ検索設定を作成します。
    /// - Returns: `DamCoreWidgetMessageLookup` オブジェクト。
    nonisolated private static func messageLookup() -> DamCoreWidgetMessageLookup {
        DamCoreWidgetMessageLookup(
            messages: loadMessages(),
            storageFallback: { percentage in
                switch percentage {
                case 80...: return WidgetLocalized.text("widget.sameura.80_100.message")
                case 60..<80: return WidgetLocalized.text("widget.sameura.60_80.message")
                case 40..<60: return WidgetLocalized.text("widget.sameura.40_60.message")
                case 20..<40: return WidgetLocalized.text("widget.sameura.20_40.message")
                case 0..<20: return WidgetLocalized.text("widget.sameura.0_20.message")
                default: return WidgetLocalized.text("widget.sameura.0.message")
                }
            },
            specialFallback: { key in
                switch key {
                case .allDataInvalid:
                    return "😴 \(WidgetLocalized.text("widget.allDataInvalidMessage"))"
                case .abnormal:
                    return WidgetLocalized.text("widget.noStorageMessageWithState")
                default:
                    return ""
                }
            },
            sameuraStorageFallback: { key in
                WidgetLocalized.text("widget.sameura.\(key.rawValue).message")
            },
            otherStorageFallback: { key in
                WidgetLocalized.text("widget.other.\(key.rawValue).message")
            }
        )
    }

    /// デフォルトストアからメッセージの辞書を読み込みます。
    /// - Returns: メッセージの辞書。見つからない場合は `nil`。
    nonisolated private static func loadMessages() -> [String: String]? {
        guard let data = WidgetDefaultsStore.shared.data(forKey: WidgetDefaultsKey.messages) else { return nil }
        return try? JSONDecoder().decode([String: String].self, from: data)
    }

    /// デフォルトストアから指定されたキーに関連付けられた文字列を取得します。
    /// - Parameter key: ユーザーデフォルトのキー。
    /// - Returns: キーに関連付けられた文字列。見つからない場合は `nil`。
    nonisolated private static func storedString(forKey key: String) -> String? {
        WidgetDefaultsStore.shared.string(forKey: key)
    }

    /// ダムの表示名を解決します（デフォルトは「早明浦ダム」）。
    /// - Parameter parsedStationName: ソースから解析された観測所名。
    /// - Returns: 表示名。
    nonisolated private static func damDisplayName(for parsedStationName: String) -> String {
        if let name = storedString(forKey: WidgetDefaultsKey.damDisplayName), !name.isEmpty {
            return name
        }
        if let name = storedString(forKey: WidgetDefaultsKey.stationName), !name.isEmpty {
            return name
        }
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.hasPrefix("ja") {
            return parsedStationName
        }
        return "Sameura Dam \(parsedStationName)"
    }
}
