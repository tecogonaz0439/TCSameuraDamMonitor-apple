// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import XCTest

final class TCSameuraDamMonitorUITests: XCTestCase {
    private var runID: String!

    override func setUpWithError() throws {
        continueAfterFailure = false
        runID = UUID().uuidString
    }

    func testEnglishDashboardNavigationHistoryGraphAndAppInfo() throws {
        let app = launch(scenario: "historicalSaved", language: "en", locale: "en_US")

        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 8))
        assertSummaryCardWhenVisible(in: app)
        XCTAssertTrue(app.element("dashboard.latestDataCard").exists)
        XCTAssertTrue(app.element("dashboard.historyCard").exists)
        tapFullHistory(in: app)
        XCTAssertTrue(app.element("dashboard.history.fullView").waitForExistence(timeout: 3))
        tapBack(in: app)
        XCTAssertTrue(app.waitForElement("dashboard.graphCard"))
        XCTAssertTrue(app.waitForElement("dashboard.sourceCard"))

        openNavigationItem("nav.settings", in: app)
        XCTAssertTrue(app.element("settings.root").waitForExistence(timeout: 3))
        tapBackIfCompact(in: app)

        openNavigationItem("nav.appInfo", in: app)
        XCTAssertTrue(app.element("appInfo.root").waitForExistence(timeout: 3))
        XCTAssertFalse(app.element("appInfo.ossLicense").exists)
        tapWhenHittable(app.element("appInfo.terms"), in: app)
        XCTAssertTrue(app.element("appInfo.detail.terms").waitForExistence(timeout: 3))
        tapBack(in: app)
        tapWhenHittable(app.element("appInfo.privacy"), in: app)
        XCTAssertTrue(app.element("appInfo.detail.privacy").waitForExistence(timeout: 3))
        tapBack(in: app)
        tapWhenHittable(app.element("appInfo.license"), in: app)
        XCTAssertTrue(app.element("appInfo.detail.license").waitForExistence(timeout: 3))
    }

    func testHistoricalSearchValidationAndFailureStates() throws {
        let duplicateApp = launch(scenario: "historicalSearchDuplicate", language: "en", locale: "en_US")
        openNavigationItem("nav.historicalSearch", in: duplicateApp)
        XCTAssertTrue(duplicateApp.element("historicalSearch.root").waitForExistence(timeout: 3))
        XCTAssertTrue(duplicateApp.element("historicalSearch.validationError").waitForExistence(timeout: 3))
        XCTAssertFalse(duplicateApp.button("historicalSearch.submit").isEnabled)
        tapWhenHittable(duplicateApp.button("historicalSearch.cancel"), in: duplicateApp)

        let errorApp = launch(scenario: "historicalSearchError", language: "en", locale: "en_US")
        openNavigationItem("nav.historicalSearch", in: errorApp)
        XCTAssertTrue(errorApp.element("historicalSearch.root").waitForExistence(timeout: 3))
        tapWhenHittable(errorApp.element("historicalSearch.dam"), in: errorApp)
        XCTAssertTrue(errorApp.element("historicalSearch.damPicker").waitForExistence(timeout: 3))
        let alternateDam = errorApp.element("historicalSearch.damPicker.row.1368010125140")
        tapWhenHittable(alternateDam, in: errorApp)
        XCTAssertTrue(errorApp.element("historicalSearch.root").waitForExistence(timeout: 3))
        tapWhenHittable(errorApp.element("historicalSearch.dam"), in: errorApp)
        XCTAssertTrue(alternateDam.waitForExistence(timeout: 3))
        XCTAssertTrue(alternateDam.isSelected)
        tapWhenHittable(alternateDam, in: errorApp)
        XCTAssertTrue(errorApp.button("historicalSearch.submit").isEnabled)
        tapWhenHittable(errorApp.button("historicalSearch.submit"), in: errorApp)
        XCTAssertTrue(errorApp.element("snackbar.message").waitForExistence(timeout: 8))
    }

    func testSettingsDamSelectionSheetPickerCancelAndSelect() throws {
        let app = launch(scenario: "dashboardLoaded", language: "en", locale: "en_US")
        let sameuraDamID = "1368080700010"
        let alternateDamID = "1368010125140"

        openNavigationItem("nav.settings", in: app)
        XCTAssertTrue(app.element("settings.root").waitForExistence(timeout: 3))

        // リアルタイムデータソースの既定は sudmonitor のためダム行が無効。MLIT 直接取得へ切り替えてから検証する。
        switchRealtimeDataSourceToMlit(in: app)
        openDamSelectionSheet(in: app)
        assertDamSelectionSheetStructure(in: app)
        openSettingsDamPicker(in: app)

        let initialDam = app.element("settings.damSelection.damPicker.row.\(sameuraDamID)")
        XCTAssertTrue(initialDam.waitForExistence(timeout: 3))
        XCTAssertTrue(initialDam.isSelected)
        tapWhenHittable(
            app.element("settings.damSelection.damPicker.row.\(alternateDamID)"),
            in: app
        )
        XCTAssertTrue(app.element("settings.damSelection.sheet").waitForExistence(timeout: 3))

        tapWhenHittable(app.button("settings.damSelection.cancel"), in: app)
        XCTAssertTrue(app.element("settings.damSelection.sheet").waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.element("settings.root").exists)

        openDamSelectionSheet(in: app)
        openSettingsDamPicker(in: app)
        XCTAssertTrue(initialDam.waitForExistence(timeout: 3))
        XCTAssertTrue(initialDam.isSelected, "Cancel must discard the temporary dam selection")

        tapWhenHittable(
            app.element("settings.damSelection.damPicker.row.\(alternateDamID)"),
            in: app
        )
        XCTAssertTrue(app.element("settings.damSelection.sheet").waitForExistence(timeout: 3))
        tapWhenHittable(app.button("settings.damSelection.select"), in: app)
        XCTAssertTrue(app.element("settings.damSelection.sheet").waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 5))

        openNavigationItem("nav.settings", in: app)
        openDamSelectionSheet(in: app)
        openSettingsDamPicker(in: app)
        let confirmedDam = app.element("settings.damSelection.damPicker.row.\(alternateDamID)")
        XCTAssertTrue(confirmedDam.waitForExistence(timeout: 3))
        XCTAssertTrue(confirmedDam.isSelected, "Select must persist the chosen dam")
        tapWhenHittable(confirmedDam, in: app)
        tapWhenHittable(app.button("settings.damSelection.cancel"), in: app)
    }

    func testSettingsSystemRowsAndAppearanceOrdering() throws {
        let app = launch(scenario: "dashboardLoaded", language: "en", locale: "en_US")

        openNavigationItem("nav.settings", in: app)
        XCTAssertTrue(app.element("settings.root").waitForExistence(timeout: 3))

        let appSettings = app.element("settings.systemAppSettings")
        let appearance = app.element("settings.appearance")
        let realtimeDataSource = app.element("settings.realtimeDataSource")

        XCTAssertTrue(appSettings.waitForExistence(timeout: 3))
        XCTAssertTrue(appearance.waitForExistence(timeout: 3))
        XCTAssertFalse(
            app.element("settings.language").exists,
            "The macOS-only language row must not appear on iOS or iPadOS"
        )
        XCTAssertTrue(realtimeDataSource.waitForExistence(timeout: 3))
        XCTAssertFalse(appearance.frame.isEmpty)
        XCTAssertFalse(realtimeDataSource.frame.isEmpty)
        XCTAssertLessThan(
            appearance.frame.minY,
            realtimeDataSource.frame.minY,
            "Appearance must be vertically above the realtime data source row"
        )
    }

    func testSettingsDataSourceFooterFormat() throws {
        let app = launch(scenario: "dashboardLoaded", language: "en", locale: "en_US")

        openNavigationItem("nav.settings", in: app)
        XCTAssertTrue(app.element("settings.root").waitForExistence(timeout: 3))

        // 既定 sudmonitor: realtime/過去データ説明とダム固定文言が全て Section footer に表示される。
        XCTAssertTrue(scrollToElement(app.element("settings.realtimeDataSourceFooter"), in: app).exists)
        XCTAssertTrue(scrollToElement(app.element("settings.historicalDataSourceFooter"), in: app).exists)
        XCTAssertTrue(scrollToElement(app.element("settings.damLockedFooter"), in: app).exists)
        XCTAssertTrue(
            scrollToStaticText(
                "Real-time data is retrieved from cache server sudmonitor.kusugami-lab.net.",
                in: app
            ).exists
        )

        // footer は行の下に配置される (他の設定項目と同一フォーマット)。
        let realtimeRow = app.element("settings.realtimeDataSource")
        let realtimeFooter = app.element("settings.realtimeDataSourceFooter")
        XCTAssertTrue(realtimeRow.exists)
        XCTAssertTrue(realtimeFooter.exists)
        XCTAssertLessThanOrEqual(
            realtimeRow.frame.maxY,
            realtimeFooter.frame.minY,
            "Data source help must be in the section footer below the row"
        )

        // MLIT 切替後: ダム固定 footer は消え、realtime/過去データ説明は footer に残る。
        switchRealtimeDataSourceToMlit(in: app)
        XCTAssertTrue(scrollToElement(app.element("settings.realtimeDataSourceFooter"), in: app).exists)
        XCTAssertTrue(scrollToElement(app.element("settings.historicalDataSourceFooter"), in: app).exists)
        XCTAssertFalse(
            app.element("settings.damLockedFooter").exists,
            "Dam locked footer must disappear when realtime source is MLIT direct"
        )
        XCTAssertTrue(
            scrollToStaticText(
                "Real-time data is retrieved directly from the MLIT Water Information System.",
                in: app
            ).exists
        )
    }

    func testSettingsStorageMessageSectionsToggleAndReset() throws {
        let app = launch(scenario: "dashboardLoaded", language: "en", locale: "en_US")
        openNavigationItem("nav.settings", in: app)
        XCTAssertTrue(app.element("settings.root").waitForExistence(timeout: 3))

        // マスターセクション「Storage Percentage Messages」が表示される。
        XCTAssertTrue(scrollToStaticText("Storage Percentage Messages", in: app).exists)

        // 早明浦ダム用セクションのヘッダーと新ラベル（貯水量しきい値表記）。
        XCTAssertTrue(scrollToStaticText("Storage Percentage Messages (Sameura Dam)", in: app).exists)
        XCTAssertTrue(scrollToStaticText("Storage rate 80-100%", in: app).exists)
        XCTAssertTrue(scrollToStaticText("Volume ≥ 80,000×10³m³", in: app).exists)

        // 早明浦ダム以外用セクションのヘッダーと従来ラベル（貯水率帯表記）。
        XCTAssertTrue(scrollToStaticText("Storage Percentage Messages (Other Dams)", in: app).exists)
        XCTAssertTrue(scrollToStaticText("80-100%", in: app).exists)
        XCTAssertTrue(scrollToStaticText("60-80%", in: app).exists)

        // toggle OFF で2セクションが非表示、ON で再表示される。
        let toggle = app.element("settings.showStorageMessage")
        XCTAssertTrue(scrollToElement(toggle, in: app).exists)
        tapToggle(identifier: "settings.showStorageMessage", in: app)
        XCTAssertFalse(scrollToStaticText("Storage Percentage Messages (Sameura Dam)", in: app, maxSwipes: 4).exists)
        XCTAssertFalse(scrollToStaticText("Storage Percentage Messages (Other Dams)", in: app, maxSwipes: 4).exists)
        tapToggle(identifier: "settings.showStorageMessage", in: app)
        XCTAssertTrue(scrollToStaticText("Storage Percentage Messages (Sameura Dam)", in: app).exists)
        XCTAssertTrue(scrollToStaticText("Storage Percentage Messages (Other Dams)", in: app).exists)

        // 既定のままのリセットボタンは確認なしで即時リセットされる。
        let resetButton = app.button("settings.resetOtherStorageRateMessages")
        XCTAssertTrue(scrollToElement(resetButton, in: app).exists)
        tapWhenHittable(resetButton, in: app)
        XCTAssertTrue(app.alerts["Storage Percentage Messages"].waitForNonExistence(timeout: 2))
    }

    func testSettingsOtherStorageRateResetConfirmationAlert() throws {
        let app = launch(scenario: "otherStorageRateMessagesCustomized", language: "en", locale: "en_US")
        openNavigationItem("nav.settings", in: app)
        XCTAssertTrue(app.element("settings.root").waitForExistence(timeout: 3))

        // カスタム済みのためリセット時に確認 alert が表示される。
        let resetButton = app.button("settings.resetOtherStorageRateMessages")
        XCTAssertTrue(scrollToElement(resetButton, in: app).exists)
        tapWhenHittable(resetButton, in: app)

        let alert = app.alerts["Storage Percentage Messages"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        XCTAssertTrue(alert.staticTexts["Reset all storage percentage messages? This action cannot be undone."].exists)
        tapWhenHittable(alert.buttons["Cancel"], in: app)
        XCTAssertTrue(alert.waitForNonExistence(timeout: 3))

        // OK でリセットされ、以降は確認なしで即時リセットになる。
        tapWhenHittable(resetButton, in: app)
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        tapWhenHittable(alert.buttons["OK"], in: app)
        XCTAssertTrue(alert.waitForNonExistence(timeout: 3))
        tapWhenHittable(resetButton, in: app)
        XCTAssertTrue(alert.waitForNonExistence(timeout: 2))
    }

    func testJapaneseSettingsStorageMessageSections() throws {
        let app = launch(scenario: "dashboardLoaded", language: "ja", locale: "ja_JP")
        openNavigationItem("nav.settings", in: app)
        XCTAssertTrue(app.element("settings.root").waitForExistence(timeout: 3))

        // マスターセクションと新ヘッダー2件が表示される。
        XCTAssertTrue(scrollToStaticText("貯水率メッセージ", in: app).exists)
        XCTAssertTrue(scrollToStaticText("貯水率メッセージ(早明浦ダム)", in: app).exists)
        XCTAssertTrue(scrollToStaticText("貯水率メッセージ(早明浦ダム以外)", in: app).exists)

        // 早明浦ダム用の新ラベル（貯水量しきい値表記）と早明浦ダム以外用の従来ラベル。
        XCTAssertTrue(scrollToStaticText("貯水率 80-100%", in: app).exists)
        XCTAssertTrue(scrollToStaticText("貯水量 80,000×10³m³以上", in: app).exists)
        XCTAssertTrue(scrollToStaticText("貯水量 60,000×10³m³以上80,000×10³m³未満", in: app).exists)
        XCTAssertTrue(scrollToStaticText("80-100%", in: app).exists)
        XCTAssertTrue(scrollToStaticText("0-20%", in: app).exists)

        // リセットボタンの文言。カスタム済みシナリオでは確認 alert が表示される。
        let resetButton = app.button("settings.resetOtherStorageRateMessages")
        XCTAssertTrue(scrollToElement(resetButton, in: app).exists)
        XCTAssertFalse(app.alerts["貯水率メッセージ"].exists)
    }

    func testJapaneseSettingsOtherStorageRateResetConfirmationAlert() throws {
        let app = launch(scenario: "otherStorageRateMessagesCustomized", language: "ja", locale: "ja_JP")
        openNavigationItem("nav.settings", in: app)
        XCTAssertTrue(app.element("settings.root").waitForExistence(timeout: 3))

        let resetButton = app.button("settings.resetOtherStorageRateMessages")
        XCTAssertTrue(scrollToElement(resetButton, in: app).exists)
        tapWhenHittable(resetButton, in: app)

        let alert = app.alerts["貯水率メッセージ"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        XCTAssertTrue(alert.staticTexts["全ての貯水率メッセージをリセットしますか？この操作は元に戻せません。"].exists)
        tapWhenHittable(alert.buttons["キャンセル"], in: app)
        XCTAssertTrue(alert.waitForNonExistence(timeout: 3))
    }

    func testHistoricalManageEmptyAndDeleteAll() throws {
        let emptyApp = launch(scenario: "historicalEmpty", language: "en", locale: "en_US")
        openNavigationItem("nav.historicalManage", in: emptyApp)
        XCTAssertTrue(emptyApp.element("historicalManage.root").waitForExistence(timeout: 3))
        XCTAssertTrue(emptyApp.element("historicalManage.empty").exists)

        let savedApp = launch(scenario: "historicalSaved", language: "en", locale: "en_US")
        openNavigationItem("nav.historicalManage", in: savedApp)
        XCTAssertTrue(savedApp.element("historicalManage.root").waitForExistence(timeout: 3))
        XCTAssertTrue(savedApp.element(containing: "historicalManage.row.").waitForExistence(timeout: 3))
        tapEdit(in: savedApp)
        tapWhenHittable(savedApp.element("historicalManage.deleteAll"), in: savedApp)
        tapWhenHittable(savedApp.button("historicalManage.deleteAll.confirm"), in: savedApp)
        openNavigationItem("nav.historicalManage", in: savedApp)
        XCTAssertTrue(savedApp.element("historicalManage.empty").waitForExistence(timeout: 3))
    }

    func testHistoricalManageRowTapOpensDisplay() throws {
        let app = launch(scenario: "historicalSaved", language: "en", locale: "en_US")
        openNavigationItem("nav.historicalManage", in: app)
        XCTAssertTrue(app.element("historicalManage.root").waitForExistence(timeout: 3))
        let row = app.element(containing: "historicalManage.row.")
        XCTAssertTrue(row.waitForExistence(timeout: 3))

        tapEdit(in: app)
        tapWhenHittable(row, in: app)
        XCTAssertTrue(app.element("historicalManage.root").waitForExistence(timeout: 3))
        XCTAssertFalse(app.element("dashboard.root").exists)

        tapEdit(in: app)
        tapWhenHittable(row, in: app)
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 5))
        XCTAssertFalse(app.element("historicalManage.root").exists)
    }

    func testErrorFirstLaunchAndDebugVisibility() throws {
        let firstLaunchApp = launch(scenario: "firstLaunch", language: "en", locale: "en_US")
        XCTAssertTrue(firstLaunchApp.alerts.firstMatch.waitForExistence(timeout: 8))
        firstLaunchApp.alerts.firstMatch.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(firstLaunchApp.element("dashboard.root").waitForExistence(timeout: 5))

        let errorApp = launch(scenario: "dashboardError", language: "en", locale: "en_US")
        XCTAssertTrue(errorApp.element("snackbar.message").waitForExistence(timeout: 8))

        let hiddenDebugApp = launch(scenario: "debugDisabled", language: "en", locale: "en_US")
        openMenuIfNeeded(in: hiddenDebugApp)
        XCTAssertFalse(hiddenDebugApp.element("nav.debug").exists)

        let debugApp = launch(scenario: "debugEnabled", language: "en", locale: "en_US")
        openNavigationItem("nav.debug", in: debugApp)
        XCTAssertTrue(debugApp.element("debug.root").waitForExistence(timeout: 3))
        XCTAssertTrue(debugApp.element("debug.mode").exists)
        XCTAssertTrue(debugApp.element("debug.log").exists)
        tapWhenHittable(debugApp.element("debug.disable"), in: debugApp)
        openMenuIfNeeded(in: debugApp)
        XCTAssertFalse(debugApp.element("nav.debug").exists)
    }

    func testJapaneseDashboardNavigationSmoke() throws {
        let app = launch(scenario: "dashboardLoaded", language: "ja", locale: "ja_JP")

        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 8))
        assertSummaryCardWhenVisible(in: app)
        XCTAssertTrue(app.element("dashboard.latestDataCard").exists)
        openNavigationItem("nav.settings", in: app)
        XCTAssertTrue(app.element("settings.root").waitForExistence(timeout: 3))
        tapBackIfCompact(in: app)
        openNavigationItem("nav.appInfo", in: app)
        XCTAssertTrue(app.element("appInfo.root").waitForExistence(timeout: 3))
    }

    func testCardTogglesOnlyFromGenerousIconTargetAndRestoresAfterNavigation() throws {
        let app = launch(scenario: "dashboardLoaded", language: "en", locale: "en_US")
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 8))
        let toggle = cardToggle("realtime.latest", in: app)
        tapWhenHittable(toggle, in: app, performTap: false)
        assertExpanded(toggle)
        XCTAssertGreaterThanOrEqual(toggle.frame.width, 44)
        XCTAssertGreaterThanOrEqual(toggle.frame.height, 44)

        let title = app.staticTexts["Latest Observation Data"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        title.tap()
        assertExpanded(toggle, "Tapping the card title must not toggle the card")

        if toggle.frame.minX - title.frame.maxX >= 12 {
            tapScreenPoint(
                x: (title.frame.maxX + toggle.frame.minX) / 2,
                y: toggle.frame.midY,
                in: app
            )
            assertExpanded(toggle, "Tapping the space between the title and icon must not toggle the card")
        }

        tapWhenHittable(toggle, in: app)
        assertCollapsed(toggle)
        openNavigationItem("nav.settings", in: app)
        XCTAssertTrue(app.element("settings.root").waitForExistence(timeout: 3))
        tapBackIfCompact(in: app)
        openNavigationItem("nav.realtime", in: app)
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 3))
        assertCollapsed(cardToggle("realtime.latest", in: app))
    }

    func testRealtimeAndHistoricalCardExpansionStatesRemainSeparate() throws {
        let app = launch(scenario: "historicalSaved", language: "en", locale: "en_US")
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 8))

        let realtimeObservation = cardToggle("realtime.observation", in: app)
        tapWhenHittable(realtimeObservation, in: app)
        assertCollapsed(realtimeObservation)

        openNavigationItem("nav.historicalSaved", in: app)
        let historicalObservation = cardToggle("historical.observation", in: app)
        XCTAssertTrue(
            historicalObservation.waitForExistence(timeout: 5),
            "The historical dashboard must replace the realtime dashboard"
        )
        tapWhenHittable(historicalObservation, in: app, performTap: false)
        assertExpanded(historicalObservation)
        let historicalHistory = cardToggle("historical.history", in: app)
        tapWhenHittable(historicalHistory, in: app)
        assertCollapsed(historicalHistory)

        openNavigationItem("nav.realtime", in: app)
        let restoredRealtimeObservation = cardToggle("realtime.observation", in: app)
        XCTAssertTrue(
            restoredRealtimeObservation.waitForExistence(timeout: 5),
            "The realtime dashboard must replace the historical dashboard"
        )
        assertCollapsed(restoredRealtimeObservation)
        let realtimeHistory = cardToggle("realtime.history", in: app)
        tapWhenHittable(realtimeHistory, in: app, performTap: false)
        assertExpanded(realtimeHistory)

        openNavigationItem("nav.historicalSaved", in: app)
        let restoredHistoricalHistory = cardToggle("historical.history", in: app)
        XCTAssertTrue(
            restoredHistoricalHistory.waitForExistence(timeout: 5),
            "The historical dashboard must replace the realtime dashboard"
        )
        assertCollapsed(restoredHistoricalHistory)
    }

    func testCardExpansionStateRestoresAfterTerminateAndRelaunch() throws {
        var app = launch(scenario: "dashboardLoaded", language: "en", locale: "en_US")
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 8))
        let toggle = cardToggle("realtime.latest", in: app)
        tapWhenHittable(toggle, in: app)
        assertCollapsed(toggle)
        app.terminate()

        app = launch(
            scenario: "dashboardLoaded",
            language: "en",
            locale: "en_US",
            preserveDefaults: true
        )
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 8))
        assertCollapsed(cardToggle("realtime.latest", in: app))
    }

    func testSameuraRealtimeGraphShowsFourModesWithDefaultModeOne() throws {
        let app = launch(scenario: "dashboardLoaded", language: "en", locale: "en_US")
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 8))

        let modeOne = app.button("graph.kind.rainfallStorage")
        XCTAssertTrue(scrollToElement(modeOne, in: app).exists)
        XCTAssertTrue(app.button("graph.kind.volumeFlow").exists)
        XCTAssertTrue(app.button("graph.kind.rainfallStorageHistory").exists)
        XCTAssertTrue(app.button("graph.kind.volumeFlowHistory").exists)
        XCTAssertTrue(modeOne.isSelected, "The default graph mode must be rainfall/storage")
        XCTAssertFalse(
            app.button("graph.year.all.storageRate").exists,
            "Year chips must be hidden while the default (non-history) mode is active"
        )
    }

    /// ライン切替チップ行が全4モードで表示され、モード別のチップ構成と初期の全選択状態を検証します。
    func testGraphLineChipRowsAcrossAllModes() throws {
        let app = launch(scenario: "dashboardLoaded", language: "en", locale: "en_US")
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 8))

        // mode 1(貯水率／流域平均雨量): 「貯水率」+「流域平均雨量」の2チップ。全選択が初期状態。
        let storageRate = app.button("graph.line.storageRate")
        XCTAssertTrue(scrollToElement(storageRate, in: app).isSelected)
        XCTAssertTrue(app.button("graph.line.rainfall").isSelected)
        XCTAssertFalse(app.button("graph.year.all.storageRate").exists, "mode 1 has no all-years chip")

        // mode 2(貯水量／流入量／放流量): 「貯水量」+「流入量」+「放流量」の3チップ。
        tapWhenHittable(app.button("graph.kind.volumeFlow"), in: app)
        XCTAssertTrue(app.button("graph.line.storageVolume").isSelected)
        XCTAssertTrue(app.button("graph.line.inflow").isSelected)
        XCTAssertTrue(app.button("graph.line.outflow").isSelected)

        // mode 3(貯水率(年比較)／流域平均雨量): 「貯水率全て」+2002..今年+「流域平均雨量」。
        // 「貯水率」単体チップは無く、全てチップは貯水率用の1つのみ。
        tapWhenHittable(app.button("graph.kind.rainfallStorageHistory"), in: app)
        let allRate = app.button("graph.year.all.storageRate")
        XCTAssertTrue(scrollToElement(allRate, in: app).isSelected)
        XCTAssertTrue(scrollToElement(app.button("graph.year.2002"), in: app).isSelected)
        XCTAssertTrue(scrollToElement(app.button("graph.year.2026"), in: app).isSelected, "The current year chip must exist in mode 3")
        XCTAssertTrue(app.button("graph.line.rainfall").isSelected)
        XCTAssertFalse(app.button("graph.line.storageRate").exists, "mode 3 has no standalone storage-rate chip")
        XCTAssertFalse(app.button("graph.year.all.storageVolume").exists, "mode 3 has only the storage-rate all chip")

        // mode 4(貯水量(年比較)／流入量／放流量): 「貯水量全て」+2002..今年+「流入量」+「放流量」。
        // 「貯水量」単体チップは無く、全てチップは貯水量用の1つのみ。
        tapWhenHittable(app.button("graph.kind.volumeFlowHistory"), in: app)
        let allVolume = app.button("graph.year.all.storageVolume")
        XCTAssertTrue(scrollToElement(allVolume, in: app).isSelected)
        XCTAssertTrue(scrollToElement(app.button("graph.year.2002"), in: app).isSelected)
        XCTAssertTrue(scrollToElement(app.button("graph.year.2026"), in: app).isSelected, "The current year chip must exist in mode 4")
        XCTAssertTrue(app.button("graph.line.inflow").isSelected)
        XCTAssertTrue(app.button("graph.line.outflow").isSelected)
        XCTAssertFalse(app.button("graph.line.storageVolume").exists, "mode 4 has no standalone storage-volume chip")
        XCTAssertFalse(app.button("graph.year.all.storageRate").exists, "mode 4 has only the storage-volume all chip")
    }

    /// 今年チップが存在し、今年のラインを個別に切替できることを検証します。
    func testCurrentYearChipTogglesCurrentYearLine() throws {
        let app = launch(scenario: "dashboardLoaded", language: "en", locale: "en_US")
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 8))

        tapWhenHittable(app.button("graph.kind.rainfallStorageHistory"), in: app)
        let year2026 = app.button("graph.year.2026")
        let allChip = app.button("graph.year.all.storageRate")
        XCTAssertTrue(scrollToElement(year2026, in: app).isSelected, "The current year must be selected initially")

        // 今年チップを外すと今年のラインが切替わり、Allチップも未選択状態になる。
        tapWhenHittable(scrollToElement(year2026, in: app), in: app)
        XCTAssertFalse(year2026.isSelected)
        XCTAssertFalse(allChip.isSelected, "Deselecting the current year must deselect the all chip")

        // 再選択するとAllチップも全選択状態へ戻る。
        tapWhenHittable(scrollToElement(year2026, in: app), in: app)
        XCTAssertTrue(year2026.isSelected)
        XCTAssertTrue(allChip.isSelected)

        // 今年を外しても他の過去年チップの選択状態は変わらない。
        tapWhenHittable(scrollToElement(year2026, in: app), in: app)
        XCTAssertFalse(year2026.isSelected)
        XCTAssertTrue(scrollToElement(app.button("graph.year.2002"), in: app).isSelected)
    }

    /// ライン切替チップ行がグラフ本体の直下・期間チップの上に表示されることを検証します。
    func testLineChipRowPositionBelowGraphAboveRangeChips() throws {
        let app = launch(scenario: "dashboardLoaded", language: "en", locale: "en_US")
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 8))

        // mode 1: ライン切替チップ行はグラフ本体(キャンバス)の直下・期間チップの上に表示される。
        let chart = app.otherElements
            .matching(NSPredicate(format: "label == %@", "Storage Rate / Catchment Rainfall"))
            .firstMatch
        XCTAssertTrue(chart.waitForExistence(timeout: 10))
        let lineChip = app.button("graph.line.storageRate")
        let rangeChip = app.button("graph.range.all")
        XCTAssertTrue(lineChip.exists)
        XCTAssertTrue(rangeChip.exists)
        XCTAssertGreaterThanOrEqual(lineChip.frame.minY, chart.frame.maxY - 1, "The line chip row must sit directly below the chart")
        XCTAssertLessThanOrEqual(lineChip.frame.maxY, rangeChip.frame.minY + 1, "The line chip row must sit above the range chips")

        // mode 3: 全対象年チップ+年チップ+ライン切替チップの行も同じ位置に表示される。
        tapWhenHittable(app.button("graph.kind.rainfallStorageHistory"), in: app)
        let allChip = app.button("graph.year.all.storageRate")
        XCTAssertTrue(allChip.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(allChip.frame.minY, chart.frame.maxY - 1, "The combined chip row must sit directly below the chart")
        XCTAssertLessThanOrEqual(allChip.frame.maxY, rangeChip.frame.minY + 1, "The combined chip row must sit above the range chips")
    }

    /// iPhone compact のライン切替チップ行の横スクロールを検証します。
    /// 非履歴modeは専用の1行(graph.line.scroll)、履歴modeは全対象年チップ+年チップ+
    /// ライン切替チップが一体の行(graph.year.scroll)になり、末尾のライン切替チップへ
    /// 横スクロールで到達して切替できることを確認します。
    func testPhoneLineChipRowScrollableSingleLine() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "compact line chip rows are iPhone-only")
        let app = launch(scenario: "dashboardLoaded", language: "en", locale: "en_US")
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 8))

        // mode 1: ライン切替チップは専用の1行横スクロール列(graph.line.scroll)に並ぶ。
        let lineRow = app.scrollViews["graph.line.scroll"]
        XCTAssertTrue(lineRow.waitForExistence(timeout: 3))
        let storageRate = app.button("graph.line.storageRate")
        XCTAssertTrue(storageRate.waitForExistence(timeout: 3))
        _ = scrollChipRowTo(storageRate, in: app)
        XCTAssertTrue(storageRate.isHittable)
        XCTAssertFalse(app.scrollViews["graph.year.scroll"].exists, "mode 1 has no year chip row")

        // mode 3: 一体の行(graph.year.scroll)になり、末尾の「流域平均雨量」チップへ横スクロールで到達できる。
        tapWhenHittable(app.button("graph.kind.rainfallStorageHistory"), in: app)
        let yearRow = app.scrollViews["graph.year.scroll"]
        XCTAssertTrue(yearRow.waitForExistence(timeout: 3))
        XCTAssertFalse(app.scrollViews["graph.line.scroll"].exists, "mode 3 uses the combined graph.year.scroll row")
        let rainfall = app.button("graph.line.rainfall")
        XCTAssertTrue(rainfall.exists)
        XCTAssertFalse(rainfall.isHittable, "The trailing line chip must be offscreen on iPhone")
        _ = scrollChipRowTo(rainfall, in: app)
        let fadeTrailing = app.descendants(matching: .any)["graph.year.fade.trailing"]
        XCTAssertTrue(fadeTrailing.waitForNonExistence(timeout: 2), "The combined row must reach the trailing edge")
        tapWhenHittable(rainfall, in: app)
        XCTAssertFalse(rainfall.isSelected, "Tapping the rainfall chip must deselect the line")
        tapWhenHittable(rainfall, in: app)
        XCTAssertTrue(rainfall.isSelected, "Re-tapping the rainfall chip must restore the line")
    }

    /// 過去データ検索結果(早明浦)のグラフCardが4mode・ライン切替チップ・年チップを提供し、
    /// 表示対象データの年のチップが主系列線を切替えることを検証します。
    func testHistoricalSearchGraphCardHasLineChips() throws {
        let app = launch(scenario: "historicalSaved", language: "en", locale: "en_US")
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 8))
        openNavigationItem("nav.historicalSaved", in: app)
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 5))

        // 早明浦の通常の過去データ表示はリアルタイムと同じ4mode。
        XCTAssertTrue(app.button("graph.kind.rainfallStorage").exists)
        XCTAssertTrue(app.button("graph.kind.volumeFlow").exists)
        XCTAssertTrue(app.button("graph.kind.rainfallStorageHistory").exists)
        XCTAssertTrue(app.button("graph.kind.volumeFlowHistory").exists)

        // mode 1/2 にもライン切替チップが常時表示される。
        let storageRate = app.button("graph.line.storageRate")
        XCTAssertTrue(scrollToElement(storageRate, in: app).exists)
        XCTAssertTrue(storageRate.isSelected)
        XCTAssertTrue(app.button("graph.line.rainfall").isSelected)

        tapWhenHittable(app.button("graph.kind.volumeFlow"), in: app)
        XCTAssertTrue(app.button("graph.line.storageVolume").isSelected)
        XCTAssertTrue(app.button("graph.line.inflow").isSelected)
        XCTAssertTrue(app.button("graph.line.outflow").isSelected)

        // ライン切替チップを外すと選択状態が連動する。
        tapWhenHittable(app.button("graph.line.inflow"), in: app)
        XCTAssertFalse(app.button("graph.line.inflow").isSelected)

        // mode 3: 全対象年チップ+年チップ。表示対象データの年(2026)チップが主系列線を切替える。
        tapWhenHittable(app.button("graph.kind.rainfallStorageHistory"), in: app)
        let allChip = app.button("graph.year.all.storageRate")
        XCTAssertTrue(scrollToElement(allChip, in: app).exists)
        XCTAssertTrue(allChip.isSelected)
        let year2026 = app.button("graph.year.2026")
        XCTAssertTrue(scrollToElement(year2026, in: app).isSelected)

        tapWhenHittable(year2026, in: app)
        XCTAssertFalse(year2026.isSelected, "The displayed year chip must toggle the main line")
        XCTAssertFalse(allChip.isSelected, "Deselecting the displayed year must deselect all")

        tapWhenHittable(year2026, in: app)
        XCTAssertTrue(year2026.isSelected)
        XCTAssertTrue(allChip.isSelected, "Re-selecting the displayed year must restore the all-selected state")
    }

    func testHistoricalGraphYearChipsSelectionSharingAndAllToggle() throws {
        let app = launch(scenario: "dashboardLoaded", language: "en", locale: "en_US")
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 8))

        tapWhenHittable(app.button("graph.kind.rainfallStorageHistory"), in: app)

        let allChip = app.button("graph.year.all.storageRate")
        XCTAssertTrue(scrollToElement(allChip, in: app).exists)
        let year2002 = app.button("graph.year.2002")
        let year2025 = app.button("graph.year.2025")
        let year2026 = app.button("graph.year.2026")
        XCTAssertTrue(scrollToElement(year2002, in: app).isSelected)
        XCTAssertTrue(scrollToElement(year2025, in: app).isSelected)
        XCTAssertTrue(year2026.isSelected, "The current year must be selected initially")
        XCTAssertTrue(allChip.isSelected)

        tapWhenHittable(allChip, in: app)
        XCTAssertFalse(allChip.isSelected, "All chip must reflect the deselected-all state")
        XCTAssertFalse(scrollToElement(year2002, in: app).isSelected)
        XCTAssertFalse(scrollToElement(year2025, in: app).isSelected)
        XCTAssertFalse(year2026.isSelected, "The all toggle must also deselect the current year")

        tapWhenHittable(allChip, in: app)
        XCTAssertTrue(allChip.isSelected)
        XCTAssertTrue(scrollToElement(year2002, in: app).isSelected)
        XCTAssertTrue(scrollToElement(year2025, in: app).isSelected)
        XCTAssertTrue(year2026.isSelected, "The all toggle must also select the current year")

        tapWhenHittable(scrollToElement(year2002, in: app), in: app)
        XCTAssertFalse(year2002.isSelected)
        XCTAssertFalse(allChip.isSelected, "All chip must not be selected while a year is deselected")

        tapWhenHittable(scrollToElement(year2002, in: app), in: app)
        XCTAssertTrue(year2002.isSelected)
        XCTAssertTrue(allChip.isSelected, "Selecting the last unselected year must restore the all-selected state")

        // mode 3 → 4 で年選択を共有する。2002 を解除した状態で mode 4 へ切り替える。
        tapWhenHittable(scrollToElement(year2002, in: app), in: app)
        XCTAssertFalse(year2002.isSelected)
        tapWhenHittable(app.button("graph.kind.volumeFlowHistory"), in: app)
        XCTAssertFalse(scrollToElement(year2002, in: app).isSelected, "The deselected year must stay deselected across history modes")
        XCTAssertTrue(scrollToElement(year2025, in: app).isSelected, "The selected year must stay selected across history modes")
        XCTAssertFalse(app.button("graph.year.all.storageVolume").isSelected, "mode 4 must share the deselected state with its all chip")
    }

    func testPhoneCompactYearChipsSingleLineWithIntegratedAllAndLeadingStart() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "compact year-chip row is iPhone-only")
        let app = launch(scenario: "dashboardLoaded", language: "en", locale: "en_US")
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 8))
        tapWhenHittable(app.button("graph.kind.rainfallStorageHistory"), in: app)

        // iPhoneでは年チップが全対象年チップ+年チップ+ライン切替チップの1行横スクロール列になり、
        // 「貯水率全て」チップも他の年チップと一緒にスクロールする。
        let yearRow = app.scrollViews["graph.year.scroll"]
        XCTAssertTrue(yearRow.waitForExistence(timeout: 3))
        let allChip = app.button("graph.year.all.storageRate")
        XCTAssertTrue(allChip.exists)

        // チップ行はグラフ直下に移ったため、mode切替直後は画面外(下)にいることがある。
        // isHittableは信頼できないので、エッジフェードの有無から先頭/末尾を判定する。
        // 初期表示は先頭(左端)。右端フェードのみ表示され、左端フェードは表示されない。
        let year2025 = app.button("graph.year.2025")
        let fadeLeading = app.descendants(matching: .any)["graph.year.fade.leading"]
        let fadeTrailing = app.descendants(matching: .any)["graph.year.fade.trailing"]
        XCTAssertTrue(fadeTrailing.waitForExistence(timeout: 3))
        XCTAssertTrue(fadeLeading.waitForNonExistence(timeout: 1))

        // 横スクロール(必要なら縦スクロール)で直近の年へ到達でき、スクロール後は
        // 左端フェードが表示される。
        _ = scrollChipRowTo(year2025, in: app)
        XCTAssertTrue(fadeLeading.waitForExistence(timeout: 3))

        // スクロール列が右端まで到達すると右端フェードは表示されない。
        XCTAssertTrue(fadeTrailing.waitForNonExistence(timeout: 2))
    }

    func testPadYearChipRowSingleLineScrollable() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "single-line year chip row is iPad-only")
        let app = launch(scenario: "dashboardLoaded", language: "en", locale: "en_US")
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 8))
        tapWhenHittable(app.button("graph.kind.rainfallStorageHistory"), in: app)

        // iPadOSでも履歴モードの年チップは「全て」+年チップ+ライン切替チップが一体の
        // 1行横スクロール列(graph.year.scroll)に並び、縦方向の折返しはしない。
        let yearRow = app.scrollViews["graph.year.scroll"]
        XCTAssertTrue(yearRow.waitForExistence(timeout: 3))
        XCTAssertTrue(app.button("graph.year.all.storageRate").exists)

        // 直近の年チップへ横スクロールで到達できる(選択状態を維持している)。
        let year2026 = app.button("graph.year.2026")
        XCTAssertTrue(year2026.exists)
        _ = scrollChipRowTo(year2026, in: app)
        XCTAssertTrue(year2026.isSelected, "The current-year chip must be reachable by horizontal scrolling")
    }

    func testPhoneYearScrollPositionKeptAcrossHistoryModesAndCollapse() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "compact year-chip row is iPhone-only")
        let app = launch(scenario: "dashboardLoaded", language: "en", locale: "en_US")
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 8))
        tapWhenHittable(app.button("graph.kind.rainfallStorageHistory"), in: app)

        let yearRow = app.scrollViews["graph.year.scroll"]
        XCTAssertTrue(yearRow.waitForExistence(timeout: 3))

        // 右端(直近の年)までスクロールする。
        let year2025 = app.button("graph.year.2025")
        let fadeLeading = app.descendants(matching: .any)["graph.year.fade.leading"]
        let fadeTrailing = app.descendants(matching: .any)["graph.year.fade.trailing"]
        _ = scrollChipRowTo(year2025, in: app)
        XCTAssertTrue(fadeLeading.waitForExistence(timeout: 3))
        XCTAssertTrue(fadeTrailing.waitForNonExistence(timeout: 1))

        // mode 3 → 4 切替でもスクロール位置を維持する(先頭へ戻らない)。
        // mode 4の行は「貯水量全て+2002〜今年+流入量+放流量」でmode 3の行より長いため、
        // 末尾到達はmode 4側で再度行う。
        tapWhenHittable(app.button("graph.kind.volumeFlowHistory"), in: app)
        XCTAssertTrue(fadeLeading.waitForExistence(timeout: 3))
        _ = scrollChipRowTo(app.button("graph.line.outflow"), in: app)
        XCTAssertTrue(fadeLeading.waitForExistence(timeout: 3))
        XCTAssertTrue(fadeTrailing.waitForNonExistence(timeout: 1))

        // Cardを閉じて開いてもスクロール位置を維持する(末尾のまま)。
        let toggle = cardToggle("realtime.graph", in: app)
        tapWhenHittable(toggle, in: app)
        XCTAssertTrue(yearRow.waitForNonExistence(timeout: 3))
        tapWhenHittable(toggle, in: app)
        XCTAssertTrue(yearRow.waitForExistence(timeout: 3))
        XCTAssertTrue(fadeLeading.waitForExistence(timeout: 3))
        XCTAssertTrue(fadeTrailing.waitForNonExistence(timeout: 1))
    }

    func testPhoneChipRowGapsMatchRangeToCrosshairGap() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "iPhone-only")
        let app = launch(scenario: "dashboardLoaded", language: "en", locale: "en_US")
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 8))

        // 基準間隔: 期間チップ行(全期間)と「タップ/ドラッグで値を表示する」行の
        // チップ間の縦間隔。ライン切替チップ行(グラフ直下)と期間チップ行も同間隔になる。
        let lineChip = app.button("graph.line.storageRate")
        let rangeChip = app.button("graph.range.all")
        let crosshair = app.button("graph.crosshair")
        XCTAssertTrue(lineChip.waitForExistence(timeout: 5))
        XCTAssertTrue(rangeChip.exists)
        XCTAssertTrue(crosshair.exists)
        let referenceGap = crosshair.frame.minY - (rangeChip.frame.minY + rangeChip.frame.height)

        // 非履歴mode: ライン切替チップ行と期間チップ行のチップ間の縦間隔が基準と一致する。
        let lineRangeGap = rangeChip.frame.minY - (lineChip.frame.minY + lineChip.frame.height)
        XCTAssertEqual(
            referenceGap,
            lineRangeGap,
            accuracy: 1,
            "ライン切替チップ行と期間チップ行のチップ間の縦間隔は期間行と「タップ/ドラッグ」行の間隔と一致すること"
        )

        // 履歴mode: 全対象年チップ+年チップ+ライン切替チップが同じ行に並び、行全体として
        // 期間チップ行との間隔が基準と一致する。
        tapWhenHittable(app.button("graph.kind.rainfallStorageHistory"), in: app)
        let allChip = app.button("graph.year.all.storageRate")
        XCTAssertTrue(allChip.waitForExistence(timeout: 5))
        let historyLineRangeGap = rangeChip.frame.minY - (allChip.frame.minY + allChip.frame.height)
        XCTAssertEqual(
            referenceGap,
            historyLineRangeGap,
            accuracy: 1,
            "履歴modeのチップ行と期間チップ行のチップ間の縦間隔も基準と一致すること"
        )
    }

    func testPhoneCompactModeAndRangeChipsScrollableSingleLine() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "compact chip rows are iPhone-only")
        let app = launch(scenario: "graphPerfBaseline", language: "en", locale: "en_US")
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 8))

        // iPhoneではモードチップが1行横スクロール列になり、末尾の履歴モードチップへ
        // スクロールして選択できる。
        let modeRow = app.scrollViews["graph.mode.scroll"]
        XCTAssertTrue(modeRow.waitForExistence(timeout: 3))
        let historyMode = app.button("graph.kind.volumeFlowHistory")
        XCTAssertFalse(historyMode.isHittable, "The last mode chip must be offscreen on iPhone")
        // 先頭では右端フェードのみ表示される。
        let modeFadeLeading = app.descendants(matching: .any)["graph.mode.fade.leading"]
        let modeFadeTrailing = app.descendants(matching: .any)["graph.mode.fade.trailing"]
        XCTAssertTrue(modeFadeTrailing.waitForExistence(timeout: 3))
        XCTAssertTrue(modeFadeLeading.waitForNonExistence(timeout: 1))
        _ = revealHorizontalChip(historyMode, in: app)
        XCTAssertTrue(historyMode.isHittable)
        tapWhenHittable(historyMode, in: app)
        XCTAssertTrue(historyMode.isSelected)
        // 右方向へスクロールすると左端フェードが表示される。
        XCTAssertTrue(modeFadeLeading.waitForExistence(timeout: 3))

        // 期間チップも1行横スクロール列になり、末尾の期間チップへスクロールして選択できる。
        let rangeRow = app.scrollViews["graph.range.scroll"]
        XCTAssertTrue(rangeRow.waitForExistence(timeout: 3))
        let lastRange = app.button("graph.range.past24Hours")
        XCTAssertFalse(lastRange.isHittable, "The last range chip must be offscreen on iPhone")
        let rangeFadeLeading = app.descendants(matching: .any)["graph.range.fade.leading"]
        let rangeFadeTrailing = app.descendants(matching: .any)["graph.range.fade.trailing"]
        XCTAssertTrue(rangeFadeTrailing.waitForExistence(timeout: 3))
        _ = revealHorizontalChip(lastRange, in: app)
        XCTAssertTrue(lastRange.isHittable)
        tapWhenHittable(lastRange, in: app)
        XCTAssertTrue(lastRange.isSelected)
        XCTAssertTrue(rangeFadeLeading.waitForExistence(timeout: 3))

        // クロスヘアチップは期間チップのスクロール列の外に別行固定され、列をスクロール
        // しても表示されたまま。
        XCTAssertTrue(app.button("graph.crosshair").isHittable)
    }

    func testPhoneModeScrollPositionKeptAcrossGraphTypesAndCollapse() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "compact mode-chip row is iPhone-only")
        let app = launch(scenario: "dashboardLoaded", language: "en", locale: "en_US")
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 8))

        let modeRow = app.scrollViews["graph.mode.scroll"]
        XCTAssertTrue(modeRow.waitForExistence(timeout: 3))

        // 末尾(履歴モードチップ)までスクロールする。末尾到達後は先頭の rainfallStorage は
        // スクロール位置に関係なく画面外になるため、位置維持の検証が決定的になる。
        let historyMode = app.button("graph.kind.volumeFlowHistory")
        _ = revealHorizontalChip(historyMode, in: app)
        XCTAssertTrue(historyMode.isHittable)

        // mode切替でもスクロール位置を維持する。位置維持なら先頭の rainfallStorage は
        // 画面外のまま(先頭へ戻ると可視になる)。
        tapWhenHittable(app.button("graph.kind.volumeFlowHistory"), in: app)
        let rainfallStorage = app.button("graph.kind.rainfallStorage")
        XCTAssertFalse(rainfallStorage.isHittable, "Mode chip row must keep its scroll position across graph type changes")

        // Cardを閉じて開いてもスクロール位置を維持する。
        let toggle = cardToggle("realtime.graph", in: app)
        tapWhenHittable(toggle, in: app)
        XCTAssertTrue(modeRow.waitForNonExistence(timeout: 3))
        tapWhenHittable(toggle, in: app)
        let volumeFlowHistory = app.button("graph.kind.volumeFlowHistory")
        XCTAssertTrue(volumeFlowHistory.waitForExistence(timeout: 3))
        XCTAssertTrue(volumeFlowHistory.isHittable)
        XCTAssertFalse(rainfallStorage.isHittable, "Mode chip row must keep its scroll position across collapse")
    }

    func testPhoneRangeScrollPositionKeptAcrossGraphTypesAndResetOnCollapse() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "compact range-chip row is iPhone-only")
        let app = launch(scenario: "graphPerfBaseline", language: "en", locale: "en_US")
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 8))

        let rangeRow = app.scrollViews["graph.range.scroll"]
        XCTAssertTrue(rangeRow.waitForExistence(timeout: 3))

        // 右端(過去24時間)までスクロールする。
        let past24 = app.button("graph.range.past24Hours")
        _ = revealHorizontalChip(past24, in: app)
        XCTAssertTrue(past24.isHittable)

        // mode切替でも期間チップのスクロール位置を維持する。切替でグラフの高さが変わり
        // 期間チップ列が縦方向に画面外へ移動するため、縦スクロールで表示してから確認する
        // (横スクロールはせず、位置維持なら過去24時間チップがそのまま可視になる)。
        tapWhenHittable(app.button("graph.kind.volumeFlow"), in: app)
        var retry = 0
        while retry < 6 && !past24.isHittable {
            app.swipeUp()
            retry += 1
            usleep(300_000)
        }
        XCTAssertTrue(past24.isHittable, "Range chip row must keep its scroll position across graph type changes")

        // Cardを閉じて開くと期間が全期間へ戻り、期間チップ列も先頭へ戻る。
        let toggle = cardToggle("realtime.graph", in: app)
        tapWhenHittable(toggle, in: app)
        XCTAssertTrue(rangeRow.waitForNonExistence(timeout: 3))
        tapWhenHittable(toggle, in: app)
        let fullRange = app.button("graph.range.all")
        XCTAssertTrue(fullRange.waitForExistence(timeout: 3))
        retry = 0
        while retry < 6 && !fullRange.isHittable {
            app.swipeUp()
            retry += 1
            usleep(300_000)
        }
        XCTAssertTrue(fullRange.isHittable)
        XCTAssertFalse(past24.isHittable, "Range chip row must reset to the leading edge after collapse")
    }

    func testPadModeAndRangeChipsSingleLineScrollable() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "single-line chip rows are iPad-only")
        let app = launch(scenario: "graphPerfBaseline", language: "en", locale: "en_US")
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 8))

        // iPadOSでもモードチップ・期間チップは1行横スクロール列に並び、縦方向の折返しはしない。
        let modeRow = app.scrollViews["graph.mode.scroll"]
        XCTAssertTrue(modeRow.waitForExistence(timeout: 3))
        XCTAssertEqual(
            app.buttons
                .matching(NSPredicate(format: "identifier BEGINSWITH %@", "graph.kind."))
                .count,
            4,
            "All four mode chips must be present in the single-line mode row"
        )
        let rangeRow = app.scrollViews["graph.range.scroll"]
        XCTAssertTrue(rangeRow.waitForExistence(timeout: 3))
        XCTAssertTrue(app.button("graph.range.all").exists)

        // 「タップ/ドラッグで値を表示する」チップは期間チップのスクロール列の外に別行固定され、
        // 期間チップ列と統合されない。
        XCTAssertFalse(app.scrollViews["graph.range.scroll"].buttons["graph.crosshair"].exists)
        XCTAssertTrue(app.button("graph.crosshair").exists)
    }

    func testNonSameuraAndHistoricalDashboardsKeepTwoGraphModes() throws {
        let otherDamApp = launch(scenario: "otherDamDashboard", language: "en", locale: "en_US")
        XCTAssertTrue(otherDamApp.element("dashboard.root").waitForExistence(timeout: 8))
        XCTAssertTrue(scrollToElement(otherDamApp.button("graph.kind.rainfallStorage"), in: otherDamApp).exists)
        XCTAssertTrue(otherDamApp.button("graph.kind.volumeFlow").exists)
        XCTAssertFalse(otherDamApp.button("graph.kind.rainfallStorageHistory").exists)
        XCTAssertFalse(otherDamApp.button("graph.kind.volumeFlowHistory").exists)

        // 早明浦の通常の過去データ表示はリアルタイムと同じ4modeを提供する。
        let savedApp = launch(scenario: "historicalSaved", language: "en", locale: "en_US")
        XCTAssertTrue(savedApp.element("dashboard.root").waitForExistence(timeout: 8))
        openNavigationItem("nav.historicalSaved", in: savedApp)
        XCTAssertTrue(savedApp.element("dashboard.root").waitForExistence(timeout: 5))
        XCTAssertTrue(scrollToElement(savedApp.button("graph.kind.rainfallStorage"), in: savedApp).exists)
        XCTAssertTrue(savedApp.button("graph.kind.volumeFlow").exists)
        XCTAssertTrue(savedApp.button("graph.kind.rainfallStorageHistory").exists)
        XCTAssertTrue(savedApp.button("graph.kind.volumeFlowHistory").exists)
    }

    func testHistoricalComparisonLoadingAndErrorWithRetry() throws {
        let app = launch(scenario: "graphComparisonError", language: "en", locale: "en_US")
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 8))

        tapWhenHittable(app.button("graph.kind.rainfallStorageHistory"), in: app)
        XCTAssertTrue(app.element("graph.historicalLoading").waitForExistence(timeout: 2))
        XCTAssertTrue(app.element("graph.historicalError").waitForExistence(timeout: 6))

        let retry = app.button("graph.historicalRetry")
        XCTAssertTrue(retry.exists)
        tapWhenHittable(retry, in: app)
        XCTAssertTrue(app.element("graph.historicalLoading").waitForExistence(timeout: 2))
        XCTAssertTrue(app.element("graph.historicalError").waitForExistence(timeout: 6))
    }

    /// グラフ操作(モード/範囲/年チップ、十字線ドラッグ)のパフォーマンス計測用シナリオ。
    /// 計測はsignpostで外部実施されるため、タイミング厳格なassertは行わない。
    func testGraphPerfBaselineScenario() throws {
        let app = launch(scenario: "graphPerfBaseline", language: "en", locale: "en_US")
        let rainfallStorage = app.button("graph.kind.rainfallStorage")
        XCTAssertTrue(rainfallStorage.waitForExistence(timeout: 30))

        for rangeID in ["graph.range.past24Hours", "graph.range.past48Hours", "graph.range.past72Hours", "graph.range.all"] {
            let rangeChip = app.button(rangeID)
            XCTAssertTrue(scrollToElement(rangeChip, in: app).exists)
            tapWhenHittable(rangeChip, in: app)
            usleep(500_000)
        }

        tapWhenHittable(app.button("graph.kind.volumeFlow"), in: app)
        usleep(500_000)
        tapWhenHittable(app.button("graph.kind.rainfallStorage"), in: app)

        tapWhenHittable(app.button("graph.kind.rainfallStorageHistory"), in: app)
        let allChip = app.button("graph.year.all.storageRate")
        XCTAssertTrue(scrollToElement(allChip, in: app).exists)
        tapWhenHittable(allChip, in: app)
        usleep(500_000)
        let year2002 = app.button("graph.year.2002")
        XCTAssertTrue(scrollToElement(year2002, in: app).exists)
        tapWhenHittable(year2002, in: app)
        usleep(500_000)
        tapWhenHittable(allChip, in: app)

        tapWhenHittable(app.button("graph.kind.volumeFlowHistory"), in: app)
        XCTAssertTrue(scrollToElement(app.button("graph.year.all.storageVolume"), in: app).exists)
        tapWhenHittable(app.button("graph.kind.rainfallStorage"), in: app)

        let crosshair = app.button("graph.crosshair")
        XCTAssertTrue(scrollToElement(crosshair, in: app).exists)
        tapWhenHittable(crosshair, in: app)

        let chart = app.otherElements
            .matching(NSPredicate(format: "label == %@", "Storage Rate / Catchment Rainfall"))
            .firstMatch
        XCTAssertTrue(chart.waitForExistence(timeout: 10))
        let chartFrame = chart.frame
        XCTAssertGreaterThan(chartFrame.width, 0)
        let dragStart = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5))
        let stepX = chartFrame.width * 0.7 / 50
        var dragPoint = dragStart
        for step in 1...50 {
            let next = dragStart.withOffset(CGVector(dx: stepX * CGFloat(step), dy: 0))
            dragPoint.press(forDuration: 0.05, thenDragTo: next)
            dragPoint = next
            usleep(50_000)
        }

        tapWhenHittable(crosshair, in: app)
        XCTAssertTrue(rainfallStorage.exists)
    }

    /// 十字線のON/OFF・タップ・ドラッグ操作のインタラクション検証。
    /// タイミング厳格なassertは行わない(性能計測はsignpostで外部実施される)。
    func testGraphCrosshairInteraction() throws {
        let app = launch(scenario: "graphPerfBaseline", language: "en", locale: "en_US")
        let rainfallStorage = app.button("graph.kind.rainfallStorage")
        XCTAssertTrue(rainfallStorage.waitForExistence(timeout: 30))

        let crosshair = app.button("graph.crosshair")
        XCTAssertTrue(scrollToElement(crosshair, in: app).exists)
        XCTAssertFalse(crosshair.isSelected, "The crosshair must start disabled")

        // crosshair OFF時: ダッシュボードのスクロールが成立する。
        app.swipeUp()
        usleep(300_000)
        app.swipeDown()
        XCTAssertTrue(rainfallStorage.exists, "The dashboard must stay scrollable with the crosshair disabled")

        let chart = app.otherElements
            .matching(NSPredicate(format: "label == %@", "Storage Rate / Catchment Rainfall"))
            .firstMatch
        XCTAssertTrue(chart.waitForExistence(timeout: 10))
        let chartFrame = chart.frame
        XCTAssertGreaterThan(chartFrame.width, 0)

        // crosshair ON: チャート上のタップで選択が追従する。
        tapWhenHittable(crosshair, in: app)
        XCTAssertTrue(crosshair.isSelected)

        let tapPoint = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
        tapPoint.tap()
        usleep(200_000)
        XCTAssertTrue(crosshair.isSelected)

        // 短いドラッグを繰り返してもクラッシュせず、drag endで選択は消去される。
        let dragStart = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5))
        let stepX = chartFrame.width * 0.7 / 30
        var dragPoint = dragStart
        for step in 1...30 {
            let next = dragStart.withOffset(CGVector(dx: stepX * CGFloat(step), dy: 0))
            dragPoint.press(forDuration: 0.05, thenDragTo: next)
            dragPoint = next
            usleep(50_000)
        }
        usleep(200_000)
        let freshChart = app.otherElements
            .matching(NSPredicate(format: "label == %@", "Storage Rate / Catchment Rainfall"))
            .firstMatch
        XCTAssertTrue(freshChart.exists, "The chart must survive crosshair drags")
        XCTAssertTrue(app.button("graph.crosshair").exists)

        // 別のポイントへタップしてからOFFへ戻す。
        let secondTap = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5))
        secondTap.tap()
        usleep(200_000)
        tapWhenHittable(app.button("graph.crosshair"), in: app)
        XCTAssertFalse(app.button("graph.crosshair").isSelected, "The crosshair must turn off")

        // 履歴モード読み込み中も十字線chipは表示されたままである(loadingは一瞬のためtolerant)。
        tapWhenHittable(app.button("graph.kind.rainfallStorageHistory"), in: app)
        let loading = app.element("graph.historicalLoading")
        if loading.waitForExistence(timeout: 1) {
            XCTAssertTrue(app.button("graph.crosshair").exists, "The crosshair chip must remain while loading")
        }
    }

    /// サイドバー/メニューの sudmonitor 日次過去データ常設エントリ(3行構成)を検証します。
    /// Phase 5で「過去データ(日次)更新」セクションが廃止されたため、更新行が存在しないことも
    /// あわせて確認します(更新操作は日次表示画面のtoolbarアイコンで行う)。
    func testDailyHistorySidebarEntry() throws {
        let app = launch(scenario: "dailyHistoryLoaded", language: "ja", locale: "ja_JP")
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 8))
        openMenuIfNeeded(in: app)

        let entry = app.element("nav.sudmonitorHistory")
        XCTAssertTrue(entry.waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["過去データ(日次)更新"].exists)
        XCTAssertFalse(app.element("nav.sudmonitorHistoryAutoUpdate").exists)
        XCTAssertFalse(app.element("nav.sudmonitorHistoryManualUpdate").exists)

        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPadOS のサイドバー行は結合ラベルに3行(ダム名 / 期間 / 貯水率要約)を含む。
            XCTAssertTrue(entry.label.contains("早明浦ダム"))
            XCTAssertTrue(entry.label.contains("2026/06/01 01:00 - 2026/07/01 00:00"))
            XCTAssertTrue(entry.label.contains("81.00% → 82.00%"))
        }

        // エントリ選択で日次表示画面へ遷移できる。
        tapWhenHittable(entry, in: app)
        XCTAssertTrue(app.navigationBars["過去データ(日次)表示"].waitForExistence(timeout: 5))
    }

    /// 日次表示画面のタイトル・期間指定アイコン・自動更新/手動更新アイコンを検証します。
    func testDailyHistoryDisplayScreenTitleAndToolbarIcons() throws {
        let app = launch(scenario: "dailyHistoryLoaded", language: "ja", locale: "ja_JP")
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 8))

        openNavigationItem("nav.sudmonitorHistory", in: app)
        XCTAssertTrue(app.navigationBars["過去データ(日次)表示"].waitForExistence(timeout: 5))

        // 期間指定(カレンダー)アイコンと自動更新/手動更新アイコンがツールバーに存在する。
        let rangeButton = app.navigationBars.buttons
            .matching(NSPredicate(format: "label == %@", "過去データ表示期間"))
            .firstMatch
        XCTAssertTrue(rangeButton.waitForExistence(timeout: 3))
        XCTAssertTrue(app.navigationBars.buttons["nav.autoUpdate"].exists)
        XCTAssertTrue(app.navigationBars.buttons["nav.manualUpdate"].exists)

        // 日次サマリーカード(期間と貯水率要約)が表示される(サイドバー併設の画面では非表示)。
        if !app.element("nav.sidebar").exists {
            let summaryCard = app.element("dashboard.sudmonitorHistorySummaryCard")
            XCTAssertTrue(summaryCard.waitForExistence(timeout: 3))
            XCTAssertTrue(
                app.staticTexts["2026/06/01 01:00 - 2026/07/01 00:00"].exists
                    || summaryCard.label.contains("2026/06/01 01:00"),
                "Summary card must show the daily history period"
            )
            XCTAssertTrue(
                app.staticTexts["81.00% → 82.00% (81.00% ~ 82.00%)"].exists
                    || summaryCard.label.contains("81.00% → 82.00%"),
                "Summary card must show the storage rate summary"
            )
        }
    }

    /// 日次表示画面の手動更新後、保存変更がサマリーCard/サイドバーエントリへ即時反映されることを検証します。
    ///
    /// fixture headerFetcher がシード済みと異なる期間の latest.dat を返し、
    /// 保存時のリビジョンbumpによる UI 再評価で表示が更新される必要がある(旧実装では stale になった)。
    func testDailyHistoryManualUpdateRefreshesDisplay() throws {
        let app = launch(scenario: "dailyHistoryLoaded", language: "ja", locale: "ja_JP")
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 8))
        openMenuIfNeeded(in: app)

        let entry = app.element("nav.sudmonitorHistory")
        XCTAssertTrue(entry.waitForExistence(timeout: 3))
        tapWhenHittable(entry, in: app)
        XCTAssertTrue(app.navigationBars["過去データ(日次)表示"].waitForExistence(timeout: 5))

        tapWhenHittable(app.navigationBars.buttons["nav.manualUpdate"], in: app)

        let updatedPeriod = "2026/06/02 01:00 - 2026/07/03 00:00"
        let oldPeriod = "2026/06/01 01:00 - 2026/07/01 00:00"
        if app.element("nav.sidebar").exists {
            // iPadOS: 日次表示画面はサマリーCard非表示のため、サイドバーエントリの結合ラベルで即時反映を検証する。
            let deadline = Date().addingTimeInterval(5)
            while Date() < deadline, !entry.label.contains(updatedPeriod) {
                usleep(200_000)
            }
            XCTAssertTrue(entry.label.contains(updatedPeriod), "Sidebar entry must show the updated daily period")
            XCTAssertTrue(entry.label.contains("83.00% → 85.00%"), "Sidebar entry must show the updated storage rate summary")
            XCTAssertFalse(entry.label.contains(oldPeriod), "Old period line must disappear after the update")
        } else {
            // iPhone: 日次表示画面のサマリーCardが即時再評価される。
            let summaryCard = app.element("dashboard.sudmonitorHistorySummaryCard")
            XCTAssertTrue(summaryCard.waitForExistence(timeout: 3))
            XCTAssertTrue(app.staticTexts[updatedPeriod].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["83.00% → 85.00% (83.00% ~ 85.00%)"].waitForExistence(timeout: 5))
        }
    }

    /// 過去データ検索で読込済み日次期間と同一の検索を行い、inline error が表示されることを検証します。
    func testDailyHistorySearchDuplicateInlineError() throws {
        let app = launch(scenario: "dailyHistoryLoaded", language: "ja", locale: "ja_JP")
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 8))

        openNavigationItem("nav.historicalSearch", in: app)
        XCTAssertTrue(app.element("historicalSearch.root").waitForExistence(timeout: 3))

        // 読込済み期間(20260601〜20260630)と同一の期間を指定する。
        let calendar = Calendar.current
        let now = Date()
        let nowMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let startInitMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: calendar.date(byAdding: .day, value: -30, to: now) ?? now)) ?? nowMonthStart
        let june2026 = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1)) ?? nowMonthStart
        let july2026 = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1)) ?? nowMonthStart
        let startMonthTaps = calendar.dateComponents([.month], from: june2026, to: startInitMonthStart).month ?? 1
        let endMonthTaps = calendar.dateComponents([.month], from: june2026, to: july2026).month ?? 1
        pickDate(dayPrefix: "6月1日", pickerIdentifier: "historicalSearch.startDate", previousMonthTaps: startMonthTaps, in: app)
        pickDate(dayPrefix: "6月30日", pickerIdentifier: "historicalSearch.endDate", previousMonthTaps: endMonthTaps, in: app)

        let error = app.element("historicalSearch.validationError")
        XCTAssertTrue(error.waitForExistence(timeout: 3))
        XCTAssertEqual(
            error.label,
            "指定期間は sudmonitor の日次過去データとして読み込み済みです。サイドバーの過去データから表示してください"
        )
        XCTAssertFalse(app.button("historicalSearch.submit").isEnabled)

        tapWhenHittable(app.button("historicalSearch.cancel"), in: app)
        XCTAssertTrue(app.element("historicalSearch.root").waitForNonExistence(timeout: 3))
    }

    /// 管理画面に日次エントリが登場しないことを検証します。
    func testDailyHistoryEntryNotInManageScreen() throws {
        let app = launch(scenario: "dailyHistoryLoaded", language: "ja", locale: "ja_JP")
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 8))

        openNavigationItem("nav.historicalManage", in: app)
        XCTAssertTrue(app.element("historicalManage.root").waitForExistence(timeout: 3))
        XCTAssertTrue(app.element("historicalManage.empty").exists)
    }

    /// 設定画面で自動更新 ON + 間隔 1時間/12時間のとき footer 文言が表示されることを検証します。
    func testDailyHistorySettingsAutoUpdateIntervalFooter() throws {
        let app = launch(scenario: "dailyHistoryLoaded", language: "ja", locale: "ja_JP")
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 8))

        openNavigationItem("nav.settings", in: app)
        XCTAssertTrue(app.element("settings.root").waitForExistence(timeout: 3))
        tapToggle(identifier: "settings.autoUpdate", in: app)

        selectAutoUpdateInterval("12時間", in: app)
        XCTAssertTrue(
            app.staticTexts["過去データ(日次)の自動更新間隔は1日になります。"].waitForExistence(timeout: 3)
        )

        selectAutoUpdateInterval("1時間", in: app)
        XCTAssertTrue(app.staticTexts["過去データ(日次)の自動更新間隔は1日になります。"].exists)
    }

    /// 日次表示画面(早明浦・読込済み)で過去比較グラフが表示可能なことを検証します。
    func testDailyHistoryComparisonGraphAvailable() throws {
        let app = launch(scenario: "dailyHistoryLoaded", language: "ja", locale: "ja_JP")
        XCTAssertTrue(app.element("dashboard.root").waitForExistence(timeout: 8))

        openNavigationItem("nav.sudmonitorHistory", in: app)
        XCTAssertTrue(app.navigationBars["過去データ(日次)表示"].waitForExistence(timeout: 5))

        // 履歴モードへ切り替えると年チップ(過去比較)が表示される。
        tapWhenHittable(app.button("graph.kind.rainfallStorageHistory"), in: app)
        let allChip = app.button("graph.year.all.storageRate")
        XCTAssertTrue(scrollToElement(allChip, in: app).exists)
        XCTAssertTrue(allChip.isSelected, "All years must be selected initially")
        XCTAssertTrue(app.button("graph.year.2002").exists)
        XCTAssertTrue(app.button("graph.year.2026").exists, "The current year chip must be present in the comparison row")

        // バンドルデータの比較読込が完了し、エラーにならない。
        let loading = app.element("graph.historicalLoading")
        if loading.waitForExistence(timeout: 1) {
            XCTAssertTrue(loading.waitForNonExistence(timeout: 10))
        }
        XCTAssertFalse(app.element("graph.historicalError").exists)
        XCTAssertTrue(app.button("graph.crosshair").exists)
    }

    /// iOS 26 のカレンダーポップアップで日付を選択します。日付の選択後に
    /// 「ポップアップを閉じる」で閉じる必要がある(選択だけでは閉じない)。
    private func pickDate(
        dayPrefix: String,
        pickerIdentifier: String,
        previousMonthTaps: Int,
        in app: XCUIApplication
    ) {
        let picker = app.element(pickerIdentifier)
        XCTAssertTrue(picker.waitForExistence(timeout: 3))
        picker.tap()
        XCTAssertTrue(app.buttons["先月"].waitForExistence(timeout: 3), "calendar must open")
        for _ in 0..<previousMonthTaps {
            app.buttons["先月"].tap()
            usleep(400_000)
        }
        let day = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", dayPrefix))
            .firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 3), "day \(dayPrefix) must be visible")
        day.tap()
        usleep(600_000)
        let closePopup = app.buttons["ポップアップを閉じる"]
        if closePopup.exists {
            closePopup.tap()
        }
        XCTAssertTrue(app.buttons["先月"].waitForNonExistence(timeout: 3), "calendar must close after selection")
    }

    /// 設定の自動更新間隔ピッカーから指定ラベル(例: "12時間")を選択します。
    private func selectAutoUpdateInterval(_ label: String, in app: XCUIApplication) {
        let row = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "自動更新 間隔"))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        _ = scrollToElement(row, in: app)
        tapWhenHittable(row, in: app)
        let item = app.buttons[label]
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        item.tap()
    }

    private func launch(
        scenario: String,
        language: String,
        locale: String,
        preserveDefaults: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale,
        ]
        app.launchEnvironment = [
            "TCSMDM_UI_TESTING": "1",
            "TCSMDM_UI_SCENARIO": scenario,
            "TCSMDM_UI_TEST_RUN_ID": "\(runID!)-\(scenario)-\(language)",
        ]
        if preserveDefaults {
            app.launchEnvironment["TCSMDM_UI_TEST_PRESERVE_DEFAULTS"] = "1"
        }
        app.launch()
        return app
    }

    private func cardToggle(_ rawKey: String, in app: XCUIApplication) -> XCUIElement {
        app.button("dashboard.cardToggle.\(rawKey)")
    }

    private func assertExpanded(
        _ toggle: XCUIElement,
        _ message: String = "Expected card to be expanded",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(toggle.waitForExistence(timeout: 3), file: file, line: line)
        XCTAssertEqual(toggle.value as? String, "Expanded", message, file: file, line: line)
    }

    private func assertCollapsed(
        _ toggle: XCUIElement,
        _ message: String = "Expected card to be collapsed",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(toggle.waitForExistence(timeout: 3), file: file, line: line)
        XCTAssertEqual(toggle.value as? String, "Collapsed", message, file: file, line: line)
    }

    private func tapScreenPoint(x: CGFloat, y: CGFloat, in app: XCUIApplication) {
        let frame = app.frame
        app.coordinate(withNormalizedOffset: CGVector(
            dx: (x - frame.minX) / frame.width,
            dy: (y - frame.minY) / frame.height
        )).tap()
    }

    private func openDamSelectionSheet(in app: XCUIApplication) {
        tapWhenHittable(app.element("settings.damSelection"), in: app)
        XCTAssertTrue(app.element("settings.damSelection.sheet").waitForExistence(timeout: 3))
    }

    /// リアルタイムデータソースを水文水質データベース(MLIT)へ切り替えます。
    /// 既定は sudmonitor のためダム選択行が無効化されており、ダム選択の検証前にこれを呼びます。
    /// 設定画面のデータソースは自動更新間隔と同じ Picker 表示のため、行タップで
    /// 選択肢画面へ遷移し、選択後に戻る操作を行います。
    private func switchRealtimeDataSourceToMlit(in app: XCUIApplication) {
        tapWhenHittable(app.element("settings.realtimeDataSource"), in: app)
        let option = app.element("settings.realtimeDataSource.mlitDirect")
        XCTAssertTrue(option.waitForExistence(timeout: 3))
        tapWhenHittable(option, in: app)
        tapBack(in: app)
        XCTAssertTrue(app.element("settings.root").waitForExistence(timeout: 3))
    }

    private func assertDamSelectionSheetStructure(in app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["Select a Dam"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.element("settings.damSelection.dam").exists)
        XCTAssertTrue(app.button("settings.damSelection.cancel").exists)
        XCTAssertTrue(app.button("settings.damSelection.select").exists)
        XCTAssertFalse(app.element("historicalSearch.startDate").exists)
        XCTAssertFalse(app.element("historicalSearch.endDate").exists)
    }

    private func openSettingsDamPicker(in app: XCUIApplication) {
        tapWhenHittable(app.element("settings.damSelection.dam"), in: app)
        XCTAssertTrue(app.element("settings.damSelection.damPicker").waitForExistence(timeout: 3))
    }

    private func openNavigationItem(_ identifier: String, in app: XCUIApplication) {
        let item = app.interactiveElement(identifier)
        if item.waitForExistence(timeout: 1) {
            tapWhenHittable(item, in: app)
            return
        }
        openMenuIfNeeded(in: app)
        let menuItem = app.interactiveElement(identifier)
        if !menuItem.waitForExistence(timeout: 1) {
            for _ in 0..<6 where !menuItem.exists {
                scrollNavigationContainerUp(in: app)
                _ = menuItem.waitForExistence(timeout: 1)
            }
        }
        XCTAssertTrue(menuItem.exists, "Missing navigation item \(identifier)")
        tapWhenHittable(menuItem, in: app)
    }

    private func openMenuIfNeeded(in app: XCUIApplication) {
        if app.element("nav.sidebar").exists || app.element("nav.menu.list").exists {
            return
        }
        let menu = app.element("nav.menu")
        if menu.waitForExistence(timeout: 3) {
            tapWhenHittable(menu, in: app)
        }
    }

    private func scrollNavigationContainerUp(in app: XCUIApplication) {
        let sidebar = app.element("nav.sidebar")
        if sidebar.exists {
            sidebar.swipeUp()
            return
        }
        let menuList = app.element("nav.menu.list")
        if menuList.exists {
            menuList.swipeUp()
            return
        }
        app.swipeUp()
    }

    private func assertSummaryCardWhenVisible(in app: XCUIApplication) {
        if app.element("nav.sidebar").exists {
            return
        }
        XCTAssertTrue(app.element("dashboard.summaryCard").exists)
    }

    private func tapBack(in app: XCUIApplication) {
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists {
            backButton.tap()
        }
    }

    private func tapBackIfCompact(in app: XCUIApplication) {
        if app.element("nav.sidebar").exists {
            return
        }
        tapBack(in: app)
    }

    /// チップ行(graph.year.scroll / graph.line.scroll)をスクロールして要素を可視化します。
    /// 目標チップが論理順序(全対象年チップ先頭+年チップ昇順+ライン切替チップ固定順)の前半なら
    /// 先頭(左端)へ、後半なら末尾(右端)へスクロールする。先頭/末尾の判定は、それぞれ
    /// 左端フェード・右端フェードの消失で行う。チップ行が縦方向に画面外の場合は先に縦
    /// スクロールで表示してから横ドラッグする。
    private func scrollChipRowTo(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maxSwipes: Int = 20
    ) -> XCUIElement {
        guard element.exists else { return element }
        guard let rowID = chipRowScrollID(in: app) else { return element }
        let row = app.scrollViews[rowID]
        let fadePrefix = rowID == "graph.year.scroll" ? "graph.year" : "graph.line"
        let appFrame = app.frame
        var guardCount = 0
        while guardCount < maxSwipes {
            let rowFrame = row.frame
            if rowFrame.midY >= appFrame.minY + 130, rowFrame.midY <= appFrame.maxY {
                break
            }
            if rowFrame.midY > appFrame.maxY {
                app.swipeUp()
            } else {
                app.swipeDown()
            }
            guardCount += 1
            usleep(300_000)
        }
        let scrollFrame = row.frame
        let y = min(max(scrollFrame.midY, appFrame.minY + 30), appFrame.maxY - 30)
        let dragStart = app.coordinate(withNormalizedOffset: CGVector(
            dx: (scrollFrame.maxX - 5 - appFrame.minX) / appFrame.width,
            dy: (y - appFrame.minY) / appFrame.height
        ))
        let dragEnd = app.coordinate(withNormalizedOffset: CGVector(
            dx: (scrollFrame.minX + 5 - appFrame.minX) / appFrame.width,
            dy: (y - appFrame.minY) / appFrame.height
        ))
        let chipOrder = chipRowOrder(in: app)
        let targetIndex = chipOrder.firstIndex(of: element.identifier) ?? 0
        let isLate = targetIndex > chipOrder.count / 2
        guardCount = 0
        while guardCount < maxSwipes {
            if isLate {
                // 末尾へ: 右端フェードが消える(末尾到達)まで右方向へフリング。
                let fadeTrailing = app.descendants(matching: .any)["\(fadePrefix).fade.trailing"]
                if !fadeTrailing.exists { break }
                dragStart.press(forDuration: 0.2, thenDragTo: dragEnd, withVelocity: .fast, thenHoldForDuration: 0.15)
            } else {
                // 先頭へ: 左端フェードが消える(先頭到達)まで左方向へフリング。
                let fadeLeading = app.descendants(matching: .any)["\(fadePrefix).fade.leading"]
                if !fadeLeading.exists { break }
                dragEnd.press(forDuration: 0.2, thenDragTo: dragStart, withVelocity: .fast, thenHoldForDuration: 0.15)
            }
            guardCount += 1
            usleep(400_000)
        }
        return element
    }

    /// チップ行のスクロール列識別子を返します。履歴modeの一体行(graph.year.scroll)を
    /// 優先し、存在しなければ非履歴modeの専用行(graph.line.scroll)を返します。
    /// スクロール列が存在しない場合は `nil` を返します。
    private func chipRowScrollID(in app: XCUIApplication) -> String? {
        if app.scrollViews["graph.year.scroll"].exists { return "graph.year.scroll" }
        if app.scrollViews["graph.line.scroll"].exists { return "graph.line.scroll" }
        return nil
    }

    /// チップ行の論理順序(全対象年チップ先頭 → 年チップ昇順 → ライン切替チップ固定順)を返します。
    /// 年チップの範囲は変わるため、実在するボタンを列挙して並べ替える(ハードコードしない)。
    private func chipRowOrder(in app: XCUIApplication) -> [String] {
        let lineOrder = [
            "graph.line.storageRate",
            "graph.line.rainfall",
            "graph.line.storageVolume",
            "graph.line.inflow",
            "graph.line.outflow",
        ]
        let ids = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "graph.year."))
            .allElementsBoundByIndex.map { $0.identifier }
            + app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "graph.line."))
            .allElementsBoundByIndex.map { $0.identifier }
        return ids.sorted { lhs, rhs in
            let lIsAll = lhs.hasPrefix("graph.year.all.")
            let rIsAll = rhs.hasPrefix("graph.year.all.")
            if lIsAll != rIsAll { return lIsAll }
            if lIsAll { return lhs < rhs }
            let lIsYear = lhs.hasPrefix("graph.year.")
            let rIsYear = rhs.hasPrefix("graph.year.")
            if lIsYear != rIsYear { return lIsYear }
            if lIsYear {
                return (Int(lhs.replacingOccurrences(of: "graph.year.", with: "")) ?? 0)
                    < (Int(rhs.replacingOccurrences(of: "graph.year.", with: "")) ?? 0)
            }
            return (lineOrder.firstIndex(of: lhs) ?? Int.max) < (lineOrder.firstIndex(of: rhs) ?? Int.max)
        }
    }

    private func scrollToStaticText(
        _ label: String,
        in app: XCUIApplication,
        maxSwipes: Int = 10
    ) -> XCUIElement {
        let element = app.staticTexts[label]
        if element.waitForExistence(timeout: 1) {
            return element
        }
        for _ in 0..<maxSwipes {
            app.swipeUp()
            if element.waitForExistence(timeout: 1) {
                return element
            }
        }
        for _ in 0..<maxSwipes {
            app.swipeDown()
            if element.waitForExistence(timeout: 1) {
                return element
            }
        }
        return element
    }

    /// グラフチップの1行横スクロール列をスクロールして要素を可視化します。
    /// 年チップ(graph.year.scroll)・モードチップ(graph.mode.scroll)・期間チップ
    /// (graph.range.scroll)に共通。SwiftUI ScrollView自身はアクセシビリティフレームが
    /// 空でswipe操作できないため、可視チップ(ボタン)の実座標の範囲内で水平ドラッグして
    /// 列をスクロールします(スクロールビューの外をドラッグしても届かない)。チップ行が
    /// 縦方向に画面外の場合は先に縦スクロールで表示してから横ドラッグします。
    /// スクロール行が存在しない場合は何もしません。
    private func revealHorizontalChip(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maxSwipes: Int = 25
    ) -> XCUIElement {
        if element.isHittable {
            return element
        }
        // アクセシビリティ階層に未存在(画面外)の要素は対象外。identifier アクセスは
        // 存在しない要素では例外になるため、先に exists を確認する。
        guard element.exists else {
            return element
        }
        // チップ種別ごとにスクロール列と論理順序を解決する。年チップ・ライン切替チップは
        // チップ行(graph.year.scroll / graph.line.scroll)にあり、年の範囲が変わるため、
        // 実在するボタンを列挙して番号順に並べる(ハードコードしない)。
        let scrollID: String
        let chipOrder: [String]
        if element.identifier.hasPrefix("graph.year.") || element.identifier.hasPrefix("graph.line.") {
            guard let rowID = chipRowScrollID(in: app) else { return element }
            scrollID = rowID
            chipOrder = chipRowOrder(in: app)
        } else if element.identifier.hasPrefix("graph.kind.") {
            scrollID = "graph.mode.scroll"
            chipOrder = [
                "graph.kind.rainfallStorage",
                "graph.kind.volumeFlow",
                "graph.kind.rainfallStorageHistory",
                "graph.kind.volumeFlowHistory",
            ]
        } else if element.identifier.hasPrefix("graph.range.") {
            scrollID = "graph.range.scroll"
            chipOrder = [
                "graph.range.all",
                "graph.range.past72Hours",
                "graph.range.past48Hours",
                "graph.range.past24Hours",
            ]
        } else {
            return element
        }
        guard app.scrollViews[scrollID].exists else {
            return element
        }
        let targetIndex = chipOrder.firstIndex(of: element.identifier) ?? -1
        let appFrame = app.frame
        // 移動方向は原則として一度だけ決定する。フリックの慣性で行き過ぎた場合は
        // 要素のフレーム位置から方向を更新して戻す。ループごとの全チップ探索は
        // しない(年チップ列はチップ数が多いため、毎回の探索は非常に遅い)。
        var moveLeft: Bool?
        for _ in 0..<maxSwipes where !element.isHittable {
            let scrollFrame = app.scrollViews[scrollID].frame
            if scrollFrame.midY > appFrame.maxY {
                // チップ行が縦方向に画面外(下)。
                app.swipeUp()
                usleep(300_000)
                continue
            }
            if scrollFrame.midY < appFrame.minY + 130 {
                // チップ行がナビゲーションバー等に被ってタッチを受け付けない位置に
                // ある。コンテンツを下へスクロールしてセーフエリア内へ移動させる。
                app.swipeDown()
                usleep(300_000)
                continue
            }
            // チップ行は縦方向に画面内。要素がスクロールビューの左右どちらかに大きく
            // 外れていれば方向を更新する(フリックの慣性で行き過ぎた場合の戻り用)。
            // (frameはスクリーン座標とスクロールコンテンツ座標が混在することがあるが、
            // 画面外の大きな値同士の比較では左右の判定は成立する)
            let targetFrame = element.frame
            if targetFrame.isEmpty || targetFrame.maxX < scrollFrame.minX + 5 {
                moveLeft = true
            } else if targetFrame.minX > scrollFrame.maxX - 5 {
                moveLeft = false
            } else if targetFrame.minX < scrollFrame.minX {
                // 左端がスクロール行の左端より外(部分的に可視)。左方向へスクロールする。
                moveLeft = true
            } else if targetFrame.maxX > scrollFrame.maxX {
                // 右端がスクロール行の右端より外(部分的に可視)。右方向へスクロールする。
                moveLeft = false
            }
            if moveLeft == nil {
                // 移動方向は「スクロールビュー内に表示されている最初のチップ」から決める。
                let visibleChips = chipOrder.compactMap { identifier -> XCUIElement? in
                    let chip = app.button(identifier)
                    guard chip.exists, !chip.frame.isEmpty else { return nil }
                    return chip.frame.intersects(scrollFrame) ? chip : nil
                }
                guard !visibleChips.isEmpty else {
                    // チップが見つからない場合は縦スクロールで表示を試みる。
                    if targetFrame.isEmpty || targetFrame.midY > appFrame.maxY {
                        app.swipeUp()
                    } else {
                        app.swipeDown()
                    }
                    usleep(300_000)
                    continue
                }
                let first = visibleChips[0]
                let leftmostIndex = chipOrder.firstIndex(of: first.identifier) ?? -1
                moveLeft = leftmostIndex > targetIndex
            }
            // チップのframeはスクロールコンテンツ座標を返すことがあり信頼できないため、
            // ドラッグはスクロールビュー自身のフレーム(スクリーン座標)の範囲内で行う。
            let y = min(max(scrollFrame.midY, appFrame.minY + 30), appFrame.maxY - 30)
            let dragStartX = moveLeft! ? scrollFrame.minX + 5 : scrollFrame.maxX - 5
            let dragEndX = moveLeft! ? scrollFrame.maxX - 5 : scrollFrame.minX + 5
            let start = app.coordinate(withNormalizedOffset: CGVector(
                dx: (dragStartX - appFrame.minX) / appFrame.width,
                dy: (y - appFrame.minY) / appFrame.height
            ))
            let end = app.coordinate(withNormalizedOffset: CGVector(
                dx: (dragEndX - appFrame.minX) / appFrame.width,
                dy: (y - appFrame.minY) / appFrame.height
            ))
            // 短い press はタップとして処理されスクロールとして認識されないため、
            // press + ドラッグ + 末尾保持で確実にスクロールさせる。年チップ列は
            // 可視幅が狭いため、高速ドラッグの慣性で1回あたりの移動量を稼ぐ。
            // 慣性で行き過ぎた場合はループ冒頭の方向更新で戻す。
            start.press(forDuration: 0.2, thenDragTo: end, withVelocity: .fast, thenHoldForDuration: 0.15)
            usleep(400_000)
        }
        // フリングの慣性が残っているとisHittableが信頼できないため、
        // 要素フレームが安定するまで待つ。
        if element.exists {
            for _ in 0..<10 {
                let frame = element.frame
                usleep(200_000)
                if element.frame == frame {
                    break
                }
            }
        }
        return element
    }

    private func scrollToElement(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maxSwipes: Int = 10
    ) -> XCUIElement {
        // 存在しない要素のisHittable・identifier等はXCUITestで"No matches found"になり
        // テストを中断するため、プロパティへアクセスする前は必ずexistsで確認する。
        if element.exists, element.isHittable {
            return element
        }
        // チップ行(年チップ・ライン切替チップの横スクロール列が存在する場合)はiOS 26の
        // XCUITestでisHittableが常にfalseを返すため、エッジフェードの有無から先頭/末尾へ
        // スクロールする専用経路を使う。
        if element.exists,
           (element.identifier.hasPrefix("graph.year.") || element.identifier.hasPrefix("graph.line.")),
           chipRowScrollID(in: app) != nil {
            return scrollChipRowTo(element, in: app, maxSwipes: maxSwipes)
        }
        for _ in 0..<maxSwipes {
            app.swipeUp()
            if element.exists, element.isHittable {
                return element
            }
        }
        for _ in 0..<maxSwipes {
            app.swipeDown()
            if element.exists, element.isHittable {
                return element
            }
        }
        return element
    }

    /// SwiftUI の Form 行はアクセシビリティ要素の frame が行全体になるため、
    /// 実スイッチ（行内の子孫 Switch 要素）をタップしてトグルを切り替えます。
    /// ビュー更新後の再解決に備え、毎回新しいクエリから取得します。
    private func tapToggle(identifier: String, in app: XCUIApplication) {
        let fresh = app.element(identifier)
        _ = scrollToElement(fresh, in: app)
        tapWhenHittable(fresh, in: app, performTap: false)
        usleep(500_000)
        let innerSwitch = fresh.descendants(matching: .switch).firstMatch
        if innerSwitch.exists {
            innerSwitch.tap()
        } else {
            fresh.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        }
    }

    private func tapEdit(in app: XCUIApplication) {
        let editButton = app.navigationBars.buttons["Edit"]
        if editButton.waitForExistence(timeout: 2) {
            editButton.tap()
            return
        }
        let doneButton = app.navigationBars.buttons["Done"]
        if doneButton.waitForExistence(timeout: 2) {
            doneButton.tap()
        }
    }

    private func tapFullHistory(in app: XCUIApplication) {
        let elementByID = app.element("dashboard.history.full")
        if elementByID.waitForExistence(timeout: 1) {
            tapWhenHittable(elementByID, in: app)
            return
        }

        let elementByLabel = app.element(labeled: "Show all-period observation data")
        if elementByLabel.waitForExistence(timeout: 1) {
            tapWhenHittable(elementByLabel, in: app)
            return
        }

        let card = app.element("dashboard.historyCard")
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.92)).tap()
    }

    private func tapWhenHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        performTap: Bool = true
    ) {
        if !element.waitForExistence(timeout: 1) {
            for _ in 0..<6 where !element.exists {
                app.swipeUp()
                _ = element.waitForExistence(timeout: 1)
            }
        }
        if !element.exists {
            for _ in 0..<8 where !element.exists {
                app.swipeDown()
                _ = element.waitForExistence(timeout: 1)
            }
        }
        XCTAssertTrue(element.exists)
        // チップ行(年チップ・ライン切替チップの横スクロール列が存在する場合)はiOS 26の
        // XCUITestでisHittableが常にfalseを返すため、エッジフェードから先頭/末尾へスクロールし、
        // 実座標タップでタップする。末尾側のチップはアクセシビリティフレームが
        // スクロールコンテンツ座標になることがあるため、フレームが行内に収まる場合のみ
        // 実座標タップし、収まらない場合は後続チップの幅(コンテンツ座標でも正しい)から
        // 対象チップの中心Xを導出してタップする。行右端のチップ(最終チップ)は行右端
        // 付近の座標がそのまま当たる。
        if element.identifier.hasPrefix("graph.year.") || element.identifier.hasPrefix("graph.line."),
           let chipRowID = chipRowScrollID(in: app) {
            _ = scrollChipRowTo(element, in: app)
            if performTap {
                let rowFrame = app.scrollViews[chipRowID].frame
                let appFrame = app.frame
                let y = min(max(rowFrame.midY, appFrame.minY + 30), appFrame.maxY - 30)
                let chipOrder = chipRowOrder(in: app)
                let targetIndex = chipOrder.firstIndex(of: element.identifier) ?? 0
                let targetFrame = element.frame
                let framePlausible = !targetFrame.isEmpty
                    && targetFrame.minX >= rowFrame.minX - 1
                    && targetFrame.maxX <= rowFrame.maxX + 1
                if targetIndex > chipOrder.count / 2, !framePlausible {
                    // 行末尾までスクロール済みなので、後続チップの幅合計と間隔から対象チップの
                    // 中心Xを導出する(フレームの幅はスクロールコンテンツ座標でも正しい)。
                    let following = Array(chipOrder.dropFirst(targetIndex + 1))
                    let followingWidths = following.compactMap { id -> CGFloat? in
                        let chip = app.button(id)
                        guard chip.exists, chip.frame.width > 0 else { return nil }
                        return chip.frame.width
                    }
                    if followingWidths.count == following.count {
                        let spacingWidth = CGFloat(following.count) * 8
                        let halfWidth = min(max(targetFrame.width / 2, 25), 80)
                        let tapX = min(max(
                            rowFrame.maxX - followingWidths.reduce(0, +) - spacingWidth - halfWidth,
                            rowFrame.minX + 30
                        ), rowFrame.maxX - 20)
                        app.coordinate(withNormalizedOffset: CGVector(
                            dx: (tapX - appFrame.minX) / appFrame.width,
                            dy: (y - appFrame.minY) / appFrame.height
                        )).tap()
                    } else {
                        // 幅が取得できない場合は行右端(最終チップ)をタップする。
                        app.coordinate(withNormalizedOffset: CGVector(
                            dx: (rowFrame.maxX - 20 - appFrame.minX) / appFrame.width,
                            dy: (y - appFrame.minY) / appFrame.height
                        )).tap()
                    }
                } else {
                    element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                }
            }
            return
        }
        _ = revealHorizontalChip(element, in: app)
        for _ in 0..<8 where !element.isHittable {
            if element.frame.midY < app.frame.midY {
                app.swipeDown()
            } else {
                app.swipeUp()
            }
            _ = element.waitForExistence(timeout: 1)
        }
        XCTAssertTrue(element.isHittable)
        if performTap {
            element.tap()
        }
    }
}

