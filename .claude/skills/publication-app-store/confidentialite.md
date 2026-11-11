<!--
SPDX-FileCopyrightText: 2026 Philippe TRESSARD
SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
-->

# Confidentialité : la fiche, les étiquettes « App Privacy », le manifeste

Lot P4 de la spec push (#19). Trois textes disent ce que l'app fait des données, et ils
disent la même chose (`standards/14` §3 bis, déclaré = réel) :

| Texte | Où | Qui l'écrit |
|---|---|---|
| le manifeste embarqué | `CoproFirst/PrivacyInfo.xcprivacy` | ce dépôt |
| la fiche et les étiquettes | App Store Connect | **Philippe**, à partir de ce fichier (§9) |
| la politique de confidentialité | <https://coprofirst.fr/confidentialite.html#t-application> | le dépôt `coprofirst-site` |

**Ce fichier est lu par un contrôle** : `scripts/verifier-confidentialite.py`, rejoué par
`scripts/verifier-depot.sh` (pre-commit, CI). Les tableaux précédés d'une marque
`<!-- table:… -->` et les preuves (un chemin, le signe ›, un extrait, chacun entre accents
graves) sont comparés au code,
au manifeste, à `project.yml` et à `Package.resolved`, dans les deux sens. Un envoi neuf,
un module neuf, un droit neuf : le contrôle échoue tant que ce fichier **et** le manifeste
ne le disent pas. Ne pas reformater ces tableaux ; une preuve est un extrait exact du code.

Les règles d'Apple changent : types de données, raisons admises et questionnaire ont été
relus dans sa documentation le 11/11/2026. **Les relire avant chaque saisie.**

## 1. Le choix : déclarer ce qui part vers la résidence

L'app n'envoie rien à l'éditeur : elle parle à **l'installation que l'utilisateur a
choisie** (le site de sa résidence), qui garde ce qu'il y écrit. Apple définit la
« collecte » comme une donnée transmise hors de l'appareil et gardée par le développeur ou
ses partenaires. Une app cliente d'un serveur tenu par un tiers peut soutenir qu'elle ne
collecte rien.

**Ce dépôt déclare quand même** ces données, liées à la personne, pour la seule finalité
« fonctionnement de l'app » :

- l'éditeur tient lui-même des installations (la démonstration, sa propre résidence), et
  une offre hébergée est à l'étude : « rien n'est collecté » y serait faux ;
- une déclaration plus étroite que la réalité est un manquement ; plus large, non ;
- l'étiquette dit alors à l'utilisateur ce qui quitte son téléphone, ce qui est vrai
  quel que soit l'hébergeur.

⚠️ C'est une lecture prudente, pas un avis juridique. Si Philippe retient l'autre lecture
(« Data Not Collected »), le manifeste, le §5 et le §6 changent ensemble — le contrôle
l'impose.

## 2. Ce qui sort de l'appareil

Les seuls fichiers qui ouvrent une connexion (`URLSession`, `URLRequest`) :

<!-- table:portes -->
| Fichier | Vers qui | Ce qui part |
|---|---|---|
| `Paquets/ClientAPI/Sources/ClientAPI/ClientCoproFirst.swift` | l'installation choisie | le client généré : toutes les routes de l'API, sous `/api` |
| `CoproFirst/Session/ServiceAPI.swift` | l'installation choisie | une session HTTP par hôte, éphémère, cookies en mémoire |
| `CoproFirst/Session/ServiceAPI+Detail.swift` | l'installation choisie | le téléchargement d'un document, par la même session |
| `CoproFirst/Session/PreuveAASA.swift` | l'installation choisie | lecture de `/.well-known/apple-app-site-association`, sans cookie |
| `CoproFirst/Entree/Contenu/Vitrine.swift` | `coprofirst.fr` (l'éditeur) | lecture de `contenu.json` à l'ouverture de l'accueil, sans cookie ni identifiant |

Preuves : `CoproFirst/Session/ServiceAPI.swift` › `let configuration = URLSessionConfiguration.ephemeral` ;
`CoproFirst/Session/PreuveAASA.swift` › `configuration.httpCookieAcceptPolicy = .never` ;
`CoproFirst/Entree/Contenu/Vitrine.swift` › `static let adresse = URL(string: "https://coprofirst.fr/contenu.json")`.

La lecture de `contenu.json` ne porte rien de l'utilisateur, mais c'est une requête : le
site de l'éditeur et son intermédiaire (Cloudflare) voient l'adresse IP, comme pour toute
visite. Les notifications, elles, ne partent pas de l'app : la résidence passe par le
relais de l'éditeur, puis par Apple (§4).

## 3. Ce qui reste sur l'appareil

| Quoi | Où | Preuve |
|---|---|---|
| le jeton de session, **si** Face ID est activé | Trousseau, biométrie, jamais synchronisé | `CoproFirst/Session/Trousseau.swift` › `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .biometryCurrentSet` |
| le courriel de la dernière connexion, par résidence | Trousseau, sans biométrie | `CoproFirst/Session/InstallationsConnues.swift` › `coffre.ranger(Data(email.utf8), Self.prefixeIdentifiant + installation.hote)` |
| le profil dans la résidence (statut, rôles, logement) | Trousseau, sans biométrie | `CoproFirst/Session/InstallationsConnues.swift` › `coffre.ranger(donnees, Self.prefixeProfil + installation.hote)` ; `CoproFirst/Session/Trousseau.swift` › `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` |
| les résidences ouvertes (adresse, nom) | réglages (`UserDefaults`) | `CoproFirst/Session/InstallationsConnues.swift` › `private static let cle = "installations-connues"` |
| Face ID déjà proposé, par résidence | réglages | `CoproFirst/Session/InstallationsConnues.swift` › `reglages.set(true, forKey: "faceid-propose." + installation.hote)` |
| l'abonnement push, par résidence | réglages | `CoproFirst/Fonctions/Notifications/Push/AbonnementsPush.swift` › `private static let cle = "push-abonnements"` |
| la date du report de l'offre de notifications | réglages | `CoproFirst/Fonctions/Notifications/Push/NotificationsPush.swift` › `private static let cleReport = "push-offre-reportee"` |
| le thème choisi | réglages | `CoproFirst/Fonctions/Profil/ThemeChoisi.swift` › `@AppStorage(ThemeChoisi.cle)` |
| la dernière lecture de la vitrine | cache de l'app | `CoproFirst/Entree/Contenu/Vitrine.swift` › `appendingPathComponent("contenu-vitrine.json")` |
| un document ouvert | dossier temporaire, chiffré | `CoproFirst/Commun/Session/FichierServi.swift` › `try donnees.write(to: fichier, options: [.atomic, .completeFileProtection])` |

La déconnexion efface la session : `CoproFirst/Session/ServiceAPI+Compte.swift` › `Trousseau.supprimer(pour: installation.hote)`.
« Oublier toutes les résidences » efface le courriel et le profil. La caméra lit le QR
code sur l'appareil (`CoproFirst/Entree/Decouverte/ScannerQRView.swift` › `DataScannerViewController(`),
aucune image n'est gardée ni envoyée ; Face ID est vérifié par iOS.

## 4. Les droits, les autorisations, les notifications

<!-- table:droits -->
| Droit (`project.yml`) | À quoi il sert | Ce qu'en dit la fiche |
|---|---|---|
| `aps-environment` | recevoir les notifications d'APNs | notifications, ci-dessous |
| `com.apple.developer.usernotifications.time-sensitive` | laisser un avis **urgent** traverser le mode Concentration | Apple apprend qu'un avis est urgent, rien de son contenu |
| `com.apple.developer.associated-domains` | ouvrir l'app par un lien du site d'une résidence connue | aucune donnée : iOS lit le fichier d'association chez Apple |

<!-- table:autorisations -->
| Autorisation (`project.yml`) | Ce que l'app en fait |
|---|---|
| `NSCameraUsageDescription` | lire le QR code de la fiche d'arrivée ; l'image reste sur l'appareil |
| `NSFaceIDUsageDescription` | rouvrir la session gardée au Trousseau ; l'app ne reçoit que la réponse d'iOS |

**Ce que les notifications transmettent** (spec push de coprofirst §5 et §7, lue à la
version du plancher) :

- l'app envoie à la résidence, si l'utilisateur a accepté les notifications, le jeton
  d'appareil d'APNs et un **abonnement** aléatoire tiré par l'app — rien d'autre :
  `CoproFirst/Fonctions/Notifications/Push/ServiceAppareils.swift` › `jeton: appareil.jeton.hexadecimal`,
  `CoproFirst/Fonctions/Notifications/Push/AbonnementsPush.swift` › `var generateur = SystemRandomNumberGenerator()`,
  `CoproFirst/Fonctions/Notifications/Push/NotificationsPush.swift` › `guard autorisation == .accordee else { return }` ;
- le jeton ne s'écrit ni dans un journal ni sur le disque :
  `CoproFirst/Fonctions/Notifications/Push/JetonAPNs.swift` › `static let masque = "‹jeton APNs masqué›"` ;
- à la déconnexion, l'appareil se retire :
  `CoproFirst/Fonctions/Notifications/Push/NotificationsPush.swift` › `retirerAppareil(abonnement, dans: installation)` ;
- ce qui part chez Apple est composé par le relais, pas par l'app ni par la résidence : le
  texte fixe « Vous avez une nouvelle notification. » et l'abonnement. Ni nom, ni résidence,
  ni objet, ni nombre ;
- pour un avis urgent seulement, la charge porte le niveau *time-sensitive* :
  `project.yml` › `com.apple.developer.usernotifications.time-sensitive: true`.

## 5. Le questionnaire « App Privacy » : les réponses

**« Collectez-vous des données depuis cette app ? » → Oui** (§1). Puis cocher ces huit
types, et eux seuls. Pour **chacun** : finalité **App Functionality** seule ; lié à
l'identité de l'utilisateur : **Oui** ; utilisé pour le suivi (*tracking*) : **Non**.

<!-- table:donnees -->
| Type (manifeste) | Case d'App Store Connect | Ce que c'est | Preuve |
|---|---|---|---|
| `NSPrivacyCollectedDataTypeName` | Contact Info › Name | nom et prénom du profil | `CoproFirst/Fonctions/Profil/ServiceAPI+Profil.swift` › `nom: saisie.nom.trimmingCharacters(in: .whitespaces)` |
| `NSPrivacyCollectedDataTypeEmailAddress` | Contact Info › Email Address | le courriel de connexion | `CoproFirst/Session/ServiceAPI.swift` › `body: .json(.init(email: email, password: motDePasse))` |
| `NSPrivacyCollectedDataTypePhoneNumber` | Contact Info › Phone Number | le téléphone du profil | `CoproFirst/Fonctions/Profil/ServiceAPI+Profil.swift` › `telephone: saisie.telephone.nulSiVide` |
| `NSPrivacyCollectedDataTypeEmailsOrTextMessages` | User Content › Emails or Text Messages | les messages d'une affaire | `CoproFirst/Session/ServiceAPI+Detail.swift` › `postTicketsTicketIdMessages(` |
| `NSPrivacyCollectedDataTypeOtherUserContent` | User Content › Other User Content | affaires, annonces, idées, avis, votes, questions, demandes de badge | `CoproFirst/Fonctions/Affaires/Donnees/ServiceAffaires+API.swift` › `postTickets(body: .json(corps))` |
| `NSPrivacyCollectedDataTypeUserID` | Identifiers › User ID | le compte et sa session (cookies posés par la résidence) | `CoproFirst/Session/ServiceAPI.swift` › `poserCookie("refresh_token", valeur: jeton, installation)` |
| `NSPrivacyCollectedDataTypeDeviceID` | Identifiers › Device ID | le jeton d'appareil d'APNs et l'abonnement | `CoproFirst/Fonctions/Notifications/Push/ServiceAppareils.swift` › `abonnement: appareil.abonnement` |
| `NSPrivacyCollectedDataTypeOtherDataTypes` | Other Data › Other Data Types | mot de passe à la connexion, société, fonction, statut et bâtiment demandés, réglages du compte, rôles donnés par un administrateur | `CoproFirst/Fonctions/Profil/ServiceAPI+Profil.swift` › `societe: saisie.societe.nulSiVide` |

**Ce qui n'est PAS coché, et pourquoi :**

- *Usage Data*, *Diagnostics* : l'app n'envoie aucune mesure d'usage, aucun rapport de
  plantage. La collecte de statistiques de la résidence est une route que seul le site
  appelle (`/telemetry/collect`) ; le contrôle échoue si l'app se met à l'appeler ;
- *Search History* : le terme d'une recherche part à la résidence pour y répondre
  (`CoproFirst/Fonctions/Affaires/Donnees/ServiceAffaires+API.swift` › `getTicketsRecherche(query: .init(q: terme))`),
  qui ne le garde pas (lu dans coprofirst à la version du plancher, non contrôlé ici) ;
- *Photos or Videos*, *Location*, *Contacts*, *Health*, *Financial Info*, *Browsing
  History*, *Purchases*, *Sensitive Info* : l'app n'en lit ni n'en envoie. Elle ne joint
  aucune photo ; la caméra ne sert qu'au QR code ;
- *Tracking* : aucun. `NSPrivacyTracking` est faux, aucun domaine de traçage, aucun
  identifiant publicitaire, aucun SDK de mesure (§7).

Le mot de passe n'a pas de case chez Apple : il est rangé sous « Other Data Types ». Le
bâtiment demandé dans une demande de modification est un identifiant de la résidence,
pas une adresse saisie : il y est aussi. À revoir si Philippe juge que « Physical
Address » s'applique.

## 6. Chaque envoi, classé

Tous les appels d'écriture du client généré, et le type de donnée que chacun porte
(« — » : un geste sur un objet existant, sans donnée saisie).

<!-- table:envois -->
| Envoi | Type de donnée |
|---|---|
| `postAuthLogin` | `EmailAddress` `UserID` `OtherDataTypes` |
| `postAuthRefresh` | `UserID` |
| `postAuthLogout` | — |
| `postAuthChangePassword` | `OtherDataTypes` |
| `patchAuthMe` | `Name` `EmailAddress` `PhoneNumber` `OtherDataTypes` |
| `postAuthMeDemandeModification` | `OtherDataTypes` |
| `patchAuthMeOptOutTelemetrie` | `OtherDataTypes` |
| `deleteAuthMeTelemetrie` | — |
| `postAppareils` | `DeviceID` |
| `deleteAppareilsAbonnement` | `DeviceID` |
| `postTickets` | `OtherUserContent` |
| `patchTicketsTicketId` | `OtherUserContent` |
| `postTicketsTicketIdEvolutions` | `OtherUserContent` |
| `postTicketsTicketIdMessages` | `EmailsOrTextMessages` |
| `postSignalements` | `OtherUserContent` |
| `postReglementQuestions` | `OtherUserContent` |
| `postAnnonces` | `OtherUserContent` |
| `patchAnnoncesAnnonceIdStatut` | — |
| `deleteAnnoncesAnnonceId` | — |
| `postAnnoncesCibleIdReponses` | `OtherUserContent` |
| `deleteAnnoncesCibleIdReponsesRepId` | — |
| `postAnnoncesHall` | `OtherUserContent` |
| `patchAnnoncesHallAnnonceId` | — |
| `deleteAnnoncesHallAnnonceId` | — |
| `postAnnoncesHallAnnonceIdRenvoyerEmail` | — |
| `postIdees` | `OtherUserContent` |
| `postIdeesIdeeIdVoter` | `OtherUserContent` |
| `postIdeesCibleIdReponses` | `OtherUserContent` |
| `deleteIdeesCibleIdReponsesRepId` | — |
| `postSondagesSondageIdVoter` | `OtherUserContent` |
| `postSondagesSondageIdCommenter` | `OtherUserContent` |
| `deleteSondagesSondageIdCommentairesCommentaireId` | — |
| `postAvis` | `OtherUserContent` |
| `patchAvisAvisId` | `OtherUserContent` |
| `patchAvisAvisIdArchivage` | — |
| `postAccesCommandes` | `OtherUserContent` |
| `postAccesDeclarerBadge` | `OtherDataTypes` |
| `patchAccesVigiksVigikIdPerdu` | `OtherUserContent` |
| `patchAccesTelecommandesTcIdPerdu` | `OtherUserContent` |
| `postBailleurBauxBailIdRecupererAcces` | — |
| `postDelegations` | `OtherUserContent` |
| `postDelegationsDelegationIdAccepter` | — |
| `postDelegationsDelegationIdRevoquer` | — |
| `patchNotificationsNotifIdLue` | — |
| `postNotificationsToutMarquerLu` | — |
| `postNotificationsSupprimerLues` | — |
| `postNotificationsSupprimerSelection` | — |
| `deleteNotificationsNotifId` | — |
| `postAdminComptesUserIdTraiter` | `OtherUserContent` |
| `postAdminDemandesProfilDemandeIdTraiter` | `OtherUserContent` |
| `postAdminCommandesAccesCmdIdTraiter` | `OtherUserContent` |
| `postAdminUtilisateursUserIdAjouterRole` | `OtherDataTypes` |
| `postAdminUtilisateursUserIdRetirerRole` | `OtherDataTypes` |
| `postAdminUtilisateursUserIdAccueilArrivant` | `OtherDataTypes` |
| `postAdminUtilisateursUserIdAutoMatch` | — |
| `patchAdminUtilisateursUserIdBanCommunaute` | `OtherDataTypes` |
| `deleteAdminUtilisateursUserId` | — |
| `putAdminAnnuaireCs` | `Name` `OtherDataTypes` |
| `putAdminAnnuaireSyndic` | `Name` `EmailAddress` `PhoneNumber` `OtherDataTypes` |

## 7. Aucun SDK tiers : les modules et les paquets

Tout ce que le code de l'app importe. Un module absent de cette table fait échouer le
contrôle.

<!-- table:modules -->
| Module | Éditeur | Ce qu'il fait ici |
|---|---|---|
| `Foundation` | Apple (iOS) | types de base, réseau, réglages |
| `SwiftUI` | Apple (iOS) | l'interface |
| `UIKit` | Apple (iOS) | presse-papiers, ponts vers SwiftUI |
| `Observation` | Apple (iOS) | état observable |
| `CoreGraphics` | Apple (iOS) | géométrie |
| `Charts` | Apple (iOS) | graphiques, dessinés sur l'appareil |
| `Security` | Apple (iOS) | le Trousseau |
| `LocalAuthentication` | Apple (iOS) | Face ID, vérifié par iOS |
| `Network` | Apple (iOS) | savoir si l'appareil est en ligne |
| `UserNotifications` | Apple (iOS) | autorisation et réception des notifications |
| `VisionKit` | Apple (iOS) | lecture du QR code, sur l'appareil |
| `QuickLook` | Apple (iOS) | aperçu d'un document téléchargé |
| `SafariServices` | Apple (iOS) | ouvrir une page du site dans Safari intégré |
| `ClientAPI` | ce dépôt | le client généré depuis le contrat |
| `OpenAPIRuntime` | Apple (paquet libre) | types du client généré |
| `OpenAPIURLSession` | Apple (paquet libre) | transport HTTP par `URLSession` |
| `HTTPTypes` | Apple (paquet libre) | requêtes et réponses HTTP |

Chaque paquet de `Paquets/ClientAPI/Package.resolved`, à la **révision** où ses sources
ont été relues. Aucun paquet embarqué n'appelle d'API à raison requise, ne porte de
symbole de traçage ni ne livre son propre manifeste. Une montée de version change la
révision : le contrôle échoue jusqu'à la relecture (au poste, après `swift build` dans
`Paquets/ClientAPI`, il relit les sources lui-même).

<!-- table:paquets -->
| Paquet | Révision examinée | Rôle | Sources examinées | Constat |
|---|---|---|---|---|
| `swift-openapi-runtime` | `b9ebb3f06f1dac717156a04f0919ad444cbcf8f5` | embarqué | `Sources/OpenAPIRuntime` | aucune API à raison requise |
| `swift-openapi-urlsession` | `c97e0f0187d95542b4a254f5bb4dc67f43bf73c9` | embarqué | `Sources/OpenAPIURLSession` | aucune API à raison requise |
| `swift-http-types` | `bff4b6903cdc99dda49649dd52f46c11cfd3ed50` | embarqué | `Sources/HTTPTypes` | aucune API à raison requise |
| `swift-collections` | `f96b909e1a9e469620bc5037c1e24e00153f376f` | embarqué | `Sources/DequeModule` `Sources/InternalCollectionsUtilities` `Sources/SpanPreview` | aucune ; seuls `DequeModule` et ses deux modules internes sont liés (transport) — lu dans les produits du build, 11/11/2026 |
| `swift-openapi-generator` | `fbf4512ebc69ccbca33aa3c5fa4393887e687b76` | outil | — | greffon de build ; le client qu'il génère est relu quand il est construit |
| `openapikit` | `5b72eb9a6b23b1fec439d9a0bf38f115400421f9` | outil | — | dépendance du générateur |
| `yams` | `a27b21e0c81c5bf42049b897a62aaf387e80f279` | outil | — | dépendance du générateur |
| `swift-argument-parser` | `6a52f3251125d74daf04fcbd5e6f08a75d074382` | outil | — | dépendance du générateur |
| `swift-algorithms` | `87e50f483c54e6efd60e885f7f5aa946cee68023` | outil | — | dépendance du générateur |
| `swift-numerics` | `0c0290ff6b24942dadb83a929ffaaa1481df04a2` | outil | — | dépendance du générateur |

**API à raison requise** : une seule catégorie, `NSPrivacyAccessedAPICategoryUserDefaults`,
raison `CA92.1` (des réglages lus et écrits par l'app seule, §3). Les quatre autres
catégories (horodatage de fichier, temps de démarrage, espace disque, claviers actifs) ne
sont appelées nulle part.

## 8. Ce qui n'est pas mesuré

Le contrôle le redit à chaque passage (INCONNU, jamais conforme) :

- ce que chaque installation garde et journalise : c'est son code et sa politique ;
- ce que le relais garde (spec : rien, son journal ne porte aucun jeton) ;
- ce que la page de confidentialité du site affiche : son dépôt a son contrôle
  (`scripts/verifier-app-ios.py` de `coprofirst-site`) ;
- ce qui est saisi dans App Store Connect ;
- un champ neuf dans un envoi **déjà classé** : la table classe l'envoi, pas ses champs ;
- ce que les cadres d'Apple transmettent d'eux-mêmes.

Au poste, après une archive : Xcode › Organizer › clic droit sur l'archive › *Generate
Privacy Report* donne le rapport qu'Apple tirera du manifeste — à comparer au §5.

## 9. À saisir dans App Store Connect (Philippe)

Rien de ce qui suit n'envoie l'app en revue ; rien n'est soumis sans le « oui » de
Philippe (SKILL.md). Les libellés sont ceux de l'interface en anglais ; ils peuvent avoir
changé.

| Où | Quoi |
|---|---|
| App Store Connect › Apps › CoproFirst › *App Privacy* › *Privacy Policy* › *Edit* | *Privacy Policy URL* : `https://coprofirst.fr/confidentialite.html` — laisser *User Privacy Choices URL* vide |
| même page › *Get Started* | « Do you or your third-party partners collect data from this app? » → **Yes, we collect data from this app** |
| l'écran des types de données | cocher les huit cases de la colonne « Case d'App Store Connect » du §5, aucune autre |
| chaque type, l'un après l'autre | usage : **App Functionality** seule ; *linked to the user's identity* : **Yes** ; *used for tracking* : **No** |
| même page › *Publish* | publier les réponses ; relire l'étiquette affichée : « Data Linked to You », aucune ligne « Data Used to Track You » |
| la version › *App Information* / fiche › *Description* | ajouter le paragraphe « Confidentialité » ci-dessous |
| la version › *App Review Information* › *Notes* | coller la note ci-dessous |

L'adresse de la politique est celle que l'app affiche déjà :
`CoproFirst/Entree/Contenu/Genere/ContenuEmbarque.swift` › `https://coprofirst.fr/confidentialite.html`.

**Paragraphe pour la description :**

> Confidentialité. CoproFirst se connecte au site de votre résidence, dont vous saisissez
> l'adresse ou scannez le QR code. Ce que vous y lisez et y écrivez est gardé par votre
> résidence, pas par l'éditeur de l'application. Aucune publicité, aucun traceur, aucune
> mesure d'audience. Les notifications ne contiennent aucune information personnelle : le
> message est toujours « Vous avez une nouvelle notification. », et le détail se lit dans
> l'application. Un avis urgent (une fuite, un ascenseur bloqué) est signalé comme urgent
> à iOS pour traverser le mode Concentration : Apple apprend qu'il est urgent, pas ce
> qu'il dit.

**Note pour la revue (*App Review Information*) :**

> L'application est le client d'un logiciel libre de gestion de copropriété : elle se
> connecte au serveur de la résidence de l'utilisateur. Le compte de démonstration ouvre
> la résidence fictive demo.coprofirst.fr.
> Notifications : la charge est générique (« Vous avez une nouvelle notification. ») et
> ne porte qu'un identifiant aléatoire propre à l'appareil ; aucun contenu, aucun nom.
> Time Sensitive Notifications : le niveau n'est utilisé que pour les avis urgents de la
> résidence qui demandent une action immédiate (fuite d'eau, ascenseur bloqué) ; tous les
> autres avis partent au niveau normal.
> Caméra : lecture, sur l'appareil, du QR code qui donne l'adresse de la résidence. Face
> ID : réouverture de la session gardée au Trousseau.
