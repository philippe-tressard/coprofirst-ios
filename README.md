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

**Amorce** (novembre 2026) : un écran d'accueil et le client d'API généré. L'app
n'est distribuée nulle part. Elle se signe au poste (signature automatique, équipe
Apple `GUX8KASNTG`) ; la CI construit et teste sans signer.

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
connexion, démo, puis le fil de la résidence, jour par jour, et ses affaires. La
barre du bas suit l'ordre réglé par l'administration de la résidence
(`pages_order`) ; les entrées non livrées annoncent « Bientôt ».

Où en est chaque onglet du site — fait, prévu (et par quel ticket), ou réservé
au site — et la feuille de route : [`Parite/PARITE.md`](Parite/PARITE.md),
jugé en CI.

Pour les essayer sans réseau, l'app accepte des arguments de lancement :
`-api-simulee` (une résidence inventée, aucune requête ne part) et
`-ecran en-savoir-plus|connexion|faceid|demo|fil|affaires`.

## Charte

Les couleurs, la table des natures du fil et l'ordre par défaut des pages sont
**générés** depuis les sources de CoproFirst, jamais recopiés :
`python3 scripts/generer-charte.py` écrit `CoproFirst/Charte/Palette*.swift` (la
charte et les palettes d'une résidence, claires et sombres), `NaturesDuFil.swift`,
`CoproFirst/Navigation/PagesParDefaut.swift` et la liste des onglets du site
(`Parite/ONGLETS-DU-SITE.md`). Le contrôle du dépôt refuse une couleur écrite à
la main dans l'app.

Les générateurs lisent un clone de CoproFirst : `$COPROFIRST_RACINE` (par défaut
`/Volumes/Data/Dev/5hostachy`), ou le chemin passé en argument.

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
