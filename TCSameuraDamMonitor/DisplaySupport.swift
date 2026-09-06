// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Foundation
import SwiftUI
import TCSameuraDamCore

/// アプリで使用する言語コードやロケールの設定を管理するユーティリティ。
internal enum AppLocale {
    /// 端末の優先言語リストおよびシステム設定から決定された、現在有効な言語コードを取得します。
    internal nonisolated static var effectiveLanguageCode: String {
        let preferred = Locale.preferredLanguages
            .compactMap { Locale(identifier: $0).language.languageCode?.identifier }
            .first
        return preferred ?? Locale.autoupdatingCurrent.language.languageCode?.identifier ?? "en"
    }

    /// 現在有効な `Locale` オブジェクトを取得します。
    internal nonisolated static var effectiveLocale: Locale {
        Locale(identifier: effectiveLanguageCode)
    }

    /// 現在設定されている有効言語が日本語であるかどうかを判定します。
    internal nonisolated static var isJapanese: Bool {
        effectiveLanguageCode == "ja"
    }
}

/// アプリケーション内で使用される、ローカライズに対応した表示用静的テキスト文言のプロキシ。
internal enum AppText {
    /// 日本語設定状態であるかどうかのフラグ。
    internal static var isJapanese: Bool {
        AppLocale.isJapanese
    }

    /// キーに対応するローカライズテキストを返します。
    private static func t(_ key: String) -> String {
        AppLocalized.text(key, locale: AppLocale.effectiveLocale)
    }

