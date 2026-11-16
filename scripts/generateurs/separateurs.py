# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les séparateurs du site (`SEPARATEUR` de `front/src/lib/separateurs.ts`, #188), lus dans
la table que la release publie depuis v3.105.0 (`separateurs`, tables-clients.json 1.3.0,
#239) — plus dans le source par motif.

Une espace SÉCABLE avant, INSÉCABLE après : la ligne se coupe devant le séparateur,
qui ouvre la suivante avec son mot (coprofirst#2360). Chaque clé de la constante
devient une constante de la table — `point`, `tiret`, `fleche` à ce jour ; une clé
retirée par le site fait échouer le build là où l'app l'emploie.
`scripts/verifier-separateurs.py` refuse une recopie dans l'app.

→ `CoproFirst/Commun/Texte/Genere/Separateur.swift`.
"""

from __future__ import annotations

import pathlib
import re

from generateurs._commun import chaine, ecrire_table

SOURCES: list[str] = []  # separateurs de tables-clients.json (#239)
SORTIE = pathlib.Path("CoproFirst/Commun/Texte/Genere/Separateur.swift")


def _litteral(js: str) -> str:
    """Une chaîne JavaScript en littéral Swift : un `\\u00a0` y reste lisible, `\\u{00A0}`."""
    texte = re.sub(r"\\u([0-9a-fA-F]{4})", lambda m: chr(int(m.group(1), 16)), js)
    swift = chaine(texte)
    return "".join(c if c.isascii() or c.isalnum() or c in "—«»·→" else f"\\u{{{ord(c):04X}}}" for c in swift)


def generer(ctx) -> str:
    publies = ctx.table("separateurs")
    if not isinstance(publies, dict) or not publies or not all(isinstance(v, str) for v in publies.values()):
        raise SystemExit("❌ separateurs : forme inattendue — l'app doit l'apprendre")
    entrees = list(publies.items())
    corps = "".join(f"    /// `SEPARATEUR.{cle}`\n    static let {cle} = {_litteral(valeur)}\n" for cle, valeur in entrees)
    ecrire_table(ctx, SORTIE, ctx.provenance_tables("separateurs"), "Separateur",
                 "Les séparateurs du site : une espace sécable avant, insécable après — "
                 "la ligne se coupe devant eux, jamais après.", corps)
    return f"{len(entrees)} séparateurs ({', '.join(c for c, _ in entrees)})"
