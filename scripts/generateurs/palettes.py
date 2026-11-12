# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les PALETTES : la charte (`jetonsCharte`, `jetonsCharteSombre` — la palette `seine`)
et chaque palette (`palettesClaires`, `palettesSombres`), au clair et au sombre, selon
la cascade du site — un jeton que la palette ne redéfinit pas garde celui de la charte
→ `CoproFirst/Charte/Palette.swift` et `Palette+<code>.swift`.

Le site publie ces jetons avec leur TEXTE (`var(--…)`, `color-mix(…)`) dans
`tables-clients.json` : la cascade et la résolution restent ici. Une propriété par jeton
`--color-*`, `--fil-*`, `--kanban-*` (les teintes des colonnes du Kanban, #34),
`--serie-*` et `--palier-*` (les tranches des répartitions du Reporting, #15) ; les
autres jetons (`--teinte-*`…) ne servent qu'à résoudre un `var(--…)`.

`GET /config/palettes` sert les mêmes couleurs, mais à l'administrateur seul : l'app,
qui colore l'écran de connexion, ne peut pas le lire (coprofirst#2460).
"""

from __future__ import annotations

import re

from generateurs._commun import CHARTE, VAR_JETON, jetons, jetons_de_la_charte, propriete
from generateurs._tables import source

SOURCES: list[str] = []

# Tout jeton se lit (un `var(--teinte-6)` doit se résoudre) ; seuls ces préfixes deviennent
# des propriétés de `Palette`.
EXPOSES = ("color-", "fil-", "kanban-", "serie-", "palier-")
# La charte elle-même : la palette que le site applique sans `data-palette`.
CHARTE_DU_SITE = "seine"
HEX = re.compile(r"^#([0-9a-fA-F]{6})$")
RGBA = re.compile(r"^rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([0-9.]+)\s*\)$")


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
    if m := VAR_JETON.match(valeur):
        return resoudre(m.group(1), table, (*vus, nom))
    return None


def litteral(c: tuple) -> str:
    r, v, b, a = c
    return f"RVBA(0x{r:02X}, 0x{v:02X}, 0x{b:02X}, {a:g})"


def cascades(ctx) -> tuple[dict[str, str], dict[str, tuple[dict, dict]]]:
    """La charte, et pour chaque palette ses jetons au clair et au sombre, selon la cascade
    du site : au clair, la palette sur la charte ; au sombre, la charte sombre par-dessus
    la palette claire, puis la palette sombre par-dessus tout."""
    socle = jetons_de_la_charte(ctx)
    sombre = jetons(ctx.table("jetonsCharteSombre", {str: str}))
    claires = ctx.table("palettesClaires", {str: {str: str}})
    sombres = ctx.table("palettesSombres", {str: {str: str}})
    if CHARTE_DU_SITE in claires or set(sombres) != set(claires):
        raise SystemExit("❌ palettesClaires et palettesSombres ne nomment pas les mêmes palettes "
                         f"(hors « {CHARTE_DU_SITE} », la charte) : {sorted(claires)} / {sorted(sombres)}")
    tables = {CHARTE_DU_SITE: (socle, {**socle, **sombre})}
    for code in sorted(claires):
        clair_p, sombre_p = jetons(claires[code]), jetons(sombres[code])
        tables[code] = ({**socle, **clair_p}, {**socle, **clair_p, **sombre, **sombre_p})
    return socle, tables


def generer(ctx) -> str:
    socle, tables = cascades(ctx)
    codes = list(tables)

    # Un jeton n'entre que s'il se résout partout : la structure est la même pour toutes.
    portables = [
        j for j in sorted(socle) if j.startswith(EXPOSES)
        and all(resoudre(j, t) is not None for paire in tables.values() for t in paire)
    ]
    ecartes = sorted(j for j in set(socle) - set(portables) if j.startswith(EXPOSES))

    struct = ctx.entete(source("jetonsCharte"))
    struct += "// Jetons non portés (color-mix, valeur non littérale) :\n"
    struct += "".join(f"//   --{e}: {socle[e]}\n" for e in ecartes)
    struct += "\nimport SwiftUI\n\n"
    struct += "/// Les couleurs d'une palette de CoproFirst : un jeton `--color-*`, `--fil-*`, `--kanban-*`,\n"
    struct += "/// `--serie-*` ou `--palier-*` chacune, claire et sombre. La charte est `seine` ; une\n"
    struct += "/// résidence choisit la sienne (`site_palette`).\n"
    struct += "struct Palette: Sendable {\n    let code: String\n"
    struct += "".join(f"    /// `--{j}`\n    let {propriete(j)}: Color\n" for j in portables)
    struct += "}\n\nextension Palette {\n    /// Toutes les palettes, par code (`site_palette` de GET /config).\n"
    struct += "    static let parCode: [String: Palette] = [\n"
    struct += "".join(f'        "{c}": .{c},\n' for c in codes)
    struct += "    ]\n}\n"
    ctx.ecrire(CHARTE / "Palette.swift", struct)

    for code in codes:
        clair, fonce = tables[code]
        corps = ctx.entete(source("jetonsCharte", "jetonsCharteSombre", "palettesClaires", "palettesSombres"))
        corps += f"\nimport SwiftUI\n\nextension Palette {{\n    static let {code} = Palette(\n"
        corps += f'        code: "{code}",\n'
        corps += ",\n".join(
            f"        {propriete(j)}: Color(clair: {litteral(resoudre(j, clair))}, sombre: {litteral(resoudre(j, fonce))})"
            for j in portables
        )
        corps += "\n    )\n}\n"
        ctx.ecrire(CHARTE / f"Palette+{code.capitalize()}.swift", corps)
    return f"palettes {', '.join(codes)}"
