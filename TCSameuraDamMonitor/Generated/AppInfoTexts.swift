// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

enum AppInfoTexts {
    static let license = #"""
    Copyright (C) 2026 tecogonaz

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
    """#

    static let termsOfUse = #"""
    **Last updated: September 5, 2026**

    > This English version is a translation of the Japanese original version. The Japanese original is the authoritative text. If there is any discrepancy or conflict between this English translation and the Japanese original, the Japanese original prevails.

    ## 1. Scope

    These Terms of Use ("Terms") set out the conditions for using **Sameura Dam Monitor** (Japanese name: 早明浦ダム 貯水率モニタ, the "App").

    By installing, launching, using, or obtaining the App from an official distribution source, you are deemed to have agreed to these Terms. If you do not agree to these Terms, do not use the App.

    These Terms define the conditions for using the App. They do not restrict the rights to use, reproduce, modify, distribute, or otherwise exercise rights in the source code, object code, derivative works, or redistributions granted under the Apache License, Version 2.0. Those materials are governed by **License** and **OSS Licenses**.

    ## 2. App Description

    The App retrieves dam data published through the Water Information System of the Ministry of Land, Infrastructure, Transport and Tourism of Japan ("MLIT") and displays the water storage rate and related data for 125 dams across Japan, including Sameura Dam.

    The App is an iOS / iPadOS / macOS app built with SwiftUI and related Apple frameworks. It is not an official app provided, approved, sponsored, or guaranteed by MLIT or any other government agency or third party. The App's display, name, icon, description, screenshots, and similar materials do not indicate any official affiliation with those agencies or services.

    The App is not an official source of information for disaster response, disaster prevention decisions, evacuation decisions, water intake or water use decisions, important business decisions, or decisions involving life, body, or property. When making important decisions, check official information from MLIT, local governments, the Japan Meteorological Agency, river administrators, news organizations, and other official sources.

    ## 3. Data Sources and Usage Notes

    The App retrieves and processes for display dam data published through MLIT's Water Information System.

    The App does not guarantee the accuracy, completeness, freshness, continuous provision, availability, or fitness for a particular purpose of the original data. Displayed content may not be current or accurate due to delays in original data updates, missing data, abnormal values, specification changes, publication suspension, communication failures, device conditions, OS power-saving controls, parsing failures, or similar causes.

    Displayed values, notifications, widgets, historical graphs, day-over-day changes, week-over-week changes, messages, and similar information in the App are for reference only. You use the App at your own responsibility.

    ## 4. Distribution Sources

    The official distribution sources for the App are the Releases pages of the development repositories, **Codeberg** (primary) and **GitHub** (mirror), and Apple's **TestFlight** service. Releases pages distribute ZIP archives containing the notarized macOS `.app`, while beta builds for iOS, iPadOS, and macOS are distributed through TestFlight.

    - Codeberg Releases: https://codeberg.org/tecogonaz0439/TCSameuraDamMonitor-apple/releases
    - GitHub Releases: https://github.com/tecogonaz0439/TCSameuraDamMonitor-apple/releases

    General availability of the iOS, iPadOS, and macOS versions on the Apple App Store is planned for a later date.

    If you obtain the App through TestFlight or the future Apple App Store, Apple's TestFlight and App Store terms, Apple Developer Program License Agreement, and other applicable Apple terms govern matters relating to acquisition, beta testing, distribution, updates, listing, suspension, refunds, and similar Apple-platform procedures. If these Terms conflict with Apple's terms regarding those procedures or functions, Apple's terms prevail for that scope.

    We do not guarantee the safety, completeness, authenticity, operation, updates, or support of versions obtained, modified, rebuilt, or redistributed by third parties outside official distribution channels.

    The official distribution version of the App currently does not provide paid sales, in-app purchases, advertisements, or subscriptions.

    ## 5. Open Source License

    The source code of the App is published under the Apache License, Version 2.0. You may use, reproduce, modify, and distribute the source code and object code in accordance with that license.

    The App uses multiple open source libraries under their respective licenses. Major dependencies included in the App are described in **OSS Licenses**.

