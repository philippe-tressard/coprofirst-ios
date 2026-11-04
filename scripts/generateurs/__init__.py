# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les générateurs de ce que l'app tire des sources de coprofirst — un module par domaine.

Chaque module (hors `_commun`) déclare :

- `SOURCES` : les fichiers de coprofirst qu'il lit, relatifs à la racine du dépôt
  (`front/src/lib/pages.ts`) — la concordance quotidienne (#20) les surveille ;
- `generer(ctx) -> str` : il écrit ses fichiers par `ctx.ecrire`, les date par
  `ctx.entete`, lit sous `ctx.front`, et rend une phrase de bilan.

`scripts/generer-charte.py` les découvre seul : ajouter un domaine, c'est ajouter un
fichier ici — jamais éditer `generer-charte.py`.
"""
