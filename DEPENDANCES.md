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

Trois apps sortent de ce dépôt sous une seule fiche : l'iPhone et l'iPad (`CoproFirst`), l'écran
de hall sur Apple TV (`CoproFirstTV`, #218) et l'Apple Watch (`CoproFirstWatch`, #226). Les
trois embarquent les paquets Swift ci-dessous (le client de l'API) ; seuls l'iPhone et l'iPad
embarquent les pictogrammes Lucide. La montre voyage dans l'app iPhone (`project-archive.yml`),
qui porte leurs textes.

| Paquet | Version | Licence | Rôle |
|---|---|---|---|
| apple/swift-openapi-runtime | 1.13.4 | Apache-2.0 | types du client généré |
| apple/swift-openapi-urlsession | 1.4.0 | Apache-2.0 | transport HTTP (URLSession) |
| apple/swift-http-types | transitive | Apache-2.0 | requêtes et réponses HTTP |
| apple/swift-collections (`DequeModule` et ses modules internes, seuls) | transitive | Apache-2.0 | file du transport HTTP (dépendance de swift-openapi-urlsession) |
| Lucide (tracés, via `icones-svg.json` de coprofirst) | celle du plancher | ISC, MIT (part issue de Feather) | pictogrammes de la gouttière du fil (`Pictogrammes.xcassets`, généré) |

ISC et MIT n'exigent que l'avis de copyright et de licence avec chaque copie : leurs
textes sont dans `LICENSES/` et dans l'écran « À propos » de l'iPhone (Plus › À propos ›
Composants tiers).

Apache-2.0 est compatible avec l'AGPL v3 et n'impose aucune restriction qui gêne la
distribution par l'App Store. Son texte (`LICENSES/Apache-2.0.txt`) et les avis des paquets
(NOTICE, recopiés à l'identique dans `CoproFirst/Ressources/AvisTiers/`) sont copiés dans
chaque app qui embarque un paquet — les mêmes fichiers, nommés dans les `sources` de sa cible
(`project.yml`) —, et affichés un composant par ligne : sur l'iPhone, Plus › À propos ›
Composants tiers (#168) ; sur l'Apple TV, « À propos » de l'écran de hall (#320), offert à
l'entrée, à l'appairage et, d'un clic de la télécommande, pendant la diffusion.
`swift-collections` n'a pas de fichier NOTICE. **Monter un paquet embarqué, c'est recopier
son NOTICE** : `verifier-dependances.py` le compare aux sources quand elles sont extraites au
poste, et refuse une app qui embarque un paquet sans ces textes ni un écran qui les montre.

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
| reuse | `outillage.env` | GPL-3.0-or-later (outil seulement) |
