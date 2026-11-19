<!--
SPDX-FileCopyrightText: 2026 Philippe TRESSARD
SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
-->

# CoproFirst pour iOS

Application iOS native de [CoproFirst](https://github.com/philippe-tressard/coprofirst),
le logiciel libre de gestion de copropriété : présentation du produit, entrée dans
une installation (démo, adresse saisie, QR, lien universel), puis les
fonctionnalités de l'application web, par étapes.

## État

Ce que l'app sait faire : « Écrans livrés » ci-dessous et
[`Parite/PARITE.md`](Parite/PARITE.md) ; ce qui manque : les issues ouvertes.
**L'app est publiée sur l'App Store** — iPhone, gratuite, version 1.0 en ligne depuis le
14/11/2026 : <https://apps.apple.com/fr/app/coprofirst/id6834326392>. La 1.1 (build 2,
étiquette `v1.1.0`) est coupée sur `main` le 17/11/2026 et attend sa soumission (#263).
Les versions suivantes : « Sortir une version ».

## Sortir une version

Une version sort sur l'App Store, et la soumission à la revue d'Apple reste un geste de
Philippe :

1. la version se lit dans `project.yml` (`MARKETING_VERSION`, et `CURRENT_PROJECT_VERSION`,
   qui monte à chaque envoi) ; chaque version soumise porte son étiquette `vX.Y.Z` —
   `v1.1.0`, posée à la main ; `v1.0.0`, à poser après coup, et la pose par la commande
   de contrôle : #205 ;
2. chaque PR est construite et testée par la CI (`ci.yml`), **sans signer** — sauf une PR
   de documentation seule, dont la CI saute le build et les tests macOS
   (`scripts/ci_documentation_seule.py`, #204) ; qui fusionne sur `main` se lit au champ
   `fusion` du registre (`CLAUDE.md`, « Dépôt ») ;
3. au poste : l'archive Release, signée automatiquement (équipe `GUX8KASNTG`) ; Philippe
   l'envoie à App Store Connect, juge le rendu (simulateur, son iPhone, TestFlight
   interne), puis la soumet — rien ne part en revue sans son « oui » écrit pour cette
   version.

Le contrôle de cohérence qui précède chaque soumission, et l'étiquette qu'il pose :
#205. Le pas à pas (archive, captures, fiche, ce qui a surpris pour la 1.0) et ce qui est
un geste de Philippe : skill
[`publication-app-store`](.claude/skills/publication-app-store/SKILL.md).

## Construire

Prérequis : Xcode 16 ou plus récent, un runtime iOS du simulateur
(`xcodebuild -downloadPlatform iOS`), et l'outillage aux versions
d'[`outillage.env`](outillage.env) :

```bash
brew install xcodegen swiftlint swift-format
```

```bash
bash scripts/generer-projet.sh
```

```bash
open CoproFirst.xcodeproj
```

Le greffon `swift-openapi-generator` demande, à la première ouverture, d'être
autorisé par Xcode (« Trust & Enable ») ; en ligne de commande :
`-skipPackagePluginValidation`.

### L'écran de hall (Apple TV)

La cible `CoproFirstTV` (tvOS 17, #218) fait d'une Apple TV l'écran de hall d'une
résidence : elle fera défiler les affiches d'un périmètre, en lecture seule, une fois
l'écran appairé (serveur : coprofirst#2770). On y entre dans la résidence par son
adresse, ou par la démo (lot 2) — ni QR, ni lien universel, ni Face ID, que tvOS n'a pas —,
puis l'écran attend son appairage (lot 3). Elle compile les fichiers de l'app que
`project.yml` nomme — la charte, le texte du site, l'entrée (adresse, GET /config,
plancher) — et rejoue leurs tests sur tvOS, avec les siens (`CoproFirstTVTests/`) :

```bash
APPAREIL=tv bash scripts/tests-simulateur.sh
```

### L'Apple Watch

La cible `CoproFirstWatch` (watchOS 10, #226) montre au poignet la cloche de la dernière
résidence ouverte sur l'iPhone : les non lues d'abord, les urgentes devant, puis « Déjà
lues », repliée ; un toucher ouvre l'alerte entière. Elle ne fait que lire — rien ne s'y
marque comme lu. Elle se reliera à l'iPhone par un jeton de montre (coprofirst#2771) ;
d'ici là, elle dit de l'ouvrir par l'iPhone. Elle compile les fichiers de l'app que
`project.yml` nomme — la charte, le texte du site, l'alerte servie — et joue ses tests et
ceux du code partagé sur watchOS (`-api-simulee` : une résidence inventée,
`-cloche vide|injoignable|<nombre>`) :

```bash
APPAREIL=montre bash scripts/tests-simulateur.sh
```

## Écrans livrés

Accueil, En savoir plus, connexion en un écran (résidence reconnue par son
adresse ou son QR code — aucun annuaire), Face ID proposé après la première
connexion — l'activation dit ce qui garde la session : Face ID, ou le seul
verrouillage de l'appareil quand la biométrie manque —, démo, puis le fil de la résidence, jour par jour, et ses affaires.
« Nouvelle affaire » et « Modifier l'affaire » se composent selon la saisie réglée au
Profil pour le compte, Essentielle ou Complète, comme sur le site.
Pendant la saisie, la résidence dit ce qu'elle en fera, à mesure qu'on écrit
(coprofirst v3.88.1, contrat 1.26.0) : qui lira la nouvelle affaire, le lieu choisi en
clair (dans l'affaire comme dans une affiche de hall), et le nom affiché d'une
personne qu'on nomme (le Profil, une fiche de l'annuaire du conseil). Sans réseau, la
dernière réponse reste et rien n'empêche de saisir.
Une suite de l'Historique d'une affaire se corrige — et s'efface, pour
l'administrateur — depuis son entrée, quand la résidence en sert le droit
(coprofirst v3.84.0, contrat 1.19.0). Quand l'affaire ne suit pas la correction —
une suite plus récente a changé son état —, une alerte le dit avec la phrase de la
résidence, et propose d'appliquer l'état à l'affaire (contrat 1.30.0, #187).
Une affaire peut faire intervenir **plusieurs prestataires** (coprofirst v3.90.0,
contrat 1.28.0, #181) : la fiche les dit un par ligne, la carte du Kanban montre le
premier puis « +N », et « Modifier l'affaire » en ajoute, en retire et les réordonne
quand la résidence en sert le droit — d'une résidence plus ancienne, le seul
prestataire qu'elle sert, comme avant.
Une affaire ouverte se lit en fil, sur un rail : la demande, la suite, les comptes
rendus, la synthèse — pastille pleine pour le réalisé ; un toucher ouvre une entrée
quatre secondes, un double toucher ou un appui long la garde ouverte (#178).
Un contrat résilié dit, sur sa carte, par qui il est remplacé et dès quand ; celui qui
prend la suite dit qui il remplace (coprofirst v3.91.0, contrat 1.29.0, #185) — rien de
plus d'une installation antérieure. La saisie d'un contrat reste au site.
Les **avis du conseil syndical sur un prestataire** se lisent par exercice et par
intervention, tels que la résidence les regroupe (#207). Le conseil y note un prestataire
— « ⭐ Noter », sur sa fiche ou sur la carte d'un contrat : l'affaire jugée (les siennes
d'abord, avec la recherche de la page Affaires ; une affaire où il n'intervient pas
l'y ajoute, après confirmation), l'état (Mauvais, Neutre, Excellent), les points forts
et faibles qui composent le commentaire, un texte libre — et retire un avis, après
confirmation. L'auteur corrige le sien : ses cases se recochent. Chaque geste suit le
droit que la résidence sert (`est_moderateur`, `peut_modifier`).
L'accueil et la démo ne s'offrent qu'à un appareil qui n'a encore ouvert aucune
résidence ; ensuite l'app rouvre la dernière : Face ID demandé d'emblée si la
session est gardée, sinon la connexion avec l'adresse et le courriel retenus. La
barre du bas suit l'ordre réglé par l'administration de la résidence
(`pages_order`) ; les entrées non livrées annoncent « Bientôt ». **Sur iPad** en plein
écran (#221), une barre latérale liste toutes les pages, puis Profil et À propos ; en
Split View étroit, la barre du bas revient — la page ouverte reste ouverte au passage.
Une liste et la fiche qu'elle ouvre s'y tiennent côte à côte (#222) : Mes affaires,
le fil, Ma résidence (documents, carnet, règlement, syndic), les annonces, les
documents des contrats, les courriels et le reporting de l'Espace CS.
**Sur l'iPhone pliable** ouvert (#119, livré par #275), l'app se lit comme un carnet : les
pages en intercalaires sur la tranche droite, le fil une journée par double page (la
fiche ouverte en face) ; **pincer** ouvre la semaine du lundi au dimanche (#277), chaque
carte au jour où le serveur la range — son échéance, sa publication sinon —, et
**écarter les doigts** sur un jour ramène sa page (un fondu au mouvement réduit, une action
pour VoiceOver) ; Ma résidence y a un **sommaire** à gauche — les rubriques de la Fiche, le
carnet d'entretien, le règlement — et la page choisie à droite (#278) ; la page et la
fiche ouvertes s'y retrouvent après un arrêt par iOS ; plié, la barre du bas.
**Notifications** : la cloche de chaque écran. Le push est une fonction à venir, pour les
alertes sonores qu'émet le syndic (#283) : l'offre « Être averti sur ce téléphone »
(#17) existe, mais ne délivre rien tant que le relais de la plateforme n'est pas branché
(clé `.p8` du compte Apple, coprofirst#2494).
**Sans réseau** (#101), une résidence dont la session est gardée sous Face ID se
rouvre sur sa dernière lecture — le fil, les affaires et leur détail, le profil,
l'annuaire, les documents et photos déjà ouverts —, datée en haut de l'écran
(« Hors ligne — à jour au 10/11/2026 à 14:32 ») ; on consulte, on n'agit pas : les
gestes restent en place, grisés, et disent pourquoi. Le réseau revenu, la session
reprend et tout se relit. Cette lecture est chiffrée, hors des sauvegardes, effacée à
la déconnexion et au-delà de 7 jours ; rien de l'administration ni de l'Espace CS.

**Mesure d'audience** (coprofirst#2726, #198, contrat 1.31.0) : chaque écran vu part à la
résidence sous le chemin de la page équivalente du site (`/tickets/12`, `/admin#telemetry`)
et le canal « App iPhone », par lots de 20 au plus, toutes les 30 s et au passage en
arrière-plan — comme le site, que le tableau de bord mêle alors à l'app. Rien ne part si le
compte l'a refusée au Profil, ni vers une résidence qui ne dit pas servir au moins le
plancher de l'app (une installation antérieure au contrat 1.31.0 compterait l'app comme le
site ; une version illisible ne dit rien, #254), ni hors ligne ; aucun identifiant d'appareil. L'onglet
Télémétrie montre la répartition servie : « Accès : site ou application », et l'accès de
chaque page quand la période en a plusieurs.

Où en est chaque onglet du site — fait, prévu (et par quel ticket), ou réservé
au site — et la feuille de route : [`Parite/PARITE.md`](Parite/PARITE.md),
jugé en CI.

Pour les essayer sans réseau, un build **Debug** accepte des arguments de lancement :
`-api-simulee` (une résidence inventée, aucune requête ne part) et
`-ecran en-savoir-plus|connexion|faceid|demo|fil|affaires|retour|retour-mot-de-passe`
(`-faceid-refuse` : Face ID annulé à chaque demande ; `-protection appareil|aucune` :
la session gardée sans biométrie ; `-saisie complete` : la saisie Complète d'une
affaire, au lieu d'Essentielle ; avec `-ecran retour`, `-hors-ligne gardee|perimee|sans-lecture` :
l'appareil sans réseau, et une dernière lecture gardée, trop ancienne, ou absente). Un build Release ne compile pas la simulation
(`scripts/verifier-simule.py`, #84).

Ce que l'app retient d'un compte — profil dans chaque résidence, courriel de la
dernière connexion — va au Trousseau de l'appareil ; l'identifiant du compte, gardé avec
le profil le temps d'une session (« votre compte » dans Utilisateurs, #94), s'efface à
la déconnexion ; les réglages ne gardent que la
résidence (adresse, nom, présentation). La dernière lecture d'une résidence (hors
ligne, #101) va dans `Application Support`, chiffrée et exclue des sauvegardes.

## Charte

Le contrat d'API, les couleurs, les natures du fil, l'ordre des pages, les onglets
et les tables des menus sont **générés** depuis CoproFirst, jamais recopiés :
`python3 scripts/generer.py` écrit
`openapi.json`, `CoproFirst/Charte/Palette*.swift` (la charte et les palettes d'une
résidence, claires et sombres, teintes du Kanban comprises), `NaturesDuFil.swift`,
`CoproFirst/Navigation/PagesParDefaut.swift`, les `Fonctions/<Menu>/Genere/` et la
liste des onglets du site (`Parite/ONGLETS-DU-SITE.md`). Le contrôle du dépôt
refuse une couleur écrite à la main dans l'app.

Une seule règle de provenance : les générateurs lisent une **version publiée** de
CoproFirst (l'archive de son étiquette et les pièces jointes de sa release), nommée
dans l'en-tête « GÉNÉRÉ » de chaque fichier — jamais un clone ni une branche. Il y
en a un par domaine dans `scripts/generateurs/`, que `generer.py` découvre et lance
tous ; `--sources` liste les fichiers de CoproFirst qu'ils lisent.

**Le plancher.** L'app parle à des installations de versions différentes : elle se
génère sur la plus ancienne version servie par une installation connue, écrite à un
seul endroit, `scripts/generateurs/_plancher.py`, avec sa raison. Un contrat plus
récent rendrait obligatoires des champs qu'une installation plus ancienne n'envoie
pas. **Monter le plancher est une décision**, prise quand toutes les installations
connues ont dépassé la nouvelle version : on change `_plancher.py` et on régénère
(`python3 scripts/generer.py`) dans la même PR. `--version vX.Y.Z` ou `--derniere`
permettent de voir ce qu'une montée changerait.

Un champ qu'une installation plus récente sert déjà, au-dessus du plancher, se lit en
tolérant son absence — l'écran garde alors son geste d'avant — et l'API simulée le
déclare au juge (`AuDessusDuPlancher`) ; la méthode est dans la skill
`swiftui-patterns`.

**Concordance** (`scripts/concordance.py`) — deux verdicts, jamais confondus :

- **écart au plancher** : ce qui est généré n'est plus ce que le plancher régénère,
  ou une réponse de l'API simulée sert un champ que le serveur ne sert pas
  (`scripts/verifier-fixtures.py`). Rouge, en CI à chaque PR et chaque jour ; le
  workflow quotidien « Concordance avec CoproFirst » ouvre ou complète un ticket
  `concordance` ;
- **montée possible** : une version publiée au-dessus du plancher. Une information,
  jamais un rouge : un ticket `a-monter`, ouvert une fois et tenu à jour, dit ce que
  la montée exigerait (champs devenus requis, fichiers qui changeraient).

Une version illisible donne INCONNU — rouge, jamais vert.

## Contrat d'API

Le client est **généré** depuis
[`openapi.json`](Paquets/ClientAPI/Sources/ClientAPI/openapi.json) à chaque build ;
aucune route ne s'écrit à la main. Sa provenance est dans
[`PROVENANCE-OPENAPI.md`](Paquets/ClientAPI/PROVENANCE-OPENAPI.md).

## Licence

[AGPL-3.0-or-later](LICENSES/AGPL-3.0-or-later.txt), avec une
[permission additionnelle](LICENSES/LicenseRef-CoproFirst-AppStore.txt) (article 7)
qui autorise la distribution par l'App Store et TestFlight. Le dépôt suit la
spécification [REUSE](https://reuse.software) ; les dépendances et leurs licences
sont dans [`DEPENDANCES.md`](DEPENDANCES.md).

« CoproFirst » fait l'objet d'une demande de marque (n° 5307183) : voir la
[politique de marque](https://github.com/philippe-tressard/coprofirst/blob/main/MARQUE.md)
du projet.
