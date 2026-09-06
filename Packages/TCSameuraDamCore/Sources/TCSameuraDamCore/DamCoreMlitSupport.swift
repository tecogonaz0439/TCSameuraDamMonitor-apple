// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// 国土交通省 (MLIT) の URL ポリシーに関連するエラーを定義する列挙型。
public enum DamCoreMlitURLPolicyError: Error, Equatable, Sendable {
    /// 無効な国土交通省 (MLIT) の URL。
    case invalidMLITURL
    /// レスポンスのバイトサイズが制限を超えた。
    case responseTooLarge
    /// 予期しない HTTP ステータスコード。
    case badHTTPStatus(Int)
}

/// 国土交通省 (MLIT) との通信処理で発生するネットワークエラーを定義する列挙型。
public enum DamCoreMlitNetworkError: Error, Equatable, Sendable {
    /// 無効な国土交通省 (MLIT) の URL。
    case invalidMLITURL
    /// レスポンスのバイトサイズが制限を超えた。
    case responseTooLarge
    /// 予期しない HTTP ステータスコード。
    case badHTTPStatus(Int)
    /// その他の転送エラー（通信の切断など）。
    case transport
}

/// データ取得先ごとの URL およびコンテンツ制限ポリシーを保持する構造体。
///
/// 許可ホスト・ベース URL・User-Agent をパラメータ化し、国土交通省 (MLIT) 直接取得と
/// sudmonitor 中継取得で共通の検証パイプラインを使い回します。
public struct DamCoreURLPolicy: Sendable {
    /// アクセスが許可されるホスト名。
    public let allowedHost: String
    /// ベースとなる URL。
    public let baseURL: URL
    /// リクエスト送信時に使用する User-Agent ヘッダー値。
    public let userAgent: String
    /// 許容する最大レスポンスサイズ（バイト数）。
    public let maxResponseBytes: Int
    /// ネットワークリクエストのタイムアウト時間（秒）。
    public let requestTimeout: TimeInterval
    /// 許可する URL パスの先頭文字列。nil の場合はパス制限を行いません。
    public let allowedPathPrefix: String?

    /// ポリシーを初期化します。
    /// - Parameters:
    ///   - allowedHost: 許可するホスト名。
    ///   - baseURL: ベース URL。
    ///   - userAgent: User-Agent ヘッダー値。
    ///   - maxResponseBytes: 許容する最大レスポンスサイズ（既定は 5MiB）。
    ///   - requestTimeout: タイムアウト時間（既定は 30 秒）。
    ///   - allowedPathPrefix: 許可する URL パスの先頭文字列（既定は nil）。
    public init(
        allowedHost: String,
        baseURL: URL,
        userAgent: String,
        maxResponseBytes: Int = 5 * 1024 * 1024,
        requestTimeout: TimeInterval = 30,
        allowedPathPrefix: String? = nil
    ) {
        self.allowedHost = allowedHost
        self.baseURL = baseURL
        self.userAgent = userAgent
        self.maxResponseBytes = maxResponseBytes
        self.requestTimeout = requestTimeout
        self.allowedPathPrefix = allowedPathPrefix
    }

    /// 国土交通省 (MLIT) 直接取得用の既定ポリシー。
    public static let mlit = DamCoreURLPolicy(
        allowedHost: "www1.river.go.jp",
        baseURL: URL(string: "https://www1.river.go.jp")!,
        userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.5 Safari/605.1.15"
    )

    /// sudmonitor 中継取得用のポリシーを生成します。
    /// - Parameter userAgent: アプリ識別の User-Agent ヘッダー値。
    /// - Returns: sudmonitor ホストを許可するポリシー。
    public static func sudmonitor(userAgent: String) -> DamCoreURLPolicy {
        DamCoreURLPolicy(
            allowedHost: "sudmonitor.kusugami-lab.net",
            baseURL: URL(string: "https://sudmonitor.kusugami-lab.net")!,
            userAgent: userAgent
        )
    }

