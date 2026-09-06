// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation
import SwiftData
import Testing
@testable import TCSameuraDamMonitor

@Suite("Debug data session sidecar", .serialized)
@MainActor
struct DebugDataSessionServiceTests {
    @Test func roundTripRestoresAllRealtimeAndDailyRecords() throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        let context = try makeContext()
        seedNormalRecords(context)
        let service = DebugDataSessionService(backupRootURL: fixture.url)

        try service.beginSession(context: context, now: Date(timeIntervalSince1970: 100))
        replaceWithDebugRecords(context)

        let summary = try service.restoreSession(context: context)

        #expect(summary == DebugDataSessionRestoreSummary(realtimeRecordCount: 2, dailyHistoryRecordCount: 2))
        #expect(service.hasActiveBackup)
        let realtime = try context.fetch(FetchDescriptor<DamDataRecord>()).sorted { $0.key < $1.key }
        #expect(realtime.map(\.key) == ["latest", "secondary"])
        #expect(realtime.map(\.rawDatBytes) == [Data("normal-realtime".utf8), nil])
        #expect(realtime.first?.manualRefreshAvailableAt == Date(timeIntervalSince1970: 300))
        let daily = try context.fetch(FetchDescriptor<SudmonitorHistoryRecord>()).sorted { $0.damId < $1.damId }
        #expect(daily.map(\.damId) == ["1368080700010", "other-dam"])
        #expect(daily.map(\.rawDatBytes) == [Data("normal-daily".utf8), Data("other-daily".utf8)])