    /// キーと引数からフォーマットされたローカライズテキストを返します。
    private static func f(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: t(key), locale: AppLocale.effectiveLocale, arguments: arguments)
    }

    /// アプリケーション名。
    internal static var appName: String { t("app.name") }
    /// 一般エラーのタイトル。
    internal static var errorTitle: String { t("error.title") }
    /// データ永続化エラーのタイトル。
    internal static var persistenceFailureTitle: String { t("error.persistenceFailure.title") }
    /// データ永続化エラーの説明メッセージ。
    internal static var persistenceFailureMessage: String { t("error.persistenceFailure.message") }
    /// データ永続化エラーの詳細説明。
    internal static var persistenceFailureDetail: String { t("error.persistenceFailure.detail") }
    /// 「OK」テキスト。
    internal static var ok: String { t("common.ok") }
    /// 「キャンセル」テキスト。
    internal static var cancel: String { t("common.cancel") }
    /// 「再試行」テキスト。
    internal static var retry: String { t("common.retry") }
    /// 「保存」テキスト。
    internal static var save: String { t("common.save") }
    /// 「削除」テキスト。
    internal static var delete: String { t("common.delete") }
    /// 「すべて削除」テキスト。
    internal static var deleteAll: String { t("common.deleteAll") }
    /// 「編集」テキスト。
    internal static var edit: String { t("common.edit") }
    /// 「完了」テキスト。
    internal static var done: String { t("common.done") }
    /// 「コピー」テキスト。
    internal static var copy: String { t("common.copy") }
    /// 「共有」テキスト。
    internal static var share: String { t("common.share") }
    /// 「URLを共有」テキスト。
    internal static var shareURL: String { t("common.shareURL") }
    /// 「リンクをコピー」テキスト。
    internal static var copyLinkTitle: String { t("common.copyLinkTitle") }
    /// 「リンクを共有」テキスト。
    internal static var shareLinkTitle: String { t("common.shareLinkTitle") }
    /// 「地図URLをコピー」テキスト。
    internal static var copyGeoUrl: String { t("common.copyGeoUrl") }
    /// 「地図URLを共有」テキスト。
    internal static var shareGeoUrl: String { t("common.shareGeoUrl") }
    /// 「地図アクションを選択」テキスト。
    internal static var selectGeoAction: String { t("common.selectGeoAction") }
    /// 「リンクアクションを選択」テキスト。
    internal static var selectLinkAction: String { t("common.selectLinkAction") }
    /// 「リポジトリアクションを選択」テキスト。
    internal static var selectRepositoryAction: String { t("common.selectRepositoryAction") }
    /// 「書き出し」テキスト。
    internal static var export: String { t("common.export") }
    /// 「URLを開く」テキスト。
    internal static var openURL: String { t("common.openURL") }
    /// 「地図を開く」テキスト。
    internal static var openMap: String { t("common.openMap") }
    /// 「その他の操作」テキスト。
    internal static var moreActions: String { t("common.moreActions") }
    /// 「未設定」テキスト。
    internal static var notSet: String { t("common.notSet") }
    /// 「データなし」テキスト。
    internal static var noData: String { t("common.noData") }
    /// 「キャッシュなし」テキスト。
    internal static var noCachedData: String { t("common.noCachedData") }
    /// 「読み込み中」テキスト。
    internal static var loading: String { t("common.loading") }
    /// 三点リーダー付きの「読み込み中...」テキスト。
    internal static var loadingEllipsis: String { t("common.loadingEllipsis") }
    /// macOS メニューバーからメインウィンドウを開くコマンド。
    internal static var menuBarOpenMainWindow: String { t("menuBar.openMainWindow") }
    /// macOS メニューバーから常駐アプリを終了するコマンド。
    internal static var menuBarQuit: String { t("menuBar.quit") }
    /// macOS アプリメニューからこのアプリについてを表示するコマンド。
    internal static var menuAboutApp: String { t("menu.aboutApp") }
    /// macOS アプリメニューから設定を表示するコマンド。
    internal static var menuSettings: String { t("menu.settings") }
    /// 「リアルタイム観測データ」メニューテキスト。
    internal static var navRealtimeData: String { t("nav.realtimeData") }
    /// 「過去の観測データ」メニューテキスト。
    internal static var navHistoricalData: String { t("nav.historicalData") }
    /// 「過去データ検索」メニューテキスト。
    internal static var navHistoricalSearch: String { t("nav.historicalSearch") }
    /// 「検索結果の管理」メニューテキスト。
    internal static var navHistoricalManage: String { t("nav.historicalManage") }
    /// 「出典」メニューテキスト。
    internal static var navSource: String { t("nav.source") }
    /// 「設定」メニューテキスト。
    internal static var navSettings: String { t("nav.settings") }
    /// 「アプリ情報」メニューテキスト。
    internal static var navAppInfo: String { t("nav.appInfo") }
    /// 「自動更新」テキスト。
    internal static var navAutoUpdate: String { t("nav.autoUpdate") }
    /// 「手動更新」テキスト。
    internal static var navManualUpdate: String { t("nav.manualUpdate") }
    /// 「保存された検索」テキスト。
    internal static var savedSearches: String { t("nav.savedSearches") }
    /// 「ツール」メニューテキスト。
    internal static var tools: String { t("nav.tools") }
    /// 「バージョン」表示ラベル。
    internal static var appInfoVersion: String { t("appInfo.version") }
    /// 「利用規約」表示ラベル。
    internal static var appInfoTermsOfUse: String { t("appInfo.termsOfUse") }
    /// 「利用規約 (日本語)」表示ラベル。
    internal static var appInfoTermsOfUseJa: String { t("appInfo.termsOfUseJa") }
    /// 「ライセンス」表示ラベル。
    internal static var appInfoLicense: String { t("appInfo.license") }
    /// 「Apache License 2.0」表示ラベル。
    internal static var appInfoApacheLicense: String { t("appInfo.apacheLicense") }
    /// 「プライバシーポリシー」表示ラベル。
    internal static var appInfoPrivacyPolicy: String { t("appInfo.privacyPolicy") }
    /// 「プライバシーポリシー (日本語)」表示ラベル。
    internal static var appInfoPrivacyPolicyJa: String { t("appInfo.privacyPolicyJa") }
    /// 「OSSライセンス」表示ラベル。
    internal static var appInfoOSSLicense: String { t("appInfo.ossLicense") }
    /// 「GitHubリポジトリ」表示ラベル。
    internal static var appInfoGitHub: String { t("appInfo.github") }
    /// 「Codebergリポジトリ」表示ラベル。
    internal static var appInfoCodeberg: String { t("appInfo.codeberg") }
    /// 「バージョン情報」ダイアログタイトル。
    internal static var dialogVersionTitle: String { t("dialog.version.title") }
    /// 「ライセンス情報」ダイアログタイトル。
    internal static var dialogLicenseTitle: String { t("dialog.license.title") }
    /// 「利用規約」ダイアログタイトル。
    internal static var dialogTermsOfUseTitle: String { t("dialog.termsOfUse.title") }
    /// 「利用規約 (日本語)」ダイアログタイトル。
    internal static var dialogTermsOfUseJaTitle: String { t("dialog.termsOfUseJa.title") }
    /// 「プライバシーポリシー」ダイアログタイトル。
    internal static var dialogPrivacyPolicyTitle: String { t("dialog.privacyPolicy.title") }
    /// 「プライバシーポリシー (日本語)」ダイアログタイトル。
    internal static var dialogPrivacyPolicyJaTitle: String { t("dialog.privacyPolicyJa.title") }
    /// 「OSSライセンス」ダイアログタイトル。
    internal static var dialogOSSLicenseTitle: String { t("dialog.ossLicense.title") }
    /// 初回自動更新ダイアログのタイトル。
    internal static var dialogInitialAutoUpdateTitle: String { t("dialog.initialAutoUpdate.title") }
    /// 初回自動更新ダイアログの確認メッセージ。
    internal static var dialogInitialAutoUpdateMessage: String { t("dialog.initialAutoUpdate.message") }
    /// 「はい」アクションテキスト。
    internal static var actionYes: String { t("action.yes") }
    /// 「いいえ」アクションテキスト。
    internal static var actionNo: String { t("action.no") }
    /// 「閉じる」テキスト。
    internal static var close: String { t("common.close") }
    /// Cardが展開済みであることを示すaccessibility値。
    internal static var cardExpanded: String { t("accessibility.card.expanded") }
    /// Cardが折りたたみ済みであることを示すaccessibility値。
    internal static var cardCollapsed: String { t("accessibility.card.collapsed") }
    /// Card開閉ボタンの状態に応じたaccessibilityラベル。
    internal static func cardToggleAccessibilityLabel(title: String, isExpanded: Bool) -> String {
        f(isExpanded ? "accessibility.card.collapseFormat" : "accessibility.card.expandFormat", title)
    }
    /// 最小手動更新クールダウンのブロック警告用フォーマットテンプレート。
    internal static var mainRefreshTooEarlyFormat: String { t("main.refreshTooEarly.format") }
    /// 自動更新無効時のステータステキスト。
    internal static var mainAutorenewDisabled: String { t("main.autorenewDisabled") }
    /// 自動更新処理実行中のテキスト。
    internal static var mainAutorenewInProgress: String { t("main.autorenewInProgress") }
    /// 初期ロード実行中のテキスト。
    internal static var mainInitialLoadInProgress: String { t("main.initialLoadInProgress") }
    /// 手動更新実行中のテキスト。
    internal static var mainManualUpdateInProgress: String { t("main.manualUpdateInProgress") }
    /// 「ダム観測諸量」ヘッダーテキスト。
    internal static var mainObservationData: String { t("main.observationData") }
    /// 「観測所記号」項目名。
    internal static var mainStationID: String { t("main.stationID") }
    /// 「観測所名」項目名。
    internal static var mainStationName: String { t("main.stationName") }
    /// 「水系名」項目名。
    internal static var mainRiverSystem: String { t("main.riverSystem") }
    /// 「河川名」項目名。
    internal static var mainRiverName: String { t("main.riverName") }
    /// 「位置座標」項目名。
    internal static var mainGeo: String { t("main.geo") }
    /// 「リアルタイム観測データ」セクション。
    internal static var mainLatestData: String { t("main.latestData") }
    /// 「観測データ履歴」セクション。
    internal static var mainHistoryData: String { t("main.historyData") }
    /// 履歴テーブル「日時」ヘッダ。
    internal static var mainHistoryColDatetime: String { t("main.historyColDatetime") }
    /// 履歴テーブル「雨量」ヘッダ。
    internal static var mainHistoryColRainfall: String { t("main.historyColRainfall") }
    /// 履歴テーブル「時間雨量」ヘッダ。
    internal static var mainHistoryColRainfallPerHour: String { t("main.historyColRainfallPerHour") }
    /// 履歴テーブル「貯水量」ヘッダ。
    internal static var mainHistoryColVolume: String { t("main.historyColVolume") }
    /// 履歴テーブル「流入量」ヘッダ。
    internal static var mainHistoryColInflow: String { t("main.historyColInflow") }
    /// 履歴テーブル「放流量」ヘッダ。
    internal static var mainHistoryColOutflow: String { t("main.historyColOutflow") }
    /// 履歴テーブル「貯水率」ヘッダ。
    internal static var mainHistoryColStorage: String { t("main.historyColStorage") }
    /// 「アプリ側データ取得時刻」表示。
    internal static var mainDataFetchTime: String { t("main.dataFetchTime") }
    /// 「データ最終更新時刻」表示。
    internal static var mainDataUpdateTime: String { t("main.dataUpdateTime") }
    /// 「貯水率観測日時」表示。
    internal static var mainPercentageTime: String { t("main.percentageTime") }
    /// 流域平均雨量 (Basin average rainfall)。
    internal static var mainRainfall: String { t("main.rainfall") }
    /// 流域平均雨量（時間雨量）。
    internal static var mainRainfallPerHour: String { t("main.rainfallPerHour") }
    /// 貯水量 (Storage volume)。
    internal static var mainStorageVolume: String { t("main.storageVolume") }
    /// 流入量 (Inflow)。
    internal static var mainInflow: String { t("main.inflow") }
    /// 放流量 (Outflow)。
    internal static var mainOutflow: String { t("main.outflow") }
    /// 貯水率 (Storage rate)。
    internal static var mainStoragePercentage: String { t("main.storagePercentage") }
    /// 前日同時刻差（日差分）。
    internal static var mainDayChange: String { t("main.dayChange") }
    /// SummaryとWidgetで使用する短い前日比ラベル。
    internal static var summaryDayChange: String { t("summary.dayChange") }
    /// 前週同時刻差（週差分）。
    internal static var mainWeekChange: String { t("main.weekChange") }
    /// 「観測グラフ」セクション。
    internal static var graphObservationData: String { t("graph.observationData") }
    /// 雨量&貯水率グラフの表示切替テキスト。
    internal static var graphRainfallStorageSelect: String { t("graph.rainfallStorageSelect") }
    /// 貯水量&流出入量グラフの表示切替テキスト。
    internal static var graphVolumeFlowSelect: String { t("graph.volumeFlowSelect") }
    /// 雨量&貯水率グラフの過去比較表示切替テキスト。
    internal static var graphRainfallStorageHistorySelect: String { t("graph.rainfallStorageHistorySelect") }
    /// 貯水量&流出入量グラフの過去比較表示切替テキスト。
    internal static var graphVolumeFlowHistorySelect: String { t("graph.volumeFlowHistorySelect") }
    /// 過去比較の全対象年チップ(貯水率)。
    internal static var graphAllStorageRate: String { t("graph.allStorageRate") }
    /// 過去比較の全対象年チップ(貯水量)。
    internal static var graphAllStorageVolume: String { t("graph.allStorageVolume") }
    /// ライン切替チップ「貯水率」。
    internal static var graphLineStorageRate: String { t("graph.lineStorageRate") }
    /// ライン切替チップ「流域平均雨量」。
    internal static var graphLineRainfall: String { t("graph.lineRainfall") }
    /// ライン切替チップ「貯水量」。
    internal static var graphLineStorageVolume: String { t("graph.lineStorageVolume") }
    /// ライン切替チップ「流入量」。
    internal static var graphLineInflow: String { t("graph.lineInflow") }
    /// ライン切替チップ「放流量」。
    internal static var graphLineOutflow: String { t("graph.lineOutflow") }
    /// 過去データ比較の年チップグループラベル。
    internal static var graphComparisonYears: String { t("graph.comparisonYears") }
    /// チップスクロール列のエッジフェードのアクセシビリティラベル。
    internal static var graphChipRowFade: String { t("graph.chipRowFade") }
    /// 過去データ比較の読み込み中メッセージ。
    internal static var graphLoadingHistoricalData: String { t("graph.loadingHistoricalData") }
    /// 過去データ比較の読み込み失敗メッセージ。
    internal static var graphHistoricalDataLoadFailed: String { t("graph.historicalDataLoadFailed") }
    /// 過去データ比較の再試行ボタンテキスト。
    internal static var graphRetry: String { t("graph.retry") }
    /// グラフ表示全期間指定。
    internal static var graphRangeAll: String { t("graph.range.all") }
    /// グラフ表示過去72時間。
    internal static var graphRangePast72Hours: String { t("graph.range.past72Hours") }
    /// グラフ表示過去48時間。
    internal static var graphRangePast48Hours: String { t("graph.range.past48Hours") }
    /// グラフ表示過去24時間。
    internal static var graphRangePast24Hours: String { t("graph.range.past24Hours") }
    /// 「貯水率」グラフタイトル。
    internal static var graphStoragePercentage: String { t("graph.storagePercentage") }
    /// 「貯水量・流出入量」グラフタイトル。
    internal static var graphVolumeFlow: String { t("graph.volumeFlow") }
    /// 「期間」の軸ラベル。
    internal static var graphLabelPeriod: String { t("graph.labelPeriod") }
    /// 「累加雨量」のグラフ要約。
    internal static var graphLabelRainfallTotal: String { t("graph.labelRainfallTotal") }
    /// 「最大時間雨量」のグラフ要約。
    internal static var graphLabelRainfallMax: String { t("graph.labelRainfallMax") }
    /// 「最大貯水率」のグラフ要約。
    internal static var graphLabelStorageRateMax: String { t("graph.labelStorageRateMax") }
    /// 「最小貯水率」のグラフ要約。
    internal static var graphLabelStorageRateMin: String { t("graph.labelStorageRateMin") }
    /// 「最大貯水量」のグラフ要約。
    internal static var graphLabelStorageVolumeMax: String { t("graph.labelStorageVolumeMax") }
    /// 「最小貯水量」のグラフ要約。
    internal static var graphLabelStorageVolumeMin: String { t("graph.labelStorageVolumeMin") }
    /// 「最大流入量」のグラフ要約。
    internal static var graphLabelInflowMax: String { t("graph.labelInflowMax") }
    /// 「最小流入量」のグラフ要約。
    internal static var graphLabelInflowMin: String { t("graph.labelInflowMin") }
    /// 「最大放流量」のグラフ要約。
    internal static var graphLabelOutflowMax: String { t("graph.labelOutflowMax") }
    /// 「最小放流量」のグラフ要約。
    internal static var graphLabelOutflowMin: String { t("graph.labelOutflowMin") }
    /// 貯水率の単位（%）。
    internal static var graphUnitStorageRate: String { t("graph.unitStorageRate") }
    /// 降雨量の単位（mm）。
    internal static var graphUnitRainfall: String { t("graph.unitRainfall") }
    /// 時間降水量の単位（mm/h）。
    internal static var graphUnitRainfallPerHour: String { t("graph.unitRainfallPerHour") }
    /// 貯水量の単位（万m³）。
    internal static var graphUnitStorageVolume: String { t("graph.unitStorageVolume") }
    /// 流量の単位（m³/s）。
    internal static var graphUnitFlow: String { t("graph.unitFlow") }
    /// 雨量ツールチップ項目名。
    internal static var graphTooltipRainfall: String { t("graph.tooltipRainfall") }
    /// 貯水率ツールチップ項目名。
    internal static var graphTooltipStorageRate: String { t("graph.tooltipStorageRate") }
    /// 貯水量ツールチップ項目名。
    internal static var graphTooltipStorageVolume: String { t("graph.tooltipStorageVolume") }
    /// 流入量ツールチップ項目名。
    internal static var graphTooltipInflow: String { t("graph.tooltipInflow") }
    /// 放流量ツールチップ項目名。
    internal static var graphTooltipOutflow: String { t("graph.tooltipOutflow") }
    /// クロスヘア（値追従ライン）の有効化補助指示。
    internal static var crosshairEnableLabel: String { t("graph.crosshairEnableLabel") }
    /// 元データサイトURLカードタイトル。
    internal static var mainURLCardTitle: String { t("main.urlCardTitle") }
    /// 「川の防災情報」リンクテキスト。
    internal static var urlDisaster: String { t("url.disaster") }
    /// 「ダム管理所・情報ページ」リンクテキスト。
    internal static var urlSiteInfo: String { t("url.siteInfo") }
    /// 「10分ダム諸量データ（EU-JP）」リンクテキスト。
    internal static var urlData: String { t("url.data") }
    /// 「過去データ検索（Shift_JIS）」リンクテキスト。
    internal static var urlSearch: String { t("url.search") }
    /// 出典「国交省 水文水質データベース」表記。
    internal static var navSourceDB: String { t("nav.sourceDB") }
    /// 出典「国交省 川の防災情報」表記。
    internal static var navSourcePDL: String { t("nav.sourcePDL") }
    /// デバッグメニュー。
    internal static var navDebug: String { t("nav.debug") }
    internal static var navSudmonitorHistory: String { t("nav.sudmonitorHistory") }
    /// 「過去データ検索」ダイアログタイトル。
    internal static var historicalSearchTitle: String { t("historical.search.title") }
    /// 検索対象ダム選択ラベル。
    internal static var historicalSearchDam: String { t("historical.search.dam") }
    /// 検索開始日選択ラベル。
    internal static var historicalSearchStartDate: String { t("historical.search.startDate") }
    /// 検索終了日選択ラベル。
    internal static var historicalSearchEndDate: String { t("historical.search.endDate") }
    /// 「検索実行」ボタンテキスト。
    internal static var historicalSearchButton: String { t("historical.search.button") }
    /// 「検索中...」ステータス。
    internal static var historicalSearchSearching: String { t("historical.search.searching") }
    /// 開始/終了日のいずれかが未選択の警告。
    internal static var historicalSearchDateNotSelected: String { t("historical.search.dateNotSelected") }
    /// 開始終了の前後関係矛盾の警告。
    internal static var historicalSearchErrorDateRange: String { t("historical.search.errorDateRange") }
    /// 今日を含む指定への警告。
    internal static var historicalSearchErrorToday: String { t("historical.search.errorToday") }
    /// 日数制限（31日）超過の警告。
    internal static var historicalSearchErrorTooLong: String { t("historical.search.errorTooLong") }
    /// 検索可能な期間より過去の日時指定への警告。
    internal static var historicalSearchErrorTooOld: String { t("historical.search.errorTooOld") }
    /// 重複した過去検索の実行警告。
    internal static var historicalSearchDuplicate: String { t("historical.search.duplicate") }
    /// 過去データ検索 (Historical data search) の最大上限数に達した際のスナックバーメッセージ。
    internal static func historicalSearchMaxCountSnackbar(_ count: Int) -> String {
        f("historical.search.maxCountSnackbar", count)
    }
    /// 履歴期間絞り込みタイトル。
    internal static var historicalRangeTitle: String { t("historical.range.title") }
    /// 「表示期間の確定」ボタン。
    internal static var historicalRangeDisplayButton: String { t("historical.range.displayButton") }
    /// 「絞り込み解除」ボタン。
    internal static var historicalRangeReset: String { t("historical.range.reset") }
    /// 期間指定ボタンのアクセシビリティ説明。
    internal static var historicalRangeIconButtonDesc: String { t("historical.range.iconButtonDesc") }
    /// 期間リセットボタンのアクセシビリティ説明。
    internal static var historicalRangeResetIconDesc: String { t("historical.range.resetIconDesc") }
    /// 絞り込み指定の日付範囲が検索全体の範囲外である旨の警告。
    internal static var historicalRangeErrorOutOfBounds: String { t("historical.range.errorOutOfBounds") }
    internal static var historicalSudmonitorHistoryDuplicateLoaded: String { t("historical.sudmonitorHistory.duplicateLoaded") }
    internal static var titleSudmonitorHistory: String { t("title.sudmonitorHistory") }
    /// 「システム設定」ヘッダー。
    internal static var settingsHeaderSystem: String { t("settings.headerSystem") }
    /// 「一般設定」ヘッダー。
    internal static var settingsHeaderGeneral: String { t("settings.headerGeneral") }
    /// 「表示・監視対象ダム」ヘッダー。
    internal static var settingsHeaderDam: String { t("settings.headerDam") }
    /// 「データソース」ヘッダー。
    internal static var settingsHeaderDataSource: String { t("settings.headerDataSource") }
    /// 「デバッグ機能」ヘッダー。
    internal static var settingsHeaderDebug: String { t("settings.headerDebug") }
    /// 「システムログ」タイトル。
    internal static var debugLogTitle: String { t("settings.debugLogTitle") }
    /// 「テーマ設定」項目。
    internal static var settingsTheme: String { t("settings.theme") }
    /// 「システム設定に従う」テーマ。
    internal static var themeSystem: String { t("settings.themeSystem") }
    /// 「ライトモード」テーマ。
    internal static var themeLight: String { t("settings.themeLight") }
    /// 「ダークモード」テーマ。
    internal static var themeDark: String { t("settings.themeDark") }
    /// 「外観モード」項目。
    internal static var settingsAppearance: String { t("settings.appearance") }
    /// 「言語」項目。
    internal static var settingsLanguage: String { t("settings.language") }
    /// 「システムに従う」外観設定。
    internal static var appearanceAuto: String { t("settings.appearanceAuto") }
    /// 「常にライトモード」外観設定。
    internal static var appearanceLight: String { t("settings.appearanceLight") }
    /// 「常にダークモード」外観設定。
    internal static var appearanceDark: String { t("settings.appearanceDark") }
    /// 「通知を許可」設定項目。
    internal static var settingsShowNotification: String { t("settings.showNotification") }
    /// 「ログイン時に起動する」設定項目。
    internal static var settingsLaunchAtLogin: String { t("settings.launchAtLogin") }
    /// ログイン時起動の詳細フッター説明。
    internal static var settingsLaunchAtLoginFooter: String { t("settings.launchAtLoginFooter") }
    /// 「メニューバーに常駐する」設定項目。
    internal static var settingsMenuBarResidency: String { t("settings.menuBarResidency") }
    /// メニューバー非常駐時の詳細フッター説明。
    internal static var settingsMenuBarResidencyFooterNotResident: String { t("settings.menuBarResidencyFooterNotResident") }
    /// メニューバー常駐（ウインドウ非表示）時の詳細フッター説明。
    internal static var settingsMenuBarResidencyFooterResidentHidden: String { t("settings.menuBarResidencyFooterResidentHidden") }
    /// メニューバー常駐（ウインドウ表示）時の詳細フッター説明。
    internal static var settingsMenuBarResidencyFooterResidentVisible: String { t("settings.menuBarResidencyFooterResidentVisible") }
    /// 「起動時自動更新」設定項目。
    internal static var settingsUpdateOnBoot: String { t("settings.updateOnBoot") }
    /// 「自動更新を有効化」設定項目。
    internal static var settingsAutoUpdate: String { t("settings.autoUpdate") }
    /// 「更新時間間隔」設定項目。
    internal static var settingsAutoUpdateInterval: String { t("settings.autoUpdateInterval") }
    internal static var settingsAutoUpdateIntervalDailyHistoryFooter: String { t("settings.autoUpdateIntervalDailyHistoryFooter") }
    /// 「最終自動更新実行時間」表示。
    internal static var settingsAutoUpdateLast: String { t("settings.autoUpdateLast") }
    /// 「次回自動更新予定時間」表示。
    internal static var settingsAutoUpdateNext: String { t("settings.autoUpdateNext") }
    /// 「次回自動更新予定時間」の選択案内。
    internal static var settingsAutoUpdateNextHint: String { t("settings.autoUpdateNextHint") }
    /// 「システム通知設定を開く」項目。
    internal static var settingsSystemAppSettings: String { t("settings.systemAppSettings") }
    /// 「端末側の通知制御画面にジャンプします」説明。
    internal static var settingsSystemAppSettingsDesc: String { t("settings.systemAppSettingsDesc") }
    /// 通知のシステム連携フッター説明。
    internal static var settingsSystemAppSettingsFooter: String { t("settings.systemAppSettingsFooter") }
    /// 通知の機能詳細フッター説明。
    internal static var settingsShowNotificationFooter: String { t("settings.showNotificationFooter") }
    /// macOSにおける通知の機能詳細フッター説明。
    internal static var settingsShowNotificationFooterMacos: String { t("settings.showNotificationFooterMacos") }
    /// 通知許可が拒否されている旨の警告。
    internal static var settingsNotificationDenied: String { t("settings.notificationDenied") }
    /// 起動時更新の詳細フッター説明。
    internal static var settingsUpdateOnBootFooter: String { t("settings.updateOnBootFooter") }
    /// macOSにおける起動時更新の詳細フッター説明。
    internal static var settingsUpdateOnBootFooterMacos: String { t("settings.updateOnBootFooterMacos") }
    /// 自動更新の詳細フッター説明。
    internal static var settingsAutoUpdateFooter: String { t("settings.autoUpdateFooter") }
    /// macOSにおける自動更新の詳細フッター説明。
    internal static var settingsAutoUpdateFooterMacos: String { t("settings.autoUpdateFooterMacos") }
    /// iOSにおける自動更新予定日時の補足説明フッター。
    internal static var settingsAutoUpdateNextFooterIos: String { t("settings.autoUpdateNextFooterIos") }
    /// 自動更新時刻選択ダイアログの「日付」ラベル。
    internal static var settingsAutoUpdateNextDialogDate: String { t("settings.autoUpdateNextDialogDate") }
    /// 自動更新時刻選択ダイアログの「時刻」ラベル。
    internal static var settingsAutoUpdateNextDialogTime: String { t("settings.autoUpdateNextDialogTime") }
    /// 選択した自動更新予定時刻がポリシー違反の場合の警告。
    internal static func settingsAutoUpdateNextTimingWarning(_ minDate: String) -> String {
        f("settings.autoUpdateNextTimingWarning", minDate)
    }
    /// 状況表示ラベル。
    internal static var dialogStateLabel: String { t("settings.dialogStateLabel") }
    /// メッセージ編集用テキストラベル。
    internal static var dialogMessageLabel: String { t("settings.dialogMessageLabel") }
    /// 入力メッセージが全角1文字または半角1文字である必要性のエラー。
    internal static var dialogErrorOneCharOnly: String { t("settings.dialogErrorOneCharOnly") }
    /// 「初期値に戻す」ボタン。
    internal static var dialogReset: String { t("settings.dialogReset") }
    /// 「設定を保存」ボタン。
    internal static var dialogSave: String { t("settings.dialogSave") }
    /// 「キャンセル」ボタン。
    internal static var dialogCancel: String { t("settings.dialogCancel") }
    /// 「OK」ボタン。
    internal static var dialogOK: String { t("settings.dialogOK") }
    /// 個別の削除オプション。
    internal static var resetOptionDelete: String { t("settings.resetOptionDelete") }
    /// 早明浦ダムの初期値を採用するオプション。
    internal static var resetOptionSameura: String { t("settings.resetOptionSameura") }
    /// 貯水率メッセージリセット確認。
    internal static var resetStorageRateMessagesPrompt: String { t("settings.resetStorageRateMessagesPrompt") }
    /// 早明浦ダム専用の初期値にリセットする確認ラベル。
    internal static var resetStorageRateMessagesSameura: String { t("settings.resetStorageRateMessagesSameura") }
    /// 英語表記の初期値にリセットする確認ラベル。
    internal static var resetStorageRateMessagesNonJa: String { t("settings.resetStorageRateMessagesNonJa") }
    /// 貯水率メッセージリセット確認タイトル。
    internal static var resetStorageRateMessagesConfirmTitle: String { t("settings.resetStorageRateMessagesConfirmTitle") }
    /// 貯水率メッセージリセット確認メッセージ。
    internal static var resetStorageRateMessagesConfirmMessage: String { t("settings.resetStorageRateMessagesConfirmMessage") }
    /// その他メッセージリセット確認タイトル。
    internal static var resetOtherMessagesConfirmTitle: String { t("settings.resetOtherMessagesConfirmTitle") }
    /// その他メッセージリセット確認メッセージ。
    internal static var resetOtherMessagesConfirmMessage: String { t("settings.resetOtherMessagesConfirmMessage") }
    /// 次回実行日時に関する設定ポリシー警告。
    internal static var nextTimingWarning: String { t("settings.nextTimingWarning") }
    /// 貯水率帯メッセージ (Sameura Dam/早明浦ダム)設定セクション。
    internal static var settingsMessagesSameura: String { t("settings.messagesSameura") }
    /// 貯水率帯メッセージ (早明浦ダム用)設定セクションタイトル。
    internal static var settingsStorageMessagesSameuraTitle: String { t("settings.storageMessagesSameuraTitle") }
    /// 貯水率帯メッセージ (早明浦ダム以外用)設定セクションタイトル。
    internal static var settingsStorageMessagesOtherTitle: String { t("settings.storageMessagesOtherTitle") }
    /// 早明浦ダム以外のすべての貯水率メッセージをリセットするボタン。
    internal static var resetOtherStorageRateMessages: String { t("settings.resetOtherStorageRateMessages") }
    /// 早明浦ダム以外の貯水率メッセージリセット確認タイトル。
    internal static var resetOtherStorageRateMessagesConfirmTitle: String { t("settings.resetOtherStorageRateMessagesConfirmTitle") }
    /// 早明浦ダム以外の貯水率メッセージリセット確認メッセージ。
    internal static var resetOtherStorageRateMessagesConfirmMessage: String { t("settings.resetOtherStorageRateMessagesConfirmMessage") }
    /// 貯水率帯メッセージ (その他のダム)設定セクション。
    internal static var settingsMessagesOther: String { t("settings.messagesOther") }
    /// その他の状態メッセージ設定セクション。
    internal static var settingsOtherMessages: String { t("settings.otherMessages") }
    /// 「データ読み込み失敗時」のメッセージ設定。
    internal static var settingsLoadingErrorMessage: String { t("settings.loadingErrorMessage") }
    /// 「全データ欠測時」のメッセージ設定。
    internal static var settingsAllAbnormalMessage: String { t("settings.allAbnormalMessage") }
    /// 「配信停止・対象外時」のメッセージ設定。
    internal static var settingsAllDataInvalidMessage: String { t("settings.allDataInvalidMessage") }
    /// 「初期ロード未完了時」のメッセージ設定。
    internal static var settingsInitialMessage: String { t("settings.initialMessage") }
    /// 「通信切断時」のメッセージ設定。
    internal static var settingsNetworkUnavailableMessage: String { t("settings.networkUnavailableMessage") }
    /// 「配信停止検知時」のメッセージ設定。
    internal static var settingsDataDistributionStoppedMessage: String { t("settings.dataDistributionStoppedMessage") }
    /// 「配信再開検知時」のメッセージ設定。
    internal static var settingsDataDistributionResumedMessage: String { t("settings.dataDistributionResumedMessage") }
    /// 状況区分表示。
    internal static var stateLabel: String { t("settings.stateLabel") }
    /// メッセージ本文表示。
    internal static var messageLabel: String { t("settings.messageLabel") }
    /// 「すべてのメッセージをリセット」ボタン。
    internal static var resetAllMessages: String { t("settings.resetAllMessages") }
    /// 「すべてのその他メッセージをリセット」ボタン。
    internal static var resetAllOtherMessages: String { t("settings.resetAllOtherMessages") }
    /// ダム選択設定の項目タイトル。
    internal static var settingsDamName: String { t("settings.damName") }
    /// 「リアルタイムデータ」データソース項目。
    internal static var settingsDataSourceRealtime: String { t("settings.dataSourceRealtime") }
    /// リアルタイムデータ取得ソース: sudmonitor 中継。
    internal static var settingsDataSourceRealtimeSudmonitor: String { t("settings.dataSourceRealtimeSudmonitor") }
    /// リアルタイムデータ取得ソース: 国土交通省 (MLIT) 直接取得。
    internal static var settingsDataSourceRealtimeMlit: String { t("settings.dataSourceRealtimeMlit") }
    /// リアルタイムデータ取得ソースの説明（sudmonitor 選択時）。
    internal static func settingsDataSourceRealtimeHelpSudmonitor(_ host: String) -> String {
        f("settings.dataSourceRealtimeHelpSudmonitor", host)
    }
    /// リアルタイムデータ取得ソースの説明（MLIT 選択時）。
    internal static var settingsDataSourceRealtimeHelpMlit: String { t("settings.dataSourceRealtimeHelpMlit") }
    /// 「過去データ」データソース項目。
    internal static var settingsDataSourceHistorical: String { t("settings.dataSourceHistorical") }
    /// 過去データ取得ソースの固定表示値。
    internal static var settingsDataSourceHistoricalValue: String { t("settings.dataSourceHistoricalValue") }
    /// 過去データ取得ソースの説明（sudmonitor 選択時）。
    internal static func settingsDataSourceHistoricalHelpSudmonitor(_ host: String) -> String {
        f("settings.dataSourceHistoricalHelpSudmonitor", host)
    }
    /// 過去データ取得ソースの説明（MLIT 選択時）。
    internal static var settingsDataSourceHistoricalHelpMlit: String { t("settings.dataSourceHistoricalHelpMlit") }
    /// sudmonitor 選択時のダム固定説明。
    internal static var settingsDataSourceDamLocked: String { t("settings.dataSourceDamLocked") }
    /// データソース切替確認ダイアログのタイトル。
    internal static var settingsDataSourceSwitchConfirmTitle: String { t("settings.dataSourceSwitchConfirmTitle") }
    /// データソース切替確認ダイアログの本文。
    internal static var settingsDataSourceSwitchConfirmMessage: String { t("settings.dataSourceSwitchConfirmMessage") }
    /// データソース切替確認ダイアログの確定ボタン。
    internal static var settingsDataSourceSwitchConfirmAction: String { t("settings.dataSourceSwitchConfirmAction") }
    /// ダム一覧の選択画面タイトル。
    internal static var damSelectionTitle: String { t("damSelection.title") }
    /// ダム変更を確定する「選択」ボタン。
    internal static var damSelectionSelectAction: String { t("damSelection.selectAction") }
    /// 「現在選択中」のアクセシビリティ読み上げテキスト。
    internal static var currentlySelected: String { t("accessibility.currentlySelected") }
    /// 「デバッグモードを有効にする」トグルラベル。
    internal static var settingsDebugMode: String { t("settings.debugMode") }
    /// 「通信シミュレーション」項目。
    internal static var settingsDebugSimulateMode: String { t("settings.debugSimulateMode") }
    /// シミュレーション無効。
    internal static var simulateNone: String { t("settings.simulateNone") }
    /// シミュレートされたネットワーク不通。
    internal static var simulateNetworkUnavailable: String { t("settings.simulateNetworkUnavailable") }
    /// シミュレートされた読み込みエラー。
    internal static var simulateLoadingFailure: String { t("settings.simulateLoadingFailure") }
    /// リアルタイムデータDATファイルのエクスポートボタン。
    internal static var exportRealtimeDat: String { t("settings.exportRealtimeDat") }
    /// 過去データ(日次)DATファイルのエクスポートボタン。
    internal static var exportHistoricalDailyDat: String { t("settings.exportHistoricalDailyDat") }
    /// 書き出しDATのエンコード指定確認。
    internal static var exportDebugDatEncodingPrompt: String { t("settings.exportDebugDatEncodingPrompt") }
    /// DATの元の文字エンコードのまま書き出す。
    internal static var exportDebugDatRaw: String { t("settings.exportDebugDatRaw") }
    /// DATをUTF-8に変換して書き出す。
    internal static var exportDebugDatUTF8: String { t("settings.exportDebugDatUTF8") }
    /// 書き出すキャッシュが存在しない警告。
    internal static var exportDebugDatNoData: String { t("settings.exportDebugDatNoData") }
    /// 履歴テーブルヘッダータイトル。
    internal static var fullHistory: String { t("main.fullHistory") }
    /// 「すべての観測履歴を表示」ボタン。
    internal static var showFullHistory: String { t("main.showFullHistory") }
    /// ログが空である旨の表示。
    internal static var debugLogEmpty: String { t("settings.debugLogEmpty") }
    /// ログ削除の確認タイトル。
    internal static var debugLogDeleteTitle: String { t("settings.debugLogDeleteTitle") }
    /// リアルタイムデータ用のデバッグDATソース設定項目。
    internal static var settingsDebugRealtimeDatFile: String { t("settings.debugRealtimeDatFile") }
    /// 過去データ(日次)用のデバッグDATソース設定項目。
    internal static var settingsDebugHistoricalDailyDatFile: String { t("settings.debugHistoricalDailyDatFile") }
    /// デバッグDATファイルの利用なし。
    internal static var settingsDebugDatNone: String { t("settings.debugDatNone") }
    /// 「アセットバンドルのデバッグ用DAT」を使用。
    internal static var debugDatFileBundled: String { t("settings.debugDatFileBundled") }
    /// Debug Mode ON直前のリアルタイムDATを使用。
    internal static var debugDatFileLatestRealtime: String { t("settings.debugDatFileLatestRealtime") }
    /// Debug Mode ON直前の過去データ(日次)DATを使用。
    internal static var debugDatFileLatestHistoricalDaily: String { t("settings.debugDatFileLatestHistoricalDaily") }
    /// ユーザーが選択したリアルタイムDATを使用。
    internal static var debugDatFileUserSelectedRealtime: String { t("settings.debugDatFileUserSelectedRealtime") }
    /// ユーザーが選択した過去データDATを使用。
    internal static var debugDatFileUserSelectedHistorical: String { t("settings.debugDatFileUserSelectedHistorical") }
    /// リアルタイムデータのテスト動作期間設定項目。
    internal static var debugRealtimeDataPeriod: String { t("settings.debugRealtimeDataPeriod") }
    /// 全データ期間を使用（絞り込みなし）。
    internal static var debugDataPeriodAll: String { t("settings.debugDataPeriodAll") }
    /// テスト対象範囲を手動で絞り込む。
    internal static var debugDataPeriodCustom: String { t("settings.debugDataPeriodCustom") }
    /// テスト動作期間「開始日時」表示。
    internal static var debugDataPeriodStartTime: String { t("settings.debugDataPeriodStartTime") }
    /// テスト動作期間「終了日時（進行対象）」項目。
    internal static var debugDataPeriodEndDate: String { t("settings.debugDataPeriodEndDate") }
    /// テスト動作期間「終了時刻」項目。
    internal static var debugDataPeriodEndTime: String { t("settings.debugDataPeriodEndTime") }
    /// 「テスト期間の適用」ボタン。
    internal static var debugDataPeriodSetButton: String { t("settings.debugDataPeriodSetButton") }
    /// リアルタイムデータ期間の自動進行トグル。
    internal static var debugRealtimeDataPeriodAutoAdvance: String { t("settings.debugRealtimeDataPeriodAutoAdvance") }
    /// 「すべてのデバッグ機能を無効化する」ボタン。
    internal static var disableDebug: String { t("settings.disableDebug") }
    /// ログ削除の確認メッセージ。
    internal static var debugLogDeleteMessage: String { t("settings.debugLogDeleteMessage") }
    /// 「デバッグ設定が無効化されました」通知。
    internal static var debugSettingsDisabled: String { t("settings.debugSettingsDisabled") }
    /// 「デバッグ設定が有効化されました」通知。
    internal static var debugSettingsEnabled: String { t("settings.debugSettingsEnabled") }
    /// 「戻る」テキスト。
    internal static var back: String { t("common.back") }
    /// 「検索履歴の管理」タイトル。
    internal static var historicalManageTitle: String { t("historical.manage.title") }
    /// 検索履歴が存在しない場合の表示。
    internal static var historicalManageEmpty: String { t("historical.manage.empty") }
    /// 個別の履歴削除の確認タイトル。
    internal static var historicalManageDeleteTitle: String { t("historical.manage.deleteTitle") }
    /// 個別の履歴削除の確認メッセージ。
    internal static var historicalManageDeleteMessage: String { t("historical.manage.deleteMessage") }
    /// すべての履歴削除の確認タイトル。
    internal static var historicalManageDeleteAllTitle: String { t("historical.manage.deleteAllTitle") }
    /// すべての履歴削除の確認メッセージ。
    internal static var historicalManageDeleteAllMessage: String { t("historical.manage.deleteAllMessage") }
    /// 「ピン留め」アクション。
    internal static var historicalManagePin: String { t("historical.manage.pin") }
    /// 「ピン留め解除」アクション。
    internal static var historicalManageUnpin: String { t("historical.manage.unpin") }
    /// ピン留めの最大上限数に達した際のエラー警告。
    internal static var historicalManagePinLimit: String { t("historical.manage.pinLimit") }
    /// 「開く」ボタン。
    internal static var open: String { t("common.open") }
    /// トレンド上昇テキスト。
    internal static var trendUp: String { t("trend.up") }
    /// トレンド下降テキスト。
    internal static var trendDown: String { t("trend.down") }
    /// トレンド横ばいテキスト。
    internal static var trendFlat: String { t("trend.flat") }
    /// トレンド不明テキスト。
    internal static var trendUnknown: String { t("trend.unknown") }

    /// バージョンおよびビルド番号をフォーマットしてダイアログ文字列を作成します。
    /// - Parameters:
    ///   - version: バージョン名。
    ///   - build: ビルド番号。
    /// - Returns: フォーマット後のバージョン表示。
    internal static func dialogVersionFormat(_ version: String, _ build: String) -> String {
        f("dialog.version.format", version, build)
    }

    /// クールダウン期間中の手動更新ブロック警告テキストを構築します。
    /// - Parameter time: 更新が可能になる時刻文字列。
    /// - Returns: 警告文。
    internal static func mainRefreshTooEarly(_ time: String) -> String {
        f("main.refreshTooEarly.format", time)
    }

    /// 自動更新有効時の（初回実行案内）テキストを構築します。
    /// - Parameters:
    ///   - interval: 自動更新の実行間隔。
    ///   - next: 次回の予定日時。
    /// - Returns: 案内文。
    internal static func mainAutorenewEnabledFirst(interval: String, next: String) -> String {
        f("main.autorenewEnabledFirst.format", interval, next)
    }

    /// 自動更新有効時の（最終実行記録付き）案内テキストを構築します。
    /// - Parameters:
    ///   - interval: 自動更新の実行間隔。
    ///   - last: 最後の自動更新日時。
    /// - Returns: 案内文。
    internal static func mainAutorenewEnabledWithLast(interval: String, last: String) -> String {
        f("main.autorenewEnabledWithLast.format", interval, last)
    }

    /// デバッグ用のテスト動作データ期間を表示するためのノート文字列を構築します。
    /// - Parameters:
    ///   - start: テストデータ期間の開始日時。
    ///   - end: テストデータ期間の終了日時。
    /// - Returns: 設定ノートテキスト。
    internal static func debugDataPeriodNote(_ start: String, _ end: String) -> String {
        f("settings.debugDataPeriodNote.format", start, end)
    }

    /// リアルタイム観測データ (Real-time observation data) 画面のナビゲーションタイトル。
    internal static func titleRealtimeData() -> String {
        t("main.titleRealtimeData.format")
    }

    /// 過去データ検索 (Historical data search) 結果画面のナビゲーションタイトル。
    internal static func titleHistoricalData() -> String {
        t("main.titleHistoricalData.format")
    }

    /// 履歴データ読み込みの基準日案内テキストを構築します。
    /// - Parameter date: 基準となる日付文字列。
    /// - Returns: 案内テキスト。
    internal static func mainHistoryLoadDate(_ date: String) -> String {
        f("main.historyLoadDate.format", date)
    }

    /// 出典のクレジット表示に日付情報を加えてフォーマットします。
    /// - Parameter date: 取得したデータの日時表記。
    /// - Returns: 出典クレジット文字列。
    internal static func navSourceCredit(_ date: String) -> String {
        f("nav.sourceCredit.format", date)
    }

    /// 過去データ検索時の指定可能範囲ノート文字列を構築します。
    /// - Parameters:
    ///   - start: 指定可能な最古の日。
    ///   - endNextDay: システム上の最新日（翌日表現）。
    /// - Returns: 検索時の注意書きテキスト。
    internal static func historicalSearchPeriodNote(start: String, endNextDay: String) -> String {
        f("historical.search.periodNote.format", start, endNextDay)
    }

    /// メッセージ編集ダイアログのタイトルを構築します。
    /// - Parameter name: 設定する貯水率状態または異常値状態のラベル名。
    /// - Returns: 編集用ダイアログのタイトル。
    internal static func dialogSetTitle(_ name: String) -> String {
        f("settings.dialogSetTitle.format", name)
    }

    /// 貯水率メッセージ編集ダイアログ用のタイトル。
    internal static var dialogSetTitleStorage: String { t("dialogSetTitleStorage") }
    /// その他メッセージ編集ダイアログ用のタイトル。
    internal static var dialogSetTitleOther: String { t("dialogSetTitleOther") }
    /// 編集ダイアログでの日本語メッセージ入力のラベル。
    internal static var dialogMessageJaLabel: String { t("dialogMessageJaLabel") }
    /// 編集ダイアログでの英語メッセージ入力のラベル。
    internal static var dialogMessageNonJaLabel: String { t("dialogMessageNonJaLabel") }
    /// 貯水率メッセージを表示する設定項目の表示ラベル。
    internal static var settingsShowStorageMessage: String { t("settings.showStorageMessage") }
    /// 貯水率メッセージを表示する項目の詳細説明。
    internal static var settingsShowStorageMessageDesc: String { t("settings.showStorageMessageDesc") }
    /// 「貯水率データがありません」表示テキスト。
    internal static var settingsNoStorageData: String { t("settings.noStorageData") }
    /// 日本語デフォルトメッセージ（貯水率 80-100%）。
    internal static var storageDefaultMsgJa80_100: String { t("storage.defaultMsg.ja.80_100") }
    /// 日本語デフォルトメッセージ（貯水率 60-80%）。
    internal static var storageDefaultMsgJa60_80: String { t("storage.defaultMsg.ja.60_80") }
    /// 日本語デフォルトメッセージ（貯水率 40-60%）。
    internal static var storageDefaultMsgJa40_60: String { t("storage.defaultMsg.ja.40_60") }
    /// 日本語デフォルトメッセージ（貯水率 20-40%）。
    internal static var storageDefaultMsgJa20_40: String { t("storage.defaultMsg.ja.20_40") }
    /// 日本語デフォルトメッセージ（貯水率 0-20%）。
    internal static var storageDefaultMsgJa0_20: String { t("storage.defaultMsg.ja.0_20") }
    /// 日本語デフォルトメッセージ（貯水率 0%）。
    internal static var storageDefaultMsgJa0: String { t("storage.defaultMsg.ja.0") }
    /// 英語デフォルトメッセージ（貯水率 80-100%）。
    internal static var storageDefaultMsgNonJa80_100: String { t("storage.defaultMsg.nonJa.80_100") }
    /// 英語デフォルトメッセージ（貯水率 60-80%）。
    internal static var storageDefaultMsgNonJa60_80: String { t("storage.defaultMsg.nonJa.60_80") }
    /// 英語デフォルトメッセージ（貯水率 40-60%）。
    internal static var storageDefaultMsgNonJa40_60: String { t("storage.defaultMsg.nonJa.40_60") }
    /// 英語デフォルトメッセージ（貯水率 20-40%）。
    internal static var storageDefaultMsgNonJa20_40: String { t("storage.defaultMsg.nonJa.20_40") }
    /// 英語デフォルトメッセージ（貯水率 0-20%）。
    internal static var storageDefaultMsgNonJa0_20: String { t("storage.defaultMsg.nonJa.0_20") }
    /// 英語デフォルトメッセージ（貯水率 0%）。
    internal static var storageDefaultMsgNonJa0: String { t("storage.defaultMsg.nonJa.0") }
    /// 日本語デフォルトメッセージ（全データ異常・欠測）。
    internal static var storageDefaultMsgJaAllAbnormal: String { t("storage.defaultMsg.ja.allAbnormal") }
    /// 英語デフォルトメッセージ（全データ異常・欠測）。
    internal static var storageDefaultMsgNonJaAllAbnormal: String { t("storage.defaultMsg.nonJa.allAbnormal") }
    /// 日本語デフォルトメッセージ（配信停止・対象外）。
    internal static var storageDefaultMsgJaAllDataInvalid: String { t("storage.defaultMsg.ja.allDataInvalid") }
    /// 英語デフォルトメッセージ（配信停止・対象外）。
    internal static var storageDefaultMsgNonJaAllDataInvalid: String { t("storage.defaultMsg.nonJa.allDataInvalid") }
    /// 日本語デフォルトメッセージ（初期状態）。
    internal static var storageDefaultMsgJaInitial: String { t("storage.defaultMsg.ja.initial") }
    /// 英語デフォルトメッセージ（初期状態）。
    internal static var storageDefaultMsgNonJaInitial: String { t("storage.defaultMsg.nonJa.initial") }
    /// 日本語デフォルトメッセージ（通信切断・ネットワークエラー）。
    internal static var storageDefaultMsgJaNetworkUnavailable: String { t("storage.defaultMsg.ja.networkUnavailable") }
    /// 英語デフォルトメッセージ（通信切断・ネットワークエラー）。
    internal static var storageDefaultMsgNonJaNetworkUnavailable: String { t("storage.defaultMsg.nonJa.networkUnavailable") }
    /// 日本語デフォルトメッセージ（読み込み失敗・サーバーエラー）。
    internal static var storageDefaultMsgJaLoadingError: String { t("storage.defaultMsg.ja.loadingError") }
    /// 英語デフォルトメッセージ（読み込み失敗・サーバーエラー）。
    internal static var storageDefaultMsgNonJaLoadingError: String { t("storage.defaultMsg.nonJa.loadingError") }
    /// 日本語デフォルトメッセージ（配信停止検知）。
    internal static var storageDefaultMsgJaDataDistributionStopped: String { t("storage.defaultMsg.ja.dataDistributionStopped") }
    /// 英語デフォルトメッセージ（配信停止検知）。
    internal static var storageDefaultMsgNonJaDataDistributionStopped: String { t("storage.defaultMsg.nonJa.dataDistributionStopped") }
    /// 日本語デフォルトメッセージ（配信再開検知）。
    internal static var storageDefaultMsgJaDataDistributionResumed: String { t("storage.defaultMsg.ja.dataDistributionResumed") }
    /// 英語デフォルトメッセージ（配信再開検知）。
    internal static var storageDefaultMsgNonJaDataDistributionResumed: String { t("storage.defaultMsg.nonJa.dataDistributionResumed") }
    /// 英語表記メッセージ用のリセットオプションボタンテキスト。
    internal static var resetOptionNonJa: String { t("resetOptionNonJa") }
    /// 「その他メッセージのリセット」ボタン。
    internal static var resetOtherMessage: String { t("resetOtherMessage") }
}