    /// sudmonitor 履歴ファイル(月次 / latest.dat)取得用のポリシー。`/v1/history/` パスのみ許可する。
    public static func sudmonitorHistory(userAgent: String) -> DamCoreURLPolicy {
        DamCoreURLPolicy(
            allowedHost: "sudmonitor.kusugami-lab.net",
            baseURL: URL(string: "https://sudmonitor.kusugami-lab.net")!,
            userAgent: userAgent,
            allowedPathPrefix: "/v1/history/"
        )
    }

    /// 指定された文字列から、ポリシーに適合する URL オブジェクトを構築・検証します。
    ///
    /// - Parameter urlString: URL を表す文字列。
    /// - Throws: URL が無効、または許可されていないホストやスキームである場合に `DamCoreMlitURLPolicyError.invalidMLITURL` をスローします。
    /// - Returns: 検証済みの URL オブジェクト。
    public func validatedURL(from urlString: String) throws(DamCoreMlitURLPolicyError) -> URL {
        guard let url = URL(string: urlString), isAllowedURL(url) else {
            throw DamCoreMlitURLPolicyError.invalidMLITURL
        }
        return url
    }

    /// 指定されたリンク先（href）を、ポリシーに適合する dat ファイルの絶対 URL に解決します。
    ///
    /// - Parameter href: 解決対象の相対パスまたは絶対 URL 文字列。
    /// - Returns: 解決され、かつ許可されたホストの dat ファイルを指す絶対 URL。無効な場合は nil を返します。
    public func resolvedDatURL(from href: String) -> URL? {
        let candidate: URL?
        if href.hasPrefix("http://") || href.hasPrefix("https://") {
            candidate = URL(string: href.replacingOccurrences(of: "http://", with: "https://"))
        } else {
            candidate = URL(string: href, relativeTo: baseURL)?.absoluteURL
        }
        guard let candidate, isAllowedDatURL(candidate) else { return nil }
        return candidate
    }

    /// 指定された URL が、許可されたホストおよび安全なスキームに合致するか判定します。
    ///
    /// `allowedPathPrefix` が設定されている場合は、URL パスがその先頭文字列で始まることも必須となります。
    ///
    /// - Parameter url: 判定対象の URL。
    /// - Returns: 許可された URL であれば true、それ以外は false。
    public func isAllowedURL(_ url: URL) -> Bool {
        url.scheme == "https"
            && url.host?.caseInsensitiveCompare(allowedHost) == .orderedSame
            && (allowedPathPrefix == nil || url.path.hasPrefix(allowedPathPrefix!))
            && url.user == nil
            && url.password == nil
            && url.fragment == nil
            && (url.port == nil || url.port == 443)
    }

    /// 指定された URL が、許可された dat ファイルを指す URL かどうか判定します。
    ///
    /// - Parameter url: 判定対象の URL。
    /// - Returns: 許可された dat ファイルの URL であれば true、それ以外は false。
    public func isAllowedDatURL(_ url: URL) -> Bool {
        isAllowedURL(url) && url.path.lowercased().hasSuffix(".dat")
    }

    /// 指定された URL に対する HTTP リクエストオブジェクトを作成します。
    ///
    /// タイムアウト設定および User-Agent ヘッダーを設定します。
    ///
    /// - Parameter url: 対象の URL。
    /// - Returns: 設定済みの URLRequest オブジェクト。
    public func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: requestTimeout)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    /// 取得したデータおよび HTTP レスポンスヘッダーがポリシー（サイズ、ステータスコード、ドメイン等）に適合しているか検証します。
    ///
    /// - Parameters:
    ///   - data: 受信したバイナリデータ。
    ///   - response: 受信したネットワークレスポンス情報。
    ///   - requireDatURL: URL が dat ファイルでなければならないかどうか。
    /// - Throws: ポリシーに違反している場合に `DamCoreMlitURLPolicyError` の各エラーをスローします。
    public func validate(data: Data, response: URLResponse, requireDatURL: Bool = false) throws(DamCoreMlitURLPolicyError) {
        if response.expectedContentLength > Int64(maxResponseBytes) {
            throw DamCoreMlitURLPolicyError.responseTooLarge
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw DamCoreMlitURLPolicyError.badHTTPStatus(http.statusCode)
        }
        guard let finalURL = response.url, requireDatURL ? isAllowedDatURL(finalURL) : isAllowedURL(finalURL) else {
            throw DamCoreMlitURLPolicyError.invalidMLITURL
        }
        if data.count > maxResponseBytes {
            throw DamCoreMlitURLPolicyError.responseTooLarge
        }
    }
}

