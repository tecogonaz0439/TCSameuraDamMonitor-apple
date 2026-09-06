// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import CryptoKit
import Foundation
import SwiftData

internal enum DebugDataSessionError: Error, Equatable {
    case activeSessionAlreadyExists
    case backupNotFound
    case unsupportedVersion(Int)
    case checksumMismatch
    case duplicateRealtimeKey(String)
    case duplicateDailyHistoryDamId(String)
}

extension DebugDataSessionError: LocalizedError {
    internal var errorDescription: String? {
        switch self {
        case .activeSessionAlreadyExists:
            return "A debug data backup is already active."
        case .backupNotFound:
            return "The debug data backup was not found."
        case .unsupportedVersion(let version):
            return "The debug data backup version is not supported: \(version)."
        case .checksumMismatch:
            return "The debug data backup is damaged."
        case .duplicateRealtimeKey(let key):
            return "The debug data backup contains a duplicate realtime key: \(key)."
        case .duplicateDailyHistoryDamId(let damId):
            return "The debug data backup contains a duplicate daily history dam ID: \(damId)."
        }
    }
}

internal struct DebugDataSessionRestoreSummary: Equatable, Sendable {
    internal let realtimeRecordCount: Int
    internal let dailyHistoryRecordCount: Int
}

internal struct DebugDataSessionDatFile: Equatable, Sendable {
    internal let bytes: Data
    internal let fileName: String?
}

internal enum DebugDataSessionRecoveryResult: Equatable, Sendable {
    case none
    case activeSessionValidated
    case restoredInterruptedTransition(DebugDataSessionRestoreSummary)
}

/// Debug mode が通常データを上書きする前に、リアルタイムデータと日次過去データを
/// SwiftData store の外へ待避する。SwiftData schema を変更せず、起動中断時にも復旧できる。
@MainActor
internal final class DebugDataSessionService {
    internal static let currentVersion = 1
    internal static let activeBackupFileName = "active-v1.plist"
    internal static let stagingBackupFileName = "staging-v1.plist"

    private struct RealtimeRecordDTO: Codable, Sendable {
        let key: String
        let encodedData: Data
        let lastFetchTime: Date
        let rawDatBytes: Data?
        let rawDatFileName: String?
        let manualRefreshAvailableAt: Date?

        init(_ record: DamDataRecord) {
            key = record.key
            encodedData = record.encodedData
            lastFetchTime = record.lastFetchTime
            rawDatBytes = record.rawDatBytes
            rawDatFileName = record.rawDatFileName
            manualRefreshAvailableAt = record.manualRefreshAvailableAt
        }
    }

    private struct DailyHistoryRecordDTO: Codable, Sendable {
        let damId: String
        let periodStartDay: String
        let periodEndDay: String
        let fetchedAt: Date
        let nextUpdateAt: Date?
        let rawDatBytes: Data
        let rawDatFileName: String?

        init(_ record: SudmonitorHistoryRecord) {
            damId = record.damId
            periodStartDay = record.periodStartDay
            periodEndDay = record.periodEndDay
            fetchedAt = record.fetchedAt
            nextUpdateAt = record.nextUpdateAt
            rawDatBytes = record.rawDatBytes
            rawDatFileName = record.rawDatFileName
        }
    }

    private struct Payload: Codable, Sendable {
        let realtimeRecords: [RealtimeRecordDTO]
        let dailyHistoryRecords: [DailyHistoryRecordDTO]
    }

    private struct Envelope: Codable, Sendable {
        let version: Int
        let createdAt: Date
        let payload: Data
        let payloadSHA256: String
    }

    private let fileManager: FileManager
    internal let backupRootURL: URL

    internal var activeBackupURL: URL {
        backupRootURL.appendingPathComponent(Self.activeBackupFileName, isDirectory: false)
    }

    private var stagingBackupURL: URL {
        backupRootURL.appendingPathComponent(Self.stagingBackupFileName, isDirectory: false)
    }

    internal init(backupRootURL: URL, fileManager: FileManager = .default) {
        self.backupRootURL = backupRootURL
        self.fileManager = fileManager
    }

    internal convenience init(fileManager: FileManager = .default) throws {
        guard let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        let root = applicationSupportURL
            .appendingPathComponent("net.tecogonaz.TCSameuraDamMonitor", isDirectory: true)
            .appendingPathComponent("debug-data-backup", isDirectory: true)
        self.init(backupRootURL: root, fileManager: fileManager)
    }

    internal var hasActiveBackup: Bool {
        fileManager.fileExists(atPath: activeBackupURL.path)
    }

    internal func backedUpRealtimeDatFile() throws -> DebugDataSessionDatFile? {
        guard let record = try loadValidatedPayload().realtimeRecords.first,
              let bytes = record.rawDatBytes, !bytes.isEmpty else { return nil }
        return DebugDataSessionDatFile(bytes: bytes, fileName: record.rawDatFileName)
    }

    internal func backedUpHistoricalDailyDatFile(damId: String) throws -> DebugDataSessionDatFile? {
        guard let record = try loadValidatedPayload().dailyHistoryRecords.first(where: { $0.damId == damId }),
              !record.rawDatBytes.isEmpty else { return nil }
        return DebugDataSessionDatFile(bytes: record.rawDatBytes, fileName: record.rawDatFileName)
    }

