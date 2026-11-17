# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les PALETTES : la charte (palette `seine`) et chaque palette du site, au clair et au
sombre, telles que le site les RÉSOUT — `palettesResolues` de `tables-clients.json`
(coprofirst#2754, depuis v3.102.0 ; comparées au rendu du site, 0 écart)
→ `CoproFirst/Charte/Palette.swift` et `Palette+<code>.swift`.

Une propriété par jeton `--color-*`, `--fil-*`, `--kanban-*` (les teintes des
colonnes du Kanban, #34), `--serie-*` et `--palier-*` (les tranches des répartitions du
Reporting, #15), chacun déjà en `#rrggbb` ou `rgba(…)`. Les feuilles de la charte
(`socle.css`, `palette-sombre.css`, `palettes.css`) ne se lisent plus, ni leur cascade ne
se refait ici (#227) : `generer.py` refuse leur retour.

`GET /config/palettes` sert les mêmes couleurs, mais à l'administrateur seul : l'app,
qui colore l'écran de connexion, ne peut pas le lire (coprofirst#2460).
"""

from __future__ import annotations

import re

from generateurs._commun import CHARTE, propriete

SOURCES: list[str] = []  # palettesResolues de tables-clients.json (#227), pas les feuilles du site

EXPOSES = ("color-", "fil-", "kanban-", "serie-", "palier-")
HEX = re.compile(r"^#([0-9a-fA-F]{6})$")
RGBA = re.compile(r"^rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([0-9.]+)\s*\)$")


def couleur(valeur: str) -> tuple | None:
    """(rouge, vert, bleu, alpha) d'une valeur résolue, ou None si elle n'est pas littérale."""
    if m := HEX.match(valeur):
        h = int(m.group(1), 16)
        return (h >> 16 & 0xFF, h >> 8 & 0xFF, h & 0xFF, 1.0)
    if m := RGBA.match(valeur):
        return (int(m.group(1)), int(m.group(2)), int(m.group(3)), float(m.group(4)))
    return None


def litteral(c: tuple) -> str:
    r, v, b, a = c
    return f"RVBA(0x{r:02X}, 0x{v:02X}, 0x{b:02X}, {a:g})"


def generer(ctx) -> str:
    resolues = ctx.table("palettesResolues")
    if not isinstance(resolues, dict) or "seine" not in resolues:
        raise SystemExit("❌ palettesResolues : pas de palette « seine »")
    codes = ["seine"] + sorted(c for c in resolues if c != "seine")
    # Même structure pour toutes : chaque palette porte, au clair et au sombre, les jetons de
    # la charte, chacun littéral. Sinon la table a changé de forme : on s'arrête.
    jetons = sorted(j.removeprefix("--") for j in resolues["seine"].get("clair", {}))
    portables = [j for j in jetons if j.startswith(EXPOSES)]
    tables = {}
    for code in codes:
        paire = tuple(resolues[code].get(mode, {}) for mode in ("clair", "sombre"))
        for mode, table in zip(("clair", "sombre"), paire):
            lus = sorted(j.removeprefix("--") for j in table)
            illisibles = [j for j in portables if couleur(table.get(f"--{j}", "")) is None]
            if lus != jetons or illisibles:
                raise SystemExit(f"❌ palettesResolues : {code}/{mode} n'a pas les jetons de seine, "
                                 f"ou des valeurs non littérales ({', '.join(illisibles[:3])})")
        tables[code] = paire
    if not portables:
        raise SystemExit("❌ palettesResolues : aucun jeton exposé")
    source = ctx.provenance_tables("palettesResolues")

    struct = ctx.entete(source)
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
        corps = ctx.entete(source)
        corps += f"\nimport SwiftUI\n\nextension Palette {{\n    static let {code} = Palette(\n"
        corps += f'        code: "{code}",\n'
        corps += ",\n".join(
            f"        {propriete(j)}: Color(clair: {litteral(couleur(clair['--' + j]))}, "
            f"sombre: {litteral(couleur(fonce['--' + j]))})"
            for j in portables
        )
        corps += "\n    )\n}\n"
        ctx.ecrire(CHARTE / f"Palette+{code.capitalize()}.swift", corps)
    return f"palettes {', '.join(codes)}"