/// 国土交通省 (MLIT) のデータ取得時における URL およびコンテンツ制限ポリシーを管理する列挙型。
///
/// 既存の静的 API を維持するため、`DamCoreURLPolicy.mlit` プリセットへ委譲します。
public enum DamCoreMlitURLPolicy {
    /// アクセスが許可されるホスト名。
    public nonisolated static let allowedHost = DamCoreURLPolicy.mlit.allowedHost
    /// 許容する最大レスポンスサイズ（5MB）。
    public nonisolated static let maxResponseBytes = DamCoreURLPolicy.mlit.maxResponseBytes
    /// ネットワークリクエストのタイムアウト時間（秒）。
    public nonisolated static let requestTimeout = DamCoreURLPolicy.mlit.requestTimeout
    /// リクエスト送信時に使用する User-Agent ヘッダー値。
    public nonisolated static let userAgent = DamCoreURLPolicy.mlit.userAgent

    /// 指定された文字列から、ポリシーに適合する国土交通省 (MLIT) の URL オブジェクトを構築・検証します。
    ///
    /// - Parameter urlString: URL を表す文字列。
    /// - Throws: URL が無効、または許可されていないホストやスキームである場合に `DamCoreMlitURLPolicyError.invalidMLITURL` をスローします。
    /// - Returns: 検証済みの URL オブジェクト。
    public nonisolated static func validatedMLITURL(from urlString: String) throws(DamCoreMlitURLPolicyError) -> URL {
        try DamCoreURLPolicy.mlit.validatedURL(from: urlString)
    }

    /// 指定されたリンク先（href）を、ポリシーに適合する dat ファイルの絶対 URL に解決します。
    ///
    /// - Parameter href: 解決対象の相対パスまたは絶対 URL 文字列。
    /// - Returns: 解決され、かつ許可されたホストの dat ファイルを指す絶対 URL。無効な場合は nil を返します。
    public nonisolated static func resolvedDatURL(from href: String) -> URL? {
        DamCoreURLPolicy.mlit.resolvedDatURL(from: href)
    }

    /// 指定された URL が、国土交通省 (MLIT) の許可されたホストおよび安全なスキームに合致するか判定します。
    ///
    /// - Parameter url: 判定対象 of URL。
    /// - Returns: 許可された URL であれば true、それ以外は false。
    public nonisolated static func isAllowedMLITURL(_ url: URL) -> Bool {
        DamCoreURLPolicy.mlit.isAllowedURL(url)
    }

    /// 指定された URL が、許可された国土交通省 (MLIT) の dat ファイルを指す URL かどうか判定します。
    ///
    /// - Parameter url: 判定対象の URL。
    /// - Returns: 許可された dat ファイルの URL であれば true、それ以外は false。
    public nonisolated static func isAllowedDatURL(_ url: URL) -> Bool {
        DamCoreURLPolicy.mlit.isAllowedDatURL(url)
    }

    /// 指定された URL に対する HTTP リクエストオブジェクトを作成します。
    ///
    /// タイムアウト設定および User-Agent ヘッダーを設定します。
    ///
    /// - Parameter url: 対象の URL。
    /// - Returns: 設定済みの URLRequest オブジェクト。
    public nonisolated static func makeRequest(url: URL) -> URLRequest {
        DamCoreURLPolicy.mlit.makeRequest(url: url)
    }

