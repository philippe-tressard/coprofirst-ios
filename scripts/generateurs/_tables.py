# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les TABLES que le site publie pour ses clients : `tables-clients.json`, la pièce
jointe de chaque release de coprofirst depuis v3.88.0 (coprofirst#2634, #128).

Jusqu'à v3.87.0, les générateurs retrouvaient ces tables par MOTIF dans les composants
Svelte, les `.ts` et les feuilles de style du site : un fichier déplacé, une constante
renommée, et la génération plantait (#164) — ou pire, lisait autre chose. Le site
publie désormais chaque table telle qu'il l'exécute (`{source, valeur}`), constantes,
gabarits et concaténations déjà résolus ; un générateur la demande par son NOM et dit
la FORME qu'il en attend :

    statuts = ctx.table("statutsAcces", [{"val": str, "label": str, "badge": str}])

Une table absente, ou dont la forme n'est pas celle attendue, ARRÊTE la génération :
jamais une valeur par défaut, jamais une entrée sautée en silence. La forme se dit en
Python, à l'image de la valeur :

- `str`, `int`, `bool` : une valeur de ce type (`True` n'est pas un `int`) ;
- `[forme]` : une liste dont chaque élément a cette forme ;
- `{str: forme}` : un dictionnaire aux clés libres, chaque valeur de cette forme ;
- `{"cle": forme, …}` : un objet qui porte AU MOINS ces clés — une clé de plus est un
  ajout du site, pas une rupture ; `Facultatif(forme)` pour une clé qui peut manquer ;
- `Parmi(forme, …)` : l'une de ces formes (`Parmi(str, None)` : une chaîne ou `null`).

Une table de premier niveau vide est refusée : une liste vidée par erreur côté site ne
doit pas vider un menu de l'app sans bruit.
"""

from __future__ import annotations

import copy

PIECE_JOINTE = "tables-clients.json"

#: Ce que le site ne publie PAS en table et qu'un générateur lit encore dans l'archive de
#: la version, avec sa raison. Tout autre fichier de `front/` déclaré dans les `SOURCES`
#: d'un module arrête la génération (`fichiers_admis`) : une table du site se lit dans
#: `tables-clients.json`, jamais par motif dans une source (#128).
HORS_TABLES: dict[str, str] = {
    "front/src/lib/icones-svg.json": "le catalogue des tracés Lucide : déjà un JSON, hors des tables publiées",
    "front/src/lib/components/BadgeVerdict.svelte": "les teintes du verdict du règlement (#71) : pas de table publiée",
    "front/src/lib/separateurs.ts": "le séparateur des repères d'un extrait (#71) : pas de table publiée",
    "front/src/lib/saisie-affaire.ts": "les choix et libellés de la saisie d'une affaire (#69) : pas de table publiée",
    "front/src/lib/entites/ticket.ts": "les sections du cadre d'une affaire (#69) : pas de table publiée",
}


class Facultatif:
    """Une clé d'objet qui peut manquer ; présente, elle a la forme donnée."""

    def __init__(self, forme) -> None:
        self.forme = forme


class Parmi:
    """L'une de ces formes (`None` : la valeur `null`)."""

    def __init__(self, *formes) -> None:
        self.formes = formes


def _dit(forme) -> str:
    if isinstance(forme, type):
        return forme.__name__
    if forme is None:
        return "null"
    if isinstance(forme, Parmi):
        return " ou ".join(_dit(f) for f in forme.formes)
    return "une liste" if isinstance(forme, list) else "un objet"


def _ecart(valeur, forme, chemin: str) -> str | None:
    """Le premier écart entre `valeur` et `forme`, ou rien."""
    if isinstance(forme, Parmi):
        if any(_ecart(valeur, f, chemin) is None for f in forme.formes):
            return None
        return f"{chemin} : {_dit(forme)} attendu, {valeur!r} lu"
    if forme is None:
        return None if valeur is None else f"{chemin} : null attendu, {valeur!r} lu"
    if isinstance(forme, type):
        # `bool` est un `int` en Python : un `true` ne passe pas pour un nombre.
        juste = isinstance(valeur, forme) and (forme is bool or not isinstance(valeur, bool))
        return None if juste else f"{chemin} : {_dit(forme)} attendu, {valeur!r} lu"
    if isinstance(forme, list):
        if not isinstance(valeur, list):
            return f"{chemin} : une liste attendue, {type(valeur).__name__} lu"
        return next((e for i, v in enumerate(valeur) if (e := _ecart(v, forme[0], f"{chemin}[{i}]"))), None)
    if not isinstance(valeur, dict):
        return f"{chemin} : un objet attendu, {type(valeur).__name__} lu"
    if list(forme) == [str]:
        return next((e for c, v in valeur.items() if (e := _ecart(v, forme[str], f"{chemin}.{c}"))), None)
    for cle, attendue in forme.items():
        facultative = isinstance(attendue, Facultatif)
        if cle not in valeur:
            if facultative:
                continue
            return f"{chemin} : la clé « {cle} » manque"
        ecart = _ecart(valeur[cle], attendue.forme if facultative else attendue, f"{chemin}.{cle}")
        if ecart:
            return ecart
    return None


class Tables:
    """Les tables d'une version publiée, lues par leur nom et jugées sur leur forme."""

    def __init__(self, etiquette: str, entrees: dict[str, dict]) -> None:
        self.etiquette = etiquette
        self._entrees = entrees

    def lire(self, nom: str, forme):
        """La `valeur` de la table `nom` — une copie : un générateur peut la retoucher."""
        origine = f"{PIECE_JOINTE} de {self.etiquette}"
        if nom not in self._entrees:
            raise SystemExit(f"❌ {origine} : la table « {nom} » est absente — l'app doit l'apprendre")
        valeur = self._entrees[nom]["valeur"]
        if isinstance(valeur, (list, dict)) and not valeur:
            raise SystemExit(f"❌ {origine} : la table « {nom} » est vide")
        ecart = _ecart(valeur, forme, nom)
        if ecart:
            raise SystemExit(f"❌ {origine} : forme inattendue — {ecart}")
        return copy.deepcopy(valeur)


def source(*noms: str) -> str:
    """Ce que l'en-tête « GÉNÉRÉ » dit de sa source : la pièce jointe et les tables lues."""
    return f"pièce jointe {PIECE_JOINTE} de la release ({', '.join(noms)})"


def fichiers_admis(module: str, sources: list[str]) -> None:
    """Refuse qu'un module déclare un fichier du front que le site publie en table."""
    for chemin in sources:
        if chemin.startswith("front/") and chemin not in HORS_TABLES:
            raise SystemExit(
                f"❌ generateurs/{module}.py déclare {chemin} : une table du site se lit dans "
                f"{PIECE_JOINTE} (`ctx.table`), jamais par motif dans une source du front (#128). "
                "Un fichier que le site ne publie pas en table se déclare dans `_tables.HORS_TABLES`, avec sa raison")


def autotest() -> None:
    """Dans les deux sens : une forme juste passe, chaque écart est dit."""
    tables = Tables("v0.0.0", {
        "liste": {"source": "x", "valeur": [{"val": "a", "label": "A", "neuf": 1}, {"val": "b", "label": "B"}]},
        "codes": {"source": "x", "valeur": {"a": {"libelle": "A"}, "b": {"libelle": "B", "abrege": "b"}}},
        "duree": {"source": "x", "valeur": 4000},
        "vide": {"source": "x", "valeur": []},
        "lien": {"source": "x", "valeur": [{"href": None}, {"href": "/a"}]},
    })
    justes = [
        ("liste", [{"val": str, "label": str}]),
        ("codes", {str: {"libelle": str, "abrege": Facultatif(str)}}),
        ("duree", int),
        ("lien", [{"href": Parmi(str, None)}]),
    ]
    fautives = [
        ("absente", str),
        ("vide", [str]),
        ("liste", [{"val": str, "badge": str}]),
        ("liste", {str: str}),
        ("codes", {str: {"libelle": int}}),
        ("codes", {str: {"libelle": str, "abrege": Facultatif(int)}}),
        ("duree", str),
        ("duree", bool),
        ("lien", [{"href": str}]),
    ]
    for nom, forme in justes:
        tables.lire(nom, forme)
    for nom, forme in fautives:
        try:
            tables.lire(nom, forme)
        except SystemExit:
            continue
        raise SystemExit(f"❌ autotest des tables : « {nom} » lue malgré une forme fausse ({forme!r})")
    copie = tables.lire("liste", [{"val": str}])
    copie[0]["val"] = "retouchée"
    if tables.lire("liste", [{"val": str}])[0]["val"] != "a":
        raise SystemExit("❌ autotest des tables : une lecture doit rendre une copie")
    fichiers_admis("x", ["api/app/utils/avis.py", "LICENSES/ISC.txt", *HORS_TABLES])
    try:
        fichiers_admis("x", ["front/src/lib/pages.ts"])
    except SystemExit:
        return
    raise SystemExit("❌ autotest des tables : une source du front hors de HORS_TABLES doit être refusée")
