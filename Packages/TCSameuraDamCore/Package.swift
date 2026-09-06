// swift-tools-version: 6.0
// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import PackageDescription

let package = Package(
    name: "TCSameuraDamCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "TCSameuraDamCore", targets: ["TCSameuraDamCore"]),
    ],
    targets: [
        .target(name: "TCSameuraDamCore"),
        .testTarget(
            name: "TCSameuraDamCoreTests",
            dependencies: ["TCSameuraDamCore"]
        ),
    ]
)
