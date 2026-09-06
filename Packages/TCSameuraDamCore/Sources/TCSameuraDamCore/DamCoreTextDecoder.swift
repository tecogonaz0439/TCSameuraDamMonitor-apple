// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// テキストデコーダーで発生するエラーを定義する列挙型。
public enum DamCoreTextDecoderError: Error, Equatable, Sendable {
    /// サポートされていないエンコーディングであるエラー。
    case unsupportedEncoding
}

/// 国土交通省 (MLIT) のデータ等、日本語エンコーディングを含むテキストデータをデコードするためのユーティリティ。
public enum DamCoreTextDecoder {
    /// Shift_JIS エンコーディング。
    public nonisolated static let shiftJIS = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.shiftJIS.rawValue))
    )

    /// EUC-JP エンコーディング。
    public nonisolated static let eucJP = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.EUC_JP.rawValue))
    )

    /// 国土交通省 (MLIT) のテキストデータをデコードして文字列を返します。
    ///
    /// UTF-8 (BOM付き含む)、Shift_JIS、EUC-JP の順に試行してデコードします。
    ///
    /// - Parameter data: デコード対象のバイナリデータ。
    /// - Returns: デコードされた文字列。いずれのエンコーディングでもデコードできなかった場合は nil を返します。
    public nonisolated static func decodeMLITText(_ data: Data) -> String? {
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return String(data: data.dropFirst(3), encoding: .utf8)
        }
        return String(data: data, encoding: shiftJIS)
            ?? String(data: data, encoding: eucJP)
            ?? String(data: data, encoding: .utf8)
    }

    /// 国土交通省 (MLIT) のテキストデータを UTF-8 エンコーディングのバイナリデータに変換します。
    ///
    /// - Parameter data: 変換対象の日本語エンコーディングを含むデータ。
    /// - Throws: デコードに失敗した場合に `DamCoreTextDecoderError.unsupportedEncoding` をスローします。
    /// - Returns: UTF-8 でエンコードされたデータ。
    public nonisolated static func utf8Data(from data: Data) throws -> Data {
        guard let text = decodeMLITText(data) else {
            throw DamCoreTextDecoderError.unsupportedEncoding
        }
        return Data(text.utf8)
    }
}
