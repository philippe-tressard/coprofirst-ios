---
name: publication-app-store
description: "Signer, envoyer sur TestFlight et publier CoproFirst-iOS sur l'App Store — prérequis du compte Apple Developer, fiche, confidentialité déclarée, compte de démonstration pour la revue, exception App Store de la licence. À charger avant toute étape de signature, de TestFlight ou de soumission."
---

<!--
SPDX-FileCopyrightText: 2026 Philippe TRESSARD
SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
-->

# Publication sur l'App Store

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
| Liens universels | bloqués par l'identifiant d'équipe Apple (coprofirst#2459) |
| Push APNs | relais de la plateforme à spécifier (coprofirst#2458) |

## Ce qui reste un geste de Philippe

- **Connecter Xcode au compte** (Xcode › Réglages › Comptes) : c'est lui qui
  s'identifie, au poste. Je ne saisis, ne demande ni ne lis jamais un mot de
  passe Apple, un code de double authentification, une clé `.p8` ou un
  certificat — ni dans le dépôt, ni dans une conversation (`standards/03` §3).
- Créer l'app dans App Store Connect, accepter les contrats d'Apple.
- Le jour où la CI devra signer ou envoyer sur TestFlight : une clé d'API App
  Store Connect créée par Philippe, rangée dans les secrets de GitHub par lui —
  la CI la lit, personne ne la voit passer.

## À faire avant la première soumission

- [ ] Politique de confidentialité (URL) et étiquettes de l'App Store, confrontées
      à ce que l'app **et chaque SDK** collectent ; manifeste de confidentialité.
- [ ] Suppression du compte **dans l'app**.
- [ ] Accès au code source depuis l'interface (AGPL §13, condition 3 b de l'exception).
- [ ] Compte de démonstration pour la revue, sur `demo.coprofirst.fr`, sans donnée réelle.
- [ ] Aucune donnée personnelle dans une charge de notification.
- [ ] Clé d'API App Store Connect et clé APNs (`.p8`) : hors du dépôt
      (`.gitignore`), dans les secrets de la CI le moment venu.