/// 各種数値、単位、および日付・時刻表現を SwiftUI 等の表示向けにフォーマットするユーティリティ。
internal enum DisplayFormatters {
    /// 日本語ロケール判定。
    internal static var isJapanese: Bool { AppText.isJapanese }
    /// システムが日本標準時（JST）の環境にあるか判定（オフセット比較。"Etc/GMT-9"等もJST扱い）。
    internal static var isJST: Bool { DamCoreJSTSupport.isJst(TimeZone.current) }

    /// ダム設定に基づく、ローライズ表示名を決定して返します（例: 日本語なら「早明浦ダム」、英語なら「Sameura Dam 早明浦ダム」など）。
    /// - Parameter dam: 対象のダム設定。
    /// - Returns: UIに表示する最適なダム表記名。
    internal static func localizedDamName(_ dam: DamConfig?) -> String {
        guard let dam else { return isJapanese ? "早明浦ダム" : "Sameura Dam 早明浦ダム" }
        return isJapanese ? dam.nameJa : "\(dam.nameEn) \(dam.nameJa)".trimmingCharacters(in: .whitespaces)
    }

    /// 貯水率 (Storage rate) などの割合数値を `%` 単位付き文字列にフォーマットします。
    /// - Parameter value: 割合の浮動小数点数値。
    /// - Returns: フォーマット済みのパーセンテージ文字列。
    internal static func percent(_ value: Float?) -> String {
        guard let value else { return "-- %" }
        return String(format: "%.2f%%", value)
    }

