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
| Compte Apple Developer | ❌ **pas ouvert** — geste de Philippe ; choisir **particulier** ou **organisation** avant l'inscription (vendeur affiché, D-U-N-S) |
| Signature | ❌ désactivée (`CODE_SIGNING_ALLOWED: NO` dans `project.yml`) |
| Identifiant d'app | `fr.coprofirst.app` — provisoire, se fige à la création de l'app dans App Store Connect |
| Exception App Store de la licence | ✅ posée au premier commit (`LICENSES/LicenseRef-CoproFirst-AppStore.txt`) |
| Icône | ❌ absente — le logo entre avec sa licence propre (`REUSE.toml`) |
| Liens universels | bloqués par l'identifiant d'équipe Apple (coprofirst#2459) |
| Push APNs | relais de la plateforme à spécifier (coprofirst#2458) |

## À faire avant la première soumission

- [ ] Politique de confidentialité (URL) et étiquettes de l'App Store, confrontées
      à ce que l'app **et chaque SDK** collectent ; manifeste de confidentialité.
- [ ] Suppression du compte **dans l'app**.
- [ ] Accès au code source depuis l'interface (AGPL §13, condition 3 b de l'exception).
- [ ] Compte de démonstration pour la revue, sur `demo.coprofirst.fr`, sans donnée réelle.
- [ ] Aucune donnée personnelle dans une charge de notification.
- [ ] Clé d'API App Store Connect et clé APNs (`.p8`) : hors du dépôt
      (`.gitignore`), dans les secrets de la CI le moment venu.
