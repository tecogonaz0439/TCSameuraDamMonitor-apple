[English version](README.md)

# 早明浦ダム 貯水率モニタ

**早明浦ダム 貯水率モニタ**は、国土交通省の水文水質データベースで公開されるダム諸量データを取得し、早明浦ダムを含む日本国内 125 ダムの貯水率、および関連データを表示する iOS・iPadOS・macOS アプリです。現在、macOS 版を Codeberg/GitHub の Releases ページで直接配布（公証済みアプリを収録した ZIP 形式）し、iOS / iPadOS / macOS 版のベータビルドを TestFlight で配布しています。App Store での一般公開は後日実施予定です。

本アプリは、早明浦ダムの貯水率を心配するうどん県民(香川県民)向けに最適化されています。

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

1. リポジトリの [Releases](https://codeberg.org/tecogonaz0439/TCSameuraDamMonitor-apple/releases) ページから最新の `SameuraDamMonitor-macOS.zip` などのアーカイブファイルをダウンロードします。
2. ダウンロードした ZIP ファイルを展開します。
3. 展開された `Sameura Dam Monitor.app` をアプリケーションフォルダに移動して実行します。
   - 初回起動時に OS のセキュリティ警告が表示される場合は、システム設定の「プライバシーとセキュリティ」から実行を許可してください。

## アンインストール方法 (macOS)

アプリとすべてのデータを完全に削除するには、以下の手順を実行してください。

1. アプリが起動中の場合は終了します。
2. `Sameura Dam Monitor.app` をアプリケーションフォルダから削除します。
3. ターミナルで以下のコマンドを実行し、永続化データを削除します。

```bash
rm -rf ~/Library/Containers/net.tecogonaz.TCSameuraDamMonitor
rm -rf ~/Library/Containers/net.tecogonaz.TCSameuraDamMonitor.TCSameuraDamMonitorWidget
rm -rf ~/Library/Group\ Containers/group.net.tecogonaz.TCSameuraDamMonitor
rm -rf ~/Library/Application\ Support/net.tecogonaz.TCSameuraDamMonitor
defaults delete net.tecogonaz.TCSameuraDamMonitor 2>/dev/null || true
defaults delete group.net.tecogonaz.TCSameuraDamMonitor 2>/dev/null || true
killall cfprefsd 2>/dev/null || true
```

## 動作要件

- iOS 18.0 以上
- iPadOS 18.0 以上
- macOS 15.0 以上

## データソース

データの出所は国土交通省の水文水質データベースです。アプリとウィジェットの既定では、リアルタイムデータと過去データ（日次・検索用月次）を本プロジェクトが運営するキャッシュサーバから取得します。設定で水文水質データベース（MLIT）からの直接取得へ変更でき、過去データ検索では必要に応じて MLIT へ直接アクセスします。

- `https://sudmonitor.kusugami-lab.net`
- `https://www1.river.go.jp`

## リポジトリ

- **Codeberg** : [tecogonaz0439/TCSameuraDamMonitor-apple](https://codeberg.org/tecogonaz0439/TCSameuraDamMonitor-apple)
- **GitHub** : [tecogonaz0439/TCSameuraDamMonitor-apple](https://github.com/tecogonaz0439/TCSameuraDamMonitor-apple)

GitHubはCodebergのミラーであり、**読み取り専用**です。IssueおよびPull RequestはCodebergでのみ受け付けています。

## リンク

- 利用規約: [English](docs/TERMS.md) / [日本語](docs/TERMS-ja.md)
- プライバシーポリシー: [English](docs/PRIVACY.md) / [日本語](docs/PRIVACY-ja.md)
- OSSライセンス: [OSS-LICENSE.md](docs/OSS-LICENSE.md)
- セキュリティポリシー: [SECURITY.md](SECURITY.md)

## ライセンス

ソースコードは [Apache License, Version 2.0](LICENSE) の下で公開されています。