private extension XCUIApplication {
    func element(_ identifier: String) -> XCUIElement {
        descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", identifier)).firstMatch
    }

    func element(_ identifier: String, orLabel label: String) -> XCUIElement {
        descendants(matching: .any).matching(NSPredicate(format: "identifier == %@ OR label == %@", identifier, label)).firstMatch
    }

    func element(labeled label: String) -> XCUIElement {
        descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    func button(_ identifier: String) -> XCUIElement {
        buttons.matching(NSPredicate(format: "identifier == %@", identifier)).firstMatch
    }

    func interactiveElement(_ identifier: String) -> XCUIElement {
        let button = button(identifier)
        if button.exists {
            return button
        }
        let cell = cells.matching(NSPredicate(format: "identifier == %@", identifier)).firstMatch
        if cell.exists {
            return cell
        }
        return element(identifier)
    }

    func element(containing prefix: String) -> XCUIElement {
        descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
    }

    func waitForElement(_ identifier: String, maxSwipes: Int = 6) -> Bool {
        let candidate = element(identifier)
        if candidate.waitForExistence(timeout: 1) {
            return true
        }
        for _ in 0..<maxSwipes {
            swipeUp()
            if candidate.waitForExistence(timeout: 1) {
                return true
            }
        }
        return false
    }
}
