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
| Dossiers | voir « Arborescence » ci-dessous : un dossier par fonctionnalité, la vue et ses textes ensemble | `CoproFirst/` |
| Textes | écrits **une fois**, dans un `enum` du domaine (`Accueil.titre`) ; la vue et les tests les lisent là | `AccueilView.swift` |
| Langue | français seul : `developmentLanguage: fr`, `CFBundleLocalizations: [fr]` | `project.yml` |
| API | **le client généré** (`ClientCoproFirst.client(installation:)`), jamais `URLSession` à la main ; une route absente = un ticket dans coprofirst | `Paquets/ClientAPI` |
| Préfixe `/api` | ajouté par `ClientCoproFirst.adresseAPI`, et nulle part ailleurs | idem |
| Concurrence | Swift 6, `SWIFT_STRICT_CONCURRENCY: complete` | `project.yml` |
| Tests | Swift Testing (`@Test`, `#expect`) pour l'unitaire ; XCTest pour l'interface, éléments trouvés par `accessibilityIdentifier` (`accueil.titre`), jamais par leur texte | `CoproFirstTests/`, `CoproFirstUITests/` |
| Réseau en test | un `ClientTransport` factice (`TransportEnregistreur`) : aucun test ne sort sur le réseau | `Paquets/ClientAPI/Tests` |
| Couleurs | `@Environment(\\.palette) private var palette`, puis `palette.<jeton>` : la charte avant toute résidence, sa palette (`site_palette`) ensuite, posée par `RacineView` ; palettes **générées** (`scripts/generer-charte.py`) ; `verifier-depot.sh` refuse `Color.red`, `Color(red:)` | `Charte/` |
| Formats | dates, nombres et montants **par `FormatsDuSite`**, à la règle du site (`fmtDate` « 2 avr. 2026 », `fmtDateShort` « 02/04/2026 », `fmtNombre`, `fmtMontant` ; fr-FR, fuseau de Paris ; « — » pour une valeur absente) — jamais un `formatted()` écrit dans un écran (#37) | `Commun/Texte/FormatsDuSite.swift` |
| Typographie | titres `Font.titre(.largeTitle)` (serif New York), texte en styles dynamiques ; libellés `.styleLibelle()` (capitales) ; grands titres de navigation en serif (`ApparenceNavigation`) | `Charte/Charte.swift` |
| Composants | un par notion — catalogue ci-dessous | `Commun/` |
| Données | les écrans parlent à `ServiceCoproFirst` : `ServiceAPI` (client généré, une URLSession éphémère par hôte, jeton au Trousseau si Face ID est accepté) ou `ServiceSimule` (`-api-simulee`) | `Session/`, `Donnees/` |
| État | `@Observable` + `.environment` : `Parcours` (navigation, résidence reconnue puis ouverte), `Reseau` (hors ligne) | `Session/` |
| Navigation | la barre suit `pages_order` (`OrdrePages`), jamais un ordre écrit dans l'app ; chaque page ouvre l'écran que `RegistreDesMenus` inscrit, « Bientôt » sinon ; « où suis-je » en haut à droite | `Navigation/` |
| Erreurs | `ErreurService` : une phrase par cas, jamais un code (421 → « aucune résidence n'y est installée ») | `Session/ErreurService.swift` |
| Mouvement | `.snappy` pour un état, `.smooth` pour un changement de palette, `accessibilityReduceMotion` lu ; retours haptiques sur résidence reconnue, connexion, Face ID, filtre | — |
| Grandes tailles | `@ScaledMetric` ou `.dynamicTypeSize(...xxxLarge)` pour un pictogramme ; une rangée passe en colonne si `dynamicTypeSize.isAccessibilitySize` ; un écran fixe défile | `CarteDuFil`, `AccueilView` |
| Squelette | des identifiants propres (`0..<3`), jamais ceux des vrais éléments : SwiftUI réutiliserait les vues grisées | `FilView` |

## Arborescence (#10)

| Dossier | Contient | Qui y touche |
|---|---|---|
| `Fonctions/<Menu>/` | **un dossier par menu du site** : ses écrans, ses textes, ses états — `Fil` (`tableau-de-bord`), `Affaires` (`mes-demandes`), `Profil` ; à venir : `Residence`, `Annuaire`, `Acces` (`mon-lot`), `Prestataires`, `Communaute`, `FAQ`, `Notifications`, `EspaceCS`, `Delegations`, `Admin` | la session du menu, **seule** |
| `Commun/` | ce que **deux fonctionnalités ou plus** utilisent (catalogue ci-dessous) | personne en passant : un changement ici est un lot à part |
| `Navigation/` | barre, « Plus », ordre des pages (`OrdrePages`), **registre des menus** | une ligne par menu au registre |
| `Entree/` | ce qui précède la résidence ouverte : accueil, démo, vitrine, découverte (adresse, QR), connexion | — |
| `Charte/`, `Session/`, `Donnees/` | couleurs générées, service et état, modèles | — |

`project.yml` déclare `path: CoproFirst` : **tout fichier sous ce dossier est
compilé**, sans rien y ajouter — un dossier neuf ne touche pas `project.yml`. Il
suffit de régénérer le projet (`bash scripts/generer-projet.sh`).

### Ajouter un menu — trois gestes, aucun conflit

1. Le dossier `Fonctions/<Menu>/`, et l'écran rendu conforme à `EcranDeMenu`
   **dans ce dossier** :
   ```swift
   extension AnnuaireView: EcranDeMenu {
       init(contexte: ContexteDeMenu) { self.init(installation: contexte.installation) }
   }
   ```
   `contexte.page` porte le titre réglé par l'administration (`page.titre`), et
   `contexte.chemin` la pile de navigation de l'onglet (pour `navigationDestination`).
2. **Une ligne** dans `RegistreDesMenus.ecrans`, à la place du commentaire de son
   ticket (`"annuaire": AnnuaireView.self,`) — les lignes vides qui séparent les
   tickets évitent les conflits entre sessions parallèles.
3. Ses lignes de `Parite/PARITE.md` passent de `prévu` à `fait`, dans sa section.
   `verifier-parite.py` refuse un `fait` que le registre n'ouvre pas.

Un onglet du site (`liste`, `kanban`…) est une **section de l'écran du menu**
(segment, picker), pas une entrée du registre : le registre ne connaît que les pages.

### Les composants communs — à réutiliser, pas à modifier

Une session de fonctionnalité **s'en sert tels quels**. S'il en manque un ou s'il
faut l'étendre : ticket ou lot à part, jamais au passage d'un écran (quatre
sessions parallèles en dépendent). Un composant utilisé par **une seule**
fonctionnalité reste dans son dossier ; il monte dans `Commun/` à son deuxième usage.

| Composant | Sert à | Où |
|---|---|---|
| `StyleBouton` (`.plein`, `.contour`, `.clair`) | tout bouton d'action | `Commun/Composants/Boutons.swift` |
| `ChampSaisie` | un champ de la charte : libellé en capitales, contour à 3:1, état `enErreur` | `Commun/Composants/` |
| `Carte` | la surface d'une carte : sans ombre, le filet de la charte la détache | idem |
| `Pastille`, `PastilleStatut` | une pastille de filtre (compte sur la retenue) ; le statut d'une affaire (`StatutsAffaire`, généré) | idem |
| `PastilleTeinte`, `LibelleTeinte` | une pastille teintée par la classe `badge-*` du site (`compacte` pour une ligne dense) ; `PastilleStatut` en est le cas des affaires ; une valeur inconnue d'une table s'affiche brute, en gris (`LibelleTeinte.brut`) (#37) | idem |
| `Medaillon`, `Logo` | le logo de CoproFirst, qui suit Dynamic Type — jamais modifié (sa licence) | idem |
| `MessageErreur` | une erreur en une phrase, avec « Réessayer » au besoin | idem |
| `LigneResidence` | une résidence connue : pictogramme, nom, adresse, chevron | idem |
| `PastilleOuSuisJe` | « où suis-je » en barre d'outils (`cloche: true` dans l'espace ouvert) — **sur chaque écran de menu** | idem |
| `.sourceZoom` / `.destinationZoom` | la transition zoom d'iOS 18 (repli iOS 17) | `Commun/Composants/TransitionZoom.swift` |
| `Chargement` | charger puis montrer : squelette, erreur + « Réessayer », contenu — **jamais un écran blanc** | `Commun/Detail/` |
| `DetailAffaireView`, `SondageView`, `DocumentView` | le détail d'une affaire, d'un sondage, d'un document (QuickLook) | idem |
| `GaleriePhotos`, `RepondreFeuille`, `ResumeFeuille` | les photos protégées ; répondre ; le résumé d'un élément du fil | idem |
| `CarteDuFil`, `CarteOuvrable`, `DestinationDuFil` | une carte du fil ; toucher → résumé ; la cible (`affaire`, `sondage`, `document`) → son détail | `Commun/Fil/` |
| `FeuilleResidence`, `PastillesRoles`, `.confirmationDeSortie` | la feuille « où suis-je » ; les rôles ; se déconnecter / changer de résidence | `Commun/Compte/` |
| `TexteDuSite.apercu`, `TexteRiche(html:)` | **le texte riche du site (HTML de l'éditeur)** : `apercu` pour une carte (texte simple, puis `lineLimit`), `TexteRiche(html:)` pour un détail (`.font`, `.foregroundStyle`, `.tint(palette.primary)` de l'appelant ; listes en retrait suspendu, `<li><p>` de l'éditeur compris) — **jamais** `Text(html)`, ni WebKit, ni `NSAttributedString(.html)` (`verifier-depot.sh` refuse) ; liste blanche générée (`BalisesDuSite`) | `Commun/Texte/` |

## À trancher quand le premier cas arrive

- Rafraîchissement automatique sur un 401 en cours de session (intergiciel du
  client) : aujourd'hui, la session se reprend à l'ouverture seulement.
