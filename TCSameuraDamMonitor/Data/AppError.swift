// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation
import TCSameuraDamCore

/// 国土交通省（MLIT）のネットワーク通信中に発生するエラーを表す列挙型。
internal enum MlitNetworkError: Error, Equatable, Sendable {
    /// 無効なURL。
    case invalidURL
    /// 応答サイズ制限の超過。
    case responseTooLarge
    /// 不正なHTTPステータスコード。
    case badHTTPStatus(Int)
    /// HTTP 404（対象リソースの不存在）。
    case notFound
    /// ネットワークトランスポート層のエラー。
    case transport
}

extension MlitNetworkError {
    /// 汎用的なエラーオブジェクトから `MlitNetworkError` を初期化します。
    /// - Parameter error: 変換元のエラー。
    internal init(_ error: Error) {
        if let networkError = error as? MlitNetworkError {
            self = networkError
        } else if let coreError = error as? DamCoreMlitURLPolicyError {
            switch coreError {
            case .invalidMLITURL:
                self = .invalidURL
            case .responseTooLarge:
                self = .responseTooLarge
            case .badHTTPStatus(let status):
                self = .badHTTPStatus(status)
            }
        } else if let urlError = error as? URLError, urlError.code == .badURL {
            self = .invalidURL
        } else {
            self = .transport
        }
    }

    /// `MlitNetworkError` に対応する `AppError` を取得します。
    internal var appError: AppError {
        switch self {
        case .invalidURL:
            .invalidMLITURL
        case .responseTooLarge:
            .responseTooLarge
        case .badHTTPStatus, .transport, .notFound:
            .networkUnavailable
        }
    }
}

/// リアルタイム観測データ (Real-time observation data) の読み込み中に発生するエラーを表す列挙型。
internal enum RealtimeLoadError: Error, Equatable, Sendable {
    /// 永続化モデルコンテキストの準備が完了していない。
    case modelContextNotReady
    /// ダムの設定が見つからない。
    case damConfigMissing
    /// ネットワークが利用できない。
    case networkUnavailable
    /// シミュレートされたネットワーク不通状態。
    case simulatedNetworkUnavailable
    /// シミュレートされたロード失敗。
    case simulatedLoadingFailure
    /// データのパース処理の失敗。
    case parseFailed
    /// データの永続化保存の失敗。
    case persistenceFailed
}

/// 過去データ検索 (Historical data search) 中に発生するエラーを表す列挙型。
internal enum HistoricalSearchError: Error, Equatable, Sendable {
    /// 重複した過去データ検索。
    case duplicate
    /// サポートされていない操作。
    case unsupported
    /// 検索上限数の超過。
    case limitExceeded
    /// 該当期間のデータが存在しない。
    case noData
    /// ネットワークエラー。
    case network
    /// データのパース処理の失敗。
    case parseFailed
    /// データの永続化保存の失敗。
    case persistenceFailed
}

/// ウィジェット向けのデータ取得中に発生するエラーを表す列挙型。
internal enum WidgetFetchError: Error, Equatable, Sendable {
    /// 無効なURL。
    case invalidURL
    /// 応答サイズ制限の超過。
    case responseTooLarge
    /// 不正なHTTPステータスコード。
    case badHTTPStatus(Int)
    /// パース処理の失敗。
    case parseFailed
    /// ネットワーク通信エラー。
    case network
}

extension RealtimeLoadError {
    /// 汎用的なエラーオブジェクトから `RealtimeLoadError` を初期化します。
    /// - Parameter error: 変換元のエラー。
    internal init(_ error: Error) {
        if let realtimeError = error as? RealtimeLoadError {
            self = realtimeError
            return
        }
        if let appError = error as? AppError {
            switch appError {
            case .modelContextNotReady:
                self = .modelContextNotReady
            case .damConfigMissing:
                self = .damConfigMissing
            case .networkUnavailable:
                self = .networkUnavailable
            case .simulatedNetworkUnavailable:
                self = .simulatedNetworkUnavailable
            case .simulatedLoadingFailure:
                self = .simulatedLoadingFailure
            default:
                self = .parseFailed
            }
            return
        }
        if error is MlitNetworkError || error is URLError || (error as NSError).domain == NSURLErrorDomain {
            // 取得開始前の接続判定を通過した後の通信失敗は、Android版と同様に
            // ネットワーク未接続ではなく観測データの読み込み失敗として扱う。
            self = .parseFailed
            return
        }
        self = .parseFailed
    }

