// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation
import TCSameuraDamCore

/// 国土交通省（MLIT）のサーバーからデータを取得するためのネットワークデータソース構造体。
internal struct MlitNetworkDataSource: Sendable {
    /// ネットワークからデータをフェッチするクロージャの型定義。
    internal typealias Fetcher = @Sendable (String) async throws -> Data
    /// ネットワークからデータとレスポンスヘッダーをフェッチするクロージャの型定義。
    internal typealias HeaderFetcher = @Sendable (String) async throws -> (Data, [String: String])

    /// データを取得するフェッチャ。
    private let fetcher: Fetcher
    /// データとレスポンスヘッダーを取得するフェッチャ。
    private let headerFetcher: HeaderFetcher

    /// 新しいネットワークデータソースを初期化します。
    /// - Parameters:
    ///   - fetcher: 使用するデータフェッチャ。デフォルトは `urlSessionFetcher` です。
    ///   - headerFetcher: 使用するヘッダー付きデータフェッチャ。デフォルトは `urlSessionHeaderFetcher` です。
    internal nonisolated init(
        fetcher: @escaping Fetcher = MlitNetworkDataSource.urlSessionFetcher,
        headerFetcher: @escaping HeaderFetcher = MlitNetworkDataSource.urlSessionHeaderFetcher
    ) {
        self.fetcher = fetcher
        self.headerFetcher = headerFetcher
    }

    /// 指定されたURL文字列からデータを取得します。
    /// - Parameter urlString: 取得対象のURL文字列。
    /// - Returns: 取得したバイナリデータ。
    /// - Throws: 通信エラー、URL無効エラー、または応答超過エラー。
    internal nonisolated func fetchBytes(_ urlString: String) async throws -> Data {
        let url = try MlitURLPolicy.validatedMLITURL(from: urlString)
        do {
            return try await fetcher(url.absoluteString)
        } catch DamCoreMlitURLPolicyError.responseTooLarge {
            throw MlitNetworkError.responseTooLarge
        } catch DamCoreMlitURLPolicyError.badHTTPStatus(_) {
            throw MlitNetworkError.transport
        } catch DamCoreMlitURLPolicyError.invalidMLITURL {
            throw MlitNetworkError.invalidURL
        } catch {
            throw MlitNetworkError(error)
        }
    }

    /// 指定されたURL文字列からデータとレスポンスヘッダーを取得します（sudmonitor 中継取得用）。
    /// - Parameter urlString: 取得対象のURL文字列。
    /// - Returns: 取得したバイナリデータとレスポンスヘッダーの辞書。
    /// - Throws: 通信エラー、URL無効エラー、または応答超過エラー。
    internal nonisolated func fetchBytesWithHeaders(_ urlString: String) async throws -> (Data, [String: String]) {
        let url = try MlitURLPolicy.validatedSudmonitorURL(from: urlString)
        do {
            return try await headerFetcher(url.absoluteString)
        } catch DamCoreMlitURLPolicyError.responseTooLarge {
            throw MlitNetworkError.responseTooLarge
        } catch DamCoreMlitURLPolicyError.badHTTPStatus(_) {
            throw MlitNetworkError.transport
        } catch DamCoreMlitURLPolicyError.invalidMLITURL {
            throw MlitNetworkError.invalidURL
        } catch {
            throw MlitNetworkError(error)
        }
    }

    /// sudmonitor 履歴ファイル(月次 / latest.dat)を取得します。404 のみ `MlitNetworkError.notFound` として区別します。
    /// - Throws: 通信エラー、URL無効エラー、応答超過エラー、`MlitNetworkError.notFound`。
    internal nonisolated func fetchHistoryBytes(_ urlString: String) async throws -> (Data, [String: String]) {
        let url = try MlitURLPolicy.validatedSudmonitorHistoryURL(from: urlString)
        do {
            return try await headerFetcher(url.absoluteString)
        } catch DamCoreMlitURLPolicyError.badHTTPStatus(404) {
            throw MlitNetworkError.notFound
        } catch DamCoreMlitURLPolicyError.responseTooLarge {
            throw MlitNetworkError.responseTooLarge
        } catch DamCoreMlitURLPolicyError.badHTTPStatus(_) {
            throw MlitNetworkError.transport
        } catch DamCoreMlitURLPolicyError.invalidMLITURL {
            throw MlitNetworkError.invalidURL
        } catch {
            throw MlitNetworkError(error)
        }
    }

    /// 取得したデータとHTTPレスポンスの正当性を検証します。
    /// - Parameters:
    ///   - data: 検証対象のデータ。
    ///   - response: HTTPレスポンス情報。
    ///   - maxBytes: 許容する最大バイト数。
    ///   - requireDatURL: DATファイルのURLを必須とするかどうかのフラグ。
    /// - Throws: バリデーションエラー。
    internal nonisolated static func validate(data: Data, response: URLResponse, maxBytes: Int, requireDatURL: Bool = false) throws {
        do {
            try DamCoreMlitURLPolicy.validate(data: data, response: response, requireDatURL: requireDatURL)
        } catch DamCoreMlitURLPolicyError.responseTooLarge {
            throw AppError.responseTooLarge
        } catch DamCoreMlitURLPolicyError.badHTTPStatus(_) {
            throw URLError(.badServerResponse)
        } catch DamCoreMlitURLPolicyError.invalidMLITURL {
            throw AppError.invalidMLITURL
        } catch {
            throw error
        }
    }

    /// デフォルトのURLSessionを用いたフェッチ実装。
    private nonisolated static func urlSessionFetcher(_ urlString: String) async throws -> Data {
        try await DamCoreMlitNetwork.fetchBytes(urlString)
    }

    /// デフォルトのURLSessionを用いたヘッダー付きフェッチ実装（sudmonitor ポリシー）。
    private nonisolated static func urlSessionHeaderFetcher(_ urlString: String) async throws -> (Data, [String: String]) {
        try await DamCoreMlitNetwork.fetch(urlString, policy: MlitURLPolicy.sudmonitorPolicy)
    }
}

