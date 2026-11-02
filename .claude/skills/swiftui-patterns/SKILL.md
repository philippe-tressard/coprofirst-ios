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
| Couleurs | `@Environment(\\.palette) private var palette`, puis `palette.<jeton>` : la charte avant toute résidence, sa palette (`site_palette`) ensuite, posée par `RacineView` ; palettes **générées** (`scripts/generer-charte.py`) ; `verifier-depot.sh` refuse `Color.red`, `Color(red:)` | `Charte/` |
| Typographie | titres `Font.titre(.largeTitle)` (serif New York), texte en styles dynamiques ; libellés `.styleLibelle()` (capitales) ; grands titres de navigation en serif (`ApparenceNavigation`) | `Charte/Charte.swift` |
| Composants | un par notion : `StyleBouton` (`.plein`, `.contour`, `.clair`), `ChampSaisie`, `Carte`, `Pastille`, `Medaillon`, `MessageErreur`, `LigneResidence`, `PastilleOuSuisJe` | `Composants/` |
| Données | les écrans parlent à `ServiceCoproFirst` : `ServiceAPI` (client généré, une URLSession éphémère par hôte, jeton au Trousseau si Face ID est accepté) ou `ServiceSimule` (`-api-simulee`) | `Session/`, `Donnees/` |
| État | `@Observable` + `.environment` : `Parcours` (navigation, résidence reconnue puis ouverte), `Reseau` (hors ligne) | `Session/` |
| Navigation | la barre suit `pages_order` (`OrdrePages`), jamais un ordre écrit dans l'app ; « où suis-je » en haut à droite | `Navigation/` |
| Erreurs | `ErreurService` : une phrase par cas, jamais un code (421 → « aucune résidence n'y est installée ») | `Session/ErreurService.swift` |
| Mouvement | `.snappy` pour un état, `.smooth` pour un changement de palette, `accessibilityReduceMotion` lu ; retours haptiques sur résidence reconnue, connexion, Face ID, filtre | — |
| Grandes tailles | `@ScaledMetric` ou `.dynamicTypeSize(...xxxLarge)` pour un pictogramme ; une rangée passe en colonne si `dynamicTypeSize.isAccessibilitySize` ; un écran fixe défile | `CarteDuFil`, `AccueilView` |
| Squelette | des identifiants propres (`0..<3`), jamais ceux des vrais éléments : SwiftUI réutiliserait les vues grisées | `FilView` |

## À trancher quand le premier cas arrive

- Rafraîchissement automatique sur un 401 en cours de session (intergiciel du
  client) : aujourd'hui, la session se reprend à l'ouverture seulement.
