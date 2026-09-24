[English version](README.md)

# 早明浦ダム 貯水率モニタ

**早明浦ダム 貯水率モニタ**は、国土交通省の水文水質データベースからダム諸量データを取得し、早明浦ダムを含む国内 125 ダムの貯水率と関連データを表示する iOS・iPadOS・macOS アプリです。macOS 版は公証済みアプリを収録した ZIP 形式で GitHub Releases から配布しています。iOS / iPadOS / macOS 版のベータビルドは TestFlight で配布中です。App Store での一般公開は後日予定しています。AltStore PAL は日本での iOS 版配布の将来候補です。日本向け代替配信は iPhone 用 iOS アプリが対象で、iPadOS 版と macOS 版は対象外です。

本アプリは、早明浦ダムの貯水率を心配するうどん県民（香川県民）向けに最適化されています。

**本アプリは、国土交通省を含む政府機関、またはその他の第三者が提供・承認する公式アプリではありません。**

## 機能

- **リアルタイムデータ表示** — リアルタイムデータを取得・保存、貯水率、貯水量、流入量、放流量、流域平均雨量を表示
- **貯水率メッセージ表示** — 貯水率に応じた状態とメッセージを表示、カスタマイズ対応
- **過去データ表示** — 任意期間の過去データを取得・保存、オフライン検索対応(早明浦ダムのみ)
- **インタラクティブグラフ** — リアルタイムデータ・過去データのグラフ表示(雨量/貯水率、貯水量/流入量/放流量)
- **ホーム画面ウィジェット** — リアルタイムの貯水率とメッセージを一目で確認
- **自動更新・通知** — バックグラウンドでのリアルタイムデータ取得と貯水率変化通知
- **多言語対応** — 日本語・英語

## 入手方法 (macOS)

