<!--
SPDX-FileCopyrightText: 2026 Philippe TRESSARD
SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
-->

# Dépendances et licences

Inventaire figé (`standards/14` §6.3) : relu à chaque ajout. Versions exactes dans
`Paquets/ClientAPI/Package.swift`, transitives dans `Paquets/ClientAPI/Package.resolved`.

## Embarquées dans l'application

| Paquet | Version | Licence | Rôle |
|---|---|---|---|
| apple/swift-openapi-runtime | 1.13.3 | Apache-2.0 | types du client généré |
| apple/swift-openapi-urlsession | 1.4.0 | Apache-2.0 | transport HTTP (URLSession) |
| apple/swift-http-types | transitive | Apache-2.0 | requêtes et réponses HTTP |

Apache-2.0 est compatible avec l'AGPL v3 et n'impose aucune restriction qui gêne la
distribution par l'App Store. Son texte et ses avis (NOTICE) devront figurer dans
l'écran « À propos / licences » de l'app avant la première distribution.

## Outils de construction (non embarqués)

| Outil | Version | Licence |
|---|---|---|
| apple/swift-openapi-generator (greffon de build) et ses dépendances (swift-argument-parser, swift-collections, OpenAPIKit, Yams…) | 1.14.3 | Apache-2.0, MIT |
| XcodeGen | `outillage.env` | MIT |
| SwiftLint | `outillage.env` | MIT |
| swift-format | `outillage.env` | Apache-2.0 |
| reuse | 6.2.0 | GPL-3.0-or-later (outil seulement) |
