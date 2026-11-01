---
name: swiftui-patterns
description: "Écrire un écran, un état, une navigation ou un appel réseau en SwiftUI dans CoproFirst-iOS — structure des dossiers, état observable, client d'API généré, concurrence stricte, tests, aperçus. À charger avant d'écrire la moindre vue ou le moindre modèle de l'app."
---

<!--
SPDX-FileCopyrightText: 2026 Philippe TRESSARD
SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
-->

# SwiftUI — les patterns de CoproFirst-iOS

> Squelette posé à l'amorce (01/11/2026). Il se remplit avec le code : un pattern
> utilisé **deux fois** s'écrit ici, à l'identique de ses occurrences
> (`standards/11` §1). Règles générales : `standards/02` (factorisation, 500
> lignes), `standards/11` (interface) — elles ne se recopient pas ici.

## Ce qui est posé

| Sujet | Règle | Où |
|---|---|---|
| Dossiers | un dossier par écran ou domaine (`CoproFirst/Accueil/`), la vue et ses textes ensemble | `CoproFirst/` |
| Textes | écrits **une fois**, dans un `enum` du domaine (`Accueil.titre`) ; la vue et les tests les lisent là | `AccueilView.swift` |
| Langue | français seul : `developmentLanguage: fr`, `CFBundleLocalizations: [fr]` | `project.yml` |
| API | **le client généré** (`ClientCoproFirst.client(installation:)`), jamais `URLSession` à la main ; une route absente = un ticket dans coprofirst | `Paquets/ClientAPI` |
| Préfixe `/api` | ajouté par `ClientCoproFirst.adresseAPI`, et nulle part ailleurs | idem |
| Concurrence | Swift 6, `SWIFT_STRICT_CONCURRENCY: complete` | `project.yml` |
| Tests | Swift Testing (`@Test`, `#expect`) pour l'unitaire ; XCTest pour l'interface, éléments trouvés par `accessibilityIdentifier` (`accueil.titre`), jamais par leur texte | `CoproFirstTests/`, `CoproFirstUITests/` |
| Réseau en test | un `ClientTransport` factice (`TransportEnregistreur`) : aucun test ne sort sur le réseau | `Paquets/ClientAPI/Tests` |
| Couleurs | système seulement, tant que les jetons de coprofirst ne sont pas **générés** depuis `socle.css` — jamais recopiés | CLAUDE.md |

## À trancher quand le premier cas arrive

- État partagé : `@Observable` + injection par `.environment` (iOS 17) — à
  confirmer au premier modèle partagé entre deux écrans.
- Navigation : `NavigationStack` à chemin typé, une pile par installation.
- Session par hôte (plusieurs installations, une session chacune) : cookies
  (coprofirst#2457), un `HTTPCookieStorage` par installation.
- Chargement et erreur : un seul composant d'état (chargement, vide, erreur,
  contenu), réutilisé partout.
