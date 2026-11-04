#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les tables de « Mes lots & accès » et de « Prestataires », GÉNÉRÉES depuis les
sources de coprofirst (#13).

Le contrat d'API ne sert que des CODES (`StatutAcces`, `StatutBail`,
`TypePrestataire`) : les libellés et les teintes vivent dans le front du site. Rien
ne se recopie à la main (garde-fou de `projets.json`) ; ce script les lit :

- les onglets des pages `mon-lot` et `prestataires` (`pages.ts`) ;
- `STATUTS_ACCES` et `TYPES_ACCES` (`types-acces.ts`) ;
- l'état d'un bail (`parAttribut` de `bail.ts`) ;
- `TYPES_PRESTATAIRE` et `FILTRES_CONTRAT` (`prestataires.ts`).

Sorties, dans le dossier de chaque menu (aucune session parallèle n'y touche) :
`CoproFirst/Fonctions/Acces/Genere/TablesAcces.swift` et
`CoproFirst/Fonctions/Prestataires/Genere/TablesPrestataires.swift`.

Les sources se lisent À LA VERSION PUBLIÉE épinglée (`REVISION`, `COPROFIRST_REVISION`
pour une autre), par `git show` : ni `dev`, ni un arbre modifié. Ce script rejoindra
`scripts/generateurs/` quand le dossier existera.

Usage : python3 scripts/generer-acces-prestataires.py [chemin/vers/coprofirst/front]
"""

from __future__ import annotations

import os
import pathlib
import re
import subprocess
import sys

import lecture_ts

RACINE = pathlib.Path(__file__).resolve().parents[1]
RACINE_COPROFIRST = os.environ.get("COPROFIRST_RACINE", "/Volumes/Data/Dev/5hostachy")
FRONT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else f"{RACINE_COPROFIRST}/front")
# La version PUBLIÉE de coprofirst que les installations font tourner.
REVISION = os.environ.get("COPROFIRST_REVISION", "v3.61.0")
SORTIE_ACCES = RACINE / "CoproFirst" / "Fonctions" / "Acces" / "Genere" / "TablesAcces.swift"
SORTIE_PRESTATAIRES = RACINE / "CoproFirst" / "Fonctions" / "Prestataires" / "Genere" / "TablesPrestataires.swift"


def git(*args: str) -> str:
    return subprocess.run(["git", "-C", str(FRONT), *args], capture_output=True, text=True,
                          check=True).stdout


def lire(nom: str) -> str:
    """Un module de `front/src/lib/`, tel qu'il est À LA RÉVISION épinglée."""
    prefixe = git("rev-parse", "--show-prefix").strip()
    return git("show", f"{REVISION}:{prefixe}src/lib/{nom}")


def chaine(valeur) -> str:
    texte = str(valeur).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    return f'"{texte}"'


def sans_pictogramme(libelle: str) -> str:
    return re.sub(r"^[^\w«(]+", "", libelle).strip()


def objet_par_attribut(texte: str, nom: str) -> dict:
    """L'objet littéral passé à `parAttribut({...})` dans `const <nom> = parAttribut(`."""
    m = re.search(rf"\bconst {re.escape(nom)}\s*=\s*parAttribut\(", texte)
    if not m:
        raise SystemExit(f"❌ {nom} = parAttribut(...) introuvable")
    # Le lecteur de littéraux de lecture_ts (tableaux et objets) : mêmes règles que `table`.
    return lecture_ts._Lecteur(lecture_ts._jetons(texte[m.end():])).objet()


def page(identifiant: str) -> dict:
    return next(p for p in lecture_ts.table(lire("pages.ts"), "PAGES") if p["id"] == identifiant)


def onglets(identifiant: str) -> str:
    lignes = [
        f"        OngletDuSite(id: {chaine(o['id'])}, libelle: {chaine(sans_pictogramme(o['label']))}, "
        f"descriptif: {chaine(o.get('descriptif', ''))}),\n"
        for o in page(identifiant)["onglets"]
    ]
    return (
        f"    /// Les onglets de la page `{identifiant}`, leur libellé (sans pictogramme) et leur descriptif.\n"
        "    static let onglets: [OngletDuSite] = [\n" + "".join(lignes) + "    ]\n"
    )


def teintes(nom: str, entrees: list[tuple[str, str, str]], doc: str) -> str:
    lignes = "".join(f"        {chaine(c)}: LibelleTeinte({chaine(l)}, {chaine(b)}),\n" for c, l, b in entrees)
    return f"    /// {doc}\n    static let {nom}: [String: LibelleTeinte] = [\n{lignes}    ]\n"


def acces() -> str:
    texte = lire("types-acces.ts")
    statuts = [(s["val"], s["label"], s["badge"]) for s in lecture_ts.table(texte, "STATUTS_ACCES")]
    types = "".join(
        f"        ({chaine(t['val'])}, {chaine(t['label'])}),\n" for t in lecture_ts.table(texte, "TYPES_ACCES"))
    bail = objet_par_attribut(lire("bail.ts"), "ETAT")
    return (
        onglets("mon-lot")
        + teintes("statutsAcces", statuts, "L'état d'un badge ou d'une télécommande (`STATUTS_ACCES`).")
        + "    /// Les deux familles d'accès, dans l'ordre du site (`TYPES_ACCES`).\n"
        "    static let typesAcces: [(code: String, libelle: String)] = [\n" + types + "    ]\n"
        + teintes("statutsBail", [(c, v["libelle"], v["badge"]) for c, v in bail.items()],
                  "L'état d'un bail (`ETAT` de `bail.ts`).")
    )


def prestataires() -> str:
    texte = lire("prestataires.ts")
    types = "".join(
        f"        TypePrestataire(code: {chaine(t['val'])}, libelle: {chaine(t['label'])}, "
        f"description: {chaine(t['desc'])}),\n"
        for t in lecture_ts.table(texte, "TYPES_PRESTATAIRE"))
    filtres = "".join(
        f"        ({chaine(f['val'])}, {chaine(f['label'])}),\n" for f in lecture_ts.table(texte, "FILTRES_CONTRAT"))
    return (
        onglets("prestataires")
        + "    /// Les catégories de prestataires, dans l'ordre du site (`TYPES_PRESTATAIRE`).\n"
        "    static let types: [TypePrestataire] = [\n" + types + "    ]\n"
        "    /// Le filtre « Contrat » (`FILTRES_CONTRAT`).\n"
        "    static let filtresContrat: [(code: String, libelle: String)] = [\n" + filtres + "    ]\n"
    )


# L'en-tête que le script ÉCRIT : une chaîne, pas la déclaration de ce script.
# REUSE-IgnoreStart
def entete(provenance: str, sources: str) -> str:
    return (
        "// GÉNÉRÉ par scripts/generer-acces-prestataires.py — NE PAS MODIFIER À LA MAIN.\n"
        "// SPDX-FileCopyrightText: 2026 Philippe TRESSARD\n"
        "// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore\n"
        "//\n"
        "// swift-format-ignore-file\n"
        "// swiftlint:disable line_length\n"
        f"// Source : {provenance}\n"
        f"//   {sources}\n"
    )


# REUSE-IgnoreEnd


def ecrire(sortie: pathlib.Path, provenance: str, sources: str, nom: str, doc: str, corps: str) -> None:
    texte = (entete(provenance, sources) + f"\n/// {doc}\nenum {nom} {{\n" + corps
             + "}\n// swiftlint:enable line_length\n")
    sortie.parent.mkdir(parents=True, exist_ok=True)
    with open(sortie, "w", encoding="utf-8", newline="\n") as f:
        f.write(texte)
    print(f"✅ {provenance} → {sortie.relative_to(RACINE)}")


def main() -> None:
    commit = git("rev-parse", f"{REVISION}^{{commit}}").strip()
    provenance = f"philippe-tressard/coprofirst {REVISION} (commit {commit}),"
    ecrire(SORTIE_ACCES, provenance, "front/src/lib/pages.ts, types-acces.ts, bail.ts.", "TablesAcces",
           "Ce que le site écrit de « Mes lots & accès » et que le contrat ne sert pas.", acces())
    ecrire(SORTIE_PRESTATAIRES, provenance, "front/src/lib/pages.ts, prestataires.ts.", "TablesPrestataires",
           "Ce que le site écrit de « Prestataires » et que le contrat ne sert pas.", prestataires())


if __name__ == "__main__":
    main()
