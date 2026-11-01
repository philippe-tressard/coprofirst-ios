<!--
SPDX-FileCopyrightText: 2026 Philippe TRESSARD
SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
-->

# CLAUDE.md — CoproFirst-iOS

## ⚠️ Socle commun d'abord

Bonnes pratiques valables pour tous les projets : `~/.claude/standards/`
(routage : `~/.claude/CLAUDE.md` §1). Ce fichier ne contient que l'instanciation
CoproFirst-iOS ; les garde-fous non négociables sont dans `~/.claude/projets.json`,
affichés à chaque session. Déclencheurs du projet : `.claude/coprofirst-ios-preflight.md`.

## Stack et état

- **Application iOS native en SwiftUI**, iOS 17 minimum, iPhone, **français seul**.
  Décision du 01/11/2026 (coprofirst#2460) : native, pas une WebView ; iOS seul.
- **Projet Xcode généré** par XcodeGen depuis `project.yml` — `CoproFirst.xcodeproj`
  n'est pas versionné : `bash scripts/generer-projet.sh` (qui fige aussi les
  versions des paquets).
- **Client d'API** : `Paquets/ClientAPI`, généré à chaque build par
  `swift-openapi-generator` depuis `openapi.json`. Le contrat n'est pas encore
  publié par coprofirst (coprofirst#2456) : en attendant, `bash
  scripts/generer-openapi.sh` le produit depuis `/Volumes/Data/Dev/5hostachy/api`
  (venv à soi, aucune base) et écrit sa provenance dans
  `Paquets/ClientAPI/PROVENANCE-OPENAPI.md`. Les chemins s'entendent sous `/api`.
- **État au 01/11/2026** : amorce — écran d'accueil seul. Pas de compte Apple
  Developer : **aucune signature**, pas de TestFlight (skill `publication-app-store`).
- **Outillage** : versions épinglées dans `outillage.env` (XcodeGen, SwiftLint,
  swift-format) ; Homebrew sur le poste, binaires vérifiés par empreinte en CI.
- **Dépôt** : `philippe-tressard/coprofirst-ios`, public, branche `main`. Qui
  fusionne : champ `fusion` du registre — `utilisateur` : je m'arrête à la PR.
  Les commits portent l'adresse *noreply* de GitHub, réglée dans la configuration
  **locale** du clone (l'adresse globale du poste est personnelle).

## Ce qui est propre à ce projet

- **Licence** : AGPL-3.0-or-later **avec une permission additionnelle** (GPL §7)
  qui autorise la distribution par l'App Store et TestFlight —
  `LICENSES/LicenseRef-CoproFirst-AppStore.txt`. Chaque fichier se déclare
  `AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore`. `LICENSE` est la
  réunion des deux textes, réassemblée par `bash scripts/verifier-depot.sh
  --ecrire-licence`, jamais écrite à la main.
- **Le logo** n'est pas encore dans le dépôt ; il y entrera sous
  `LicenseRef-CoproFirst-Logo` (`REUSE.toml`).
- **Ce dépôt et coprofirst ne partagent que le contrat d'API publié** — jamais du
  code recopié. Couleurs, tailles, ordre des sections, formats : à **générer**
  depuis les sources de coprofirst. Un besoin côté serveur devient un ticket (ou
  un commentaire sur coprofirst#2460), jamais une modification de
  `/Volumes/Data/Dev/5hostachy` depuis ce projet.
- **Installation** : aucun annuaire — démo, adresse saisie, QR, lien universel ;
  l'énumération des installations est interdite (spec `multi-coproprietes.md`
  §4.1 bis de coprofirst).
- **Contrôles** : `bash scripts/verifier-depot.sh` (500 lignes, encodage, modes,
  syntaxe, LICENSE) et `reuse lint`, rejoués par le hook pre-commit (armé par
  `git config core.hooksPath .githooks`) et par la CI ; SwiftLint `--strict` ;
  tests `swift test` (ClientAPI) et `xcodebuild test` au simulateur
  (`scripts/destination-simulateur.sh`).
- **Skills du projet** : `swiftui-patterns`, `ux-patterns-ios`,
  `publication-app-store` (`.claude/skills/`).
