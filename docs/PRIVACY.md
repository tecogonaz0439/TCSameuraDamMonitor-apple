# Privacy Policy

**Last updated: September 5, 2026**

> This English version is a translation of the Japanese original `PRIVACY-ja.md`. The Japanese original is the authoritative text. If there is any discrepancy or conflict between this English translation and the Japanese original, the Japanese original prevails.

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
