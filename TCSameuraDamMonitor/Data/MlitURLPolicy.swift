// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation
import TCSameuraDamCore

/// 国土交通省（MLIT）関連のURL処理に関するエラーを表す列挙型。
internal enum MlitURLPolicyError: Error, Equatable, Sendable {
    /// 無効な国土交通省（MLIT）のURLである場合のエラー。
    case invalidMLITURL
}

/// 国土交通省（MLIT）のサーバーアクセス用URLポリシーを定義するユーティリティ。
internal enum MlitURLPolicy {
    /// 接続を許可するホスト名。
    internal nonisolated static let allowedHost = DamCoreMlitURLPolicy.allowedHost
    /// 許容する最大レスポンスサイズ（バイト数）。
    internal nonisolated static let maxResponseBytes = DamCoreMlitURLPolicy.maxResponseBytes
    /// リクエストのタイムアウト時間（秒）。
    internal nonisolated static let requestTimeout = DamCoreMlitURLPolicy.requestTimeout
    /// 送信するUser-Agentヘッダ。
    internal nonisolated static let userAgent = DamCoreMlitURLPolicy.userAgent

    /// 国土交通省（MLIT）の有効なURLかどうかを検証し、結果のURLを返します（ドメイン固有エラー）。
    /// - Parameter urlString: 検証対象のURL文字列。
    /// - Returns: 検証済みのURL。
    /// - Throws: `MlitURLPolicyError.invalidMLITURL`URLが無効な場合。
    internal nonisolated static func validatedCoreMLITURL(from urlString: String) throws(MlitURLPolicyError) -> URL {
        do {
            return try DamCoreMlitURLPolicy.validatedMLITURL(from: urlString)
        } catch {
            throw MlitURLPolicyError.invalidMLITURL
        }
    }

    /// 国土交通省（MLIT）の有効なURLかどうかを検証し、結果のURLを返します（アプリ共通エラー）。
    /// - Parameter urlString: 検証対象のURL文字列。
    /// - Returns: 検証済みのURL。
    /// - Throws: `AppError.invalidMLITURL`URLが無効な場合。
    internal nonisolated static func validatedMLITURL(from urlString: String) throws -> URL {
        do {
            return try validatedCoreMLITURL(from: urlString)
        } catch {
            throw AppError.invalidMLITURL
        }
    }

    /// 抽出されたhrefから、正規化されたDATファイルのURLを解決します。
    /// - Parameter href: HTML等から抽出したアンカーリンク文字列。
    /// - Returns: 解決されたDATファイルのURL。解決できない場合は `nil`。
    internal nonisolated static func resolvedDatURL(from href: String) -> URL? {
        DamCoreMlitURLPolicy.resolvedDatURL(from: href)
    }

    /// 指定されたURLが許可された国土交通省（MLIT）ドメインのものであるかを判定します。
    /// - Parameter url: 判定対象のURL。
    /// - Returns: 許可対象であれば `true`、それ以外は `false`。
    internal nonisolated static func isAllowedMLITURL(_ url: URL) -> Bool {
        DamCoreMlitURLPolicy.isAllowedMLITURL(url)
    }

    /// 指定されたURLが許可されたDATファイル提供元URLであるかを判定します。
    /// - Parameter url: 判定対象のURL。
    /// - Returns: 許可対象であれば `true`、それ以外は `false`。
    internal nonisolated static func isAllowedDatURL(_ url: URL) -> Bool {
        DamCoreMlitURLPolicy.isAllowedDatURL(url)
    }

    /// sudmonitor 中継取得で送信するアプリ識別の User-Agent ヘッダー値。
    internal nonisolated static var sudmonitorUserAgent: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        return "TCSameuraDamMonitor-Apple/\(version)"
    }

    /// sudmonitor 中継取得用の URL ポリシー。
    internal nonisolated static var sudmonitorPolicy: DamCoreURLPolicy {
        DamCoreURLPolicy.sudmonitor(userAgent: sudmonitorUserAgent)
    }

    /// sudmonitor 中継取得の有効なURLかどうかを検証し、結果のURLを返します（アプリ共通エラー）。
    /// - Parameter urlString: 検証対象のURL文字列。
    /// - Returns: 検証済みのURL。
    /// - Throws: `AppError.invalidMLITURL`URLが無効な場合。
    internal nonisolated static func validatedSudmonitorURL(from urlString: String) throws -> URL {
        do {
            return try sudmonitorPolicy.validatedURL(from: urlString)
        } catch {
            throw AppError.invalidMLITURL
        }
    }

    /// sudmonitor 履歴ファイル取得用のポリシー(月次 / latest.dat)。
    internal nonisolated static let sudmonitorHistoryPolicy = DamCoreURLPolicy.sudmonitorHistory(userAgent: sudmonitorUserAgent)

    /// sudmonitor 履歴の URL を検証します。
    /// - Parameter urlString: 検証対象のURL文字列。
    /// - Returns: 検証済みのURL。
    /// - Throws: `AppError.invalidMLITURL`URLが無効な場合。
    internal nonisolated static func validatedSudmonitorHistoryURL(from urlString: String) throws -> URL {
        do {
            return try sudmonitorHistoryPolicy.validatedURL(from: urlString)
        } catch {
            throw AppError.invalidMLITURL
        }
    }
}