    If you distribute a modified or derivative version using the App's name, icon, screens, description, repository information, developer name, attribution notices, or similar materials, do not mislead users into believing that it is an official version, approved version, or sponsored version of MLIT or any other third party. If you distribute a modified version, comply with the Apache License, Version 2.0, applicable laws, the terms of the distribution store, and third-party rights.

    If you submit Issues, Pull Requests, patches, translations, documentation, ideas, or other contributions to the source code repository, those contributions may be incorporated into the App under the Apache License, Version 2.0, unless expressly stated otherwise at the time of submission.

    ## 6. Privacy and On-Device Data

    The handling of data in the App is governed by the separate Privacy Policy.

    - Privacy Policy: see **Privacy Policy**

    The App does not require registration of a name, email address, or similar information, and it does not use device location APIs, device identifiers, advertising SDKs, usage-analytics SDKs, or a developer-operated crash-reporting SDK. It also does not automatically upload retrieved dam data, user preferences, or debug logs.

    The dam data originates from MLIT's Water Information System. The default network destination for both real-time and historical data is the cache server operated by the project developer (https://sudmonitor.kusugami-lab.net). The cache server provides real-time, daily historical, and monthly data used for historical searches. You can select direct retrieval from the MLIT origin server (https://www1.river.go.jp) independently for each data source, and historical searches may access that server directly when necessary.

    When the App communicates with the cache server, Cloudflare processes request metadata such as the source IP address, destination, request time, and User-Agent for service delivery, security, abuse prevention, and incident investigation. For TestFlight builds, Apple may process sessions, crashes, and feedback voluntarily submitted by users and may make that information available to the project developer. See the Privacy Policy for details and retention periods.

    The App stores dam data retrieved from MLIT (real-time data and historical data), user settings, debug logs, and similar data in its application storage. It does not automatically upload this data to an external server or provide its own cloud synchronization. Files managed by the App under Application Support are marked as excluded from backup where supported by the OS. Data in OS-managed SwiftData storage, standard UserDefaults, and App Group UserDefaults may, however, be included in iCloud Backup, device-to-device transfer, or other backup and migration functions provided by the OS. Stored data may also leave the device through sharing features in the App, screenshots, manual copying, sharing to external apps, or other user actions.

    The in-app deletion features can delete saved historical-search results and debug logs. To delete all local data, including daily historical data, uninstall the App on iOS or iPadOS. On macOS, deleting the `.app` file alone may leave containers or preferences behind; follow the complete reset procedure under "Uninstallation (macOS)" in the README. However, iCloud backups, copies created through device-to-device transfer, files shared or copied by you, and data passed to external apps may not be deletable from within the App.

    ## 7. Permissions, Notifications, and Background Updates

    The App communicates with the cache server or MLIT servers via HTTPS to retrieve dam data, checks network status, requests notification permission from the user, and performs background or scheduled data refreshes.

    On iOS / iPadOS, background refresh is performed at the discretion of the OS and may not execute at exact scheduled intervals. On macOS, the App primarily uses in-app timers and refresh on launch. Notifications, automatic updates, and widget updates are affected by OS specifications, device settings, network conditions, user settings, notification permissions, and background restrictions. The App does not guarantee that notifications or automatic updates will always run exactly at scheduled times.

    Debug logs are generated automatically for troubleshooting and stored in the App's storage. Exporting or sharing logs is performed by user action. You are responsible for checking the destination, save location, file contents, and whether disclosure to a third party is necessary.

    ## 8. External Services and Links

    The App may link to, launch, or share content with external services or external apps, including MLIT-related pages, map apps, browsers, OS sharing features, Codeberg, and GitHub.

    Use of external services or external apps is subject to the terms, privacy policies, and usage conditions of each provider. We are not responsible for the content, availability, accuracy, safety, changes, suspension, or results of use of external services or external apps.

    ## 9. User Responsibilities and Prohibited Acts

    You must use the App in compliance with applicable laws, these Terms, the terms of distribution sources, Apple's terms and conditions, third-party rights, and generally accepted social norms.

    You must not engage in the following acts.

