// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Testing
@testable import TCSameuraDamMonitor

/// 画面ロック復帰後のシート再構築世代の進み方を検証する。
///
/// 長時間のバックグラウンドから復帰したときだけ世代が進み、短時間のアプリ切替では
/// シート内容が作り直されないことを確認する。
@Suite("Sheet recovery generation")
@MainActor
struct SheetRecoveryGenerationTests {
    @Test func activeWithoutBackgroundKeepsGeneration() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let appModel = makeAppModel(defaults: defaults)

        appModel.noteSceneBecameActive(now: referenceDate)

        #expect(appModel.sheetRecoveryGeneration == 0)
    }

    @Test func backgroundShorterThanThresholdKeepsGeneration() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let appModel = makeAppModel(defaults: defaults)

        appModel.noteSceneEnteredBackground(now: referenceDate)
        appModel.noteSceneBecameActive(
            now: referenceDate.addingTimeInterval(appModel.sheetRecoveryBackgroundThreshold - 0.5)
        )

        #expect(appModel.sheetRecoveryGeneration == 0)
    }

    @Test func backgroundAtThresholdAdvancesGeneration() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let appModel = makeAppModel(defaults: defaults)

        appModel.noteSceneEnteredBackground(now: referenceDate)
        appModel.noteSceneBecameActive(
            now: referenceDate.addingTimeInterval(appModel.sheetRecoveryBackgroundThreshold)
        )

        #expect(appModel.sheetRecoveryGeneration == 1)
    }

    @Test func injectedThresholdAdvancesGeneration() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let appModel = makeAppModel(defaults: defaults, threshold: 5)

        appModel.noteSceneEnteredBackground(now: referenceDate)
        appModel.noteSceneBecameActive(now: referenceDate.addingTimeInterval(5))

        #expect(appModel.sheetRecoveryGeneration == 1)
    }

    @Test func longBackgroundAdvancesGeneration() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let appModel = makeAppModel(defaults: defaults)

        appModel.noteSceneEnteredBackground(now: referenceDate)
        appModel.noteSceneBecameActive(now: referenceDate.addingTimeInterval(3 * 60 * 60))

        #expect(appModel.sheetRecoveryGeneration == 1)
    }

    @Test func repeatedActiveWithoutNewBackgroundKeepsGeneration() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let appModel = makeAppModel(defaults: defaults)

        appModel.noteSceneEnteredBackground(now: referenceDate)
        appModel.noteSceneBecameActive(now: referenceDate.addingTimeInterval(3600))
        appModel.noteSceneBecameActive(now: referenceDate.addingTimeInterval(3601))

        #expect(appModel.sheetRecoveryGeneration == 1)
    }

    @Test func consecutiveLongBackgroundsAdvanceGenerationOncePerRecovery() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let appModel = makeAppModel(defaults: defaults)

        appModel.noteSceneEnteredBackground(now: referenceDate)
        appModel.noteSceneBecameActive(now: referenceDate.addingTimeInterval(3600))
        appModel.noteSceneEnteredBackground(now: referenceDate.addingTimeInterval(7200))
        appModel.noteSceneBecameActive(now: referenceDate.addingTimeInterval(10_800))

        #expect(appModel.sheetRecoveryGeneration == 2)
    }
}

private let referenceDate = Date(timeIntervalSinceReferenceDate: 800_000_000)

private func makeDefaults() throws -> (UserDefaults, String) {
    let name = "SheetRecoveryGenerationTests.\(UUID().uuidString)"
    return (try #require(UserDefaults(suiteName: name)), name)
}

@MainActor
private func makeAppModel(
    defaults: UserDefaults,
    threshold: TimeInterval = DamAppModel.defaultSheetRecoveryBackgroundThreshold
) -> DamAppModel {
    DamAppModel(
        settingsRepository: SettingsRepository(defaults: defaults),
        dashboardCardExpansionRepository: DashboardCardExpansionRepository(defaults: defaults),
        widgetGroupDefaults: defaults,
        widgetStandardDefaults: defaults,
        sheetRecoveryBackgroundThreshold: threshold
    )
}