    /// 割合の数値を小数点第2位までの文字列表記に変換します。
    /// - Parameter number: 割合。
    /// - Returns: フォーマット文字列。
    internal static func percentValue(_ number: Float?) -> String {
        Self.value(number, decimals: 2)
    }

    /// 浮動小数点数値を、指定された小数桁でフォーマットします。
    /// - Parameters:
    ///   - value: 数値。
    ///   - decimals: 表示する小数点以下の桁数。デフォルトは `0`（整数化）です。
    /// - Returns: フォーマット後のテキスト。
    internal static func value(_ value: Float?, decimals: Int = 0) -> String {
        guard let value else { return "--" }
        if decimals == 0 {
            return String(Int(value))
        }
        return String(format: "%.\(decimals)f", value)
    }

    /// 雨量（流域平均雨量）の数値をフォーマットします（小数点第1位）。
    /// - Parameter value: 雨量のミリ数。
    /// - Returns: フォーマットされた文字列。
    internal static func rainfall(_ value: Float?) -> String {
        guard let value else { return "--" }
        return String(format: "%.1f", value)
    }

    /// 差分数値（日差、週差など）に対して正負符号付き表記でフォーマットします（例: "+1.25", "-0.50"）。
    /// - Parameter value: 差分数値。
    /// - Returns: 符号付きのフォーマット文字列。
    internal static func change(_ value: Float?) -> String {
        guard let value else { return "--" }
        return String(format: "%+.2f", value)
    }