    /// ネットワークに起因するエラーであるかどうかを示すフラグ。
    internal var isNetworkFailure: Bool {
        switch self {
        case .networkUnavailable, .simulatedNetworkUnavailable:
            return true
        default:
            return false
        }
    }
}

extension HistoricalSearchError {
    /// 汎用的なエラーオブジェクトから `HistoricalSearchError` を初期化します。
    /// - Parameter error: 変換元のエラー。
    internal init(_ error: Error) {
        if let historicalError = error as? HistoricalSearchError {
            self = historicalError
            return
        }
        if let appError = error as? AppError {
            switch appError {
            case .duplicateHistoricalSearch:
                self = .duplicate
            case .historicalSearchMatchesLoadedDaily:
                self = .duplicate
            case .historicalSearchNotSupported:
                self = .unsupported
            case .historicalSearchLimitExceeded:
                self = .limitExceeded
            case .noHistoricalData:
                self = .noData
            case .networkUnavailable, .simulatedNetworkUnavailable:
                self = .network
            default:
                self = .parseFailed
            }
            return
        }
        if error is MlitNetworkError || error is URLError || (error as NSError).domain == NSURLErrorDomain {
            self = .network
            return
        }
        self = .parseFailed
    }
}

/// アプリ全体で共有される共通のエラー定義。ローカライズされた説明を提供します。
internal enum AppError: LocalizedError, Equatable, Sendable {
    /// 永続化モデルコンテキストの準備が完了していない。
    case modelContextNotReady
    /// ダムの設定が見つからない。
    case damConfigMissing
    /// 過去データ検索 (Historical data search) が重複している。
    case duplicateHistoricalSearch
    /// 指定期間が sudmonitor の日次過去データとして読み込み済みである。
    case historicalSearchMatchesLoadedDaily
    /// 過去データ検索 (Historical data search) がサポートされていない期間・条件である。
    case historicalSearchNotSupported
    /// 過去データ検索 (Historical data search) の上限数を超過している。
    case historicalSearchLimitExceeded
    /// 該当期間の履歴データが存在しない。
    case noHistoricalData
    /// 応答サイズ制限の超過。
    case responseTooLarge
    /// 無効な国土交通省（MLIT）のURL。
    case invalidMLITURL
    /// デバッグ用のDATファイルが無効。
    case invalidDebugDatFile
    /// ネットワーク接続エラー。
    case networkUnavailable
    /// デバッグ用のファイルが存在しない。
    case debugFileMissing
    /// シミュレートされたネットワーク不通状態。
    case simulatedNetworkUnavailable
    /// シミュレートされたロード失敗。
    case simulatedLoadingFailure

    /// エラーのローカライズされた説明文字列。
    internal var errorDescription: String? {
        switch self {
        case .modelContextNotReady: return AppLocalized.text("error.modelContextNotReady")
        case .damConfigMissing: return AppLocalized.text("error.damConfigMissing")
        case .duplicateHistoricalSearch: return AppLocalized.text("error.duplicateHistoricalSearch")
        case .historicalSearchMatchesLoadedDaily: return AppLocalized.text("historical.sudmonitorHistory.duplicateLoaded")
        case .historicalSearchNotSupported: return AppLocalized.text("error.historicalSearchNotSupported")
        case .historicalSearchLimitExceeded: return AppLocalized.text("error.historicalSearchLimitExceeded")
        case .noHistoricalData: return AppLocalized.text("error.noHistoricalData")
        case .responseTooLarge: return AppLocalized.text("error.responseTooLarge")
        case .invalidMLITURL: return AppLocalized.text("error.invalidMLITURL")
        case .invalidDebugDatFile: return AppLocalized.text("error.invalidDebugDatFile")
        case .networkUnavailable: return AppLocalized.text("error.networkUnavailable")
        case .debugFileMissing: return AppLocalized.text("error.debugFileMissing")
        case .simulatedNetworkUnavailable: return AppLocalized.text("error.simulatedNetworkUnavailable")
        case .simulatedLoadingFailure: return AppLocalized.text("error.simulatedLoadingFailure")
        }
    }
}
