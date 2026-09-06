[日本語版はこちら](README-ja.md)

# Sameura Dam Monitor

**Sameura Dam Monitor** is an iOS, iPadOS, and macOS app that retrieves dam data published through the Water Information System of the Ministry of Land, Infrastructure, Transport and Tourism of Japan and displays the water storage rate and related data for 125 dams across Japan, including Sameura Dam. The macOS app is currently distributed directly as a ZIP archive containing the notarized app through the Codeberg/GitHub Releases pages, and beta builds for iOS, iPadOS, and macOS are distributed through TestFlight. General availability on the App Store is planned for a later date.

This app is optimized for udon noodle lovers in Kagawa Prefecture who worry about Sameura Dam's water storage rate.

**This app is not an official app provided or approved by MLIT or any other government agency or third party.**

## Features

- **Real-time data display** — Fetch and save real-time data; display water storage rate, storage volume, inflow, outflow, and catchment average rainfall
- **Storage rate message display** — Display status and message based on the water storage rate, with customization support
- **Historical data display** — Retrieve and save past dam data for any date range; offline search support (Sameura Dam only)
- **Interactive graphs** — Graph display of real-time and historical data (rainfall/storage rate; storage volume/inflow/outflow)
- **Home screen widget** — Check the real-time storage rate and message at a glance
- **Auto-update & notifications** — Background real-time data fetching and water storage rate change notifications
- **Multi-language support** — Japanese and English

## How to Obtain (macOS)

1. Download the latest archive file such as `SameuraDamMonitor-macOS.zip` from the [Releases](https://codeberg.org/tecogonaz0439/TCSameuraDamMonitor-apple/releases) page of the repository.
2. Extract the downloaded ZIP file.
3. Move the extracted `Sameura Dam Monitor.app` to your Applications folder and run it.
   - If an OS security warning appears on the first launch, allow execution from the "Privacy & Security" section in System Settings.

## Uninstallation (macOS)

To completely remove the app and all its data from your system:

1. Quit the app if it is running.
2. Delete `Sameura Dam Monitor.app` from the Applications folder.
3. Remove persistent data by running the following commands in Terminal:

```bash
rm -rf ~/Library/Containers/net.tecogonaz.TCSameuraDamMonitor
rm -rf ~/Library/Containers/net.tecogonaz.TCSameuraDamMonitor.TCSameuraDamMonitorWidget
rm -rf ~/Library/Group\ Containers/group.net.tecogonaz.TCSameuraDamMonitor
rm -rf ~/Library/Application\ Support/net.tecogonaz.TCSameuraDamMonitor
defaults delete net.tecogonaz.TCSameuraDamMonitor 2>/dev/null || true
defaults delete group.net.tecogonaz.TCSameuraDamMonitor 2>/dev/null || true
killall cfprefsd 2>/dev/null || true
```

## Requirements

- iOS 18.0 or later
- iPadOS 18.0 or later
- macOS 15.0 or later

## Data Source

The data originates from MLIT's Water Information System. By default, the app and widget retrieve both real-time data and historical data (daily and monthly data used for searches) through the cache server operated by this project. You can select direct retrieval from MLIT in the app settings, and historical searches may access MLIT directly when necessary.

- `https://sudmonitor.kusugami-lab.net`
- `https://www1.river.go.jp`

## Repositories

- **Codeberg** : [tecogonaz0439/TCSameuraDamMonitor-apple](https://codeberg.org/tecogonaz0439/TCSameuraDamMonitor-apple)
- **GitHub** : [tecogonaz0439/TCSameuraDamMonitor-apple](https://github.com/tecogonaz0439/TCSameuraDamMonitor-apple)

GitHub is a mirror of Codeberg and is **read-only**. Issues and pull requests are only accepted on Codeberg.

## Links

- Terms of Use: [English](docs/TERMS.md) / [Japanese](docs/TERMS-ja.md)
- Privacy Policy: [English](docs/PRIVACY.md) / [Japanese](docs/PRIVACY-ja.md)
- OSS License: [OSS-LICENSE.md](docs/OSS-LICENSE.md)
- Security Policy: [SECURITY.md](SECURITY.md)

## License

The source code is licensed under the [Apache License, Version 2.0](LICENSE).
