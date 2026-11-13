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
L'app n'est distribuée nulle part (« Sortir une version »).

## Sortir une version

Aujourd'hui, une version ne sort que sur l'iPhone de Philippe :

1. la version se lit dans `project.yml` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`) ;
   l'app n'a ni étiquette ni release ;
2. chaque PR est construite et testée par la CI (`ci.yml`), **sans signer** ; qui fusionne
   sur `main` se lit au champ `fusion` du registre (`CLAUDE.md`, « Dépôt ») ;
3. au poste : `bash scripts/generer-projet.sh`, puis Xcode signe (signature automatique,
   équipe `GUX8KASNTG`) et installe l'app sur l'iPhone branché.

Manquent pour TestFlight : l'app créée dans App Store Connect, un numéro de build qui
monte à chaque envoi, une archive envoyée (au poste, ou par la CI avec une clé d'API
rangée par Philippe), et un runner macOS épinglé plutôt que `macos-latest`. Ce qui
est un geste de Philippe, et ce qui précède la première soumission : skill
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
(coprofirst v3.84.0, contrat 1.19.0).
Une affaire peut faire intervenir **plusieurs prestataires** (coprofirst v3.90.0,
contrat 1.28.0, #181) : la fiche les dit un par ligne, la carte du Kanban montre le
premier puis « +N », et « Modifier l'affaire » en ajoute, en retire et les réordonne
quand la résidence en sert le droit — d'une résidence plus ancienne, le seul
prestataire qu'elle sert, comme avant.
Une affaire ouverte se lit en fil, sur un rail : la demande, la suite, les comptes
rendus, la synthèse — pastille pleine pour le réalisé ; un toucher ouvre une entrée
quatre secondes, un double toucher ou un appui long la garde ouverte (#178).
L'accueil et la démo ne s'offrent qu'à un appareil qui n'a encore ouvert aucune
résidence ; ensuite l'app rouvre la dernière : Face ID demandé d'emblée si la
session est gardée, sinon la connexion avec l'adresse et le courriel retenus. La
barre du bas suit l'ordre réglé par l'administration de la résidence
(`pages_order`) ; les entrées non livrées annoncent « Bientôt ».
**Sans réseau** (#101), une résidence dont la session est gardée sous Face ID se
rouvre sur sa dernière lecture — le fil, les affaires et leur détail, le profil,
l'annuaire, les documents et photos déjà ouverts —, datée en haut de l'écran
(« Hors ligne — à jour au 10/11/2026 à 14:32 ») ; on consulte, on n'agit pas : les
gestes restent en place, grisés, et disent pourquoi. Le réseau revenu, la session
reprend et tout se relit. Cette lecture est chiffrée, hors des sauvegardes, effacée à
la déconnexion et au-delà de 7 jours ; rien de l'administration ni de l'Espace CS.

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
