# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les générateurs de ce que l'app tire de coprofirst — un module par domaine.

Chaque module (hors `_*`) déclare :

- `SOURCES` : les fichiers de coprofirst qu'il lit, relatifs à la racine du dépôt — seuls
  ceux-là sont extraits de la version lue ; vides partout depuis #356 : `INTERDITS` refuse
  l'API et le front, que la release publie (`ctx.table`, `ctx.constante`) ;
- `generer(ctx) -> str` : il lit par `ctx.table`, `ctx.constante` (ou `ctx.lire`), écrit par
  `ctx.ecrire`, date par `ctx.entete`, et rend une phrase de bilan.

Un module peut aussi déclarer `PIECES_JOINTES` (les fichiers joints à la release
qu'il lit par `ctx.version.piece_jointe`), et `autotest()` — la preuve qu'il refuse ce
qu'il doit refuser, jouée par `generer.py --sources`, donc par `verifier-depot.sh`.

Aucun module ne lit coprofirst autrement que par `ctx` : `_source.py` seul y touche,
à une version publiée (`verifier-depot.sh` refuse le reste). `scripts/generer.py` les
découvre seul : ajouter un domaine, c'est ajouter un fichier ici.
"""
