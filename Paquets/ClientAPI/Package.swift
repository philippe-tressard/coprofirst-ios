// swift-tools-version: 6.0
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

// Le client de l'API de CoproFirst, GÉNÉRÉ à chaque build depuis openapi.json par
// swift-openapi-generator : aucune route ne s'écrit à la main ici (CLAUDE.md).
import PackageDescription

// Le client, généré par le greffon. Une fonction : la cible de l'iPhone et celle de la montre
// sont le même code, compilé deux fois.
func client(_ nom: String, chemin: String? = nil) -> Target {
    .target(
        name: nom,
        dependencies: [
            .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
        ],
        path: chemin,
        plugins: [
            .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
        ]
    )
}

let package = Package(
    name: "ClientAPI",
    platforms: [.iOS(.v17), .tvOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [
        .library(name: "ClientAPI", targets: ["ClientAPI"]),
        // La montre a son produit (#324). Embarquée dans l'iPhone, elle construisait ClientAPI
        // pour watchOS dans le MÊME build : le greffon écrivait deux fois le même dossier
        // d'intermédiaires (« Multiple commands produce », défaut de Xcode signalé FB13750966,
        // toujours présent sous Xcode 27). Sous un autre nom de cible, le greffon a son dossier.
        // `Sources/ClientAPIMontre` est un lien vers `Sources/ClientAPI` : une seule source.
        // La montre l'importe sous le nom `ClientAPI` (`-module-alias`, project.yml).
        .library(name: "ClientAPIMontre", targets: ["ClientAPIMontre"]),
    ],
    dependencies: [
        // Versions exactes : une montée se décide, elle ne s'importe pas (DEPENDANCES.md).
        .package(url: "https://github.com/apple/swift-openapi-generator", exact: "1.14.4"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", exact: "1.13.4"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", exact: "1.4.0"),
    ],
    targets: [
        client("ClientAPI"),
        client("ClientAPIMontre", chemin: "Sources/ClientAPIMontre"),
        .testTarget(
            name: "ClientAPITests",
            dependencies: ["ClientAPI"]
        ),
    ]
)
