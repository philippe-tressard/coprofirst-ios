# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les tables de « Mes lots & accès » et de « Prestataires » (#13).

Le contrat d'API ne sert que des CODES (`StatutAcces`, `StatutBail`,
`TypePrestataire`) : les libellés et les teintes vivent dans le front du site :

- le descriptif des onglets de `mon-lot` et `prestataires` (`pages.ts`) — les onglets
  eux-mêmes sont dans `Charte/OngletsDuSite.swift` (#30) ;
- `STATUTS_ACCES` et `TYPES_ACCES` (`types-acces.ts`) ;
- l'état d'un bail (`parAttribut` de `bail.ts`) ;
- `TYPES_PRESTATAIRE` et `FILTRES_CONTRAT` (`prestataires.ts`).

→ `CoproFirst/Fonctions/Acces/Genere/TablesAcces.swift` et
`CoproFirst/Fonctions/Prestataires/Genere/TablesPrestataires.swift`.
"""

from __future__ import annotations

import re

import lecture_ts
from generateurs._commun import FONCTIONS, chaine, ecrire_table

SOURCES = [
    "front/src/lib/pages.ts",
    "front/src/lib/types-acces.ts",
    "front/src/lib/bail.ts",
    "front/src/lib/prestataires.ts",
]


def lire(ctx, nom: str) -> str:
    return ctx.lire(f"front/src/lib/{nom}")


def objet_par_attribut(texte: str, nom: str) -> dict:
    """L'objet littéral passé à `parAttribut({...})` dans `const <nom> = parAttribut(`."""
    m = re.search(rf"\bconst {re.escape(nom)}\s*=\s*parAttribut\(", texte)
    if not m:
        raise SystemExit(f"❌ {nom} = parAttribut(...) introuvable")
    # Le lecteur de littéraux de lecture_ts (tableaux et objets) : mêmes règles que `table`.
    return lecture_ts._Lecteur(lecture_ts._jetons(texte[m.end():])).objet()


def page(ctx, identifiant: str) -> dict:
    return next(p for p in lecture_ts.table(lire(ctx, "pages.ts"), "PAGES") if p["id"] == identifiant)


def descriptifs(ctx, identifiant: str) -> str:
    """Le descriptif de chaque onglet de la page (`pages.ts`). Les onglets eux-mêmes —
    libellé, ordre, réserve — sont générés une fois pour toute l'app :
    `Charte/OngletsDuSite.swift` (#30)."""
    lignes = "".join(
        f"        {chaine(o['id'])}: {chaine(o.get('descriptif', ''))},\n" for o in page(ctx, identifiant)["onglets"])
    return (
        f"    /// Le descriptif de chaque onglet de la page `{identifiant}` (texte du site, parfois HTML).\n"
        "    static let descriptifs: [String: String] = [\n" + lignes + "    ]\n"
    )


def teintes(nom: str, entrees: list[tuple[str, str, str]], doc: str) -> str:
    lignes = "".join(f"        {chaine(c)}: LibelleTeinte({chaine(l)}, {chaine(b)}),\n" for c, l, b in entrees)
    return f"    /// {doc}\n    static let {nom}: [String: LibelleTeinte] = [\n{lignes}    ]\n"


def acces(ctx) -> str:
    texte = lire(ctx, "types-acces.ts")
    statuts = [(s["val"], s["label"], s["badge"]) for s in lecture_ts.table(texte, "STATUTS_ACCES")]
    types = "".join(
        f"        ({chaine(t['val'])}, {chaine(t['label'])}),\n" for t in lecture_ts.table(texte, "TYPES_ACCES"))
    bail = objet_par_attribut(lire(ctx, "bail.ts"), "ETAT")
    return (
        descriptifs(ctx, "mon-lot")
        + teintes("statutsAcces", statuts, "L'état d'un badge ou d'une télécommande (`STATUTS_ACCES`).")
        + "    /// Les deux familles d'accès, dans l'ordre du site (`TYPES_ACCES`).\n"
        "    static let typesAcces: [(code: String, libelle: String)] = [\n" + types + "    ]\n"
        + teintes("statutsBail", [(c, v["libelle"], v["badge"]) for c, v in bail.items()],
                  "L'état d'un bail (`ETAT` de `bail.ts`).")
    )


def prestataires(ctx) -> str:
    texte = lire(ctx, "prestataires.ts")
    types = "".join(
        f"        TypePrestataire(code: {chaine(t['val'])}, libelle: {chaine(t['label'])}, "
        f"description: {chaine(t['desc'])}),\n"
        for t in lecture_ts.table(texte, "TYPES_PRESTATAIRE"))
    filtres = "".join(
        f"        ({chaine(f['val'])}, {chaine(f['label'])}),\n" for f in lecture_ts.table(texte, "FILTRES_CONTRAT"))
    return (
        descriptifs(ctx, "prestataires")
        + "    /// Les catégories de prestataires, dans l'ordre du site (`TYPES_PRESTATAIRE`).\n"
        "    static let types: [TypePrestataire] = [\n" + types + "    ]\n"
        "    /// Le filtre « Contrat » (`FILTRES_CONTRAT`).\n"
        "    static let filtresContrat: [(code: String, libelle: String)] = [\n" + filtres + "    ]\n"
    )


def generer(ctx) -> str:
    ecrire_table(ctx, FONCTIONS / "Acces" / "Genere" / "TablesAcces.swift",
                 "front/src/lib/pages.ts, types-acces.ts, bail.ts", "TablesAcces",
                 "Ce que le site écrit de « Mes lots & accès » et que le contrat ne sert pas.", acces(ctx),
                 lignes_longues=True)
    ecrire_table(ctx, FONCTIONS / "Prestataires" / "Genere" / "TablesPrestataires.swift",
                 "front/src/lib/pages.ts, prestataires.ts", "TablesPrestataires",
                 "Ce que le site écrit de « Prestataires » et que le contrat ne sert pas.", prestataires(ctx),
                 lignes_longues=True)
    return "accès, baux et prestataires"
