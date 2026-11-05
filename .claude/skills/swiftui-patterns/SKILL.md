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
| Tests | Swift Testing (`@Test`, `#expect`) pour l'unitaire ; XCTest pour l'interface, éléments trouvés par `accessibilityIdentifier` (`accueil.titre`), jamais par leur texte ni leur type — « Tests d'interface » ci-dessous | `CoproFirstTests/`, `CoproFirstUITests/` |
| Réseau en test | un `ClientTransport` factice (`TransportEnregistreur`) : aucun test ne sort sur le réseau | `Paquets/ClientAPI/Tests` |
| Couleurs | `@Environment(\\.palette) private var palette`, puis `palette.<jeton>` : la charte avant toute résidence, sa palette (`site_palette`) ensuite, posée par `RacineView` ; palettes **générées** (`scripts/generer.py`), teintes du Kanban comprises (`palette.kanbanAg`…, #34) ; `verifier-depot.sh` refuse `Color.red`, `Color(red:)` | `Charte/` |
| Formats | dates, nombres et montants **par `FormatsDuSite`**, à la règle du site (`fmtDate` « 2 avr. 2026 », `fmtDateShort` « 02/04/2026 », `fmtDateLong` « 2 avril 2026 » et `fmtDatetime` « 2 avr. 2026, 16:30 » (#12, la « Dernière connexion » du Profil), `fmtTime` « 16:30 » (`heure`, #41 : une notification du jour, une carte du fil), `fmtNombre`, `fmtMontant` ; fr-FR, fuseau de Paris ; « — » pour une valeur absente) — jamais un `formatted()` écrit dans un écran (#37) | `Commun/Texte/FormatsDuSite.swift` |
| Typographie | titres `Font.titre(.largeTitle)` (serif New York), texte en styles dynamiques ; libellés `.styleLibelle()` (capitales) ; grands titres de navigation en serif (`ApparenceNavigation`) | `Charte/Charte.swift` |
| Composants | un par notion — catalogue ci-dessous | `Commun/` |
| Données | les écrans parlent à `ServiceCoproFirst` : `ServiceAPI` (client généré, une URLSession éphémère par hôte, jeton au Trousseau si Face ID est accepté) ou `ServiceSimule` (`-api-simulee`) | `Session/`, `Donnees/` |
| État | `@Observable` + `.environment` : `Parcours` (navigation, résidence reconnue puis ouverte), `Reseau` (hors ligne) | `Session/` |
| Navigation | la barre suit `pages_order` (`OrdrePages`), jamais un ordre écrit dans l'app ; chaque page ouvre l'écran que `RegistreDesMenus` inscrit, « Bientôt » sinon ; « où suis-je » en haut à droite | `Navigation/` |
| Erreurs | `ErreurService` : une phrase par cas, jamais un code (421 → « aucune résidence n'y est installée ») ; un écran montre `ErreurService.depuis(error).phrase` — « Phrase du serveur » ci-dessous | `Session/ErreurService.swift` |
| Mouvement | `.snappy` pour un état, `.smooth` pour un changement de palette, `accessibilityReduceMotion` lu ; retours haptiques sur résidence reconnue, connexion, Face ID, filtre | — |
| Grandes tailles | `@ScaledMetric` ou `.dynamicTypeSize(...xxxLarge)` pour un pictogramme ; une rangée passe en colonne si `dynamicTypeSize.isAccessibilitySize` ; un écran fixe défile ; **le titre d'un écran de menu** : `.titreDeMenu()` après `.navigationTitle(…)` (grand titre, en ligne aux tailles d'accessibilité — #41), jamais un `navigationBarTitleDisplayMode` calculé dans l'écran | `CarteDuFil`, `AccueilView`, `Commun/Composants/TitreDeMenu.swift` |
| Squelette | des identifiants propres (`0..<3`), jamais ceux des vrais éléments : SwiftUI réutiliserait les vues grisées | `FilView` |

## Arborescence (#10)

| Dossier | Contient | Qui y touche |
|---|---|---|
| `Fonctions/<Menu>/` | **un dossier par menu du site** : ses écrans, ses textes, ses états — `Fil` (`tableau-de-bord`), `Affaires` (`mes-demandes`), `Profil` ; à venir : `Residence`, `Annuaire`, `Acces` (`mon-lot`), `Prestataires`, `Communaute`, `FAQ`, `Notifications`, `EspaceCS`, `Delegations`, `Admin` | la session du menu, **seule** |
| `Commun/` | ce que **deux fonctionnalités ou plus** utilisent (catalogue ci-dessous) ; `Commun/Session/` : les gestes communs du dialogue avec l'API (`Relecture`, `RefusDuServeur`) | personne en passant : un changement ici est un lot à part |
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

Un **fichier généré** depuis coprofirst (table, libellés, règle de données) : un module
`scripts/generateurs/<domaine>.py` — `SOURCES` (les fichiers lus, pour la concordance
de #20) et `generer(ctx)` —, découvert seul par `scripts/generer.py`. Une session
ajoute SON module ; elle n'édite ni `generer.py` ni le module d'un autre. Un module ne lit
coprofirst que par `ctx` (`ctx.lire`, `ctx.front`) : `generateurs/_source.py` seul y touche,
au **plancher** (`generateurs/_plancher.py`), jamais un clone ni l'arbre de travail —
`verifier-depot.sh` refuse le reste. Une teinte est un jeton de la `Palette`, nommé par son
chemin (`\.kanbanAg`) : aucune couleur dans `Genere/`.

Les **onglets** d'une page et ce qu'un compte en ouvre : `OngletsDuSite.ouverts(page:
droits:)` avec `DroitsOnglet(profil: parcours.ouverteAJour?.profil)` (#29). La table
est générée depuis `pages.ts` (réserves comprises), la règle est celle du site : un
écran n'écrit jamais lui-même « le locataire ne voit pas le carnet ».
   `verifier-parite.py` refuse un `fait` que le registre n'ouvre pas.

Un onglet du site (`liste`, `kanban`…) est une **section de l'écran du menu**
(segment, picker), pas une entrée du registre : le registre ne connaît que les pages.

### Un service par menu, réalisé par extension (#11)

Ce qu'un menu demande au serveur ne s'ajoute **pas** à `ServiceCoproFirst`
(`Session/`) : quatre sessions y écriraient au même endroit. Le menu déclare son
propre protocole **dans son dossier**, et les deux services le réalisent par
extension, dans ce même dossier — modèle d'exemple : `Fonctions/Affaires/Donnees/`.

| Fichier du menu | Contient |
|---|---|
| `Service<Menu>.swift` | `protocol Service<Menu>: Sendable`, ses types, et l'accès depuis la session : `extension ServiceCoproFirst { var menu<Menu>: (any Service<Menu>)? { self as? any Service<Menu> } }` |
| `Service<Menu>+API.swift` | `extension ServiceAPI: Service<Menu>` — le client GÉNÉRÉ, rien d'écrit à la main |
| `Service<Menu>+Simule.swift` | `extension ServiceSimule: Service<Menu>` et ses données inventées (un magasin par instance : deux tests ne se marchent pas dessus) |

- **Aucun `nil` silencieux.** Un test affecte les deux services au protocole
  (`let _: any Service<Menu> = ServiceAPI()`, idem `ServiceSimule`) : un oubli de
  conformité casse le build (`CoproFirstTests/ServiceAffairesTests.swift`). À
  l'écran, un service absent se dit en une phrase (`ErreurAffaires.serviceAbsent`),
  jamais par une liste vide.
- **Un modèle que seul le menu lit vit dans le menu** ; il ne monte dans
  `Donnees/` qu'à son deuxième lecteur, comme un composant monte dans `Commun/`.
  Exemple : `Perimetre` (`PerimetreRead`), lu par Ma résidence et Mes affaires, vit
  dans `Donnees/Perimetre.swift` avec **sa** lecture, `ServicePerimetres` ; les deux
  protocoles de menu en **héritent** (`protocol ServiceAffaires: ServicePerimetres`)
  au lieu de redéclarer `perimetres(_:)` avec chacun son type de retour (#41).
- **Une règle du serveur ne se recopie pas** (`standards/09` §8) : le périmètre par
  défaut est `code_par_defaut` côté serveur ; l'app ne le devine pas — « Non précisé »
  envoie un lieu vide, et le serveur pose son défaut — en attendant de le lire dans
  l'API (coprofirst#2514).
- **Les tables que le contrat ne sert pas** (libellés, ordre du front du site) se
  génèrent dans `Fonctions/<Menu>/Genere/`, par un module de `scripts/generateurs/`
  (`ecrire_table`). La 1re ligne dit « GÉNÉRÉ par scripts/generer.py — NE PAS
  MODIFIER » et l'en-tête nomme la version publiée lue : `verifier-depot.sh` refuse un
  fichier de `Genere/` sans elle, et toute couleur (une teinte = un jeton de `Palette`).
  La CI et le workflow quotidien régénèrent tout depuis le plancher et comparent à
  l'octet (#20). **Monter le plancher est une décision** : quand toutes les
  installations connues ont dépassé la nouvelle version (ticket `a-monter`, qui dit
  les champs devenus requis), on change `_plancher.py` et on régénère, dans la même PR.
- **Une réponse de l'API simulée** s'écrit en JSON, à la forme de sa route, dans un
  `Fixtures*.swift` qui la déclare (`Reponse(nom:schema:json:)`) : `scripts/verifier-fixtures.py`
  la juge contre le schéma du serveur — un champ qu'il ne sert pas fait échouer (#13, #20).

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

## Lire une réponse, dire un refus (#41)

| Geste | Règle | Où |
|---|---|---|
| **Réponse non typée** | une route sans `response_model` côté serveur rend un `OpenAPIValueContainer` : il se relit par `Relecture.lire(T.self, depuis: valeur)` (`json:` pour des octets, dans un test) — clés `snake_case` → `camelCase`, dates comme le client généré (ISO, sans fuseau = UTC). Le modèle ne déclare **pas** de `CodingKeys` en `snake_case` (la conversion les rendrait muets). Jamais un `JSONDecoder` monté dans un service. Chaque usage est un besoin noté pour coprofirst (#2460, #2505, #2507) | `Commun/Session/Relecture.swift` |
| **Phrase du serveur** | la réponse non documentée d'un **geste** (POST, PATCH, DELETE) passe par `throw await Self.refus(statut, reponse)` : `{"detail": "…"}` devient `ErreurService.refus(RefusDuServeur)`, dont la `phrase` est celle du serveur ; sans phrase, le cas que dit le statut. Une **lecture** refusée garde `ErreurService.depuisLecture(statut)` (« introuvable »). Un service simulé lève la même chose : `ErreurService.refus(.init(phrase: …))` | `Commun/Session/RefusDuServeur.swift` (tests : `CommunSessionTests`) |
| **Afficher un échec** | `ErreurService.depuis(error).phrase` ; un écran qui a sa propre phrase d'échec (celle du site, « Erreur lors de l'export. ») écrit `ErreurService.phrase(error, sinon: "…")` : la phrase du serveur passe devant. Un menu qui a ses erreurs (`ErreurAffaires`) range un refus en `.service(.refus(…))`, jamais une phrase fixe par statut | `Session/ErreurService.swift` |

## Tests d'interface — la CI tranche, pas le poste (#11, #12)

La CI tourne sous **iOS 26.5** (iPhone 17 Pro), le poste sous **iOS 27.2** : un même
contrôle n'y a pas la même forme d'accessibilité. Un test vert au poste n'est pas vert ;
seule la CI le dit.

1. **Jamais par le TYPE.** Ni `app.buttons[…]`, ni `app.links[…]`, ni `app.textFields[…]` :
   un `Link` est un lien au poste et autre chose sur le runner (#12). Par identifiant,
   quel que soit le type :
   ```swift
   app.descendants(matching: .any).matching(identifier: "nouvelle.titre").firstMatch
   ```
   Un élément sans identifiant (onglet de la barre, segment d'un `Picker`) se cherche
   par son libellé, de la même façon : `app.descendants(matching: .any)["Kanban"]`.
2. **Un identifiant peut être porté par un CONTENEUR** (« Other ») qui enveloppe le
   contrôle — un bouton de barre d'outils sous iOS 26. `firstMatch` convient pour
   `tap()`, **pas** pour lire `isEnabled` ou `value` : le conteneur est toujours actif.
   L'état se lit par un prédicat sur tous les éléments de l'identifiant (#11) :
   ```swift
   app.descendants(matching: .any)
       .matching(NSPredicate(format: "identifier == %@ AND isEnabled == false", "nouvelle.envoyer"))
       .firstMatch.exists
   ```
3. Aucun délai ne s'allonge pour rendre un test vert : un échec de CI se lit dans son
   journal (`gh run view <id> --log-failed`, la ligne « Check for interrupting elements
   affecting … » donne le type réellement trouvé).

## À trancher quand le premier cas arrive

- Rafraîchissement automatique sur un 401 en cours de session (intergiciel du
  client) : aujourd'hui, la session se reprend à l'ouverture seulement.
