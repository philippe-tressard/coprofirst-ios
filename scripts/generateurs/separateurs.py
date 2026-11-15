# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les séparateurs du site (`SEPARATEUR` de `front/src/lib/separateurs.ts`, #188).

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

SOURCES = ["front/src/lib/separateurs.ts"]
SORTIE = pathlib.Path("CoproFirst/Commun/Texte/Genere/Separateur.swift")


def _litteral(js: str) -> str:
    """Une chaîne JavaScript en littéral Swift : un `\\u00a0` y reste lisible, `\\u{00A0}`."""
    texte = re.sub(r"\\u([0-9a-fA-F]{4})", lambda m: chr(int(m.group(1), 16)), js)
    swift = chaine(texte)
    return "".join(c if c.isascii() or c.isalnum() or c in "—«»·→" else f"\\u{{{ord(c):04X}}}" for c in swift)


def separateurs(texte: str) -> list[tuple[str, str, str]]:
    """(clé, valeur JavaScript, commentaire) de chaque séparateur, dans l'ordre du site."""
    bloc = re.search(r"export const SEPARATEUR = \{(.*?)\} as const;", texte, re.S)
    entrees = re.findall(r"/\*\*\s*(.*?)\s*\*/\s*(\w+): '([^']*)'", bloc.group(1), re.S) if bloc else []
    if not entrees:
        raise SystemExit("❌ SEPARATEUR illisible dans separateurs.ts — l'app doit l'apprendre")
    return [(cle, valeur, doc) for doc, cle, valeur in entrees]


def generer(ctx) -> str:
    entrees = separateurs(ctx.lire(SOURCES[0]))
    corps = "".join(f"    /// {doc}\n    static let {cle} = {_litteral(valeur)}\n" for cle, valeur, doc in entrees)
    ecrire_table(ctx, SORTIE, "front/src/lib/separateurs.ts", "Separateur",
                 "Les séparateurs du site : une espace sécable avant, insécable après — "
                 "la ligne se coupe devant eux, jamais après.", corps)
    return f"{len(entrees)} séparateurs ({', '.join(c for c, _, _ in entrees)})"
