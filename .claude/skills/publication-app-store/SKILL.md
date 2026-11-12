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

> Squelette posé à l'amorce (01/11/2026). Ce qu'il faut vérifier se lit dans
> `standards/14` §3 bis ; les **règles d'Apple en vigueur** se relisent avant
> chaque soumission — cette skill dit où en est CoproFirst-iOS, pas ce qu'Apple exige.

## État au 01/11/2026

| Étape | État |
|---|---|
| Compte Apple Developer | ✅ ouvert le 01/11/2026, **au titre de particulier** : le vendeur affiché sur l'App Store est le nom civil du titulaire — il ne s'écrit **pas** dans ce dépôt public |
| Équipe | `GUX8KASNTG` — pas un secret (elle figure dans chaque app signée) ; `DEVELOPMENT_TEAM` de `project.yml` |
| Signature | automatique (`CODE_SIGN_STYLE: Automatic`), **au poste seulement** ; la CI ne signe pas (`CODE_SIGNING_ALLOWED=NO` dans `ci.yml`), aucun certificat ni secret Apple dans GitHub |
| Identifiant d'app | `fr.coprofirst.app` — **figé** le 01/11/2026 : c'est un contrat (liens universels `GUX8KASNTG.fr.coprofirst.app`, APNs, App Store Connect) |
| Exception App Store de la licence | ✅ posée au premier commit (`LICENSES/LicenseRef-CoproFirst-AppStore.txt`) |
| Icône | ✅ rendue du logo du site (`scripts/importer-logo.sh`), 1024 px opaque ; licence `LicenseRef-CoproFirst-Logo`, qui couvre l'app publiée par son auteur (coprofirst#2474) ; `verifier-logo.sh` en CI |
| Liens universels | capacité Associated Domains enregistrée le 10/11/2026 (droits dans `project.yml`) ; l'AASA est servi (coprofirst#2459) ; la liste des domaines et l'ouverture dans l'app : #18 |
| Push APNs | capacité Push enregistrée le 10/11/2026 (`aps-environment` dans `project.yml`, `production` à l'archive). Côté app livré par #17 : autorisation demandée dans la cloche, jamais au lancement ; appareil enregistré à l'ouverture d'une résidence, retiré à la déconnexion (`Fonctions/Notifications/Push/`). Droit `time-sensitive` (avis urgents, décision du 03/11/2026) ajouté par #17 ; capacité « Time Sensitive Notifications » **acceptée par Philippe le 11/11/2026**, enregistrée au compte à la prochaine compilation signée au poste. Réception réelle **INCONNUE** tant que le relais (coprofirst#2494) n'a pas sa clé `.p8` |
| Confidentialité | manifeste embarqué (`CoproFirst/PrivacyInfo.xcprivacy`) et texte de la fiche prêts le 11/11/2026 (#19) : [`confidentialite.md`](confidentialite.md), tenus au code par `scripts/verifier-confidentialite.py` ; la **saisie** dans App Store Connect reste à faire (Philippe) |

## Ce qui reste un geste de Philippe

- **Connecter Xcode au compte** (Xcode › Réglages › Comptes) : c'est lui qui
  s'identifie, au poste. Je ne saisis, ne demande ni ne lis jamais un mot de
  passe Apple, un code de double authentification, une clé `.p8` ou un
  certificat — ni dans le dépôt, ni dans une conversation (`standards/03` §3).
- Créer l'app dans App Store Connect, accepter les contrats d'Apple.
- Saisir la politique de confidentialité, les étiquettes « App Privacy » et la note de
  revue : le pas à pas (Où / Quoi) et les réponses exactes sont dans
  [`confidentialite.md`](confidentialite.md) §9 et §5.
- Le jour où la CI devra signer ou envoyer sur TestFlight : une clé d'API App
  Store Connect créée par Philippe, rangée dans les secrets de GitHub par lui —
  la CI la lit, personne ne la voit passer.

## À faire avant la première soumission

- [x] Manifeste de confidentialité, et texte de la fiche confronté à ce que l'app **et
      chaque paquet** transmettent : [`confidentialite.md`](confidentialite.md) (#19).
- [ ] Politique de confidentialité (URL) et étiquettes « App Privacy » **saisies** dans
      App Store Connect par Philippe, à partir de ce fichier (§9) — après avoir relu les
      règles d'Apple en vigueur.
- [ ] Suppression du compte **dans l'app** : une DEMANDE lancée depuis le Profil, traitée
      par l'admin de la résidence sous un délai annoncé (arbitrage de Philippe, 12/11/2026) —
      #166, bloqué par coprofirst#2699. À confronter à la règle d'Apple en vigueur.
- [ ] Notes de revue : dire que la communauté est fermée (comptes validés par la résidence),
      que tout contenu se signale au conseil syndical, qui modère — pas de blocage d'un
      auteur (arbitrage du 12/11/2026, #167 ; à rouvrir si la revue le demande).
- [x] Texte et avis d'Apache-2.0 des paquets embarqués dans « À propos » (#168), tenus par
      `scripts/verifier-dependances.py`.
- [ ] Accès au code source depuis l'interface (AGPL §13, condition 3 b de l'exception).
- [ ] Compte de démonstration pour la revue, sur `demo.coprofirst.fr`, sans donnée réelle.
- [ ] Aucune donnée personnelle dans une charge de notification — côté app, tenu
      (#17 : l'app ne lit que l'abonnement opaque `a`, le jeton ne s'écrit nulle part) ;
      la charge est composée par le relais (coprofirst#2494), à vérifier à sa mise en route.
- [ ] Clé d'API App Store Connect : hors du dépôt (`.gitignore`), dans les secrets de
      la CI le moment venu. La clé APNs (`.p8`) n'entre **ni** dans ce dépôt **ni** dans
      sa CI : elle vit chez le relais de la plateforme seul (spec push N1).