1. [GitHub Releases](https://github.com/tecogonaz0439/TCSameuraDamMonitor-apple/releases) から最新の macOS 用 ZIP アーカイブをダウンロードします。
2. ダウンロードした ZIP ファイルを展開します。
3. 展開された `Sameura Dam Monitor.app` をアプリケーションフォルダに移動して実行します。
   - 初回起動時に OS のセキュリティ警告が表示される場合は、システム設定の「プライバシーとセキュリティ」から実行を許可してください。

## アンインストール方法 (macOS)

アプリとすべてのデータを完全に削除するには、以下の手順を実行してください。

1. アプリが起動中の場合は終了します。
2. `TCSameuraDamMonitor.app` をアプリケーションフォルダから削除します。
3. ターミナルで以下のコマンドを実行し、永続化データを削除します。macOS 15以降では、事前にターミナルアプリへフルディスクアクセスを許可しないとアプリコンテナを削除できません(`sudo` を付けても回避できません)。
4. 作業が完了したら、手順3で許可したフルディスクアクセスを必ず解除してください。

フルディスクアクセスを許可するには、システム設定 > プライバシーとセキュリティ > フルディスクアクセス で使用中のターミナルアプリを有効にします。その後、以下を実行します。

```bash
rm -rf ~/Library/Containers/net.tecogonaz.TCSameuraDamMonitor
rm -rf ~/Library/Containers/net.tecogonaz.TCSameuraDamMonitor.TCSameuraDamMonitorWidget
rm -rf ~/Library/Group\ Containers/group.net.tecogonaz.TCSameuraDamMonitor
rm -rf ~/Library/Application\ Scripts/net.tecogonaz.TCSameuraDamMonitor
rm -rf ~/Library/Application\ Scripts/net.tecogonaz.TCSameuraDamMonitor.TCSameuraDamMonitorWidget
rm -rf ~/Library/Application\ Scripts/group.net.tecogonaz.TCSameuraDamMonitor
```

注記: これらのコマンドの実行後も、`~/Library/Containers/net.tecogonaz.TCSameuraDamMonitor` と `~/Library/Containers/net.tecogonaz.TCSameuraDamMonitor.TCSameuraDamMonitorWidget` の空のフォルダが残る場合があります。これはmacOSがコンテナ管理メタデータを保護しているためです。これらのフォルダにアプリのデータは残っておらず、macOSによってログアウト後の再ログインや再起動のタイミングで自動的に削除されます。

## 不具合の報告

不具合を報告する際は、アプリのバージョンとビルド番号(「このアプリについて」で確認できます)、OSのバージョン、問題が起きる直前にしていた操作、表示されたエラーメッセージを添えてください。

### TestFlightベータ版(iOS / iPadOS / macOS)

iOS / iPadOS ではクラッシュログは自動収集されます。クラッシュ時にアラートが表示された場合は「共有」を選び、コメントを追加してください。

macOS では、以下の2つの設定が両方有効な場合にのみクラッシュログが開発者へ送信されます。システム設定 > プライバシーとセキュリティ > 解析と改善 を開き、**「Macの解析を共有」**と**「Appデベロッパと共有」**を有効にしてください。アプリがクラッシュすると問題レポートのダイアログが表示されるので、**OK** を押して送信してください。クラッシュログは数分〜1日程度で開発者に届きます。

アプリ内のデバッグログも併せて送る場合は、デバッグ画面(「このアプリについて」でバージョンを5回タップ)の「Debug Log」を開き、共有または保存ボタンでCSVファイルを書き出してください。

### 直接ダウンロード版(macOS ZIP)

直接配布版のクラッシュログはAppleには収集されません。クラッシュした場合は、ターミナルで以下のコマンドを実行して収集してください:

```bash
mkdir -p ~/Desktop/SameuraDamMonitor-crashlogs
cp ~/Library/Logs/DiagnosticReports/TCSameuraDamMonitor-*.ips ~/Desktop/SameuraDamMonitor-crashlogs/ 2>/dev/null
cp ~/Library/Logs/DiagnosticReports/Retired/TCSameuraDamMonitor-*.ips ~/Desktop/SameuraDamMonitor-crashlogs/ 2>/dev/null
sw_vers
sysctl -n hw.model
open ~/Desktop/SameuraDamMonitor-crashlogs
```

TestFlight版でも、クラッシュログが送信されていない・開発者に届いていない場合は同じコマンドが使えます。

収集した `.ips` ファイル、`sw_vers` と `sysctl -n hw.model` の出力、書き出したDebug LogのCSVを [tecogonaz@kusugami-lab.net](mailto:tecogonaz@kusugami-lab.net) までお送りください。

### 注意

- クラッシュログにはMacの機種、macOSのバージョン、ファイルパスなどの情報が含まれます。公開のIssueには投稿せず、メールでお送りください。
- アップロードされたクラッシュログはAppleで120日間保持されます。クラッシュではなく応答停止(ハング)の場合はクラッシュログが記録されないため、発生時の状況を文章でお知らせください。

## 動作要件

- iOS 18.0 以上
- iPadOS 18.0 以上
- macOS 15.0 以上

## データソース

データの出所は国土交通省の水文水質データベースです。アプリとウィジェットの既定では、リアルタイムデータと過去データ（日次・検索用月次）を本プロジェクトが運営するキャッシュサーバから取得します。設定で水文水質データベース（MLIT）からの直接取得へ変更でき、過去データ検索では必要に応じて MLIT へ直接アクセスします。

- `https://sudmonitor.kusugami-lab.net`
- `https://www1.river.go.jp`

## リポジトリ

- **GitHub**: [tecogonaz0439/TCSameuraDamMonitor-apple](https://github.com/tecogonaz0439/TCSameuraDamMonitor-apple)

不具合の報告や提案は、GitHub の Issue からお寄せください。Pull Request も同リポジトリで受け付けています。

## リンク

- 利用規約: [English](docs/TERMS.md) / [日本語](docs/TERMS-ja.md)
- プライバシーポリシー: [English](docs/PRIVACY.md) / [日本語](docs/PRIVACY-ja.md)
- OSSライセンス: [OSS-LICENSE.md](docs/OSS-LICENSE.md)
- セキュリティポリシー: [SECURITY.md](SECURITY.md)

## ライセンス

ソースコードは [Apache License, Version 2.0](LICENSE) の下で公開されています。