    /// 前日比・前週比を符号とパーセント単位付きで表示する。
    internal static func changePercent(_ value: Float?) -> String {
        guard let value else { return "-- %" }
        return String(format: "%+.2f%%", value)
    }

    /// アプリ設定でカスタマイズされている文言マッピングに基づいて、ダムの現在の状態説明テキストを取得します。
    /// - Parameters:
    ///   - settings: アプリ設定。
    ///   - percentage: 貯水率 (Storage rate)。
    ///   - isAllDataInvalid: 全データが無効であるかどうかのフラグ。
    ///   - isSameura: 早明浦ダム用の分類を行うかどうか。
    ///   - storageVolumeForMessage: 欠測前の最新正常貯水量 (Storage volume)。nil は不明扱い。
    /// - Returns: 表示するステータステキスト。
    internal static func statusText(
        settings: AppSettings,
        percentage: Float?,
        isAllDataInvalid: Bool = false,
        isSameura: Bool = false,
        storageVolumeForMessage: Float? = nil
    ) -> String {
        let isJa = AppLocale.isJapanese
        let pair = settings.storageRateMessage(
            for: percentage,
            isJapanese: isJa,
            isAllDataInvalid: isAllDataInvalid,
            isSameura: isSameura,
            storageVolumeForMessage: storageVolumeForMessage
        )
        return settings.displayText(state: pair.0, message: pair.1)
    }