    /// 取得したデータおよび HTTP レスポンスヘッダーがポリシー（サイズ、ステータスコード、ドメイン等）に適合しているか検証します。
    ///
    /// - Parameters:
    ///   - data: 受信したバイナリデータ。
    ///   - response: 受信したネットワークレスポンス情報。
    ///   - requireDatURL: URL が dat ファイルでなければならないかどうか。
    /// - Throws: ポリシーに違反している場合に `DamCoreMlitURLPolicyError` の各エラーをスローします。
    public nonisolated static func validate(data: Data, response: URLResponse, requireDatURL: Bool = false) throws(DamCoreMlitURLPolicyError) {
        try DamCoreURLPolicy.mlit.validate(data: data, response: response, requireDatURL: requireDatURL)
    }
}

/// HTTP レスポンスヘッダーの参照を補助するユーティリティ。
public enum DamCoreHTTPHeaders {
    /// 大文字小文字を区別せずにヘッダーフィールド値を取得します。
    /// - Parameters:
    ///   - headers: ヘッダー辞書。
    ///   - name: 取得対象のフィールド名。
    /// - Returns: 該当するフィールド値。存在しない場合は nil。
    public nonisolated static func value(_ headers: [String: String], forField name: String) -> String? {
        headers.first(where: { $0.key.caseInsensitiveCompare(name) == .orderedSame })?.value
    }
}

/// HTTP リダイレクトを強制的に拒否するための URLSession タスクデリゲートクラス。
public final class DamCoreRedirectRejectingDelegate: NSObject, @unchecked Sendable, URLSessionTaskDelegate {
    /// リダイレクト要求が発生した際に呼び出され、リダイレクトを拒否（completionHandler に nil を渡す）します。
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

/// 国土交通省 (MLIT) のサーバーからデータを取得するためのネットワーククライアントユーティリティ。
public enum DamCoreMlitNetwork {
    /// 指定された URL 文字列からバイナリデータを非同期にダウンロードし、検証を行います。
    ///
    /// リダイレクトは拒否され、レスポンスサイズ制限が適用されます。国土交通省 (MLIT) 直接取得用の
    /// 既定ポリシーを使用します。
    ///
    /// - Parameter urlString: ダウンロード対象の URL 文字列。
    /// - Throws: ネットワーク通信エラーやポリシー検証エラー。
    /// - Returns: ダウンロードされたデータ。
    public nonisolated static func fetchBytes(_ urlString: String) async throws -> Data {
        try await fetch(urlString, policy: .mlit).data
    }

    /// 指定されたポリシーを用いて URL 文字列からバイナリデータとレスポンスヘッダーを非同期にダウンロードし、検証を行います。
    ///
    /// リダイレクトは拒否され、レスポンスサイズ制限が適用されます。
    ///
    /// - Parameters:
    ///   - urlString: ダウンロード対象の URL 文字列。
    ///   - policy: 適用する URL / コンテンツポリシー。
    /// - Throws: ネットワーク通信エラーやポリシー検証エラー。
    /// - Returns: ダウンロードされたデータと、HTTP レスポンスヘッダーの辞書。
    public nonisolated static func fetch(_ urlString: String, policy: DamCoreURLPolicy) async throws -> (data: Data, headers: [String: String]) {
        let url = try policy.validatedURL(from: urlString)
        let request = policy.makeRequest(url: url)
        let redirectDelegate = DamCoreRedirectRejectingDelegate()
        let (bytes, response) = try await URLSession.shared.bytes(for: request, delegate: redirectDelegate)
        if response.expectedContentLength > Int64(policy.maxResponseBytes) {
            throw DamCoreMlitURLPolicyError.responseTooLarge
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw DamCoreMlitURLPolicyError.badHTTPStatus(http.statusCode)
        }
        guard let finalURL = response.url,
              policy.isAllowedURL(finalURL),
              !policy.isAllowedDatURL(url) || policy.isAllowedDatURL(finalURL) else {
            throw DamCoreMlitURLPolicyError.invalidMLITURL
        }
        let data = try await collect(bytes: bytes, maxBytes: policy.maxResponseBytes)
        try policy.validate(data: data, response: response, requireDatURL: policy.isAllowedDatURL(url))
        return (data, normalizedHeaders(from: response))
    }

