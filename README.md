[日本語版はこちら](README-ja.md)

# Sameura Dam Monitor

**Sameura Dam Monitor** is an iOS, iPadOS, and macOS app that retrieves dam data published through the Water Information System of the Ministry of Land, Infrastructure, Transport and Tourism of Japan and displays the water storage rate and related data for 125 dams across Japan, including Sameura Dam. The notarized macOS app is distributed as a ZIP archive through GitHub Releases. Beta builds for iOS, iPadOS, and macOS are distributed through TestFlight. General availability on the Apple App Store is planned for a later date. AltStore PAL is a future distribution candidate for the iOS app in Japan; iPadOS and macOS distribution through this marketplace is not available for Japan.

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

1. Download the latest archive file such as `SameuraDamMonitor-macOS.zip` from [GitHub Releases](https://github.com/tecogonaz0439/TCSameuraDamMonitor-apple/releases).
2. Extract the downloaded ZIP file.
3. Move the extracted `Sameura Dam Monitor.app` to your Applications folder and run it.
   - If an OS security warning appears on the first launch, allow execution from the "Privacy & Security" section in System Settings.

## Uninstallation (macOS)

To completely remove the app and all its data from your system:

1. Quit the app if it is running.
2. Delete `TCSameuraDamMonitor.app` from the Applications folder.
3. Remove persistent data by running the following commands in Terminal. On macOS 15 or later, the Terminal app must be granted Full Disk Access beforehand to delete app containers; `sudo` does not bypass this restriction.
4. When you are done, revoke the Full Disk Access permission granted in step 3.

To grant Full Disk Access, choose System Settings > Privacy & Security > Full Disk Access and enable the Terminal app you use. Then run:

```bash
rm -rf ~/Library/Containers/net.tecogonaz.TCSameuraDamMonitor
rm -rf ~/Library/Containers/net.tecogonaz.TCSameuraDamMonitor.TCSameuraDamMonitorWidget
rm -rf ~/Library/Group\ Containers/group.net.tecogonaz.TCSameuraDamMonitor
rm -rf ~/Library/Application\ Scripts/net.tecogonaz.TCSameuraDamMonitor
rm -rf ~/Library/Application\ Scripts/net.tecogonaz.TCSameuraDamMonitor.TCSameuraDamMonitorWidget
rm -rf ~/Library/Application\ Scripts/group.net.tecogonaz.TCSameuraDamMonitor
```

Note: Even after running these commands, the empty folders `~/Library/Containers/net.tecogonaz.TCSameuraDamMonitor` and `~/Library/Containers/net.tecogonaz.TCSameuraDamMonitor.TCSameuraDamMonitorWidget` may remain because macOS protects the container management metadata. These folders no longer contain any app data, and macOS removes them automatically after you log out and back in or restart.

## Reporting a Problem

When reporting an issue, please include the app version and build (shown in "About This App"), your OS version, what you did before the problem occurred, and any error message you saw.

### TestFlight beta (iOS, iPadOS, macOS)

On iOS and iPadOS, crash reports are collected automatically. If a crash alert appears, tap **Share** and add any comments.

On macOS, crash reports are sent to the developer only when both of the following settings are turned on. Open System Settings > Privacy & Security > Analytics & Improvements and enable **Share Mac Analytics** and **Share With App Developers**. When the app crashes, a problem report dialog appears; click **OK** to send the crash report. Crash reports reach the developer within minutes to about a day.

To also send the in-app debug log, open the Debug screen (tap the version five times in "About This App"), open "Debug Log", and export the CSV file using the share or save button.

### Direct download (macOS ZIP)

Crash reports for directly distributed builds are not collected by Apple. If the app crashes, collect the report with the following commands in Terminal:

```bash
mkdir -p ~/Desktop/SameuraDamMonitor-crashlogs
cp ~/Library/Logs/DiagnosticReports/TCSameuraDamMonitor-*.ips ~/Desktop/SameuraDamMonitor-crashlogs/ 2>/dev/null
cp ~/Library/Logs/DiagnosticReports/Retired/TCSameuraDamMonitor-*.ips ~/Desktop/SameuraDamMonitor-crashlogs/ 2>/dev/null
sw_vers
sysctl -n hw.model
open ~/Desktop/SameuraDamMonitor-crashlogs
```

The same commands also work for the TestFlight version if a crash report was not sent or was not received by the developer.

Send the collected `.ips` files, the output of `sw_vers` and `sysctl -n hw.model`, and the exported Debug Log CSV to [tecogonaz@kusugami-lab.net](mailto:tecogonaz@kusugami-lab.net).

### Notes

- Crash reports contain device information such as the Mac model, macOS version, and file paths. Please do not post them to public issue trackers; send them by email instead.
- Apple keeps uploaded crash reports for 120 days. If the app becomes unresponsive instead of crashing, no crash report is recorded; describe what happened in your message.

## Requirements

- iOS 18.0 or later
- iPadOS 18.0 or later
- macOS 15.0 or later

## Data Source

The data originates from MLIT's Water Information System. By default, the app and widget retrieve both real-time data and historical data (daily and monthly data used for searches) through the cache server operated by this project. You can select direct retrieval from MLIT in the app settings, and historical searches may access MLIT directly when necessary.

- `https://sudmonitor.kusugami-lab.net`
- `https://www1.river.go.jp`

## Repository

- **GitHub**: [tecogonaz0439/TCSameuraDamMonitor-apple](https://github.com/tecogonaz0439/TCSameuraDamMonitor-apple)

Please report issues and submit pull requests in this repository.

## Links

- Terms of Use: [English](docs/TERMS.md) / [Japanese](docs/TERMS-ja.md)
- Privacy Policy: [English](docs/PRIVACY.md) / [Japanese](docs/PRIVACY-ja.md)
- OSS License: [OSS-LICENSE.md](docs/OSS-LICENSE.md)
- Security Policy: [SECURITY.md](SECURITY.md)

## License

The source code is licensed under the [Apache License, Version 2.0](LICENSE).
