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
  `swift-openapi-generator` depuis `openapi.json`, la pièce jointe de la release de
  coprofirst (coprofirst#2456). Les chemins s'entendent sous `/api`.
- **Tout ce qui vient de coprofirst se génère** — contrat, charte, palettes, pages,
  onglets, tables des menus — par `python3 scripts/generer.py`, depuis le
  **plancher** (`scripts/generateurs/_plancher.py`, une version publiée), jamais un
  clone (#34) : un module par domaine dans `scripts/generateurs/`, `_source.py` seul
  lit coprofirst. Le plancher est la plus ancienne version servie par une
  installation connue (l'app parle à plusieurs versions) — **mesurée** chaque jour
  (`version_contrat` de `_plancher.INSTALLATIONS`, #83) ; il ne monte que sur
  décision, quand toutes l'ont dépassé. La CI et le workflow quotidien « Concordance
  avec CoproFirst » rendent rouge un écart au plancher (API simulée et installation
  sous le plancher comprises) ; une version au-dessus est une information, ticket
  `a-monter` (`scripts/concordance.py`, `scripts/verifier-fixtures.py`, #20).
- **État** : il ne se recopie pas ici — il se lit dans `README.md` (« Écrans
  livrés », « Sortir une version »), `Parite/PARITE.md` (jugé en CI) et les
  issues ouvertes. Signature **au poste** seulement, jamais en CI ; identifiant
  `fr.coprofirst.app` **figé** (contrat : liens universels, APNs) ; compte Apple
  et TestFlight : skill `publication-app-store`.
- **Outillage** : versions épinglées dans `outillage.env` (XcodeGen, SwiftLint,
  swift-format) ; Homebrew sur le poste, binaires vérifiés par empreinte en CI.
- **Dépôt** : `philippe-tressard/coprofirst-ios`, public, branche `main`. Qui
  fusionne : champ `fusion` du registre. **Décision du 11/11/2026** (Philippe :
  « tu es plus à même de fusionner et de voir les conséquences ») : je fusionne
  mes PR moi-même — branche à jour de `main` (la protection l'exige), contrôles
  rejoués au poste, puis fusion automatique `--squash` une fois la CI verte. Je
  suis ensuite `main` : sa CI après la fusion, et les PR ouvertes qu'elle oblige
  à rebaser. **Contrepartie** : un compte rendu après chaque fusion (ce qui est
  entré, l'état de la CI de `main`). Philippe oriente par la **priorité** des
  tickets, pas par la fusion. Fusionner n'est pas soumettre : TestFlight externe
  et App Store restent suspendus à la validation du rendu.
  Les commits portent l'adresse *noreply* de GitHub, réglée dans la configuration
  **locale** du clone (l'adresse globale du poste est personnelle).

## Ce qui est propre à ce projet

- **Licence** : AGPL-3.0-or-later **avec une permission additionnelle** (GPL §7)
  qui autorise la distribution par l'App Store et TestFlight —
  `LICENSES/LicenseRef-CoproFirst-AppStore.txt`. Chaque fichier se déclare
  `AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore`. `LICENSE` est la
  réunion des deux textes, réassemblée par `bash scripts/verifier-depot.sh
  --ecrire-licence`, jamais écrite à la main.
- **Le logo** de CoproFirst est intégré (icône, accueil, pastille) sous sa licence
  propre `LicenseRef-CoproFirst-Logo`, élargie à l'app par coprofirst#2474
  (`REUSE.toml`) ; le texte est recopié à l'identique et `scripts/verifier-logo.sh`
  en garde l'identité (`scripts/importer-logo.sh` pour le recopier).
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
  tests `swift test` (ClientAPI) et `bash scripts/tests-simulateur.sh` au
  simulateur — requêtes d'accessibilité expirées au résumé du run, et une relance
  au plus, déclarée, sur les seules causes de `scripts/bilan_tests_ui.py` (#50) ;
  un seul passage à la fois sur le poste, tenu par le verrou du script (#108).
- **Skills du projet** : `swiftui-patterns`, `ux-patterns-ios`,
  `publication-app-store` (`.claude/skills/`).