    /// Debug ON を永続化する前に呼ぶ。空のstoreも正規のsnapshotとして記録する。
    internal func beginSession(context: ModelContext, now: Date = Date()) throws {
        guard !hasActiveBackup else {
            throw DebugDataSessionError.activeSessionAlreadyExists
        }
        let payload = Payload(
            realtimeRecords: try context.fetch(FetchDescriptor<DamDataRecord>())
                .sorted { $0.key < $1.key }
                .map(RealtimeRecordDTO.init),
            dailyHistoryRecords: try context.fetch(FetchDescriptor<SudmonitorHistoryRecord>())
                .sorted { $0.damId < $1.damId }
                .map(DailyHistoryRecordDTO.init)
        )
        try validate(payload)
        let payloadData = try Self.encode(payload)
        let envelope = Envelope(
            version: Self.currentVersion,
            createdAt: now,
            payload: payloadData,
            payloadSHA256: Self.sha256Hex(payloadData)
        )
        let envelopeData = try Self.encode(envelope)

        try fileManager.createDirectory(at: backupRootURL, withIntermediateDirectories: true)
        Self.excludeFromSystemBackup(backupRootURL)
        if fileManager.fileExists(atPath: stagingBackupURL.path) {
            try fileManager.removeItem(at: stagingBackupURL)
        }
        try envelopeData.write(to: stagingBackupURL, options: .atomic)
        Self.excludeFromSystemBackup(stagingBackupURL)
        try fileManager.moveItem(at: stagingBackupURL, to: activeBackupURL)
        Self.excludeFromSystemBackup(activeBackupURL)
    }

    /// active backup をSwiftDataへ復元する。呼出側がDebug OFFを永続化した後に
    /// `removeBackupAfterSuccessfulExit()` を呼ぶまでbackupを保持する。
    @discardableResult
    internal func restoreSession(context: ModelContext) throws -> DebugDataSessionRestoreSummary {
        let payload = try loadValidatedPayload()
        do {
            try context.fetch(FetchDescriptor<DamDataRecord>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<SudmonitorHistoryRecord>()).forEach(context.delete)

            for record in payload.realtimeRecords {
                context.insert(DamDataRecord(
                    key: record.key,
                    encodedData: record.encodedData,
                    lastFetchTime: record.lastFetchTime,
                    rawDatBytes: record.rawDatBytes,
                    rawDatFileName: record.rawDatFileName,
                    manualRefreshAvailableAt: record.manualRefreshAvailableAt
                ))
            }
            for record in payload.dailyHistoryRecords {
                context.insert(SudmonitorHistoryRecord(
                    damId: record.damId,
                    periodStartDay: record.periodStartDay,
                    periodEndDay: record.periodEndDay,
                    fetchedAt: record.fetchedAt,
                    nextUpdateAt: record.nextUpdateAt,
                    rawDatBytes: record.rawDatBytes,
                    rawDatFileName: record.rawDatFileName
                ))
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return DebugDataSessionRestoreSummary(
            realtimeRecordCount: payload.realtimeRecords.count,
            dailyHistoryRecordCount: payload.dailyHistoryRecords.count
        )
    }

    /// Debug OFF設定の保存とメモリ状態の再読込が完了した後にだけ呼ぶ。
    internal func removeBackupAfterSuccessfulExit() throws {
        guard hasActiveBackup else { return }
        try fileManager.removeItem(at: activeBackupURL)
    }

    /// cache load / Widget bridge import / foreground startup より前に呼ぶ。
    /// DebugがOFFなのにbackupが残っていれば、中断した遷移として冪等に復元して片付ける。
    internal func recoverAtLaunch(context: ModelContext, debugModeEnabled: Bool) throws -> DebugDataSessionRecoveryResult {
        guard hasActiveBackup else {
            removeAbandonedStagingFile()
            return .none
        }
        if debugModeEnabled {
            _ = try loadValidatedPayload()
            removeAbandonedStagingFile()
            return .activeSessionValidated
        }
        let summary = try restoreSession(context: context)
        try removeBackupAfterSuccessfulExit()
        removeAbandonedStagingFile()
        return .restoredInterruptedTransition(summary)
    }

    private func loadValidatedPayload() throws -> Payload {
        guard hasActiveBackup else {
            throw DebugDataSessionError.backupNotFound
        }
        let envelopeData = try Data(contentsOf: activeBackupURL, options: .mappedIfSafe)
        let envelope = try Self.decode(Envelope.self, from: envelopeData)
        guard envelope.version == Self.currentVersion else {
            throw DebugDataSessionError.unsupportedVersion(envelope.version)
        }
        guard Self.sha256Hex(envelope.payload) == envelope.payloadSHA256 else {
            throw DebugDataSessionError.checksumMismatch
        }
        let payload = try Self.decode(Payload.self, from: envelope.payload)
        try validate(payload)
        return payload
    }

    private func validate(_ payload: Payload) throws {
        var realtimeKeys = Set<String>()
        for record in payload.realtimeRecords where !realtimeKeys.insert(record.key).inserted {
            throw DebugDataSessionError.duplicateRealtimeKey(record.key)
        }
        var dailyDamIds = Set<String>()
        for record in payload.dailyHistoryRecords where !dailyDamIds.insert(record.damId).inserted {
            throw DebugDataSessionError.duplicateDailyHistoryDamId(record.damId)
        }
    }

    private func removeAbandonedStagingFile() {
        guard fileManager.fileExists(atPath: stagingBackupURL.path) else { return }
        try? fileManager.removeItem(at: stagingBackupURL)
    }

    private nonisolated static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(value)
    }

    private nonisolated static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try PropertyListDecoder().decode(type, from: data)
    }

    private nonisolated static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private nonisolated static func excludeFromSystemBackup(_ url: URL) {
        var mutableURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? mutableURL.setResourceValues(values)
    }
}