    - Acts that violate laws, public order and morals, third-party rights, these Terms, or the terms of distribution sources
    - Acts that impose excessive load, cause failures, perform unauthorized access, or interfere with the App, MLIT public servers, the cache server, Codeberg, GitHub, external services, third-party devices, or networks
    - Acts that mislead users into believing that the App or a modified version is an official version, approved version, or sponsored version of MLIT or any other third party
    - Acts of using or distributing the App or a modified version for malware, unauthorized code, phishing, fraud, impersonation, false display, misleading display, or deception of users
    - Acts of presenting displayed data from the App as if it were official information and causing third parties to make incorrect important decisions
    - Other acts that we reasonably determine to be outside the normal scope of use of the App

    ## 10. Changes, Suspension, and Termination

    We may change the App's features, specifications, displays, supported OS versions, supported devices, distribution methods, distribution sources, repositories, documentation, Privacy Policy, or these Terms as necessary.

    We may suspend or terminate distribution, updates, provision, or support of the App due to changes in MLIT public data specifications, suspension of external services, changes in policies or terms of distribution platforms such as Codeberg/GitHub, changes in Apple App Store or Apple Developer Program policies, security reasons, maintenance, legal requirements, or other unavoidable circumstances.

    If these Terms are changed, the revised Terms take effect when published in the repository, in the App, on a distribution page, or by another method we deem appropriate. If you use the App after the change, you are deemed to have agreed to the revised Terms.

    ## 11. No Warranty

    The App is provided free of charge on an as-is and as-available basis. We do not warrant the App's accuracy, completeness, freshness, usefulness, availability, continuity, safety, absence of errors, fitness for a particular purpose, non-infringement of third-party rights, compatibility with devices or OS versions, storage or restoration of data, or reliable execution of notifications or automatic updates.

    You are responsible for handling any damage arising from use or inability to use the App, displayed data, missing data, incorrect display, update delays, notification delays, loss of on-device data, use of external services, acquisition or installation of executable files, or use of modified versions or third-party distributions.

    ## 12. Limitation of Liability

    To the maximum extent permitted by law, we are not liable for any damage suffered by you or any third party in connection with the App.

    Even if we cannot be exempt from liability under applicable law, except in cases of our willful misconduct or gross negligence, our liability is limited to ordinary and direct damages actually incurred. We are not liable for special, indirect, incidental, consequential damages, lost profits, data loss, business interruption, device failure, third-party claims, or damage caused by failure to check official information.

    ## 13. Use by Minors

    If a minor uses the App, the minor must obtain consent from a parent or other legal representative. If a minor uses the App, the minor is deemed to have obtained consent from the legal representative.

    ## 14. Governing Law and Jurisdiction

    The formation, validity, interpretation, performance, and disputes related to these Terms and the App are governed by the laws of Japan.

    If a dispute arises between us and a user in connection with these Terms or the App, the Takamatsu District Court has exclusive jurisdiction as the court of first instance.

    ## 15. Contact

    As a general rule, inquiries regarding these Terms, the App, the Privacy Policy, or licenses should be made through Issues in the source code repository (Codeberg).

    - Codeberg: https://codeberg.org/tecogonaz0439/TCSameuraDamMonitor-apple

    We do not guarantee individual responses, investigations, fixes, updates, or support for all inquiries.
    """#

    static let termsOfUseJa = #"""
    **最終更新日: 2026-09-05**

    ## 1. 適用

    本利用規約（以下「本規約」）は、**早明浦ダム 貯水率モニタ**(以下「本アプリ」)の利用条件を定めるものです。

    利用者は、本アプリをインストール、起動、利用、または公式配布元から取得した時点で、本規約に同意したものとみなされます。本規約に同意しない場合は、本アプリを利用しないでください。

    本規約は本アプリの利用条件を定めるものであり、Apache License, Version 2.0 により許諾されるソースコード、オブジェクトコード、派生物、再配布物の利用、複製、改変、配布その他の権利を制限するものではありません。これらの取扱いは、**本アプリのライセンス**、および **本アプリのOSSライセンス** に従います。

    ## 2. 本アプリの内容