    /// トレンド状態を表現する SF Symbols のシンボル名を取得します。
    /// - Parameter trend: トレンド種別。
    /// - Returns: システムイメージの名称。
    internal static func trendSystemImage(_ trend: Trend) -> String {
        switch trend {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .flat: return "arrow.right"
        case .unknown: return "minus"
        }
    }

    /// Widgetと同じトレンド記号を返す。不明な場合は空文字列とする。
    internal static func trendGlyph(_ trend: Trend) -> String {
        switch trend {
        case .up: return "↗"
        case .down: return "↘"
        case .flat: return "→"
        case .unknown: return ""
        }
    }

    /// トレンド状態の日本語/英語のアクセシビリティ用・表示用説明を取得します。
    /// - Parameter trend: トレンド種別。
    /// - Returns: ローカライズされた説明テキスト。
    internal static func trendLabel(_ trend: Trend) -> String {
        switch trend {
        case .up: return AppText.trendUp
        case .down: return AppText.trendDown
        case .flat: return AppText.trendFlat
        case .unknown: return AppText.trendUnknown
        }
    }

    /// トレンド表示にトレンドカラー（赤・青）を適用すべきかどうかを判定します。
    /// - Parameter trend: トレンド種別。
    /// - Returns: 適用対象である（上昇・下降）の場合は `true`。
    internal static func usesTrendColor(_ trend: Trend) -> Bool {
        trend == .up || trend == .down
    }

