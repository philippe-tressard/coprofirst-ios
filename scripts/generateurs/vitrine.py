# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""La copie EMBARQUÉE du contenu de la vitrine (#51) : `site/contenu.json` de
coprofirst-site, à un commit épinglé → `CoproFirst/Entree/Contenu/Genere/ContenuEmbarque.swift`.

L'app lit https://coprofirst.fr/contenu.json et en garde la dernière lecture en cache ;
cette copie sert au premier lancement et hors ligne. Elle ne vient pas de coprofirst
(`SOURCES` est vide) : `ctx.lire_site` la lit au commit `COMMIT`, immuable comme une
étiquette — la concordance la régénère donc à l'identique, quel que soit le plancher.

Le commit ne monte que par décision, comme le plancher : on change `COMMIT` (un commit
de la branche principale de coprofirst-site), puis `python3 scripts/generer.py`, et
le test `ContenuVitrineTests` dit si la copie porte encore chaque `id` dont l'app
dépend (`ContenuVitrine.idsRequis`).

Le JSON est réécrit sans en changer une valeur : l'en-tête sur une ligne, puis une
section par ligne, pour qu'un diff dise quelle section a changé.
"""

from __future__ import annotations

import json
import pathlib

from generateurs._commun import ecrire_table

SOURCES: list[str] = []
COMMIT = "e5e18b3969035702dc0fdc0c3ade255d6095fc38"
RAISON = "le contenu que coprofirst.fr sert le 08/11/2026, coprofirst-site#60"
CHEMIN = "site/contenu.json"
# Le format que l'app sait lire (`ContenuDuSite.formatConnu`) : un autre est refusé ici.
FORMAT_CONNU = 1
SORTIE = pathlib.Path("CoproFirst/Entree/Contenu/Genere/ContenuEmbarque.swift")


def une_section_par_ligne(donnees: dict) -> str:
    """Le même JSON : l'en-tête sur une ligne, puis une section par ligne."""
    tete = {cle: valeur for cle, valeur in donnees.items() if cle != "sections"}
    compact = json.dumps(tete, ensure_ascii=False, separators=(",", ":"))
    lignes = [json.dumps(s, ensure_ascii=False, separators=(",", ":")) for s in donnees["sections"]]
    texte = compact[:-1] + ',"sections":[\n' + ",\n".join(lignes) + "\n]}"
    if json.loads(texte) != donnees:
        raise SystemExit("❌ vitrine : la réécriture du JSON en change le contenu")
    return texte


def litteral_brut(texte: str, retrait: str) -> str:
    """Une chaîne brute Swift sur plusieurs lignes (`#\"\"\"…\"\"\"#`), avec assez de `#`
    pour que rien du texte ne la ferme ni ne s'y lise comme un échappement."""
    dieses = "#"
    while f'"""{dieses}' in texte or f"\\{dieses}" in texte:
        dieses += "#"
    corps = "\n".join(retrait + ligne for ligne in texte.split("\n"))
    return f'{dieses}"""\n{corps}\n{retrait}"""{dieses}'


def generer(ctx) -> str:
    brut = ctx.lire_site(COMMIT, CHEMIN)
    try:
        donnees = json.loads(brut.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as erreur:
        raise SystemExit(f"❌ vitrine : {CHEMIN} illisible au commit {COMMIT} ({erreur})") from erreur
    if donnees.get("format") != FORMAT_CONNU or not isinstance(donnees.get("sections"), list):
        raise SystemExit(f"❌ vitrine : {CHEMIN} n'est pas au format {FORMAT_CONNU} — l'app ne saurait pas le lire")
    texte = une_section_par_ligne(donnees)
    corps = (
        f"    /// `{CHEMIN}` au commit épinglé par `scripts/generateurs/vitrine.py` ({RAISON}).\n"
        f"    static let json = {litteral_brut(texte, '    ')}\n"
    )
    ecrire_table(
        ctx, SORTIE, f"{CHEMIN}", "ContenuEmbarque",
        "Le contenu de la vitrine (coprofirst.fr), embarqué : premier lancement et hors ligne (#51).",
        corps, provenance=ctx.provenance_site(COMMIT))
    ids = [s.get("id") for s in donnees["sections"]]
    return f"{len(ids)} sections ({', '.join(map(str, ids))}), coprofirst-site {COMMIT[:7]}"
