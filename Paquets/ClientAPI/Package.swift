// swift-tools-version: 6.0
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

// Le client de l'API de CoproFirst, GÉNÉRÉ à chaque build depuis openapi.json par
// swift-openapi-generator : aucune route ne s'écrit à la main ici (CLAUDE.md).
import PackageDescription

let package = Package(
    name: "ClientAPI",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ClientAPI", targets: ["ClientAPI"])
    ],
    dependencies: [
        // Versions exactes : une montée se décide, elle ne s'importe pas (DEPENDANCES.md).
        .package(url: "https://github.com/apple/swift-openapi-generator", exact: "1.14.4"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", exact: "1.13.4"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", exact: "1.4.0"),
    ],
    targets: [
        .target(
            name: "ClientAPI",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
            ],
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
            ]
        ),
        .testTarget(
            name: "ClientAPITests",
            dependencies: ["ClientAPI"]
        ),
    ]
)