    /// トレンドに対応する表示色を返します（上昇:赤、下降:青、その他:標準色）。
    /// - Parameter trend: トレンド種別。
    /// - Returns: SwiftUI の `Color`。
    internal static func trendColor(_ trend: Trend) -> Color {
        switch trend {
        case .up: return .red
        case .down: return .blue
        case .flat, .unknown: return .primary
        }
    }

    /// ダム時間表記の日時文字列をフォーマットします。ローカルが日本時間外であれば "(JST)" サフィックスを加えます。
    /// - Parameters:
    ///   - text: ダム時間文字列。
    ///   - withJSTSuffix: JSTのサフィックス表記を有効にするかどうか。
    /// - Returns: フォーマット後の日時文字列。
    internal static func damDateTime(_ text: String?, withJSTSuffix: Bool = true) -> String {
        guard let text, !text.isEmpty else { return "--" }
        let normalized = TimeFormatters.normalizeDamTime(text)
        guard let date = TimeFormatters.jstDisplay.date(from: normalized) else { return text }
        let base = TimeFormatters.jstDisplay.string(from: date)
        return withJSTSuffix ? DamCoreJSTSupport.appendingJstSuffix(base, isLocalJst: isJST) : base
    }

    /// 日時のうち時刻部分（"HH:mm"）のみを切り出してフォーマットします。
    /// - Parameter text: ダム時間文字列。
    /// - Returns: フォーマット後の時刻文字列。
    internal static func damTime(_ text: String?) -> String {
        let full = damDateTime(text, withJSTSuffix: false)
        guard full != "--" else { return "--" }
        return DamCoreJSTSupport.appendingJstSuffix(String(full.suffix(5)), isLocalJst: isJST)
    }

