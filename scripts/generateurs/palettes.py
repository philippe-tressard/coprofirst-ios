# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les PALETTES : la charte (`socle.css`, `palette-sombre.css`, palette `seine`) et
chaque palette de `palettes.css`, au clair et au sombre, selon la cascade du site — un
jeton que la palette ne redéfinit pas garde celui de la charte
→ `CoproFirst/Charte/Palette.swift` et `Palette+<code>.swift`.

Une propriété par jeton `--color-*`, `--fil-*` et `--kanban-*` (les teintes des
colonnes du Kanban, #34) ; les autres jetons (`--teinte-*`…) ne servent qu'à résoudre
un `var(--…)`.

`GET /config/palettes` sert les mêmes couleurs, mais à l'administrateur seul : l'app,
qui colore l'écran de connexion, ne peut pas le lire (coprofirst#2460).
"""

from __future__ import annotations

import re

from generateurs._commun import CHARTE, propriete

SOURCES = [
    "front/src/styles/socle.css",
    "front/src/styles/palette-sombre.css",
    "front/src/styles/palettes.css",
]

# Tout jeton se lit (un `var(--teinte-6)` doit se résoudre) ; seuls ces préfixes deviennent
# des propriétés de `Palette`.
JETON = re.compile(r"--([a-z][a-z0-9-]*)\s*:\s*([^;]+);")
EXPOSES = ("color-", "fil-", "kanban-")
HEX = re.compile(r"^#([0-9a-fA-F]{6})$")
RGBA = re.compile(r"^rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([0-9.]+)\s*\)$")
VAR = re.compile(r"^var\(--([a-z][a-z0-9-]*)\)$")


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


def jetons(corps: str) -> dict[str, str]:
    sans = re.sub(r"/\*.*?\*/", "", corps, flags=re.S)
    return {nom: valeur.strip() for nom, valeur in JETON.findall(sans)}


def resoudre(nom: str, table: dict[str, str], vus=()) -> tuple | None:
    """(rouge, vert, bleu, alpha) du jeton dans `table`, ou None s'il n'est pas portable."""
    valeur = table.get(nom)
    if valeur is None or nom in vus:
        return None
    if m := HEX.match(valeur):
        h = int(m.group(1), 16)
        return (h >> 16 & 0xFF, h >> 8 & 0xFF, h & 0xFF, 1.0)
    if m := RGBA.match(valeur):
        return (int(m.group(1)), int(m.group(2)), int(m.group(3)), float(m.group(4)))
    if m := VAR.match(valeur):
        return resoudre(m.group(1), table, (*vus, nom))
    return None


def litteral(c: tuple) -> str:
    r, v, b, a = c
    return f"RVBA(0x{r:02X}, 0x{v:02X}, 0x{b:02X}, {a:g})"


def generer(ctx) -> str:
    socle = jetons(bloc((ctx.front / "src" / "styles" / "socle.css").read_text(encoding="utf-8"), ":root,"))
    sombre = jetons(bloc((ctx.front / "src" / "styles" / "palette-sombre.css").read_text(encoding="utf-8"), ":root[data-theme='dark']"))
    texte = (ctx.front / "src" / "styles" / "palettes.css").read_text(encoding="utf-8")
    codes = ["seine"] + sorted(set(re.findall(r":root\[data-palette='([a-z]+)'\]", texte)))

    # La cascade du site : au clair, la palette sur la charte ; au sombre, la charte
    # sombre par-dessus la palette claire, puis la palette sombre par-dessus tout.
    tables = {}
    for code in codes:
        clair_p = sombre_p = {}
        if code != "seine":
            clair_p = jetons(bloc(texte, f":root[data-palette='{code}'],"))
            sombre_p = jetons(bloc(texte, f":root[data-palette='{code}'][data-theme='dark']"))
        tables[code] = ({**socle, **clair_p}, {**socle, **clair_p, **sombre, **sombre_p})

    # Un jeton n'entre que s'il se résout partout : la structure est la même pour toutes.
    portables = [
        j for j in sorted(socle) if j.startswith(EXPOSES)
        and all(resoudre(j, t) is not None for paire in tables.values() for t in paire)
    ]
    ecartes = sorted(j for j in set(socle) - set(portables) if j.startswith(EXPOSES))

    struct = ctx.entete("front/src/styles/socle.css")
    struct += "// Jetons non portés (color-mix, valeur non littérale) :\n"
    struct += "".join(f"//   --{e}: {socle[e]}\n" for e in ecartes)
    struct += "\nimport SwiftUI\n\n"
    struct += "/// Les couleurs d'une palette de CoproFirst : un jeton `--color-*`, `--fil-*` ou `--kanban-*`\n"
    struct += "/// chacune, claire et sombre. La charte est `seine` ; une résidence choisit la sienne\n"
    struct += "/// (`site_palette`).\n"
    struct += "struct Palette: Sendable {\n    let code: String\n"
    struct += "".join(f"    /// `--{j}`\n    let {propriete(j)}: Color\n" for j in portables)
    struct += "}\n\nextension Palette {\n    /// Toutes les palettes, par code (`site_palette` de GET /config).\n"
    struct += "    static let parCode: [String: Palette] = [\n"
    struct += "".join(f'        "{c}": .{c},\n' for c in codes)
    struct += "    ]\n}\n"
    ctx.ecrire(CHARTE / "Palette.swift", struct)

    for code in codes:
        clair, fonce = tables[code]
        corps = ctx.entete("front/src/styles/socle.css, palette-sombre.css, palettes.css")
        corps += f"\nimport SwiftUI\n\nextension Palette {{\n    static let {code} = Palette(\n"
        corps += f'        code: "{code}",\n'
        corps += ",\n".join(
            f"        {propriete(j)}: Color(clair: {litteral(resoudre(j, clair))}, sombre: {litteral(resoudre(j, fonce))})"
            for j in portables
        )
        corps += "\n    )\n}\n"
        ctx.ecrire(CHARTE / f"Palette+{code.capitalize()}.swift", corps)
    return f"palettes {', '.join(codes)}"