    本アプリは、国土交通省の水文水質データベースで公開されるダム諸量データを取得し、早明浦ダムを含む日本国内 125 ダムの貯水率、および関連データを閲覧するための iOS / iPadOS / macOS アプリです。

    本アプリは、国土交通省を含む政府機関、またはその他の第三者が提供、承認、後援、保証する公式アプリではありません。本アプリ内の表示、アプリ名、アイコン、説明、スクリーンショット等は、これらの機関またはサービスとの公式な提携関係を示すものではありません。

    本アプリは、災害対応、防災判断、避難判断、取水・利水判断、業務上の重要判断、生命・身体・財産に関わる判断のための公式情報源ではありません。重要な判断を行う場合は、国土交通省、自治体、気象庁、河川管理者、報道機関等の公式情報を確認してください。

    ## 3. データの出典と利用上の注意

    本アプリは、国土交通省の水文水質データベースで公開されるダム諸量データを取得し、表示用に加工して作成します。

    本アプリは、原データの正確性、完全性、最新性、継続提供、可用性、特定目的への適合性を保証しません。原データの更新遅延、欠測、異常値、仕様変更、公開停止、通信障害、端末状態、OSの省電力制御、パース処理の失敗等により、表示内容が最新または正確でない場合があります。

    本アプリの表示値、通知、ウィジェット、履歴グラフ、前日比、前週比、メッセージ等は参考情報です。利用者は、自己の責任で本アプリを利用するものとします。

    ## 4. 配布元

    本アプリの公式配布元は、開発用リポジトリである **Codeberg**（メイン）および **GitHub**（ミラー）の Releases ページと、Apple の **TestFlight** です。Releases ページでは公証済みの macOS `.app` を収めた ZIP ファイルを直接配布し、TestFlight では iOS / iPadOS / macOS 向けのベータビルドを配布します。

    - Codeberg Releases: https://codeberg.org/tecogonaz0439/TCSameuraDamMonitor-apple/releases
    - GitHub Releases: https://github.com/tecogonaz0439/TCSameuraDamMonitor-apple/releases

    iOS / iPadOS / macOS アプリの Apple App Store での一般公開は後日別途実施する予定です。

    TestFlight または将来の Apple App Store から本アプリを取得する場合、Apple の TestFlight・App Store 利用規約、Apple Developer Program License Agreement、その他適用される Apple の条件が、取得、ベータテスト、配布、更新、掲載、停止、返金等の Apple プラットフォーム上の手続きに適用されます。本規約と Apple の条件がこれらの手続きまたは機能に関して矛盾する場合、その範囲では Apple の条件が優先されます。

    当方は、公式配布チャネル以外で第三者が入手、改変、再ビルド、再配布した版について、その安全性、完全性、真正性、動作、更新、サポートを保証しません。

    本アプリの公式配布版は、現時点で有償販売、アプリ内課金、広告、サブスクリプションを提供しません。

    ## 5. オープンソースライセンス

    本アプリのソースコードは、Apache License, Version 2.0 に基づき公開されています。利用者は、同ライセンスに従い、ソースコードおよびオブジェクトコードを利用、複製、改変、配布することができます。

    本アプリは、複数のオープンソースライブラリをそれぞれのライセンスに基づいて使用しています。本アプリに含まれる主な依存ライブラリは、**本アプリのOSSライセンス** に記載されています。

    本アプリの名称、アイコン、画面、説明、リポジトリ情報、開発者名、出典表記その他の表示を利用して改変版または派生版を配布する場合、国土交通省、または第三者の公式版、承認版、後援版であると誤認させないようにしてください。改変版を配布する場合は、Apache License, Version 2.0 の条件、適用法令、配布先ストアの規約、および第三者の権利を遵守してください。

    ソースコードリポジトリにIssue、Pull Request、パッチ、翻訳、ドキュメント、アイデアその他の投稿を行う場合、その投稿は、投稿時に明示された別段の条件がない限り、Apache License, Version 2.0 に基づき本アプリへ取り込まれる可能性があります。

    ## 6. プライバシーと端末内データ

    本アプリにおけるデータの取扱いは、別途定めるプライバシーポリシーに従います。