    /// URL レスポンスから HTTP ヘッダー辞書を正規化して抽出します。
    /// - Parameter response: 受信したネットワークレスポンス情報。
    /// - Returns: 文字列キー・文字列値に正規化されたヘッダー辞書。HTTP 応答でない場合は空辞書。
    nonisolated private static func normalizedHeaders(from response: URLResponse) -> [String: String] {
        guard let http = response as? HTTPURLResponse else { return [:] }
        var result: [String: String] = [:]
        for (key, value) in http.allHeaderFields {
            guard let keyString = key as? String else { continue }
            result[keyString] = (value as? String) ?? String(describing: value)
        }
        return result
    }

    /// 取得ストリームから指定された最大バイト数を超えないようにバイナリデータを収集します。
    ///
    /// - Parameters:
    ///   - bytes: 非同期非構造化バイトストリーム。
    ///   - maxBytes: 許容する最大バイトサイズ。
    /// - Throws: 最大サイズを超過した場合に `DamCoreMlitURLPolicyError.responseTooLarge` をスローします。
    /// - Returns: 収集されたデータ。
    public nonisolated static func collect<S: AsyncSequence>(bytes: S, maxBytes: Int = DamCoreMlitURLPolicy.maxResponseBytes) async throws -> Data where S.Element == UInt8 {
        var data = Data()
        data.reserveCapacity(min(maxBytes, 64 * 1024))
        for try await byte in bytes {
            data.append(byte)
            if data.count > maxBytes {
                throw DamCoreMlitURLPolicyError.responseTooLarge
            }
        }
        return data
    }
}

/// 国土交通省 (MLIT) のデータで使用される日時の解釈・変換を担うユーティリティ。
public enum DamCoreDamTime {
    /// 解析で使用する日本標準時（JST）のカレンダー。
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }()

    /// 解析およびフォーマットで使用する日付フォーマッタ。
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        formatter.isLenient = false
        return formatter
    }()

    /// 日時文字列を正規化された形式（"yyyy/MM/dd HH:mm"）に変換します。
    ///
    /// - Parameter text: 元の日時文字列。
    /// - Returns: 正規化された日時文字列。解析できない場合は nil を返します。
    public nonisolated static func normalizedString(_ text: String) -> String? {
        guard let date = date(from: text) else { return nil }
        return formatter.string(from: date)
    }

    /// 国土交通省 (MLIT) 特有の形式（例: 時刻に "24:00" を許容する表現）を含む日時文字列を Date に解析します。
    ///
    /// "24:00" の場合は翌日の "00:00" として解釈されます。
    ///
    /// - Parameter text: 解析対象の日時文字列。
    /// - Returns: 解析された Date オブジェクト。解析できない場合は nil を返します。
    public nonisolated static func date(from text: String) -> Date? {
        let parts = text.split(separator: " ", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let day = parts[0].split(separator: "/", omittingEmptySubsequences: false).compactMap { Int($0) }
        let time = parts[1].split(separator: ":", omittingEmptySubsequences: false).compactMap { Int($0) }
        guard day.count == 3, time.count == 2 else { return nil }
        guard (0...59).contains(time[1]) else { return nil }

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = TimeZone(identifier: "Asia/Tokyo")
        components.year = day[0]
        components.month = day[1]
        components.day = day[2]

        if time[0] == 24 {
            guard time[1] == 0 else { return nil }
            components.hour = 0
            components.minute = 0
            guard let base = calendar.date(from: components) else { return nil }
            return calendar.date(byAdding: .day, value: 1, to: base)
        }

        guard (0...23).contains(time[0]) else { return nil }
        components.hour = time[0]
        components.minute = time[1]
        return calendar.date(from: components)
    }

    /// 日時文字列を 1970年からのミリ秒数に変換します。
    ///
    /// - Parameter text: 解析対象の日時文字列。
    /// - Returns: エポックからのミリ秒数。解析できない場合は nil を返します。
    public nonisolated static func millis(from text: String) -> Double? {
        date(from: text).map { $0.timeIntervalSince1970 * 1000 }
    }

    /// 日付文字列と時間文字列から、1時間単位のキー（"yyyy/MM/dd HH"）を作成します。
    ///
    /// - Parameters:
    ///   - date: 日付文字列。
    ///   - time: 時刻文字列。
    /// - Returns: 1時間単位のキー文字列。無効な場合は nil を返します。
    public nonisolated static func hourKey(date: String, time: String) -> String? {
        guard let normalized = normalizedString("\(date) \(time)") else { return nil }
        let parts = normalized.split(separator: " ")
        guard parts.count == 2, let hour = parts[1].split(separator: ":").first else { return nil }
        return "\(parts[0]) \(hour)"
    }
}