        try service.removeBackupAfterSuccessfulExit()
        #expect(!service.hasActiveBackup)
    }

    @Test func emptyStoreIsRestoredAsEmptyInsteadOfBeingTreatedAsMissing() throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        let context = try makeContext()
        let service = DebugDataSessionService(backupRootURL: fixture.url)
        try service.beginSession(context: context)
        seedDebugRecords(context)

        let summary = try service.restoreSession(context: context)

        #expect(summary == DebugDataSessionRestoreSummary(realtimeRecordCount: 0, dailyHistoryRecordCount: 0))
        #expect(try context.fetch(FetchDescriptor<DamDataRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SudmonitorHistoryRecord>()).isEmpty)
    }

    @Test func launchRecoveryRestoresWhenSettingsAreAlreadyOff() throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        let context = try makeContext()
        seedNormalRecords(context)
        let service = DebugDataSessionService(backupRootURL: fixture.url)
        try service.beginSession(context: context)
        replaceWithDebugRecords(context)

        let result = try service.recoverAtLaunch(context: context, debugModeEnabled: false)

        #expect(result == .restoredInterruptedTransition(
            DebugDataSessionRestoreSummary(realtimeRecordCount: 2, dailyHistoryRecordCount: 2)
        ))
        #expect(!service.hasActiveBackup)
        #expect(try context.fetch(FetchDescriptor<DamDataRecord>()).map(\.key).sorted() == ["latest", "secondary"])
        #expect(try context.fetch(FetchDescriptor<SudmonitorHistoryRecord>()).map(\.damId).sorted() == ["1368080700010", "other-dam"])
    }

    @Test func launchRecoveryValidatesButDoesNotRestoreActiveDebugSession() throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        let context = try makeContext()
        seedNormalRecords(context)
        let service = DebugDataSessionService(backupRootURL: fixture.url)
        try service.beginSession(context: context)
        replaceWithDebugRecords(context)

        let result = try service.recoverAtLaunch(context: context, debugModeEnabled: true)

        #expect(result == .activeSessionValidated)
        #expect(service.hasActiveBackup)
        #expect(try context.fetch(FetchDescriptor<DamDataRecord>()).map(\.key) == ["debug"])
        #expect(try context.fetch(FetchDescriptor<SudmonitorHistoryRecord>()).map(\.damId) == ["debug-dam"])
    }

    @Test func secondBeginDoesNotOverwriteOriginalBackup() throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        let context = try makeContext()
        seedNormalRecords(context)
        let service = DebugDataSessionService(backupRootURL: fixture.url)
        try service.beginSession(context: context)
        replaceWithDebugRecords(context)

        #expect(throws: DebugDataSessionError.activeSessionAlreadyExists) {
            try service.beginSession(context: context)
        }
        _ = try service.restoreSession(context: context)
        #expect(try context.fetch(FetchDescriptor<DamDataRecord>()).map(\.key).sorted() == ["latest", "secondary"])
    }

    @Test func damagedBackupIsRejectedWithoutChangingSwiftData() throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        let context = try makeContext()
        seedNormalRecords(context)
        let service = DebugDataSessionService(backupRootURL: fixture.url)
        try service.beginSession(context: context)
        replaceWithDebugRecords(context)
        var bytes = try Data(contentsOf: service.activeBackupURL)
        bytes[bytes.index(before: bytes.endIndex)] ^= 0xff
        try bytes.write(to: service.activeBackupURL, options: .atomic)

        #expect(throws: (any Error).self) {
            try service.restoreSession(context: context)
        }
        #expect(service.hasActiveBackup)
        #expect(try context.fetch(FetchDescriptor<DamDataRecord>()).map(\.key) == ["debug"])
        #expect(try context.fetch(FetchDescriptor<SudmonitorHistoryRecord>()).map(\.damId) == ["debug-dam"])
    }

    @Test func checksumMismatchIsRejectedWithoutChangingSwiftData() throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        let context = try makeContext()
        seedNormalRecords(context)
        let service = DebugDataSessionService(backupRootURL: fixture.url)
        try service.beginSession(context: context)
        replaceWithDebugRecords(context)
        let decoder = PropertyListDecoder()
        let original = try decoder.decode(TestEnvelope.self, from: Data(contentsOf: service.activeBackupURL))
        let invalid = TestEnvelope(
            version: original.version,
            createdAt: original.createdAt,
            payload: original.payload,
            payloadSHA256: String(repeating: "0", count: 64)
        )
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        try encoder.encode(invalid).write(to: service.activeBackupURL, options: .atomic)

        #expect(throws: DebugDataSessionError.checksumMismatch) {
            try service.restoreSession(context: context)
        }
        #expect(try context.fetch(FetchDescriptor<DamDataRecord>()).map(\.key) == ["debug"])
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([DamDataRecord.self, SudmonitorHistoryRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [configuration]))
    }

    private func seedNormalRecords(_ context: ModelContext) {
        context.insert(DamDataRecord(
            key: "latest",
            encodedData: Data("normal-encoded".utf8),
            lastFetchTime: Date(timeIntervalSince1970: 200),
            rawDatBytes: Data("normal-realtime".utf8),
            rawDatFileName: "normal.dat",
            manualRefreshAvailableAt: Date(timeIntervalSince1970: 300)
        ))
        context.insert(DamDataRecord(
            key: "secondary",
            encodedData: Data("secondary-encoded".utf8),
            lastFetchTime: Date(timeIntervalSince1970: 210),
            rawDatBytes: nil
        ))
        context.insert(SudmonitorHistoryRecord(
            damId: "1368080700010",
            periodStartDay: "20260509",
            periodEndDay: "20260609",
            fetchedAt: Date(timeIntervalSince1970: 220),
            nextUpdateAt: Date(timeIntervalSince1970: 400),
            rawDatBytes: Data("normal-daily".utf8),
            rawDatFileName: "daily.dat"
        ))
        context.insert(SudmonitorHistoryRecord(
            damId: "other-dam",
            periodStartDay: "20260101",
            periodEndDay: "20260131",
            fetchedAt: Date(timeIntervalSince1970: 230),
            nextUpdateAt: nil,
            rawDatBytes: Data("other-daily".utf8),
            rawDatFileName: nil
        ))
        try? context.save()
    }

    private func seedDebugRecords(_ context: ModelContext) {
        context.insert(DamDataRecord(
            key: "debug",
            encodedData: Data("debug-encoded".utf8),
            lastFetchTime: Date(timeIntervalSince1970: 500),
            rawDatBytes: Data("debug-realtime".utf8)
        ))
        context.insert(SudmonitorHistoryRecord(
            damId: "debug-dam",
            periodStartDay: "20270101",
            periodEndDay: "20270131",
            fetchedAt: Date(timeIntervalSince1970: 510),
            nextUpdateAt: nil,
            rawDatBytes: Data("debug-daily".utf8)
        ))
        try? context.save()
    }

    private func replaceWithDebugRecords(_ context: ModelContext) {
        (try? context.fetch(FetchDescriptor<DamDataRecord>()))?.forEach { context.delete($0) }
        (try? context.fetch(FetchDescriptor<SudmonitorHistoryRecord>()))?.forEach { context.delete($0) }
        seedDebugRecords(context)
    }

    private func makeFixture() throws -> DirectoryFixture {
        guard let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        let url = cacheURL
            .appendingPathComponent("TCSameuraDamMonitorTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return DirectoryFixture(url: url)
    }
}

private struct DirectoryFixture {
    let url: URL

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}

private struct TestEnvelope: Codable {
    let version: Int
    let createdAt: Date
    let payload: Data
    let payloadSHA256: String
}