    /// 履歴行向けの簡略化された日時表記（"MM/dd HH:mm"）にフォーマットします。
    /// - Parameter text: ダム時間文字列。
    /// - Returns: 簡略日時テキスト。
    internal static func historyRowDateTime(_ text: String?) -> String {
        guard let text, !text.isEmpty else { return "--" }
        let normalized = TimeFormatters.normalizeDamTime(text)
        guard let date = TimeFormatters.jstDisplay.date(from: normalized) else { return "--" }
        return TimeFormatters.historyRowMinute.string(from: date)
    }

    /// "yyyymmdd" 形式の連続数値文字列を "yyyy/MM/dd" に変換します。
    /// - Parameter yyyymmdd: 日付数字文字列。
    /// - Returns: スラッシュ区切り日付。
    internal static func slashDate(_ yyyymmdd: String) -> String {
        guard yyyymmdd.count == 8 else { return yyyymmdd }
        let year = yyyymmdd.prefix(4)
        let monthStart = yyyymmdd.index(yyyymmdd.startIndex, offsetBy: 4)
        let dayStart = yyyymmdd.index(yyyymmdd.startIndex, offsetBy: 6)
        return "\(year)/\(yyyymmdd[monthStart..<dayStart])/\(yyyymmdd[dayStart...])"
    }

    /// 与えられた日付の「翌日」を "yyyy/MM/dd" 形式にフォーマットして返します。
    /// - Parameter yyyymmdd: 日付数字文字列。
    /// - Returns: 翌日のスラッシュ区切り日付。
    internal static func nextDaySlashDate(_ yyyymmdd: String) -> String {
        guard let date = TimeFormatters.jstDay.date(from: yyyymmdd),
              let next = Calendar.jst.date(byAdding: .day, value: 1, to: date) else {
            return slashDate(yyyymmdd)
        }
        return displayDate(next)
    }

    /// 指定された日付を JST 基準の "yyyy/MM/dd" 形式にフォーマットします。
    /// - Parameter date: 日付オブジェクト。
    /// - Returns: フォーマットされた日付。
    internal static func displayDate(_ date: Date) -> String {
        TimeFormatters.jstDateSlash.string(from: date)
    }

    /// 指定された日付を JST 基準の簡略月日 "MM/dd" 形式にフォーマットします。
    /// - Parameter date: 日付オブジェクト。
    /// - Returns: 簡略月日テキスト。
    internal static func compactMonthDay(_ date: Date) -> String {
        String(TimeFormatters.historyRowMinute.string(from: date).prefix(5))
    }

    /// 過去データ検索 (Historical data search) 用の日付文字列キー（"yyyyMMdd"）を生成します。
    /// - Parameter date: 対象の日付。
    /// - Returns: 検索用日付キー文字列。
    internal static func searchDate(_ date: Date) -> String {
        TimeFormatters.jstDay.string(from: startOfJSTDay(date))
    }

    /// 指定された日時の日本標準時（JST）における一日の開始時間（00:00:00）を取得します。
    /// - Parameter date: 対象日時。
    /// - Returns: JSTでの同日開始時間日時。
    internal static func startOfJSTDay(_ date: Date) -> Date {
        Calendar.jst.startOfDay(for: date)
    }

    /// 前日の JST 開始時間日時を取得します。
    internal static func yesterdayStart() -> Date {
        Calendar.jst.date(byAdding: .day, value: -1, to: Calendar.jst.startOfDay(for: Date())) ?? Date()
    }

    /// 30日前の JST 開始時間日時を取得します。
    internal static func thirtyDaysAgoStart() -> Date {
        Calendar.jst.date(byAdding: .day, value: -30, to: Calendar.jst.startOfDay(for: Date())) ?? Date()
    }

    /// 過去検索履歴の期間範囲表記を構築します（例: "2026/06/17 01:00 - 2026/06/18 00:00"）。非JST環境では終端側にのみ "(JST)" を付与します。
    /// - Parameter meta: 過去検索メタデータ。
    /// - Returns: 期間表記テキスト。
    internal static func historicalPeriodLine(_ meta: HistoricalSearchMeta) -> String {
        DamCoreJSTSupport.appendingJstSuffix("\(slashDate(meta.searchBgnDate)) 01:00 - \(nextDaySlashDate(meta.searchEndDate)) 00:00", isLocalJst: isJST)
    }

    /// 過去データ検索 (Historical data search) 結果の貯水率 (Storage rate) の変化要約テキストを構築します（例: "50.00% → 60.00% (45.00% ~ 65.00%)"）。
    /// - Parameter meta: 過去検索メタデータ。
    /// - Returns: 変化要約文字列。
    internal static func historicalRangeLine(_ meta: HistoricalSearchMeta) -> String {
        guard let start = meta.dataStartStoragePct, let end = meta.dataEndStoragePct else { return "-- %" }
        let range: String
        if let min = meta.dataMinStoragePct, let max = meta.dataMaxStoragePct {
            range = " (\(percent(min)) ~ \(percent(max)))"
        } else {
            range = ""
        }
        return "\(percent(start)) → \(percent(end))\(range)"
    }

    /// sudmonitor 日次過去データの期間表記を構築します（例: "2026/07/15 01:00 - 2026/07/31 00:00"）。非JST環境では終端側にのみ "(JST)" を付与します。
    /// - Parameter record: 日次過去データレコード。
    /// - Returns: 期間表記テキスト。
    internal static func sudmonitorHistoryPeriodLine(_ record: SudmonitorHistoryRecord) -> String {
        DamCoreJSTSupport.appendingJstSuffix("\(slashDate(record.periodStartDay)) 01:00 - \(nextDaySlashDate(record.periodEndDay)) 00:00", isLocalJst: isJST)
    }

    /// sudmonitor 日次過去データの貯水率 (Storage rate) の変化要約テキストを構築します（例: "50.00% → 60.00% (45.00% ~ 65.00%)"）。
    /// - Parameter rows: 日次過去データの観測行（時刻昇順）。
    /// - Returns: 変化要約文字列。
    internal static func sudmonitorHistoryRangeLine(_ rows: [DamHistoricalData]) -> String {
        guard let start = rows.first?.storagePercentage, let end = rows.last?.storagePercentage else { return "-- %" }
        let range: String
        if let min = rows.compactMap(\.storagePercentage).min(), let max = rows.compactMap(\.storagePercentage).max() {
            range = " (\(percent(min)) ~ \(percent(max)))"
        } else {
            range = ""
        }
        return "\(percent(start)) → \(percent(end))\(range)"
    }
}