/// 国土交通省 (MLIT) から取得した生データ（.datファイル）をブリッジするための構造体。
public struct DamCoreRawDatBridge: Codable, Sendable {
    /// 現在のブリッジデータのスキーマバージョン。
    public static let currentVersion = 1

    /// バージョン番号。
    public let version: Int
    /// 観測所のID。
    public let stationId: String
    /// データ取得元の URL。
    public let dataUrl: String
    /// 取得完了日時。
    public let fetchedAt: Date
    /// 次回更新予定時刻（`X-TCS-Next-Update-At` ヘッダー由来、存在しない場合は nil）。
    public let nextUpdateAt: Date?
    /// ダウンロードされた生データ（バイナリ）。
    public let rawBytes: Data
    /// 元の dat ファイル名（省略可能）。
    public let rawDatFileName: String?

    /// イニシャライザ。
    ///
    /// - Parameters:
    ///   - version: スキーマバージョン（デフォルトは `currentVersion`）。
    ///   - stationId: 観測所のID。
    ///   - dataUrl: データソース URL。
    ///   - fetchedAt: 取得日時。
    ///   - nextUpdateAt: 次回更新予定時刻。
    ///   - rawBytes: 生データ。
    ///   - rawDatFileName: 生データファイル名。
    public init(version: Int = Self.currentVersion, stationId: String, dataUrl: String, fetchedAt: Date, nextUpdateAt: Date? = nil, rawBytes: Data, rawDatFileName: String? = nil) {
        self.version = version
        self.stationId = stationId
        self.dataUrl = dataUrl
        self.fetchedAt = fetchedAt
        self.nextUpdateAt = nextUpdateAt
        self.rawBytes = rawBytes
        self.rawDatFileName = rawDatFileName
    }
}

public struct DamCoreDailyHistoryBridge: Codable, Sendable {
    public static let currentVersion = 1

    public let version: Int
    public let stationId: String
    public let dataUrl: String
    public let fetchedAt: Date
    public let nextUpdateAt: Date
    public let since: String?
    public let until: String?
    public let rawBytes: Data
    public let rawDatFileName: String?

    public init(version: Int = Self.currentVersion, stationId: String, dataUrl: String, fetchedAt: Date, nextUpdateAt: Date, since: String?, until: String?, rawBytes: Data, rawDatFileName: String? = nil) {
        self.version = version
        self.stationId = stationId
        self.dataUrl = dataUrl
        self.fetchedAt = fetchedAt
        self.nextUpdateAt = nextUpdateAt
        self.since = since
        self.until = until
        self.rawBytes = rawBytes
        self.rawDatFileName = rawDatFileName
    }
}