    - プライバシーポリシー: **本アプリのプライバシーポリシー**を参照

    本アプリは氏名やメールアドレス等の登録を求めず、端末の位置情報 API、端末識別子、広告 SDK、利用状況分析 SDK または独自のクラッシュ報告 SDK を使用しません。取得したダム諸量データ、ユーザー設定およびデバッグログを自動的にアップロードすることもありません。

    ダム諸量データの出所は国土交通省の水文水質データベースです。リアルタイムデータと過去データの既定のネットワーク取得先は、本プロジェクト開発者が運営するキャッシュサーバ(https://sudmonitor.kusugami-lab.net)です。キャッシュサーバはリアルタイム、日次過去データおよび検索用月次データを配信します。設定で各取得先を国土交通省の配信元サーバ(https://www1.river.go.jp)からの直接取得へ変更でき、過去データ検索では必要に応じて同サーバへ直接アクセスします。

    キャッシュサーバへの通信では、Cloudflare が送信元 IP アドレス、要求先、要求日時、User-Agent 等の通信情報をサービス提供、安全性確保、不正利用防止および障害調査のために処理します。TestFlight では Apple がセッション、クラッシュおよび利用者が任意で送信するフィードバック等を処理し、本プロジェクト開発者へ提供する場合があります。詳細と保持期間はプライバシーポリシーを参照してください。

    本アプリは、国土交通省から取得したダム諸量データ(リアルタイムデータ・過去データ)、ユーザー設定、デバッグログ等をアプリの保存領域に保存します。本アプリは、これらのデータを自動的に外部サーバへアップロードしたり、本アプリ独自のクラウド同期を行ったりしません。Application Support 配下で本アプリが管理するファイルは、対応する OS でバックアップ対象外となるよう設定しています。一方、OS が管理する SwiftData、standard UserDefaults および App Group UserDefaults のデータは、iCloud Backup、デバイス間転送、その他 OS が提供するバックアップ・移行機能の対象となる場合があります。その他、本アプリの共有機能、画面キャプチャ、手動コピー、外部アプリへの共有等、利用者自身の操作によってデータが端末外へ移動する場合があります。

    アプリ内の削除機能で削除できるのは、保存済みの過去データ検索結果とデバッグログです。日次過去データを含むすべてのローカルデータを削除する場合、iOS / iPadOS では本アプリをアンインストールしてください。macOS では app ファイルの削除だけではコンテナや設定が残る場合があるため、README の「アンインストール方法 (macOS)」に記載した完全なリセット手順に従ってください。ただし、iCloud のバックアップ、デバイス間転送後のコピー、利用者が共有またはコピーしたファイル、外部アプリに渡したデータについては、本アプリから削除できない場合があります。

    ## 7. 権限、通知、バックグラウンド更新

    本アプリは、キャッシュサーバまたは国土交通省サーバへ HTTPS で通信してダム諸量データを取得し、ネットワーク状態を確認し、利用者からの許可に基づいて通知を表示し、バックグラウンドまたは指定時刻のデータ更新を行います。

    iOS / iPadOS において、バックグラウンド更新は OS の裁量で実行され、厳密な定期実行は保証されません。macOS では、アプリ起動中のタイマーと起動時の更新を主に使用します。通知、自動更新、ウィジェット更新は、OS の仕様、端末設定、ネットワーク状態、ユーザー設定、通知許可、バックグラウンド制限等の影響を受けます。本アプリは、通知または自動更新が常に予定時刻どおりに実行されることを保証しません。

    デバッグログはトラブルシューティングのために自動的に生成され、アプリの保存領域に保存されます。ログの書き出しまたは共有は利用者の操作により実行されます。利用者は、共有先、保存先、ファイル内容、第三者への提供の要否を自己の責任で確認してください。

    ## 8. 外部サービスとリンク

    本アプリは、国土交通省関連ページ、地図アプリ、ブラウザ、OSの共有機能、Codeberg、GitHub等の外部サービスまたは外部アプリへのリンク、起動、共有を行う場合があります。

    外部サービスまたは外部アプリの利用には、各提供者の規約、プライバシーポリシー、利用条件が適用されます。当方は、外部サービスまたは外部アプリの内容、可用性、正確性、安全性、変更、停止、利用結果について責任を負いません。

    ## 9. 利用者の責任と禁止事項

    利用者は、本アプリを適用法令、本規約、配布元の規約、Apple の規約、第三者の権利、ならびに社会通念に従って利用するものとします。

    利用者は、次の行為を行ってはなりません。

    - 法令、公序良俗、第三者の権利、本規約、配布元の規約に違反する行為
    - 本アプリ、国土交通省の公開サーバ、キャッシュサーバ、Codeberg、GitHub、外部サービス、第三者の端末またはネットワークに過度の負荷、障害、不正アクセス、妨害を与える行為
    - 本アプリまたは改変版を、国土交通省、またはその他第三者の公式版、承認版、後援版であると誤認させる行為
    - マルウェア、不正コード、フィッシング、詐欺、なりすまし、虚偽表示、誤認表示、利用者を欺く目的で本アプリまたは改変版を利用または配布する行為
    - 本アプリの表示データを、公式情報であるかのように提示し、第三者の重要判断を誤らせる行為
    - その他、当方が本アプリの通常の利用範囲を逸脱すると合理的に判断する行為

    ## 10. 変更、中断、終了

    当方は、必要に応じて、本アプリの機能、仕様、表示、対応OS、対応端末、配布方法、配布元、リポジトリ、ドキュメント、プライバシーポリシー、本規約を変更することがあります。

    当方は、国土交通省の公開データ仕様の変更、外部サービスの停止、本アプリを配布する Codeberg/GitHub 等のプラットフォームの規約・ポリシー変更、Apple App Store または Apple Developer Program のポリシー変更、セキュリティ上の理由、保守、法令上の要請、その他やむを得ない事情により、本アプリの配布、更新、提供、サポートを中断または終了することがあります。

    本規約を変更した場合、変更後の規約は、リポジトリ、アプリ内表示、配布ページ、または当方が適切と判断する方法で公開した時点から効力を生じます。変更後に本アプリを利用した場合、利用者は変更後の規約に同意したものとみなされます。

    ## 11. 非保証

    本アプリは、現状有姿かつ提供可能な範囲で無償提供されます。当方は、本アプリについて、正確性、完全性、最新性、有用性、可用性、継続性、安全性、エラーがないこと、特定目的への適合性、第三者権利の非侵害、端末またはOSとの互換性、データの保存または復元、通知または自動更新の確実な実行を保証しません。

    本アプリの利用、利用不能、データの表示、欠測、誤表示、更新遅延、通知遅延、端末内データの消失、外部サービスの利用、実行ファイルの取得またはインストール、改変版または第三者配布物の利用により生じた損害について、利用者は自己の責任で対応するものとします。

    ## 12. 責任の制限

    当方は、法令上許される最大限の範囲で、本アプリに関連して利用者または第三者に生じた損害について責任を負いません。

    法令上、当方が責任を免れない場合であっても、当方の故意または重過失による場合を除き、当方の責任は、現実に発生した通常かつ直接の損害に限られます。当方は、特別損害、間接損害、付随的損害、結果損害、逸失利益、データ消失、事業中断、端末故障、第三者からの請求、公式情報の確認を怠ったことによる損害について責任を負いません。

    ## 13. 未成年者の利用

    未成年者が本アプリを利用する場合は、親権者その他の法定代理人の同意を得たうえで利用してください。未成年者が本アプリを利用した場合、法定代理人の同意を得たものとみなされます。

    ## 14. 準拠法と管轄

    本規約の成立、効力、解釈、履行、および本アプリに関連する紛争には、日本法を準拠法とします。

    本規約または本アプリに関連して当方と利用者との間で紛争が生じた場合、高松地方裁判所を第一審の専属的合意管轄裁判所とします。

    ## 15. お問い合わせ

    本規約、本アプリ、プライバシーポリシー、ライセンスに関するお問い合わせは、原則としてソースコードリポジトリ(Codeberg)のIssueにて行ってください。

    - Codeberg: https://codeberg.org/tecogonaz0439/TCSameuraDamMonitor-apple

    当方は、すべてのお問い合わせへの個別回答、調査、修正、更新、サポート提供を保証しません。
    """#

    static let privacyPolicy = #"""
    **Last updated: September 5, 2026**

    > This English version is a translation of the Japanese original version. The Japanese original is the authoritative text. If there is any discrepancy or conflict between this English translation and the Japanese original, the Japanese original prevails.

    ## Overview

    **Sameura Dam Monitor** (Japanese name: 早明浦ダム 貯水率モニタ, the “App”) is an iOS, iPadOS, and macOS app that displays dam data published by the Ministry of Land, Infrastructure, Transport and Tourism of Japan (“MLIT”). This policy applies to official distributions of the App by the project developer and also covers processing performed by the App’s Widget.

    The App does not provide account registration or ask users to enter a name or similar information. It does not access device location APIs, advertising IDs, or other persistent device identifiers. It has no SDKs for advertising, usage analytics, or project-operated crash reporting, no server-side user profiles, and no advertising tracking. Network information is nevertheless processed by the destination when data is retrieved.

    ## Data Handled on the Device

    The App stores real-time and historical dam data, user preferences, and debug logs in its application storage. It does not automatically transmit this data to an external server operated by the project or use it for project-operated cloud synchronization.

    Some data may leave the device through OS backup or migration features, or through sharing or export initiated by the user.

    Historical-search results and debug logs can be deleted in the App. To delete all local data, uninstall the App on iOS or iPadOS; on macOS, follow the complete reset procedure under “Uninstallation (macOS)” in the README. OS backups and copies created by the user may not be deletable from within the App.

    ## Network Communications and External Services

    The dam data originates from MLIT’s Water Information System. By default, the App and Widget connect to the project developer’s cache server (https://sudmonitor.kusugami-lab.net). The settings also allow direct retrieval from the MLIT origin server (https://www1.river.go.jp).

    Either destination may automatically process network information such as the source IP address, request time, requested dam or period, identification as the Apple version, and the App version. For the cache server, Cloudflare and the project use this information only to deliver data, maintain security, prevent abuse, and investigate failures, not for advertising, usage analytics, or tracking. The App does not transmit names, email addresses, advertising IDs, location obtained through device location APIs, preferences, stored data, or debug logs to either destination. Handling of network information by the MLIT server is governed by MLIT’s policies and is outside the project’s control.

    The cache server uses Cloudflare, and its processing of network information is governed by the [Cloudflare Privacy Policy](https://www.cloudflare.com/policies/privacy/). In TestFlight builds, Apple may process diagnostics, crashes, sessions, and voluntary feedback or screenshots and provide them to the developer; the [Apple Privacy Policy](https://www.apple.com/legal/privacy/) applies.

    ## Retention and Security

    The App and Widget communicate over HTTPS. If Cloudflare operational logs or related records contain network information, they are currently retained for no more than 7 days. The project does not associate this information with names or create copies for longer retention.

    There is no account-deletion process because the App has no account or server-side user profile. Network information is not associated with an account, and it may not be possible to identify information corresponding to a particular user. See the preceding section for ways to delete on-device data.

    ## Changes and Contact

    This policy will be updated if data practices change. The update date and changes will be reflected in the published policy and source code repository. Notice will also be provided in the App or through the distribution service when appropriate.

    Questions may be submitted through an Issue in the following Codeberg repository. Issues are public, so do not include personal or confidential information. If such information is necessary, first ask how to make contact without including it.

    - Codeberg: https://codeberg.org/tecogonaz0439/TCSameuraDamMonitor-apple
    """#

    static let privacyPolicyJa = #"""
    **最終更新日: 2026-09-05**

    ## 概要

    **早明浦ダム 貯水率モニタ**（以下「本アプリ」）は、国土交通省が公開するダム諸量データを表示する iOS / iPadOS / macOS アプリです。本ポリシーは、本プロジェクト開発者が公式に配布する本アプリに適用され、Widget による処理も対象とします。

    本アプリはアカウント登録や氏名等の入力を求めず、位置情報 API、広告 ID その他の永続的な端末識別子を取得しません。広告、利用状況分析または本プロジェクト独自のクラッシュ報告のための SDK、サーバ側の利用者プロフィールおよび広告目的の追跡もありません。ただし、データ取得時の通信情報は送信先で処理されます。

    ## 端末内で扱うデータ

    本アプリは、リアルタイムおよび過去のダム諸量データ、ユーザー設定、デバッグログをアプリの保存領域に保存します。これらを本プロジェクトの外部サーバへ自動送信したり、独自のクラウド同期に使用したりすることはありません。

    一部のデータは、OS のバックアップ・移行機能または利用者による共有・書き出しによって端末外へ移る場合があります。

    過去データ検索結果とデバッグログはアプリ内で削除できます。すべてのローカルデータを削除するには、iOS / iPadOS では本アプリをアンインストールし、macOS では README の「アンインストール方法 (macOS)」にある完全なリセット手順に従ってください。OS のバックアップや利用者が作成したコピーは、本アプリから削除できない場合があります。

    ## ネットワーク通信と外部サービス

    ダム諸量データの出所は国土交通省の水文水質データベースです。本アプリと Widget は、既定では本プロジェクト開発者が運営するキャッシュサーバ（https://sudmonitor.kusugami-lab.net）へ接続し、設定により国土交通省の配信元サーバ（https://www1.river.go.jp）から直接取得することもできます。

    いずれの送信先でも、送信元 IP アドレス、日時、要求したダムや期間、Apple 版であることやアプリのバージョン等の通信情報が自動的に処理される場合があります。キャッシュサーバでは、Cloudflare と本プロジェクトがこれらをデータ提供、安全確保、不正利用防止および障害調査にのみ使用し、広告、利用状況分析または追跡には使用しません。氏名、メールアドレス、広告 ID、端末の位置情報 API から取得した位置情報、設定、保存済みデータおよびデバッグログは、いずれの送信先にも送信しません。国土交通省のサーバにおける通信情報の取扱いは、同省の方針に従い、本プロジェクトの管理対象外です。

    キャッシュサーバには Cloudflare を利用し、通信情報の処理には [Cloudflare Privacy Policy](https://www.cloudflare.com/policies/privacy/) が適用されます。TestFlight 版では、Apple が診断情報、クラッシュ、セッション、任意のフィードバックやスクリーンショットを処理して開発者へ提供する場合があり、[Apple Privacy Policy](https://www.apple.com/legal/privacy/) が適用されます。

    ## 保持期間と安全管理

    本アプリと Widget は HTTPS で通信します。Cloudflare の運用ログ等に通信情報が含まれる場合、保持期間は現在最大 7 日です。本プロジェクトは通信情報を氏名等と結び付けず、長期保存用のコピーを作成しません。

    アカウントおよびサーバ側の利用者プロフィールがないため、アカウント削除の手続はありません。通信情報はアカウントに関連付けられず、特定の利用者に対応する情報を識別できない場合があります。端末内データの削除方法は前節を参照してください。

    ## 本ポリシーの変更とお問い合わせ

    データの取扱いが変わる場合は本ポリシーを更新し、更新日と変更内容を公開中のポリシーおよびソースコードリポジトリへ反映します。必要に応じてアプリ内または配布サービス上でも案内します。

    お問い合わせは次の Codeberg リポジトリの Issue で受け付けます。Issue は公開されるため、個人情報や機密情報を記載しないでください。必要な場合は、まずそれらを含めずに連絡方法をお問い合わせください。

    - Codeberg: https://codeberg.org/tecogonaz0439/TCSameuraDamMonitor-apple
    """#

    static let ossLicense = #"""
    # Open Source Licenses - Apple (iOS / iPadOS / macOS)

    This document lists third-party open source software included in the Release distributions of **Sameura Dam Monitor** (TCSameuraDamMonitor).

    *Report generated on 2026-09-05*

    ## Summary

    No third-party open source software is linked or embedded in the Apple Release targets.

    Apple system frameworks and the application's own local Swift package are not third-party dependencies.
    """#

}
