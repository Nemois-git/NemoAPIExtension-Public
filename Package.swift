// swift-tools-version: 6.1

//
//  Package.swift
//  NemoAPIExtension
//
//  Created by Jeongcheol Kim on 7/14/26.
//  Copyright (c) 2026 Jeongcheol Kim (nemois). All rights reserved.
//
//  Licensed under the MIT License.
//  See the LICENSE file in the project root for license information.
//

import PackageDescription

/// Platform floors match NemoAPI's, whose `Duration`-based cache contract needs macOS 13 / iOS 16.
let package = Package(
    name: "NemoAPIExtension",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "NemoAPIExtension",
            targets: ["NemoAPIExtension"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", .upToNextMajor(from: "4.115.0")),
        .package(url: "https://github.com/Nemois-git/NemoAPI-Public.git", .upToNextMajor(from: "0.2.0")),
    ],
    targets: [
        .target(
            name: "NemoAPIExtension",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "NemoAPI", package: "NemoAPI-Public"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
    ]
)
