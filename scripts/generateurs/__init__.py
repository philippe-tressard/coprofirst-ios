# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les générateurs de ce que l'app tire de coprofirst — un module par domaine.

Chaque module (hors `_*`) déclare :

- `SOURCES` : les fichiers de l'ARCHIVE de coprofirst qu'il lit encore, relatifs à la
  racine du dépôt (`api/app/utils/avis.py`) — seuls ceux-là sont extraits de la version
  lue. Une table du site n'en fait plus partie : elle se lit dans la pièce jointe
  `tables-clients.json` (#128) ; un fichier de `front/` n'est admis que s'il est déclaré
  dans `_tables.HORS_TABLES`, avec sa raison ;
- `generer(ctx) -> str` : il lit une table du site par `ctx.table(nom, forme)` — absente
  ou d'une autre forme, la génération s'arrête —, un fichier de l'archive par `ctx.lire`,
  écrit par `ctx.ecrire`, date par `ctx.entete`, et rend une phrase de bilan.

Un module peut aussi déclarer `PIECES_JOINTES` (les autres fichiers joints à la release
qu'il lit par `ctx.version.piece_jointe` : `openapi.json`).

Aucun module ne lit coprofirst autrement que par `ctx` : `_source.py` seul y touche,
à une version publiée (`verifier-depot.sh` refuse le reste). `scripts/generer.py` les
découvre seul : ajouter un domaine, c'est ajouter un fichier ici.
"""
