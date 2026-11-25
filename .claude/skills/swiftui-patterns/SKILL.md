---
name: swiftui-patterns
description: "Écrire un écran, un état, une navigation ou un appel réseau en SwiftUI dans CoproFirst-iOS — structure des dossiers, état observable, client d'API généré, concurrence stricte, tests, aperçus. À charger avant d'écrire la moindre vue ou le moindre modèle de l'app."
---

<!--
SPDX-FileCopyrightText: 2026 Philippe TRESSARD
SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
-->

# SwiftUI — les patterns de CoproFirst-iOS

> Un pattern utilisé **deux fois** s'écrit ici, à l'identique de ses occurrences
> (`standards/11` §1). Règles générales : `standards/02` (factorisation, 500
> lignes), `standards/11` (interface) — elles ne se recopient pas ici.

## Ce qui est posé

| Sujet | Règle | Où |
|---|---|---|
| Dossiers | voir « Arborescence » ci-dessous : un dossier par fonctionnalité, la vue et ses textes ensemble | `CoproFirst/` |
| Textes | écrits **une fois**, dans un `enum` du domaine (`Accueil.titre`) ; la vue et les tests les lisent là | `AccueilView.swift` |
| Langue | français seul : `developmentLanguage: fr`, `CFBundleLocalizations: [fr]` | `project.yml` |
| API | **le client généré** (`ClientCoproFirst.client(installation:)` ; `ServiceAPI.client`, ou `clientPublic` pour une route publique lue hors de la session : le logo, #345), jamais `URLSession` à la main ; une route absente = un ticket dans coprofirst. Une image que le contrat déclare en JSON se lit par `octetsServis` (`fichierServi` pour un fichier écrit). Les trois lectures écrites à la main — vitrine, preuve d'un hôte, fichiers de `/uploads/` hors du contrat — sont les exceptions comptées de `scripts/verifier-ecritures-vues.py`, qui refuse toute autre | `Paquets/ClientAPI`, `Commun/Session/FichierServi.swift` |
| Vitrine (#51) | les textes d'« En savoir plus » et de la démo viennent de `https://coprofirst.fr/contenu.json` : `Vitrine` (cache, puis le site, une lecture réussie par lancement, à la porte de l'accueil) et `PagesVitrine` (les pages, ou rien si un `id` de `ContenuVitrine.idsRequis` manque) ; copie embarquée **générée** (`generateurs/vitrine.py`, coprofirst-site à un commit épinglé). Une des lectures écrites à la main de l'app (« API » ci-dessus) : un fichier statique du site, pas l'API, en session éphémère, dont aucune adresse n'est ouverte ni contactée. Symboles et ordre accrochés aux `id`, jamais aux titres ; liste figée, protégée côté site (coprofirst-site#66) | `Entree/Contenu/` |
| Mot de passe (#82) | **un seul chemin** : `parcours.garde.connecter(…)` (`GardeHote`). `ServiceCoproFirst.connecter` n'accepte qu'un `HoteConfirme`, que la garde seule fabrique (initialiseur `fileprivate`) : un écran ne peut pas envoyer un mot de passe sans elle. Un hôte jamais vu (ni résidence connue, ni démo écrite dans l'app) — et toute adresse lue dans un QR — ouvre `ConfirmationHoteFeuille` : l'hôte en entier, en chasse fixe, puis la preuve. Preuve : `/.well-known/apple-app-site-association` doit déclarer `GUX8KASNTG.fr.coprofirst.app` (`PreuveAASA`, coprofirst#2459) ; sinon l'avertissement, et un second accord. **Une lecture écrite à la main** de l'app (« API » ci-dessus) : ce fichier n'est pas une route de l'API ; session éphémère, sans cookies ni cache, aucune redirection suivie | `Session/GardeHote.swift`, `Session/PreuveAASA.swift` (tests : `GardeHoteTests`) |
| Préfixe `/api` | ajouté par `ClientCoproFirst.adresseAPI`, et nulle part ailleurs | idem |
| Jeton d'un appareil (#218, #342) | un appareil sans personne (l'écran de hall, la montre) présente son jeton par l'intercepteur `JetonAppareil` du paquet — la seule écriture de `Authorization` — sur UN client qui ne sert que les routes de sa portée (`GET /ecrans/moi/*`, `GET /notifications`). Tout jeton (APNs, session, écran, montre) se garde dans un **`JetonMasque`**, l'unique enveloppe : description, reflet et `dump` le taisent, `enClair` ne se lit qu'où il part ; aucun type ne réécrit son masquage. `scripts/verifier-jetons.py` refuse le reste | `Paquets/ClientAPI/Sources/ClientAPI/JetonAppareil.swift`, `JetonMasque.swift` |
| Coffre sans biométrie | ce qu'un appareil garde sans invite (profil et courriel d'un compte ; l'appairage de l'écran de hall) : `CoffreDuCompte`, réalisé par `CoffreTrousseau` (Trousseau, `AfterFirstUnlockThisDeviceOnly`), `CoffreEnMemoire` en simulation et en test ; compilé aussi par l'Apple TV, et par l'Apple Watch pour sa liaison (`CoffreTrousseau(service:)`, #226). La session sous Face ID reste `Trousseau` | `Session/CoffreDuCompte.swift` |
| Concurrence | Swift 6, `SWIFT_STRICT_CONCURRENCY: complete` | `project.yml` |
| Tests | Swift Testing (`@Test`, `#expect`) pour l'unitaire ; XCTest pour l'interface, éléments trouvés par `accessibilityIdentifier` (`accueil.titre`), jamais par leur texte ni leur type — « Tests d'interface » ci-dessous | `CoproFirstTests/`, `CoproFirstUITests/` |
| Réseau en test | un `ClientTransport` factice (`TransportEnregistreur`) : aucun test ne sort sur le réseau | `Paquets/ClientAPI/Tests` |
| Couleurs | `@Environment(\\.palette) private var palette`, puis `palette.<jeton>` : la charte avant toute résidence, sa palette (`site_palette`) ensuite, posée par `RacineView` ; palettes **générées** (`scripts/generer.py`), teintes du Kanban comprises (`palette.kanbanAg`…, #34) ; `verifier-depot.sh` refuse `Color.red`, `Color(red:)` | `Charte/` |
| Formats | dates, nombres et montants **par `FormatsDuSite`**, à la règle du site (`fmtDate` « 2 avr. 2026 », `fmtDateShort` « 02/04/2026 », `fmtDateLong` « 2 avril 2026 » et `fmtDatetime` « 2 avr. 2026, 16:30 » (#12, la « Dernière connexion » du Profil), `fmtTime` « 16:30 » (`heure`, #41 : une notification du jour, une carte du fil), `fmtJourCourt` « mar. 17 nov. » (`jourCourt`, #75 : la vignette d'échéance du fil, l'année seulement si ce n'est pas la courante), `fmtNombre`, `fmtMontant`, `fmtOctets` (`octets`), `fmtMoisCourt` et `fmtMonthYear` (`moisCourt`, `moisAnnee`, #16), et le nom d'une personne tel que le serveur l'affiche (`nom(affiche:prenom:nom:)` : « Prénom NOM » servi — `nom_affiche`, `locataire_nom_affiche`… — et, d'une installation antérieure, le repli prénom puis nom, écrit là seulement ; `verifier-regles-servies.py` refuse toute autre composition, #135) ; fr-FR, fuseau de Paris ; « — » pour une valeur absente) — jamais un `formatted()` écrit dans un écran (#37) ; les deux formats longs des fiches aussi : `dateHeureLongue` « 2 avril 2026 à 16:30 », `jourHeureLong` « jeudi 2 avril à 16:30 » (#346). `scripts/verifier-ecritures-vues.py` refuse `.formatted(`, `format: .dateTime`, `format: .number` et les formateurs hors de `Commun/Texte/`, ses exceptions comptées et datées | `Commun/Texte/FormatsDuSite.swift` |
| Séparateurs | « · », « — », « → » entre deux éléments d'une ligne : **`Separateur.point`, `.tiret`, `.fleche`**, générés depuis `SEPARATEUR` du site — espace sécable avant, insécable après, la ligne ne finit jamais sur un séparateur. Jamais `" · "` ni la constante recopiée : `scripts/verifier-separateurs.py` les refuse ; le tiret d'une incise dans une phrase n'en est pas un (#188) | `Commun/Texte/Genere/Separateur.swift` |
| Typographie | titres `Font.titre(.largeTitle)` (serif New York), texte en styles dynamiques ; libellés `.styleLibelle()` (capitales) ; grands titres de navigation en serif (`ApparenceNavigation`) | `Charte/Charte.swift` |
| Mesures | ce qui donne sa forme à l'app se lit dans `Mise` : rayons (`rayon` des cartes, `rayonTuile` d'une tuile dans une carte), marges d'écran (`marge`), cibles tactiles (`cible`), médaillons (`medaillon`), colonnes et largeurs (`listeIdeale`, `lecture`…) ; un petit espacement (`spacing:`, `padding`) reste écrit sur place (#347). `scripts/verifier-ecritures-vues.py` refuse `cornerRadius: <nombre>` et un cadre de 44 pt hors de `Charte/`, ses exceptions comptées et datées. Une mesure que le site a en jeton se lit dans `MesuresDuSite` (**générée**) ; une mesure propre à iOS se déclare (raison, date) dans `MesuresTests`, qui refuse une mesure non déclarée ou un écart devenu caduc (#85) | `Charte/Charte.swift`, `CoproFirstTests/MesuresTests.swift` |
| Pictogrammes | le nom **Lucide** du site, traduit par `Pictogrammes.symbole` ; un nom neuf d'une table générée ajoute son entrée à `Pictogrammes.table`, sinon `PictogrammesTests` échoue (le repli `circle.fill` ne sert qu'à l'écran, jamais en silence — #85) | `Charte/Theme.swift` |
| Composants | un par notion — catalogue ci-dessous | `Commun/` |
| Données | les écrans parlent à `ServiceCoproFirst` : `ServiceAPI` (client généré, une URLSession éphémère par hôte, jeton au Trousseau si Face ID est accepté) ou `ServiceSimule` (`-api-simulee`). Un 401 se renouvelle à UNE porte, `Renouvellement` (intergiciel du client généré, #81) : un seul POST /auth/refresh à la fois par hôte, la requête rejouée une fois ; `reprendre` y passe aussi | `Session/`, `Donnees/` |
| Consultation hors ligne (#101) | la dernière lecture d'une résidence se garde à UNE porte, glissée entre le client généré et le transport (`GarderLesLectures`, la plus extérieure) : une lecture de sa liste blanche (`LectureGardee.operations` — fil, affaires, détail, profil, annuaire, document ; **rien de l'administration ni de l'Espace CS**) qui réussit s'écrit dans `LecturesGardees` (`Application Support`, un dossier par hôte, `Fichiers.ecrire`, exclu des sauvegardes, 7 jours au plus, `LectureGardee.joursMax`) ; en consultation, la même porte la sert et refuse tout le reste (`horsLigne`) avant de partir. Un fichier protégé se lit par `fichierConsultable`, jamais `fichierProtege` depuis un écran. Le jeton, la lecture et les copies s'effacent ensemble, `oublierCeQuiEstGarde` (`verifier-depot.sh` refuse un `Trousseau.supprimer(` ailleurs). Aucun service de menu n'y touche : un menu neuf dont la lecture doit se garder ajoute sa route à la liste blanche, rien d'autre | `Session/LectureGardee/` (tests : `LectureGardeeTests`, `ConsultationHorsLigneTests`, `EntreeHorsLigneTests`, `HorsLigneUITests`) |
| État | `@Observable` + `.environment` : `Parcours` (navigation, résidence reconnue puis ouverte, `consultation` hors ligne), `Reseau` (hors ligne) | `Session/` |
| Navigation | la barre suit `pages_order` (`OrdrePages`), jamais un ordre écrit dans l'app ; une page réservée à un rôle (Prestataires, Espace CS, Admin, Délégations) n'y paraît qu'à qui l'a — `PagesOuvertes`, le filtre de `Nav.svelte`, écrit une fois, sur les populations générées (#15) — copie PARTIELLE et datée : depuis le contrat 2.11.0, le serveur SERT la règle (`acces_menu` de GET /auth/me, croisé avec `pages[].acces`, coprofirst#3003), au-dessus du plancher ; l'aidant et le compte technique y voient plus que sur le site. Elle se retire quand le plancher atteint 2.11.0 (`PagesOuvertesTests` rougit alors, #355) ; chaque page ouvre l'écran que `RegistreDesMenus` inscrit, « Bientôt » sinon ; « où suis-je » en haut à droite. **Présentation** (#221) : choisie sur la classe de taille HORIZONTALE, jamais sur l'appareil (`PresentationNavigation.pour`, tenue dans `Parcours.presentation` par `RacineView`) — barre du bas (`BarreDuBas`, quatre pages puis « Plus ») ou barre latérale (`BarreLaterale`, `NavigationSplitView` à deux colonnes, iOS 17), ou le carnet de l'iPhone pliable ouvert (`Carnet`, intercalaires sur la tranche droite, #119) — en classe régulière, la charnière (`Posture`, lue par `UIHingeInteraction` d'iOS 27.1 : UIKit seul, sous `#if compiler(>=6.4)` car la CI compile sous Xcode 26 ; `-posture deplie` la fixe en Debug) départage l'iPhone pliable de l'iPad ; la page affichée par la barre latérale et le carnet est `PageRetenue` ; `OngletsView` est LE point de choix, une présentation de plus s'y ajoute. Un seul état, `Parcours.onglet` (+ `ouverteDansPlus`) : le passage de l'une à l'autre garde la page (`PresentationNavigation.traduire`) ; Profil et À propos sont des `EntreeFixe` | `Navigation/` |
| Porte (liens, notifications) | un lien universel (#18) ou le toucher d'une notification (#17) devient une `Destination` (résidence par son adresse + écran) ; **seul** `parcours.suivre(_:decouvrir:)` l'ouvre (une notification passe `decouvrir: false` : une adresse inconnue n'ouvre rien, aucun annuaire) : résidence ouverte → l'écran (`Aiguillage` : onglet, « Plus », ou feuille), connue → sa connexion (ou l'entrée, si elle la montre déjà) puis l'écran (`porte.enAttente`), jamais vue → connexion pré-remplie, `origine: .lien` (`OrigineAdresse` : confirmation d'hôte toujours, comme un scan, #82). Un chemin d'un lien se lit par la route générée (`PagesParDefaut`), jamais une liste écrite ; une page que l'app ne porte pas → Safari intégré (`PageWebView`), jamais `openURL` (le lien reviendrait à l'app). Au simulateur : `-lien <adresse>` ; `Destination.Ecran.notifications` (#17) ouvre la cloche, UNE feuille posée par `OngletsView` sur `parcours.clocheOuverte`, que tout autre écran demandé referme | `Navigation/Porte/` (tests : `PorteTests`, `LiensUITests`) |
| Erreurs | `ErreurService` : une phrase par cas, jamais un code (421 → « aucune résidence n'y est installée ») ; un écran montre `ErreurService.depuis(error).phrase` — « Phrase du serveur » ci-dessous | `Session/ErreurService.swift` |
| Mouvement | `.snappy` pour un état, `.smooth` pour un changement de palette, `accessibilityReduceMotion` lu ; retours haptiques sur résidence reconnue, connexion, Face ID, filtre | — |
| Grandes tailles | `@ScaledMetric` ou `.dynamicTypeSize(...xxxLarge)` pour un pictogramme ; une rangée passe en colonne si `dynamicTypeSize.isAccessibilitySize` ; un écran fixe défile ; **le titre d'un écran de menu** : `.titreDeMenu()` après `.navigationTitle(…)` (grand titre, en ligne aux tailles d'accessibilité — #41), jamais un `navigationBarTitleDisplayMode` calculé dans l'écran | `CarteDuFil`, `AccueilView`, `Commun/Composants/TitreDeMenu.swift` |
| Notifications push | `NotificationsPush` (`@Environment`) : autorisation demandée **après un geste** (`OffrePush`, dans la cloche), jamais au lancement ; POST /appareils à chaque ouverture d'une résidence, DELETE avant la déconnexion ; l'abonnement opaque (`AbonnementsPush`) est la seule clé lue dans une charge ; le jeton (`JetonAPNs`) est un `JetonMasque` et ne s'écrit nulle part. Sous `-api-simulee`, `CentreSimule` (`-push non-demandee|refusee`, `-push-touchee`) | `Fonctions/Notifications/Push/` |
| Mesure d'audience (coprofirst#2726, #198) | un écran qui porte une page du site se note `.pageVue(chemin)` — le chemin **du site** (`CheminDuSite` : la route générée d'une page, `/tickets/<id>` — `CheminDuSite.affaire(_:)`, et `adresse(affaire:sur:)` pour le lien qui se copie, jamais `"tickets/…"` écrit, #348 —, `<route>#<onglet>`) ; le registre des menus, `CadreAOnglets` et les détails d'affaire et de sondage le font déjà, un écran de menu n'a rien à ajouter. La file (`MesureAudience`, tenue par `Parcours`) part par lots à la borne GÉNÉRÉE (`LimitesAudience`), toutes les 30 s et au passage en arrière-plan, avec le canal ajouté au corps généré (`CorpsEnvoye`) ; rien si le compte refuse (`ProfilResidence.refusMesure`, inconnu = refus), si l'installation ne dit pas servir le plancher (`installation.sert(.plancher)`, #254), ou hors ligne. Un échec ne se dit pas | `Session/Audience/` (tests : `MesureAudienceTests`) |
| Squelette | des identifiants propres (`0..<3`), jamais ceux des vrais éléments : SwiftUI réutiliserait les vues grisées | `FilView` |

## Arborescence (#10)

| Dossier | Contient | Qui y touche |
|---|---|---|
| `Fonctions/<Menu>/` | **un dossier par menu du site** : ses écrans, ses textes, ses états — `Fil` (`tableau-de-bord`), `Affaires` (`mes-demandes`), `Profil`, `Residence`, `Annuaire`, `Acces` (`mon-lot`), `Prestataires`, `Communaute`, `FAQ`, `Notifications`, `EspaceCS`, `Delegations`, `Admin` | la session du menu, **seule** |
| `Commun/` | ce que **deux fonctionnalités ou plus** utilisent (catalogue ci-dessous) ; `Commun/Session/` : les gestes communs du dialogue avec l'API (`Relecture`, `RefusDuServeur`, `FichierServi`) | personne en passant : un changement ici est un lot à part |
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

**Une page à beaucoup d'onglets** (l'Espace CS #15, le Paramétrage #16) : un CADRE écrit
une fois, `CadreAOnglets` (`Commun/Onglets/` : titre, `BarreOnglets` sur
`OngletsDuSite.ouverts`, descriptif généré, défilement, « tirer pour actualiser »,
`avisEphemere`), que la page déclare par une `PageAOnglets` (id, table, descriptifs, phrase
de réserve), et une TABLE d'onglets (`OngletsEspaceCS.ecrans`, `OngletsAdmin.ecrans`, une
ligne par onglet, séparée par une ligne vide), chaque onglet dans SON dossier
(`Fonctions/<Page>/<Onglet>/`) avec son protocole de service. Ajouter un onglet : le
dossier, la vue conforme à `OngletDePage` (`init(contexte: ContexteOnglet)`), une ligne
dans la table, sa ligne de parité — le cadre ne se touche pas. Une page que l'app ne porte
qu'**en partie** passe ses `routes` (générées) : la barre n'offre que les onglets inscrits,
puis « Sur le site » (`OngletSurLeSite`), qui liste les autres avec leur lien ; un écran
qui laisse une part au site le dit par `RenvoiAuSite` (`Fonctions/Admin/`).

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
- **Une règle du serveur ne se recopie pas** (`standards/09` §8) : ce que le serveur
  SERT se lit, jamais ne se recalcule — le périmètre par défaut (`par_defaut`,
  `Perimetre.codeParDefaut`), l'affaire close et urgente (`TicketRead.close`, `.urgente`),
  les gestes d'une délégation ou d'une affiche (`peut_accepter`, `peut_restaurer`…), le
  rang d'un porteur, le rapprochement d'un nom, l'annonce d'une validation (#53-#56),
  les catégories qu'un compte peut poser et ce qui lui est ouvert du réservé au conseil
  (`permise`, `reservee` : `ReferentielsAffaires.permises`, `.poseLesReservees` — jamais
  « est du conseil » déduit du profil, #105 ; `verifier-regles-servies.py` le refuse).
  Un geste que le serveur n'ouvre pas ne s'affiche pas ; un champ absent vaut « non ».
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
  Elle se lit par le type GÉNÉRÉ puis le MÊME branchement que le service réel
  (`Relecture.generee` → `Modele(_:)`). Une liste que les gestes simulés changent se tient
  par `modifierSimule(depuis: Fixtures….lues) { … }` (`EspaceCS/MagasinSimuleCS.swift`) :
  lue des fixtures au premier usage, une par type et par service simulé.
- **Une route que le contrat ne type pas** (sans `response_model`) : le service la relit par
  `Relecture.lire(_:depuis:)` — chaque usage est un ticket coprofirst —, et sa réponse
  simulée se déclare par sa ROUTE, `ReponseNonTypee(nom:route:json:)`, lue par le même
  `Relecture` (`.lire(_:)`). Le juge vérifie que la route existe et qu'elle n'est toujours pas
  typée : le jour où le contrat la type, il échoue, et la lecture passe au type généré (#16).
- **Un champ servi au-dessus du plancher** sur une route TYPÉE (#89) : l'API simulée le
  sert à la forme du serveur, et le `Fixtures*.swift` le déclare,
  `AuDessusDuPlancher(schema:champs:contrat:)` ; le juge le tolère dans ce schéma seulement,
  et échoue le jour où le contrat le déclare, ou quand plus aucune réponse ne le sert.
- **Une borne que le contrat pose sur un corps** (`maxItems`) et que le client généré
  n'expose pas : elle se GÉNÈRE du contrat (`generateurs/notifications.py` →
  `LimitesNotifications`), jamais un nombre écrit dans un écran ; l'API simulée refuse
  comme le serveur ce qui la dépasse (422), et le geste se découpe à sa taille — ce qui
  est déjà fait ne revient pas si une requête échoue en route, et la phrase dit combien
  (`EtatNotifications.supprimer`, `SuppressionInterrompue`, #118).

### Les composants communs — à réutiliser, pas à modifier

Une session de fonctionnalité **s'en sert tels quels**. S'il en manque un ou s'il
faut l'étendre : ticket ou lot à part, jamais au passage d'un écran (quatre
sessions parallèles en dépendent). Un composant utilisé par **une seule**
fonctionnalité reste dans son dossier ; il monte dans `Commun/` à son deuxième usage.

| Composant | Sert à | Où |
|---|---|---|
| `StyleBouton` (`.plein`, `.contour`, `.clair`), `StyleAppui`, `.appuiCharte(_:)`, `.survolCharte()` | tout bouton d'action — le survol du pointeur de l'iPad (#223) est dans `StyleBouton` et `StyleCarte`, un style propre neuf le pose aussi ; un bouton dont le libellé porte déjà sa forme (un état à choisir, #207) prend `StyleAppui` : l'appui de la charte seul (97 %, rien en mouvement réduit), jamais un `scaleEffect` recopié | `Commun/Composants/Boutons.swift` |
| `ChampSaisie` | un champ de la charte : libellé en capitales, contour à 3:1, état `enErreur` | `Commun/Composants/` |
| `Carte` | la surface d'une carte : sans ombre, le filet de la charte la détache | idem |
| `Pastille`, `PastilleStatut` | une pastille de filtre (compte sur la retenue) ; le statut d'une affaire : sa teinte GÉNÉRÉE par code (`StatutsAffaire.pastilles`), son libellé EN CLAIR servi. L'état en clair n'a qu'UNE écriture, `StatutsAffaire.libelle(_:servi:dans:)` : servi avec l'objet (`statut_libelle`, `nouveau_statut_libelle`…, #127), sinon par les référentiels servis avec l'affaire (`statuts[].libelle`, #105), sinon le code — plus aucune table du site | idem |
| `ChoixPerimetres` + `ChoixDePerimetres` | le choix de périmètres en pastilles (`PerimetrePicker.svelte`) : des têtes, puis les espaces d'une seule ; la règle vit dans `ChoixDePerimetres`, la vue la dessine. `ChoixDePerimetres(unique: true)` : le `mode="single"` du site (le lieu d'un écran de hall, #295) — un toucher remplace, même rendu | `Commun/Composants/ChoixPerimetres.swift`, `Donnees/ArbreDesPerimetres.swift` (tests : `ChoixDePerimetresTests`) |
| `PastilleLecture`, `LectureDetaillee`, `EtiquetteLieu` | « qui la lit » SERVIE (`Lecture`, contrat 1.22.0, #129) : la pastille bleue d'une carte (pictogrammes, libellé court, cadenas), rien quand personne n'est exclu (`Lecture.aMontrer`) — sauf pour une saisie, `memeParDefaut` (`QuiLaLira`) ; sur un détail, la phrase entière. Le lieu servi (`LieuServi.lieu`, #130) : l'épingle et le libellé, rien pour le défaut. Affaires (liste, détail), fil, idées, annonces, sondages | `Commun/Composants/PastilleLecture.swift`, `Donnees/Lecture.swift`, `Donnees/LieuServi.swift` (tests : `LectureEtLieuServisTests`) |
| `TitreAvantIcone` | le titre, puis l'icône (« 💡 Synthèse ⌄ », « Lendemain › ») ; `policeIcone` pour un chevron plus discret que le titre | `Commun/Composants/TitreAvantIcone.swift` |
| `PastilleTeinte`, `LibelleTeinte` | une pastille teintée par la classe `badge-*` du site (`compacte` pour une ligne dense) ; `PastilleStatut` en est le cas des affaires ; une valeur inconnue d'une table s'affiche brute, en gris (`LibelleTeinte.brut`) (#37) | idem |
| `Medaillon`, `MedaillonPlein` | le logo de CoproFirst (la marque), qui suit Dynamic Type — jamais modifié (sa licence) | idem |
| `LogoResidence` | **le seul** composant du logo de la résidence (pastille, feuille, connexion) : le logo téléversé, sinon celui de CoproFirst. Au sombre, la variante `sombre` quand l'installation la sert (`Installation.adresseLogo(sombre:)` : `site_logo_sombre` seul, le plancher sert la variante — aucune porte, #254) ; il suit le thème sans relancer, en fondu, sans repasser par la marque. Cache `LogosEnMemoire`, une entrée par adresse donc par variante (#70) | `Commun/Composants/LogoResidence.swift` (tests : `LogoResidenceTests`) |
| `VersionContrat`, `Installation.sert(_:)` | **la seule** comparaison de versions du contrat (`version_contrat` de GET /config), par ses nombres : un geste réservé à une version s’écrit `installation.sert(.plancher)` ou `installation.sert(.porte)` (contrat absent ou illisible : porte fermée), jamais sur la chaîne. Une porte ne vit qu’au-dessus du plancher, retirée quand il la dépasse (#254) ; celle d’une ROUTE au-dessus du plancher se génère avec elle (voir « Route au-dessus du plancher » ; aucune au plancher v3.121.2, #313) | `Session/VersionContrat.swift`, `Session/ContratDuPlancher.swift` (généré) |
| `MessageErreur` | une erreur en une phrase, avec « Réessayer » au besoin | idem |
| `BandeauHorsLigne` | l'état hors ligne, en haut, sans alerte : posé SANS condition par l'écran (`.safeAreaInset(edge: .top)`), il dit « à jour au… » en consultation (#101), « ce qui est affiché peut dater » quand le réseau tombe l'app ouverte, et rien sinon | `Commun/Composants/BandeauHorsLigne.swift` |
| `BandeauInstallation` | l'installation suspendue, lecture seule (R6, #262), sans alerte : sous la barre de CHAQUE page, posé une fois par `RegistreDesMenus.ecran` et les pages fixes (`.bandeauInstallation()`) — un écran ne le pose pas ; dans la connexion et au retour, `BandeauInstallation(encartPour:)` | `Commun/Composants/BandeauInstallation.swift` |
| `.encartAvertissement()` | l'encart d'avertissement du site (fond, bordure et rayon « warning ») — jamais ces trois lignes recopiées | `Commun/Composants/EncartAvertissement.swift` |
| `.gesteEnLigne()` | **tout** contrôle qui agit sur le serveur (envoyer, voter, déposer, exporter, modifier, archiver…) : en consultation hors ligne, il reste en place, grisé, et VoiceOver dit pourquoi — jamais un `if horsLigne` dans un écran. Un geste oublié ne part pas pour autant : la porte du client le refuse | `Commun/Composants/GesteEnLigne.swift` |
| `LigneResidence` | une résidence connue : pictogramme, nom, adresse, chevron | idem |
| `BarreOnglets` | les onglets d'une page en pastilles qui défilent (`onglet.<id>` pour les tests) ; ses onglets viennent d'`OngletsDuSite.ouverts` | `Commun/Composants/BarreOnglets.swift` |
| `CadreAOnglets`, `PageAOnglets`, `OngletDePage`, `OngletSurLeSite` | le cadre d'une page à onglets, ce qu'un onglet reçoit (`ContexteOnglet`), la pastille « Sur le site » | `Commun/Onglets/` |
| `OngletComptesCS`, `CarteDeFile`, `ValidationCompteFeuille` | la file de travail des comptes et des commandes d'accès (`require_cs_or_admin`) : l'Espace CS et « À traiter » ; une ligne de file avec « Approuver » et « Rejeter » | `Commun/Validations/` |
| `FlowCapsules` (`RangeesQuiPassent`) | des capsules qui passent à la ligne (spécialités d'un prestataire, pastilles d'un compte, capsules d'un contrat) ; une capsule plus large que la rangée y prend une ligne à elle et passe à la ligne dans sa largeur — jamais hors de la rangée pour l'éviter (#191) | `Commun/Composants/RangeesQuiPassent.swift` (tests : `RangeesQuiPassentTests`) |
| `.avisEphemere(avis)`, `avis.dire(…)` | la phrase brève qui suit un geste (le « toast » du site), portée par un `AvisDuGeste` que **seul l'avis lit**. Jamais une `Binding<String?>` : une `Binding` lit sa valeur dès sa création, et l'écran qui la fabrique se recalcule à l'arrivée et au retrait de l'avis — ses menus de barre d'outils reconstruits sous le doigt perdaient un toucher (#48). Même règle pour tout état éphémère qui change seul (minuterie) : un objet observable lu là où il s'affiche. Une **feuille** qui annonce dit `avis.direApresFermeture(…)`, et sa présentation porte `.sheet(…, onDismiss: { avis.feuilleFermee() })` : dite avant la fermeture, la phrase passait ses 4 s derrière la feuille (#43, #48). L'avis ne retient aucun toucher (`allowsHitTesting(false)`) : au très grand texte, il couvrait le bouton suivant (#207). Une phrase SERVIE garde son ton : `avis.dire(PhraseAvis(annonce))` — `TonAvis` (`success`, `warning`, `error`, `info`) choisit le pictogramme et le retour haptique (#55) | `Commun/Composants/AvisEphemere.swift` (tests : `AvisEphemereTests`) |
| `FeuilleDeSaisie`, `BoutonsFeuille` | **toute feuille de saisie** : `FeuilleDeSaisie(titre:erreur:) { champs } barre: { BoutonsFeuille(…) }` — la pile, le formulaire sur le fond, la phrase du serveur en tête, le titre en ligne (#348) ; jamais ce squelette recopié. `BoutonsFeuille` : « Annuler » / « Enregistrer », « Enregistrement… » pendant l'envoi, `actif` | `Commun/Composants/FeuilleDeSaisie.swift`, `BoutonsFeuille.swift` |
| `LienDeContact.courriel(_:)`, `.appel(_:)` | l'adresse `mailto:` ou `tel:` d'un courriel ou d'un numéro touché, formée une fois (#348) ; chaque écran garde son rendu | `Commun/Composants/LienDeContact.swift` |
| `ChampRecherche`, `.barreDeRecherche`, `Recherche.contientTousLesMots` | le champ de recherche d'une liste, dans la page — ou `.barreDeRecherche` dans la barre de navigation, jamais un `.searchable` nu : les deux posent ⌘F (#223, `verifier-depot.sh`) ; la règle du site (tous les mots, sans accents ni casse) ; un autre raccourci sans surface : `RaccourciClavier` — mais une touche que le système tient (⌘F, ⌘G, ⌘U) ne l'atteint pas : on répond à son action (`find:` au délégué, `RechercheAuClavier.swift`) | `Commun/Composants/`, `Commun/Texte/Recherche.swift` |
| `PastilleOuSuisJe` | « où suis-je » en barre d'outils (`cloche: true` dans l'espace ouvert) — **sur chaque écran de menu** ; `largeurNom` réduit le nom quand un élément occupe la gauche de la barre (le logement du fil) : sans quoi iOS replie la pastille et la cloche dans « … » | idem |
| `.sourceZoom` / `.destinationZoom` | la transition zoom d'iOS 18 (repli iOS 17) | `Commun/Composants/TransitionZoom.swift` |
| `Chargement` | charger puis montrer : squelette, erreur + « Réessayer », contenu — **jamais un écran blanc** | `Commun/Detail/` |
| `DetailAffaireView`, `DocumentView` | le détail d'une affaire, d'un document (QuickLook) | idem |
| `FilAffaire`, `EtapeFil`, `DepliageDuFil`, `RangeeDuRail` | le fil d'une affaire ouverte (#178) : La demande, La suite, Comptes rendus, La synthèse sur un rail, éléments en retrait ; `EtapeFil.du` dit les sections et leurs pastilles (pure, testée), `DepliageDuFil` ce qui est ouvert — un toucher : `DepliageDuFil.regard` (4 s), garder ouvert : double toucher, appui long, action d'accessibilité ; toucher sous VoiceOver = garder. Ses changements partent dans UNE animation (`withAnimation` du modèle) : une animation posée sur l'élément seul laissait le contenu chevaucher ses voisins | `Commun/Detail/Affaire/Fil/` (tests : `FilAffaireTests`) |
| `.bandeauAffaire(…)`, `GesteAffaire.offerts`, `SuiteFeuille`, `ModifierAffaireFeuille`, `ServiceGestesAffaire` | le bandeau d'une affaire en barre du bas : 🔗 · 💬 · 🔄 · ✏️ · options · 📦, chacun selon le droit SERVI (`DroitsServisAffaire`, `peut_*`), 💬 hors conseil ; ses gestes passent par les deux portes de `ServiceAPI+Detail` — `ajouterEvolution` (POST …/evolutions) et `modifierAffaire` (PATCH), que le menu Affaires emprunte aussi | `Commun/Detail/Affaire/` |
| `.gestesHistorique(…)`, `.gestesSuite(_:)`, `GesteSuite.offerts`, `CorrectionSuite` | les gestes d'UNE entrée de l'Historique (#91, #93) : « ⋯ » à droite de l'entrée (menu du système) et les mêmes en actions d'accessibilité — « Modifier la suite » rouvre `SuiteFeuille` partie de l'entrée (`corrigee:`), « Supprimer cette entrée » se confirme. Chacun selon le droit servi AVEC l'entrée (`DroitsServisSuite` : `peut_modifier`, `peut_supprimer`, contrat 1.19.0, typés au plancher depuis 1.26.0 : `SuiteAffaire(evolution:)`) ; absent, aucun geste. L'écran pose `.gestesHistorique` (feuille, question, alerte, avis), l'entrée `.gestesSuite` ; la correction n'envoie que ce qui a changé. Ce que l'affaire a fait de la correction se lit dans la réponse (`IssueCorrection.lue`, par le type généré, #187) : non suivie, une alerte la feuille fermée — la phrase servie, et l'état servi proposé selon `peut_changer_etat`, appliqué par `ajouterSuite` | `Commun/Detail/Affaire/GestesHistorique.swift`, `CorrectionSuite.swift`, `IssueCorrection.swift`, `ServiceSimule+Historique.swift` (le faux serveur), `Donnees/SuiteAffaire+Servie.swift` (tests : `SuiteHistoriqueTests`, `IssueCorrectionTests`, `HistoriqueUITests`) |
| `SectionPrestataires`, `PrestataireAffaire.liste(_:)`, `TextesPrestatairesAffaire.carte` | les prestataires d'une affaire (#181) : sur la fiche, une ligne chacun (`DetailAffaire.intervenants`, le rythme après le dernier) ; au Kanban, le premier puis « +N » ; dans « Modifier », une ligne à × chacun, « Monter » / « Descendre » (menu contextuel, actions d'accessibilité), puis « Ajouter un prestataire » (menu des prestataires de la résidence qui n'y sont pas) — selon `peut_changer_prestataires` seul ; la liste ENTIÈRE part, si elle a changé | `Commun/Detail/Affaire/`, `Donnees/PrestatairesAffaire.swift` (tests : `PrestatairesAffaireTests`, `PrestatairesAffaireUITests`) |
| `ChampsAffaire`, `SaisieAffaire.edition(depuis:)` | les champs d'une affaire, écrits une fois pour la Création et l'Édition ; l'Édition n'envoie que ce qui a changé (`EditionAffaire`), et ne réécrit pas une description que `TexteDuSite.saisi(html:)` ne sait pas refaire sans perte | `Fonctions/Affaires/Nouvelle/`, `Commun/Detail/Affaire/` |
| `SondageView` | la fiche d'un sondage, comme celle du site (#38) : vote (réponse à préciser, commentaire, charte ; « Voter » dit ce qui manque), résultats, fil des commentaires — avec SON service (`ServiceSondage`, API et simulé, `FixturesSondage`) | `Commun/Detail/Sondage/` |
| `FilReponses`, `GestesReponses`, `RetraitDeReponse` + `.confirmationDeRetrait` | le fil des réponses d'une idée, d'une annonce, ou les commentaires d'un sondage (`Reponses.svelte`) : « Supprimer » suit `peut_supprimer` (servi), « Signaler » s'offre sur les réponses des autres ; l'écran passe ses gestes et pose la confirmation sur SA liste — posée sur une section ou une rangée de liste, elle n'entrait pas dans l'arbre d'accessibilité | `Commun/Reponses/` |
| `.signalementAuConseil($cible)` + `ServiceSignalements` | « Signaler au conseil syndical », motif obligatoire (`signaler()` du site), mots dans `TextesSignalement` ; POST /signalements, dont les protocoles de menu héritent, ou `service.signalements` (une affaire, ses suites, le Règlement). Les cibles `affaire`, `suite`, `question_reglement` (`CibleSignalement.affaire(_:)`…) ne s'offrent qu'à une installation qui dit servir le plancher (`installation.sert(.plancher)`, #286 ; la porte `.moderation` s'est retirée à v3.121.2, #313) | `Commun/Composants/SignalementAuConseil.swift`, `Donnees/Signalement.swift` |
| `.confirmationMasquage($auteur)`, `AuteurAMasquer`, `ServiceMasquages`, `TextesMasquage` | « Masquer ce que publie… » (#286) : ne s'offre que là où le nom s'affiche (`AuteurAMasquer(id:nom:moi:)`, `nil` pour soi ou un anonyme), derrière `installation.sert(.plancher)` (#313) ; l'alerte du site, puis le geste de l'écran (la Communauté relit son onglet, une affaire se relit). Le filtre est au serveur, jamais refait ; la règle (qui ne se masque pas) aussi : 422 avec sa phrase. Profil › Personnes masquées le défait | `Commun/Composants/MasquageAuteur.swift`, `Donnees/Masquage.swift`, `Fonctions/Profil/PersonnesMasquees.swift` (tests : `ModerationTests`, `ModerationUITests`) |
| `avis.agir(avec:reussite:apres:_:)`, `avis.traiter(_:_:)` | un geste qui s'annonce par l'avis : service absent → « pas disponible », réussite → la phrase puis `apres` (relire), échec → la phrase du serveur. Le geste d'une FILE à traiter (Espace CS › Comptes, Admin › À traiter) : `avis.traiter($echec) { … }`, l'échec dans la page (#348). Jamais un `guard let service … do/catch` recopié | `Commun/Composants/AvisDuGeste+Agir.swift` |
| `.elementIdentifie(_:lu:)` | **tout** élément que les tests trouvent par identifiant et qui porte une icône et un texte (`Label`) : lu en UN élément qui dit son libellé — sous iOS 26, un `Label` identifié se résout en son image, intouchable (#183) ; `scripts/verifier-identifiants.py` refuse un `Label` identifié autrement | `Commun/Composants/ElementIdentifie.swift` |
| `ListeEtFiche`, `LienDeFiche`, `ColonneDeFiche`, `PageEtColonneDeFiche`, `.rangeeChoisie(_:)` | **toute liste qui ouvre une fiche** (#222) : `ListeEtFiche(selection: $choisi, memoire: "affaires") { liste } fiche: { Fiche($0) }` — la sélection appartient à l'écran, et une liste qui se NOMME (`memoire:`) la retrouve quand l'écran se reconstruit (changement de présentation, retour à la page) : `MemoireDesSelections`, tenue par `Parcours`, posée par `EcranDePage` (`\.selectionsDeLaPage`), clé page + liste — sans nom, rien n'est gardé (deux listes d'une page, du même type, ne s'échangent pas leur fiche) ; un `nil` voulu efface la case ; reprise AVANT d'ouvrir la colonne (pas de clignement « Aucune sélection »). Sur disque, le marque-page du pliable seul (#119), pour un élément `SelectionGardable` (son identifiant seul : `AffaireAOuvrir`), effacé par `oublierCeQuiEstGarde`. `Disposition.pour(classe, colonneFournie:)` : compacte → la fiche poussée (`navigationDestination(item:)`) ; régulière → la fiche dans la **colonne de fiche** que FOURNIT la page par l'environnement (`\.colonneDeFiche`), une pile **sœur** de celle de la page, chacune sa barre (Mail, Notes) — jamais une pile imbriquée dans la page : sa barre est celle de la page, la fiche y prenait titre, boutons et bandeau du bas. `PageEtColonneDeFiche` la fournit (la barre latérale l'emploie) ; la liste qui apparaît l'occupe (`jeton`), celle qui disparaît la rend, une page sans liste (Kanban) garde toute la largeur. Sans colonne fournie, repli côte à côte dans la page. Largeur de la liste : `Partage` (`.parDefaut` : `Mise.listeIdeale`, jamais plus de la moitié ; `.proportion(0.5)` pour le carnet, #119). Une rangée, à n'importe quelle profondeur de la liste, ouvre sa fiche par **`LienDeFiche(valeur:)`** à la place d'un `NavigationLink` : il CHOISIT, `ListeEtFiche` décide où la fiche s'ouvre (`\.choixDeFiche`, retiré de la fiche) ; `ligneDeListe: true` dans une `List`, qui garde le chevron de l'iPhone. La carte ouverte se souligne par `.rangeeChoisie(élément)` (`.rangeeDeListeChoisie(élément, fond:)` pour une rangée de `List`) et se dit `isSelected` à VoiceOver. Aucune lecture de l'idiome dans `Commun/MiseEnPage/` (`verifier-depot.sh`) | `Commun/MiseEnPage/` (tests : `ListeEtFicheTests`, `ListeEtFicheUITests`, `MemoireDesSelectionsTests`) |
| `.largeurDeLecture()`, `.feuilleACrans()`, `.actualisable { }` | un écran de texte ou un formulaire ne s'étire pas sur la largeur d'un iPad : `.largeurDeLecture()` sur le CONTENU d'un `ScrollView` (ou sur une `List`, fond posé après) — `Mise.lecture`, qui suit Dynamic Type, jamais un `frame(maxWidth: 720)` écrit à la main ; toute feuille à mi-hauteur : `.feuilleACrans()` (sur iPad, feuille de formulaire centrée) ; tout « tirer pour actualiser » : `.actualisable { }` à la place de `.refreshable`, qui ajoute ⌘R au clavier matériel (#223) | `Commun/MiseEnPage/`, `Commun/Composants/Actualisable.swift` |
| `FlowEtiquettes` | des étiquettes côte à côte, qui passent à la ligne (grand texte) | `Commun/Composants/` |
| `PiecesJointes`, `PiecesJointesView` (`.grand`, `.compact`), `VignettePieces`, `PhotoProtegee` | **les pièces jointes, partout** (affaire, suite, message, résumé du fil, annonce) : `PiecesJointes(urls:)` range photos et documents à la règle du site (`FichiersDuSite`, **générée** depuis `fichiers.ts`) — jamais un `filter(Fichiers.estImage)` qui jette les documents ; un élément ouvert montre `PiecesJointesView` (mosaïque `MosaiquePhotos`, puis `LigneDocument` : type, nom sans préfixe), une carte fermée `VignettePieces` (première photo et « +N », ou trombone) ; un toucher ouvre Coup d'œil (`.quickLookPreview`) sur les fichiers lus une fois par `PiecesLocales` (`tmp/pieces/`, protégés) | `Commun/PiecesJointes/` (tests : `PiecesJointesTests`, `PiecesJointesUITests`) |
| `RepondreFeuille`, `ResumeFeuille` | répondre — un MESSAGE (POST …/messages), rendu sous l'Historique par `FilMessagesAffaire` (`Affaire/`), jamais une suite de l'Historique ; le résumé d'un élément du fil | `Commun/Detail/` |
| `CarteDuFil`, `CarteOuvrable`, `DestinationDuFil`, `VignetteEcheance`, `PastilleNature` | une carte du fil ; toucher → résumé ; la cible (`affaire`, `sondage`, `document`) → son détail ; sous la première ligne d'une affaire datée, le délai SERVI puis les dates (`EcheanceDuFil`, relu de `meta.affaire` ; rien d'une installation antérieure à v3.79.0, #75) ; sur la première ligne, après l'heure, la NATURE de l'affaire en `PastilleTeinte` (`meta.affaire.natures`, `natureDe` du site, libellé et teinte générés ; pas répétée quand la rubrique la dit déjà ; jamais plus grande qu'`xxxLarge`, #78) | `Commun/Fil/` |
| `FeuilleResidence`, `PastillesRoles`, `.confirmationDeSortie` | la feuille « où suis-je » ; les rôles ; se déconnecter / changer de résidence | `Commun/Compte/` |
| `TexteDuSite.apercu`, `TexteRiche(html:)` | **le texte riche du site (HTML de l'éditeur)** : `apercu` pour une carte (texte simple, puis `lineLimit`), `TexteRiche(html:)` pour un détail (`.font`, `.foregroundStyle`, `.tint(palette.primary)` de l'appelant ; listes en retrait suspendu, `<li><p>` de l'éditeur compris) — **jamais** `Text(html)`, ni WebKit, ni `NSAttributedString(.html)` (`verifier-depot.sh` refuse) ; liste blanche générée (`BalisesDuSite`) | `Commun/Texte/` |

## Lire une réponse, dire un refus (#41)

| Geste | Règle | Où |
|---|---|---|
| **Réponse non typée** | une route sans `response_model` côté serveur rend un `OpenAPIValueContainer` : il se relit par `Relecture.lire(T.self, depuis: valeur)` (`json:` pour des octets, dans un test) — clés `snake_case` → `camelCase`, dates comme le client généré (ISO, sans fuseau = UTC). Le modèle ne déclare **pas** de `CodingKeys` en `snake_case` (la conversion les rendrait muets). Jamais un `JSONDecoder` monté dans un service. Chaque usage est un besoin noté pour coprofirst (#2460, #2505, #2507). **Au contrat 1.12.0, plus aucun écran n'en use** : toute réponse lue est typée (#53-#56) | `Commun/Session/Relecture.swift` |
| **Champ au-dessus du plancher** | une installation plus récente sert, sur une route **typée**, un champ que le contrat du plancher ignore — et que le type généré jette. L'appel passe par le client généré dans `CorpsServi.garder { … }`, qui rend aussi le corps servi ; le champ s'y relit par `Relecture.auDessusDuPlancher(T.self, corps:)` (`parLigne:` pour une liste, par `id`), dans un modèle aux champs **tous facultatifs**. Absent (installation antérieure) ou illisible : `nil`, et l'écran garde son geste d'avant — défaut fermé, jamais un geste que le serveur n'a pas annoncé. Le modèle de l'écran se construit par une seule fonction, partagée par le service réel et l'API simulée. **Le jour où le plancher l'atteint**, il se lit par le type généré (`init(_ lu: Components.Schemas.…)`), le corps n'est plus gardé, et le repli d'avant se retire. **À l'envoi**, le pendant : un champ qu'une installation plus récente accepte et que le type généré du corps ignore s'ajoute par `CorpsEnvoye.completer(avec: champs) { appel généré }` (clés en `snake_case`) — jamais un corps écrit à la main ; un champ que le corps généré porte déjà n'est jamais remplacé (`Collision`). Il ne part que derrière le droit servi au-dessus du plancher qui l'offre. Au plancher v3.121.2 (contrat 2.10.0, #313), aucun écran n'en use : les champs qui y sont passés (contrats #185, correction d'une Suite #187, prestataires d'une affaire #181) se lisent par leur type généré ; le mécanisme reste pour le prochain champ. Qui en use se lit dans le code, pas ici : `git grep -n -E 'Relecture\.auDessusDuPlancher|CorpsServi\.garder' -- CoproFirst`. Un repli au plancher n'a qu'UN endroit, `LieuServi` (dispensé dans `verifier-regles-servies.py`). **Un `null` explicite** passe aussi par `completer` (`[String: Int?]` à valeurs `nil`) : le type généré tait un champ `nil`, et un PATCH que le serveur lit champ par champ ne l'efface jamais — un avis ramené « sans affaire » (#207, `ServiceAPI+AvisPrestataire`) | `Paquets/ClientAPI/…/CorpsServi.swift`, `…/CorpsEnvoye.swift`, `Commun/Session/Relecture.swift` (tests : `AuDessusDuPlancherTests`, `CorpsEnvoyeTests`) |
| **Route au-dessus du plancher** | une ROUTE que le contrat du plancher n'a pas (exemple daté : `/masquages`, contrat 2.9.0, #286, retirée au plancher v3.121.2, #313) se déclare dans `AU_DESSUS_DU_PLANCHER` de `scripts/generateurs/contrat.py` : la release qui la publie, ce qu'elle ouvre, ses chemins. Le générateur l'AJOUTE au contrat du client (chemins et schémas nommés, rien d'autre ne change — un chemin déjà servi, absent, ou un schéma d'une autre forme arrête tout ; `autotest()` le prouve, joué par `generer.py --sources`) et génère sa porte (`VersionContrat.<porte>`, à la version du contrat de cette release). L'écran ne l'appelle que derrière `installation.sert(.porte)` ; l'API simulée l'ouvre par `-contrat <version>`. Le jour où le plancher la sert, la génération échoue : la déclaration se retire, la porte avec elle — jamais une requête écrite à la main | `scripts/generateurs/contrat.py`, `Session/ContratDuPlancher.swift` |
| **Phrase du serveur** | la réponse non documentée d'un **geste** (POST, PATCH, DELETE) passe par `throw await Self.refus(statut, reponse)` : `{"detail": "…"}` devient `ErreurService.refus(RefusDuServeur)`, dont la `phrase` est celle du serveur ; sans phrase, le cas que dit le statut. Une **lecture** refusée garde `ErreurService.depuisLecture(statut)` (« introuvable »). Un service simulé lève la même chose : `ErreurService.refus(.init(phrase: …))`. Un **422** servi avec SA phrase alors que le contrat le documente en erreur de validation (une liste) ne se décode pas : `appeler` le lit quand même (`refusSousValidation`, #55) | `Commun/Session/RefusDuServeur.swift` (le type, `ErreurService.depuisRefus` et `Self.refus`, écrit une fois dans `LitLesRefus`, que `ServiceAPI` et le service de l'Apple TV adoptent), `ServiceAPI+Refus.swift` (le 422 servi avec sa phrase) (tests : `CommunSessionTests`) |
| **Fichier servi** | une route qui sert un `FileResponse` que le contrat déclare en JSON (document, rapport…) se lit par `try await Self.fichierServi(nom:defaut:) { … }` : la fermeture lance l'appel généré et lève `ErreurService.depuisLecture(statut)` sur un `.undocumented` ; le corps se lit dans l'erreur du client, sur un 200 seulement, et s'écrit sous `Fichiers.nomSur` dans `tmp/documents/`, en `.completeFileProtection`. **Aucune autre écriture de ce geste** : `grep -rn "ClientCoproFirst.fichierServi" CoproFirst` ne rend que `Commun/Session/` (#32). Besoin noté : coprofirst#2505 | `Commun/Session/FichierServi.swift` (tests : `FichierServiTests`) |
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
3. **Une présentation système** (alerte, confirmation posée sur une rangée de liste) ne fait
   pas toujours descendre ses identifiants : l'alerte se trouve par son titre ; une
   confirmation se pose sur la liste, pas sur sa section ni sa rangée (#38). **Un bouton de
   balayage** glisse encore quand il apparaît, une liste défile encore après un balayage :
   attendre que l'élément soit immobile avant de le toucher ; et fermer le clavier avant de
   toucher un élément qu'il pourrait couvrir — XCTest le dit « touchable » (`SondageUITests`).
   Même piège sous la barre d'onglets flottante : on touche le milieu de la partie VISIBLE
   d'un élément, entre les barres. Un cadre se lit par `snapshot()` : une requête
   d'accessibilité au lieu de deux (`exists` puis `frame`) — chacune coûte près d'une
   seconde sur une longue liste.
4. Aucun délai ne s'allonge pour rendre un test vert : un échec de CI se lit dans son
   journal (`gh run view <id> --log-failed`, la ligne « Check for interrupting elements
   affecting … » donne le type réellement trouvé). On attend un **état**, jamais une
   durée : un écran chargé a son point d'attente commun, que tous ses tests emploient
   avant de lire le reste par `.exists` — pour le détail d'une affaire,
   `attendreDetailAffaire` (titre ET bandeau, qui arrive après le titre sur le runner :
   jusqu'à 12 s, #98) ; jamais un `.exists` juste après un toucher. Un écran lent se
   joue au poste par l'API simulée ralentie (`-delai-detail <ms>`). Le plafond de ces
   attentes est commun, et large (`Attente.plafond`, `CoproFirstUITests/Attente.swift`) :
   l'attente rend la main dès que l'état est là, un délai court ne fait gagner du temps
   qu'à un test rouge (#123). Un état autre que la présence — le focus du clavier, un
   onglet retenu — s'attend par `element.attendre("hasKeyboardFocus == true")`, la seule
   attente par prédicat : `verifier-depot.sh` refuse `expectation(for:` dans les tests.
   Un état **passager** ne s'attend pas contre la montre, même avec un long délai :
   l'avis qui suit un geste dure 4 s, et il est reparti avant d'être lu par un runner
   qui met 30 s à une requête. Le test le rend durable (`-avis-durable`, lu par
   `AvisEphemere` en Debug) et prouve le geste par l'état qui reste (la liste relue).
   La présence elle-même s'attend par `element.apparait()` (et `disparait()`), jamais
   par `waitForExistence(timeout: 8)` : aucun délai chiffré dans un test, le même
   contrôle le refuse (#147). Ce qui peut légitimement manquer — une boucle qui fait
   défiler, un chemin facultatif, une absence à prouver une fois l'écran posé — se
   LIT par `element.sonde()` (`Attente.sonde`), et ne s'affirme pas par `XCTAssertTrue`.
   Un **toucher** passe par `app.toucher(élément)` : l'élément existe, sort de sous le
   clavier, est amené à l'écran (lu sur son cadre, jamais `isHittable`, qui fait échouer le
   test sous iOS 26.5), ne bouge plus, puis il est touché — et le test
   vérifie l'EFFET. Le clavier couvre PLUS que son cadre : la barre des prédictions est
   au-dessus, et `toucher` la retranche de la zone utile. Un clavier que la barre de
   navigation ne ferme pas reste donc ouvert sans dommage ; un test ne le ferme pas lui-même
   par un retour (`typeText("…\n")`) pour atteindre le champ suivant (#379). Un `tap()` direct partait sur une feuille qui montait encore et ne
   faisait rien, sans erreur (#217). Les `tap()` directs restants sont une dette au
   plafond décroissant (`scripts/verifier-touchers.sh`) : une classe touchée par un lot se
   convertit entière et s'ajoute à `CLASSES_TOUCHER`, et le plafond baisse d'autant.
   Un toucher qui OUVRE une page (idempotent) et peut se perdre sous charge passe par
   `app.toucher(élément, jusqua: effet)` : rejoué au plus `Attente.reprises` fois, chaque
   reprise déclarée au résumé du run (`bilan_tests_ui.py`, #282) — jamais pour un
   interrupteur ni un envoi. Un DÉPLIAGE (année, exercice, fiche, avis) se déplie par
   `app.deplier(en-tête)` : il lit l'état que pose `.depliage(…)` dans la vue (« déplié »), et
   ne rejoue un toucher perdu qu'à état inchangé (#384 ; le juge des écritures refuse une
   indication « Déplie… » écrite sur place). Un ONGLET s'y touche toujours ; trouvé par son libellé, il se
   range dans une variable nommée `onglet…` — le juge (`scripts/touchers_onglets.py`, #334)
   ne reconnaît un onglet qu'à son identifiant et à ce nom. Un toucher voulu aux COORDONNÉES (sans le défilement
   d'XCUITest, #47) : `app.toucherAuDessin(élément)`, une fois son cadre immobile.
5. **Une suite lente ou rouge seulement en tête de passage** : le simulateur sortait à
   peine de son démarrage. `scripts/tests-simulateur.sh` le démarre AVANT le build et
   attend la fin de son démarrage (`simctl bootstatus -b`) ; l'autotest refuse un test
   joué avant, ou sur un démarrage non confirmé (#48). Pour mesurer : la durée d'un même
   test au premier passage et aux suivants (`-test-iterations`), et la durée des étapes
   « Find the … » du journal — plus de 3 s, l'app ne répondait pas.
6. **Un seul passage au simulateur à la fois sur le poste**, et ce n'est pas une
   consigne : `scripts/tests-simulateur.sh` prend lui-même le verrou que partagent les
   worktrees, attend son tour et dit qui le tient (#108) — on le lance nu, sans lanceur.
   Un passage s'arrête par le pid de la fiche du verrou (l'en-tête du script donne la
   commande), jamais par son nom. Un passage filtré donne **un filtre par argument** :
   s'il ne joue aucun test il sort INCONNU, pas vert (#96) — et **chaque** filtre doit
   avoir joué au moins un test, compté dans l'arbre du xcresult : un filtre vide sort
   INCONNU en se nommant, même si l'autre a joué ses 397 tests (#170). Un fichier de test
   neuf n'est compilé qu'après `bash scripts/generer-projet.sh` : absent du projet
   Xcode, il arrête le passage AVANT le build, INCONNU, avec cette commande (le script
   ne régénère pas lui-même). Sans `DESTINATION`, le
   simulateur est choisi et nommé par `scripts/destination-simulateur.sh` (#112).
7. **Un rouge ne se range dans « runner saturé » qu'après comparaison avec `main`,
   sur le même test** : signature et durées, journal contre journal. Si « App event loop
   idle notification not received » ou « main thread busy » frappe tous les tests d'un
   même écran, alors que `main` les passe sans ce signal, c'est l'app qui tourne en boucle
   (#279). Le poste, sous une autre version d'iOS, peut rester vert — la ligne « Système »
   du résumé le dit, et `OS_SIMULATEUR=ci` y joue celui de la CI (#287) : la boucle se
   prouve par une trace (`print` temporaire, `simctl launch --console-pty`). La cause
   type : un `if` sur un état dans un `ViewModifier` qui enveloppe une page. Chaque
   branche donne à la page une autre identité ; quand l'état change, la page se recrée,
   avec ses `@State`, ses `onAppear` et ses `onDisappear`. Un seul modificateur, avec une
   valeur calculée (`TitreDeMenu.mode`).
8. **Le binaire joué n'est pas toujours celui du build** (#328) : réinstallés par-dessus
   eux-mêmes, l'app et le runner des tests sont mis à jour par un **patch différentiel**
   du simulateur (« Delta patch update … from 1 (1.0) to 1 (1.0) »). Le 23/11/2026, au
   poste, le binaire du passage précédent a joué 3 fois sur 7 ainsi : build juste, app
   d'avant jouée. `scripts/tests-simulateur.sh` désinstalle donc l'app et le runner AVANT
   chaque passage (INCONNU s'il en reste un), et prouve ce qui a joué : l'empreinte des
   tests, imprimée par le runner, et celle de l'app, dite en Debug au journal du
   simulateur (`LancementSimule.direLEmpreinte`) — `scripts/empreinte_tests.py`, INCONNU
   sinon. Un `xcodebuild test` lancé à la main ne prouve rien de tel : passer par le
   script, ou `xcrun simctl uninstall <udid> fr.coprofirst.app` (et
   `fr.coprofirst.app.uitests.xctrunner`) avant, et ne rien conclure d'un mutant qui n'a
   pas rougi sans avoir vu son empreinte.
