<!--
SPDX-FileCopyrightText: 2026 Philippe TRESSARD
SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
-->

# Dépendances et licences

Inventaire figé (`standards/14` §6.3) : relu à chaque ajout. Versions exactes dans
`Paquets/ClientAPI/Package.swift`, transitives dans `Paquets/ClientAPI/Package.resolved`.
Une version écrite ici est celle de `Package.resolved`, et chaque paquet embarqué de la
fiche de confidentialité est listé ci-dessous : `scripts/verifier-dependances.py` (#143).

## Embarquées dans l'application

| Paquet | Version | Licence | Rôle |
|---|---|---|---|
| apple/swift-openapi-runtime | 1.13.4 | Apache-2.0 | types du client généré |
| apple/swift-openapi-urlsession | 1.4.0 | Apache-2.0 | transport HTTP (URLSession) |
| apple/swift-http-types | transitive | Apache-2.0 | requêtes et réponses HTTP |
| apple/swift-collections (`DequeModule` et ses modules internes, seuls) | transitive | Apache-2.0 | file du transport HTTP (dépendance de swift-openapi-urlsession) |
| Lucide (tracés, via `icones-svg.json` de coprofirst) | celle du plancher | ISC, MIT (part issue de Feather) | pictogrammes de la gouttière du fil (`Pictogrammes.xcassets`, généré) |

ISC et MIT n'exigent que l'avis de copyright et de licence avec chaque copie : leurs
textes sont dans `LICENSES/` et dans l'écran « À propos » (Plus › À propos ›
Composants tiers).

Apache-2.0 est compatible avec l'AGPL v3 et n'impose aucune restriction qui gêne la
distribution par l'App Store. Son texte et ses avis (NOTICE) devront figurer dans
l'écran « À propos / licences » de l'app avant la première distribution.

Aucun de ces paquets ne collecte ni ne transmet de donnée de lui-même, et aucun n'appelle
d'API « à raison requise » : relus à leur révision épinglée, et tenus par
`scripts/verifier-confidentialite.py` (table « paquets » de la fiche,
`.claude/skills/publication-app-store/confidentialite.md` §7).

## Outils de construction (non embarqués)

| Outil | Version | Licence |
|---|---|---|
| apple/swift-openapi-generator (greffon de build) et ses dépendances (swift-argument-parser, swift-collections, OpenAPIKit, Yams…) | 1.14.4 | Apache-2.0, MIT |
| XcodeGen | `outillage.env` | MIT |
| SwiftLint | `outillage.env` | MIT |
| swift-format | `outillage.env` | Apache-2.0 |
| reuse | 6.2.0 | GPL-3.0-or-later (outil seulement) |
