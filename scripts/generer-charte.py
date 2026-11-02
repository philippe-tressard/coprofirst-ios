#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""La charte et ce qu'en tire l'app, GÉNÉRÉS depuis les sources de coprofirst.

Rien de ce qui suit ne se recopie à la main (garde-fou de `projets.json`) :

- les PALETTES : la charte (`socle.css`, `palette-sombre.css`, palette `seine`)
  et chaque palette de `palettes.css`, au clair et au sombre, selon la cascade
  du site — un jeton que la palette ne redéfinit pas garde celui de la charte ;
  → `CoproFirst/Charte/Palette.swift` et `Palette+<code>.swift` ;
- les NATURES du fil : libellé, teinte et pictogramme de chaque type d'élément,
  lus dans la table `NATURES` de `front/src/lib/flux.ts`
  → `CoproFirst/Charte/NaturesDuFil.swift` ;
- les PAGES et leur ordre par défaut (`PAGES` de `front/src/lib/pages.ts`), que
  `pages_order` de GET /config réordonne → `CoproFirst/Navigation/PagesParDefaut.swift`.

`GET /config/palettes` sert les mêmes couleurs, mais à l'administrateur seul :
l'app, qui colore l'écran de connexion, ne peut pas le lire (coprofirst#2460).

Usage : python3 scripts/generer-charte.py [chemin/vers/coprofirst/front]
"""

from __future__ import annotations

import pathlib
import re
import subprocess
import sys

RACINE = pathlib.Path(__file__).resolve().parents[1]
FRONT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "/Volumes/Data/Dev/5hostachy/front")
STYLES = FRONT / "src" / "styles"
CHARTE = RACINE / "CoproFirst" / "Charte"
NAVIGATION = RACINE / "CoproFirst" / "Navigation"

JETON = re.compile(r"--((?:color|fil)-[a-z0-9-]+)\s*:\s*([^;]+);")
HEX = re.compile(r"^#([0-9a-fA-F]{6})$")
RGBA = re.compile(r"^rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([0-9.]+)\s*\)$")
VAR = re.compile(r"^var\(--((?:color|fil)-[a-z0-9-]+)\)$")


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


def camel(nom: str) -> str:
    morceaux = nom.split("-")
    return morceaux[0] + "".join(m.capitalize() for m in morceaux[1:])


def propriete(jeton: str) -> str:
    """`color-primary` → `primary`, `fil-rouge-fond` → `filRougeFond`."""
    return camel(jeton[len("color-"):]) if jeton.startswith("color-") else camel(jeton)


def litteral(c: tuple) -> str:
    r, v, b, a = c
    return f"RVBA(0x{r:02X}, 0x{v:02X}, 0x{b:02X}, {a:g})"


# L'en-tête que le script ÉCRIT dans chaque fichier généré : une chaîne, pas la
# déclaration de ce script — REUSE ne doit pas la lire.
# REUSE-IgnoreStart
def entete(source: str, commit: str) -> str:
    return (
        "// SPDX-FileCopyrightText: 2026 Philippe TRESSARD\n"
        "// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore\n"
        "//\n"
        "// GÉNÉRÉ par scripts/generer-charte.py — NE PAS MODIFIER À LA MAIN.\n"
        f"// Source : coprofirst@{commit}, {source}.\n"
    )
# REUSE-IgnoreEnd


def ecrire(chemin: pathlib.Path, texte: str) -> None:
    chemin.parent.mkdir(parents=True, exist_ok=True)
    with open(chemin, "w", encoding="utf-8", newline="\n") as f:
        f.write(texte)


def palettes(commit: str) -> list[str]:
    socle = jetons(bloc((STYLES / "socle.css").read_text(encoding="utf-8"), ":root,"))
    sombre = jetons(bloc((STYLES / "palette-sombre.css").read_text(encoding="utf-8"), ":root[data-theme='dark']"))
    texte = (STYLES / "palettes.css").read_text(encoding="utf-8")
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
        j for j in sorted(socle)
        if all(resoudre(j, t) is not None for paire in tables.values() for t in paire)
    ]
    ecartes = sorted(set(socle) - set(portables))

    struct = entete("front/src/styles/socle.css", commit)
    struct += "// Jetons non portés (color-mix, valeur non littérale) :\n"
    struct += "".join(f"//   --{e}: {socle[e]}\n" for e in ecartes)
    struct += "\nimport SwiftUI\n\n"
    struct += "/// Les couleurs d'une palette de CoproFirst : un jeton `--color-*` ou `--fil-*` chacune,\n"
    struct += "/// claire et sombre. La charte est `seine` ; une résidence choisit la sienne (`site_palette`).\n"
    struct += "struct Palette: Sendable {\n    let code: String\n"
    struct += "".join(f"    /// `--{j}`\n    let {propriete(j)}: Color\n" for j in portables)
    struct += "}\n\nextension Palette {\n    /// Toutes les palettes, par code (`site_palette` de GET /config).\n"
    struct += "    static let parCode: [String: Palette] = [\n"
    struct += "".join(f'        "{c}": .{c},\n' for c in codes)
    struct += "    ]\n}\n"
    ecrire(CHARTE / "Palette.swift", struct)

    for code in codes:
        clair, fonce = tables[code]
        corps = entete("front/src/styles/socle.css, palette-sombre.css, palettes.css", commit)
        corps += f"\nimport SwiftUI\n\nextension Palette {{\n    static let {code} = Palette(\n"
        corps += f'        code: "{code}",\n'
        corps += ",\n".join(
            f"        {propriete(j)}: Color(clair: {litteral(resoudre(j, clair))}, sombre: {litteral(resoudre(j, fonce))})"
            for j in portables
        )
        corps += "\n    )\n}\n"
        ecrire(CHARTE / f"Palette+{code.capitalize()}.swift", corps)
    return codes


def natures(commit: str) -> int:
    texte = (FRONT / "src" / "lib" / "flux.ts").read_text(encoding="utf-8")
    trouvees = re.findall(
        r"\n\t([a-z_]+): \{\s*libelle: '([^']*)',\s*couleur: 'var\(--([a-z-]+)\)',"
        r"\s*fond: 'var\(--([a-z-]+)\)',\s*icone: '([^']*)'",
        texte,
    )
    if not trouvees:
        raise SystemExit("❌ table NATURES introuvable dans flux.ts")
    corps = entete("front/src/lib/flux.ts (NATURES)", commit)
    corps += "\n/// Ce que le fil montre de chaque type d'élément : libellé, teinte, pictogramme (Lucide).\n"
    corps += "enum NaturesDuFil {\n    static let parType: [String: NatureDuFil] = [\n"
    for type_, libelle, couleur, fond, icone in trouvees:
        corps += (
            f'        "{type_}": NatureDuFil(libelle: "{libelle}", couleur: \\.{propriete(couleur)}, '
            f'fond: \\.{propriete(fond)}, icone: "{icone}"),\n'
        )
    corps += "    ]\n}\n"
    ecrire(CHARTE / "NaturesDuFil.swift", corps)
    return len(trouvees)


def pages(commit: str) -> int:
    texte = (FRONT / "src" / "lib" / "pages.ts").read_text(encoding="utf-8")
    debut = texte.index("export const PAGES: PageDef[] = [")
    table = texte[debut : texte.index("\n];", debut)]
    lignes = []
    for entree in re.findall(r"\n\t\{\n(.*?)\n\t\}", table, re.S):
        def champ(cle: str) -> str | None:
            m = re.search(rf"^\t\t{cle}: (?:'([^']*)'|null)", entree, re.M)
            return m.group(1) if m else None
        if champ("href") is None:
            continue  # sans entrée de navigation : ni ordonnée, ni dans la barre
        lignes.append(
            f'        PageDeNavigation(id: "{champ("id")}", route: "{champ("href")}", '
            f'libelle: "{champ("navLabel")}", titre: "{champ("titre")}", icone: "{champ("icone")}"),\n'
        )
    corps = entete("front/src/lib/pages.ts (PAGES)", commit)
    corps += "\n/// Les pages de navigation du site, dans l'ordre par défaut ; `pages_order` le remplace.\n"
    corps += "enum PagesParDefaut {\n    static let toutes: [PageDeNavigation] = [\n" + "".join(lignes) + "    ]\n}\n"
    ecrire(NAVIGATION / "PagesParDefaut.swift", corps)
    return len(lignes)


def main() -> None:
    commit = subprocess.run(["git", "-C", str(FRONT), "rev-parse", "--short=9", "HEAD"],
                            capture_output=True, text=True, check=True).stdout.strip()
    codes = palettes(commit)
    n_natures = natures(commit)
    n_pages = pages(commit)
    print(f"✅ coprofirst@{commit} : palettes {', '.join(codes)} ; {n_natures} natures du fil ; {n_pages} pages")


if __name__ == "__main__":
    main()
