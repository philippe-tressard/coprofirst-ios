#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les couleurs de la charte, GÉNÉRÉES depuis les sources de coprofirst.

Lit `socle.css` (le thème clair, bloc `:root`) et `palette-sombre.css` (le bloc
`:root[data-theme='dark']`) dans `front/src/styles/` de coprofirst, et écrit
`CoproFirst/Charte/Charte+Couleurs.swift` : une couleur dynamique par jeton
`--color-*`, claire et sombre. Jamais de couleur recopiée à la main
(garde-fou de `projets.json`, coprofirst#2460).

Un jeton absent de la palette sombre y garde sa valeur claire — c'est la règle
de `lint:palette-sombre` (« IDENTIQUE avec sa raison »). Un jeton `var(--x)` est
résolu ; un `color-mix()` n'est pas porté et se liste en tête du fichier.

Usage : python3 scripts/generer-charte.py [chemin/vers/coprofirst/front/src/styles]
"""

from __future__ import annotations

import pathlib
import re
import subprocess
import sys

RACINE = pathlib.Path(__file__).resolve().parents[1]
SORTIE = RACINE / "CoproFirst" / "Charte" / "Charte+Couleurs.swift"
STYLES = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "/Volumes/Data/Dev/5hostachy/front/src/styles")

JETON = re.compile(r"--color-([a-z0-9-]+)\s*:\s*([^;]+);")
HEX = re.compile(r"^#([0-9a-fA-F]{6})$")
RGBA = re.compile(r"^rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([0-9.]+)\s*\)$")
VAR = re.compile(r"^var\(--color-([a-z0-9-]+)\)$")


def bloc(texte: str, selecteur: str) -> str:
    """Le corps du premier bloc dont l'en-tête contient `selecteur`, accolades équilibrées."""
    debut = texte.index(selecteur)
    ouverture = texte.index("{", debut)
    profondeur = 0
    for i in range(ouverture, len(texte)):
        if texte[i] == "{":
            profondeur += 1
        elif texte[i] == "}":
            profondeur -= 1
            if profondeur == 0:
                return texte[ouverture + 1 : i]
    raise ValueError(f"bloc non fermé : {selecteur}")


def sans_commentaires(texte: str) -> str:
    return re.sub(r"/\*.*?\*/", "", texte, flags=re.S)


def jetons(corps: str) -> dict[str, str]:
    return {nom: valeur.strip() for nom, valeur in JETON.findall(sans_commentaires(corps))}


def resoudre(nom: str, table: dict[str, str], repli: dict[str, str] | None = None, vus=()) -> tuple | None:
    """(rouge, vert, bleu, alpha) du jeton, ou None s'il n'est pas portable."""
    valeur = table.get(nom) if nom in table else (repli or {}).get(nom)
    if valeur is None or nom in vus:
        return None
    if m := HEX.match(valeur):
        h = int(m.group(1), 16)
        return (h >> 16 & 0xFF, h >> 8 & 0xFF, h & 0xFF, 1.0)
    if m := RGBA.match(valeur):
        return (int(m.group(1)), int(m.group(2)), int(m.group(3)), float(m.group(4)))
    if m := VAR.match(valeur):
        return resoudre(m.group(1), table, repli, (*vus, nom))
    return None


def nom_swift(nom: str) -> str:
    morceaux = nom.split("-")
    return morceaux[0] + "".join(m.capitalize() for m in morceaux[1:])


def litteral(c: tuple) -> str:
    r, v, b, a = c
    return f"RVBA(0x{r:02X}, 0x{v:02X}, 0x{b:02X}, {a:g})"


def main() -> None:
    socle = (STYLES / "socle.css").read_text(encoding="utf-8")
    sombre = (STYLES / "palette-sombre.css").read_text(encoding="utf-8")
    clair = jetons(bloc(socle, ":root,"))
    fonce = jetons(bloc(sombre, ":root[data-theme='dark']"))

    lignes, ecartes = [], []
    for nom in sorted(clair):
        c = resoudre(nom, clair)
        # Au sombre : la valeur sombre, résolue d'abord dans la palette sombre puis,
        # pour un `var()` vers un jeton qu'elle ne redéfinit pas, dans la claire.
        s = resoudre(nom, {**clair, **fonce})
        if c is None or s is None:
            ecartes.append(f"--color-{nom}: {clair[nom]}")
            continue
        lignes.append(f"    /// `--color-{nom}`\n    static let {nom_swift(nom)} = Color(clair: {litteral(c)}, sombre: {litteral(s)})")

    depot = subprocess.run(["git", "-C", str(STYLES), "rev-parse", "--short=9", "HEAD"],
                           capture_output=True, text=True, check=True).stdout.strip()
    entete = f"""// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// GÉNÉRÉ par scripts/generer-charte.py — NE PAS MODIFIER À LA MAIN.
// Source : coprofirst@{depot}, front/src/styles/socle.css et palette-sombre.css.
// Non portés (color-mix ou valeur non littérale) :
""" + "".join(f"//   {e}\n" for e in ecartes) + """
import SwiftUI

/// Les couleurs de la charte de CoproFirst : une par jeton `--color-*`, claire et sombre.
enum Charte {
"""
    with open(SORTIE, "w", encoding="utf-8", newline="\n") as f:
        f.write(entete + "\n\n".join(lignes) + "\n}\n")
    print(f"✅ {SORTIE.relative_to(RACINE)} : {len(lignes)} couleurs, {len(ecartes)} écartées (coprofirst@{depot})")


if __name__ == "__main__":
    main()
