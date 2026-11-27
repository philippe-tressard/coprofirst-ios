---
name: publication-app-store
description: "Signer, envoyer sur TestFlight et publier CoproFirst-iOS sur l'App Store — prérequis du compte Apple Developer, fiche, confidentialité déclarée, compte de démonstration pour la revue, exception App Store de la licence. À charger avant toute étape de signature, de TestFlight ou de soumission."
---

<!--
SPDX-FileCopyrightText: 2026 Philippe TRESSARD
SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
-->

# Publication sur l'App Store

## 🔴 Rien ne part en revue chez Apple sans le « oui » écrit de Philippe

Règle de Philippe (02/11/2026). Le pourquoi et le détail sont dans la mémoire
`feedback_aucune_soumission_sans_validation_rendu` de la banque du projet ;
ce qui suit est son application au dépôt.

| | |
|---|---|
| **Interdit** sans son « oui » écrit **pour CETTE version**, captures à l'appui | soumission à l'App Store ; version proposée aux testeurs **externes** de TestFlight (elle passe par la revue d'Apple) ; tout `deliver`, `pilot` vers un groupe externe, « Submit for Review » |
| **Permis** — c'est ce qui lui sert à juger | simulateur ; installation sur son iPhone depuis Xcode ; TestFlight **interne** |

Une validation ne vaut pas pour la version suivante. Une automatisation de
publication (fastlane, workflow) n'a **aucune voie** vers la revue : pas de lane
ni de job qui soumet d'office. `scripts/verifier-depot.sh` refuse ces gestes
dans `fastlane/` et `.github/workflows/` — la soumission reste un geste manuel,
fait après le « oui ».

> Ce qu'il faut vérifier se lit dans
> `standards/14` §3 bis ; les **règles d'Apple en vigueur** se relisent avant
> chaque soumission — cette skill dit où en est CoproFirst-iOS, pas ce qu'Apple exige.

## Fondations (posées du 01 au 11/11/2026)

| Étape | État |
|---|---|
| Compte Apple Developer | ✅ ouvert le 01/11/2026, **au titre de particulier** : le vendeur affiché sur l'App Store est le nom civil du titulaire — il ne s'écrit **pas** dans ce dépôt public |
| Équipe | `GUX8KASNTG` — pas un secret (elle figure dans chaque app signée) ; `DEVELOPMENT_TEAM` de `project.yml` |
| Signature | automatique (`CODE_SIGN_STYLE: Automatic`), **au poste seulement** ; la CI ne signe pas (`CODE_SIGNING_ALLOWED=NO`, passé par les scripts qui construisent : `tests-simulateur.sh`, `verifier-archive-montre.sh`, et `verifier-montre-dependante.sh` au poste), aucun certificat ni secret Apple dans GitHub |
| Identifiant d'app | `fr.coprofirst.app` — **figé** le 01/11/2026 : c'est un contrat (liens universels `GUX8KASNTG.fr.coprofirst.app`, APNs, App Store Connect) |
| Exception App Store de la licence | ✅ posée au premier commit (`LICENSES/LicenseRef-CoproFirst-AppStore.txt`) |
| Icône | ✅ rendue du logo du site (`scripts/importer-logo.sh`), 1024 px opaque ; licence `LicenseRef-CoproFirst-Logo`, qui couvre l'app publiée par son auteur (coprofirst#2474) ; `verifier-logo.sh` en CI |
| Liens universels | capacité Associated Domains enregistrée le 10/11/2026 (droits dans `project.yml`) ; l'AASA est servi (coprofirst#2459) ; l'ouverture dans l'app est codée ; la liste des domaines (`project.yml`) n'est pas arrêtée — #18 clos pour abandon le 17/11/2026 |
| Push APNs | capacité Push enregistrée le 10/11/2026 (`aps-environment` dans `project.yml`, `production` à l'archive). Côté app livré par #17 : autorisation demandée dans la cloche, jamais au lancement ; appareil enregistré à l'ouverture d'une résidence, retiré à la déconnexion (`Fonctions/Notifications/Push/`). Droit `time-sensitive` (avis urgents, décision du 03/11/2026) ajouté par #17 ; capacité « Time Sensitive Notifications » **acceptée par Philippe le 11/11/2026**, enregistrée au compte à la prochaine compilation signée au poste. Réception réelle **INCONNUE** tant que le relais (coprofirst#2494) n'a pas sa clé `.p8`. Depuis #283 : seule l'alerte d'une actualité urgente sonne, et l'app tient le relais éteint (`RelaisPush`) jusqu'à l'allumage du service (coprofirst#2875) |
| Confidentialité | manifeste embarqué (`CoproFirst/PrivacyInfo.xcprivacy`) et texte de la fiche prêts le 11/11/2026 (#19) : [`confidentialite.md`](confidentialite.md), tenus au code par `scripts/verifier-confidentialite.py` ; **saisis** dans App Store Connect par Philippe pour la 1.0, puis pour la 1.1 (*Product Interaction*, Analytics, #199), à tenir à jour à chaque version. La consultation hors ligne (#101) garde la dernière lecture **sur l'appareil** : rien ne part, la déclaration ne change pas, mais la fiche (§3) et la politique de confidentialité du site le disent |

## Ce qui reste un geste de Philippe

- **Connecter Xcode au compte** (Xcode › Réglages › Comptes) : c'est lui qui
  s'identifie, au poste. Je ne saisis, ne demande ni ne lis jamais un mot de
  passe Apple, un code de double authentification, une clé `.p8` ou un
  certificat — ni dans le dépôt, ni dans une conversation (`standards/03` §3).
- Envoyer l'archive à App Store Connect (Organizer › Distribute App) et la soumettre à
  la revue — après son « oui » écrit pour cette version. L'app et les contrats d'Apple
  existent depuis la 1.0.
- Tenir à jour, à chaque version, la politique de confidentialité, les étiquettes
  « App Privacy », la **description** et la note de revue : le pas à pas (Où / Quoi) et
  les textes exacts sont dans [`confidentialite.md`](confidentialite.md) §9 et §5. La
  description se change là d'abord : `scripts/verifier-confidentialite.py` refuse
  qu'elle nie une donnée du manifeste (#238) et, par `scripts/fiche_magasin.py`, qu'elle
  promette de joindre ce que l'app laisse au site, ou que la description et les notes de
  revue décrivent un relais des notifications autre que celui de `RelaisPush.courant` (#343).
- Le jour où la CI devra signer ou envoyer sur TestFlight : une clé d'API App
  Store Connect créée par Philippe, rangée dans les secrets de GitHub par lui —
  la CI la lit, personne ne la voit passer.

## Les versions publiées

Chaque version soumise porte son étiquette `vX.Y.Z` ; celle qui est en ligne se relit sans
compte, jamais ici : `curl "https://itunes.apple.com/lookup?bundleId=fr.coprofirst.app&country=fr"`
(<https://apps.apple.com/fr/app/coprofirst/id6834326392>).

- **1.0** (build 1, `v1.0.0`) : approuvée le 14/11/2026 à 00:27, en ligne le 13/11 à 23:26 UTC.
- **1.1** (build 2, `v1.1.0`) : en ligne le 18/11/2026 (#263), iPhone et iPad (#219).
- **1.2** (build 3, `v1.2.0` à poser par `avant_soumission.py`) : préparée le 26/11/2026,
  sans l'Android (décision de Philippe du 26/11 : la règle de sortie commune avec l'Android
  levée pour cette version). **Avec l'app Apple Watch et l'Apple TV** (Philippe, 26/11 après-midi :
  « la livraison doit watch et tv », puis « Oui, allume-la » pour la liaison de #226), qui
  remplace son « Oui » du matin à une 1.2 sans la montre. Archive iPhone avec
  `ARCHIVE_AVEC_MONTRE=true`, archive tvOS à part (#320) ; relais des notifications éteint (#318).

Nouveautés de la 1.2 (*What's New in This Version*), à coller par Philippe :

```text
• Signalez au conseil syndical une affaire, une suite ou la réponse de l'assistant. Masquez ce que publie un voisin, pour vous seul.
• Affaires : modifiez ou supprimez votre réponse.
• Carnet d'entretien : un contrat qui n'a pas encore commencé est marqué « À venir ».
• Le menu ne montre que les pages auxquelles vous avez accès, comme sur le site.
• Premier accès avec un mot de passe temporaire : vous choisissez le vôtre avant tout.
• Sondages et annonces : pourcentages et prix identiques à ceux du site.
• iPad : la liste et la fiche côte à côte sur tous les écrans, en portrait aussi ; ⌘F pour chercher.
• iPhone pliable : le Fil en carnet, une journée par double page.
• Apple Watch : les alertes de votre résidence au poignet, en lecture seule, même sans réseau.
• Apple TV : l'écran du hall diffuse les affiches de la résidence, appairé par un code depuis l'Espace du conseil syndical.
• Meilleure lecture en très grand texte, et de nombreuses corrections.
```

`main` avance ensuite sous le dernier numéro : la version suivante monte
`MARKETING_VERSION` et `CURRENT_PROJECT_VERSION` (`project.yml`).

Fait pour la 1.0, à ne pas refaire — et à reprendre pour chaque version :

| Sujet | Ce qui a été fait, et ce qu'il faut savoir |
|---|---|
| **Archive** | `ARCHIVE_AVEC_MONTRE=true bash scripts/generer-projet.sh` — l'app Apple Watch n'est embarquée qu'ainsi (`project-archive.yml`, #226) ; vérifier qu'elle est dans l'archive : `Products/Applications/CoproFirst.app/Watch/CoproFirst.app` (la CI le rejoue sans signature : `scripts/verifier-archive-montre.sh`, #324). La signature automatique enregistre au compte l'App ID de la montre (`fr.coprofirst.app.watchkitapp`) à la première archive. Puis, sous le verrou commun du poste (#255), `python3 ~/.claude/bin/verrou_poste.py prendre --libelle "xcodebuild archive (CoproFirst-iOS)" -- xcodebuild archive -configuration Release -destination 'generic/platform=iOS' -archivePath "~/Library/Developer/Xcode/Archives/<date>/CoproFirst <jj-mm-aa hh.mm>.xcarchive"` depuis un **worktree épinglé sur le commit voulu** : Xcode › Window › Organizer la voit. La signature est automatique ; Philippe clique « Distribute App › App Store Connect › Distribute » (c'est lui qui crée le certificat de distribution). **Le numéro de build doit monter à chaque envoi** (`CURRENT_PROJECT_VERSION`). |
| **Archive Apple TV** (1.2, 27/11/2026) | `-scheme CoproFirstTV -destination 'generic/platform=tvOS'`, même worktree épinglé. Tant qu'aucun appareil tvOS n'est enregistré au compte, Apple refuse le profil de développement (« Your team has no devices »), même avec `-allowProvisioningUpdates`. Chemin éprouvé : archive avec `CODE_SIGNING_ALLOWED=NO`, puis signer l'app (et `Frameworks/*.dylib`) au poste avec l'identité « Apple Development » (`codesign --force --sign … --generate-entitlement-der`) et inscrire `ApplicationProperties › Team` dans le plist de l'archive (`<archive>.xcarchive/Info.plist`) ; sans signature, l'Organizer refuse « No Team Found in Archive ». Un `xcodebuild -exportArchive` local (méthode `app-store-connect`, `destination` `export`) prouve la re-signature App Store sans rien envoyer. Le build tvOS a son propre envoi, sous le même identifiant. |
| **Icônes** (1.2, 27/11/2026) | App Store Connect refuse l'archive iPhone dont la montre embarquée n'a pas d'icône (ITMS-90713, ITMS-90391). La montre a son catalogue (`CoproFirstWatch/Ressources/Assets.xcassets`, rendu par `scripts/images_logo.py`) et `scripts/verifier-archive-montre.sh` exige une icône compilée et nommée de l'iPhone et de la montre. Avant d'envoyer, « Validate App » dans l'Organizer joue les mêmes contrôles sans déposer de build. |
| **Contrôler l'app construite, pas `project.yml`** | Le 12/11/2026, l'archive Release sortait **iPhone et iPad** (XcodeGen posait `1,2` sur la cible) et une version écrite en dur. `ConformiteAppStoreTests` lit le plist de l'app construite ; relire aussi `codesign -d --entitlements` et la présence des symboles de simulation (aucun). |
| **Jouer le geste exigé par la revue** | La feuille « Supprimer mon compte » **ne s'ouvrait pas** (attachée à la `Section` d'une `List`) et aucun test ne le voyait. `SuppressionCompteUITests` joue le parcours. Toute règle d'Apple qui demande un geste dans l'app se joue **à l'écran** avant l'envoi. |
| **Captures** | iPhone « Dynamic Island, écran moyen » : **1206 × 2622**, PNG sans transparence, 10 au plus. Produites au simulateur par défaut, thème clair, avec `TEST_RUNNER_CAPTURES` ; dans App Store Connect, l'onglet **« Aperçus d'app et captures d'écran »** — pas « En-tête et résultats de recherche », dont la zone n'accepte que 5244 × 2950. **iPad** (app universelle depuis #219) : captures **iPad 13 pouces** (2064 × 2752 ou 2048 × 2732, portrait ou paysage), au simulateur « iPad Pro 13-inch » (`APPAREIL=ipad`). Pas d'iPhone Duo (#119). |
| **Fiche** | Textes, notes de revue (`notes-revue.md`), compte de démonstration `user-copro@demo.coprofirst.fr`, confidentialité (à la 1.0 : 8 types, tous « Fonctionnement de l'app », liés à l'identité, sans suivi ; depuis la 1.1, ce que dit `confidentialite.md` §5), classification **4+** (contenu généré par les utilisateurs : Oui ; réseaux sociaux et messagerie : Non), gratuite, 175 pays, **Mac et Vision décochés**. |
| **Publication** | Le choix « manuelle » du 13/11 n'a **pas** tenu : l'app est sortie dès l'approbation. **Vérifier le bouton radio avant « Ajouter pour vérification »** si l'on veut garder la main. |
| **UE (DSA)** | Statut **non-commerçant** déclaré le 13/11/2026 (Business › Conformité) : app gratuite, libre, à titre personnel. À revoir si l'offre hébergée payante démarre — ticket #194. |

Reste ouvert : les notifications push n'ont jamais été reçues pour de vrai (clé `.p8` du
relais, coprofirst#2494) ; le geste de suppression n'a été joué que sur l'API simulée ;
la suppression est une **demande** traitée par l'administration (arbitrage du 12/11/2026).

## Avant CHAQUE soumission : la commande de contrôle (#205)

`python3 scripts/avant_soumission.py` juge le commit exact à soumettre (`HEAD` =
`origin/main`) et refuse sur le moindre rouge comme sur un INCONNU : CI complète verte
(interface comprise), concordance avec le contrat servi en production, contrôle du dépôt,
aucun ticket `bloque-soumission` ouvert, écrans principaux en sombre et en très grand
texte au simulateur (captures dans `.build/Soumission/`). Ce que seul Philippe voit —
captures déposées, notes de version, étiquette App Privacy, rendu validé — se confirme
nommément par `--confirme`. La liste fait foi dans le script
(`CONFIRMATIONS`), elle ne se recopie pas ici. Tout vert, `--etiqueter` pose et pousse
`vX.Y.Z` ; le compte rendu (`--rapport`) va dans la note de publication. **Dans la foulée de
l'étiquette**, la version se déclare dans coprofirst, comme le compte rendu le dit : ticket ou
PR « contrat figé de coprofirst-ios X.Y au plancher vA.B.C » (son entrée `EN_CIRCULATION` et
son contrat figé, coprofirst#3023). Sans elle, la CI du serveur refuse l'étiquette et rougit
toutes ses PR ; le ticket de la version ne se ferme qu'avec ce renvoi (#354). Une version
refusée à la revue garde son étiquette : elle se déclare de même, ou sort par `SORTIES`. La parité avec
l'Android n'en est pas une condition (18/11/2026 : sortir ensemble est une occasion). La
soumission reste le geste de Philippe.

## La première soumission — historique (1.0, 13/11/2026)

Tout ce qui suit a été fait pour la 1.0 ; ce qui reste à rejouer à chaque version est
dit sur la ligne.

- [x] Manifeste de confidentialité, et texte de la fiche confronté à ce que l'app **et
      chaque paquet** transmettent : [`confidentialite.md`](confidentialite.md) (#19).
- [x] Politique de confidentialité (URL) et étiquettes « App Privacy » **saisies** dans
      App Store Connect par Philippe (1.0, puis 1.1), à partir de `confidentialite.md` §9 —
      à relire contre les règles d'Apple en vigueur à chaque version.
- [x] Suppression du compte **dans l'app** : une DEMANDE lancée depuis le Profil, traitée
      par l'admin de la résidence sous un délai annoncé (arbitrage de Philippe, 12/11/2026) —
      livrée par #166 (PR #182), route coprofirst#2699 en production. **À rejouer sur la
      démo avant de soumettre** (jamais vue à l'écran) ; à confronter à la règle d'Apple en vigueur.
- [x] Notes de revue : le texte est prêt dans [`notes-revue.md`](notes-revue.md), suppression
      du compte comprise (à relire contre l'app de la version soumise). Il dit que la communauté est fermée (comptes validés par la résidence),
      que tout contenu se signale au conseil syndical, qui modère, la réponse de l'IA
      comprise, et qu'un résident peut masquer ce que publie un autre (#286, décision du
      17/11/2026, qui remplace l'arbitrage du 12/11 de #167). Ces gestes sont au plancher
      depuis v3.121.2 (#313) : toute résidence qui s'ouvre les sert.
- [x] Texte et avis d'Apache-2.0 des paquets embarqués dans « À propos » (#168), tenus par
      `scripts/verifier-dependances.py`.
- [x] Accès au code source depuis l'interface (AGPL §13, condition 3 b de l'exception) :
      À propos › « Code source de l'app » (`Fonctions/APropos/AProposView.swift`).
- [x] Compte de démonstration pour la revue, sur `demo.coprofirst.fr`, sans donnée réelle
      (`user-copro@demo.coprofirst.fr`, « Fiche » plus haut).
- [ ] Aucune donnée personnelle dans une charge de notification — côté app, tenu
      (#17 : l'app ne lit que l'abonnement opaque `a`, le jeton ne s'écrit nulle part) ;
      la charge est composée par le relais (coprofirst#2494), à vérifier à sa mise en route.
- [ ] Clé d'API App Store Connect : hors du dépôt (`.gitignore`), dans les secrets de
      la CI le moment venu. La clé APNs (`.p8`) n'entre **ni** dans ce dépôt **ni** dans
      sa CI : elle vit chez le relais de la plateforme seul (spec push N1).
