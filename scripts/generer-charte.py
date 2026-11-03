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
  `pages_order` de GET /config réordonne → `CoproFirst/Navigation/PagesParDefaut.swift` ;
- les STATUTS d'une affaire, libellé et pastille (`STATUTS_TICKET` et ses deux
  compléments de `front/src/lib/tickets.ts`) → `CoproFirst/Charte/StatutsAffaire.swift` ;
- les RÔLES et STATUTS d'un utilisateur (`ROLE`, `STATUT`, `LIBELLES_HERITES` de
  `front/src/lib/roles.ts`) et les rôles que l'en-tête de l'accueil met en avant
  (`EnteteAccueil.svelte`) → `CoproFirst/Charte/RolesUtilisateur.swift` ;
- les ONGLETS de chaque page du site (`PAGES` et `PAGES_ROLES`), que la table de
  parité doit tous classer → `Parite/ONGLETS-DU-SITE.md` (scripts/verifier-parite.py).

`GET /config/palettes` sert les mêmes couleurs, mais à l'administrateur seul :
l'app, qui colore l'écran de connexion, ne peut pas le lire (coprofirst#2460).

Usage : python3 scripts/generer-charte.py [chemin/vers/coprofirst/front]
  Sans argument : $COPROFIRST_RACINE/front — le clone de coprofirst du poste
  (défaut : /Volumes/Data/Dev/5hostachy).
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
        "// swift-format-ignore-file\n"
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


def tables_des_pages() -> tuple[list[dict], list[dict]]:
    """`PAGES` (sans l'étalement `...PAGES_ROLES`) et `PAGES_ROLES`, lues par lecture_ts."""
    lib = FRONT / "src" / "lib"
    return (lecture_ts.table((lib / "pages.ts").read_text(encoding="utf-8"), "PAGES"),
            lecture_ts.table((lib / "pages-roles.ts").read_text(encoding="utf-8"), "PAGES_ROLES"))


def pages(commit: str) -> int:
    lignes = []
    for p in tables_des_pages()[0]:
        if p.get("href") is None:
            continue  # sans entrée de navigation : ni ordonnée, ni dans la barre
        lignes.append(
            f'        PageDeNavigation(id: "{p["id"]}", route: "{p["href"]}", '
            f'libelle: "{p["navLabel"]}", titre: "{p["titre"]}", icone: "{p["icone"]}"),\n'
        )
    corps = entete("front/src/lib/pages.ts (PAGES)", commit)
    corps += "\n/// Les pages de navigation du site, dans l'ordre par défaut ; `pages_order` le remplace.\n"
    corps += "enum PagesParDefaut {\n    static let toutes: [PageDeNavigation] = [\n" + "".join(lignes) + "    ]\n}\n"
    ecrire(NAVIGATION / "PagesParDefaut.swift", corps)
    return len(lignes)


def statuts(commit: str) -> int:
    texte = (FRONT / "src" / "lib" / "tickets.ts").read_text(encoding="utf-8")
    debut = texte.index("export const STATUTS_TICKET")
    fin = texte.index("export const STATUT_TICKET_LABELS", debut)
    table = texte[debut:fin]
    trouves = re.findall(r"value: '([^']+)',\s*label: '([^']+)',.*?badge: '([^']+)'", table, re.S)
    trouves += re.findall(r"\n\t([^\s:]+): \{ label: '([^']+)', badge: '([^']+)' \}", table)
    if len(trouves) < 6:
        raise SystemExit("❌ STATUTS_TICKET introuvable dans tickets.ts")
    corps = entete("front/src/lib/tickets.ts (STATUTS_TICKET et compléments)", commit)
    corps += "\n/// Le libellé et la pastille de chaque statut d'une affaire, comme le site les écrit.\n"
    corps += "enum StatutsAffaire {\n    static let parCode: [String: (libelle: String, pastille: String)] = [\n"
    corps += "".join(f'        "{v}": ("{l}", "{b}"),\n' for v, l, b in trouves)
    corps += "    ]\n}\n"
    ecrire(CHARTE / "StatutsAffaire.swift", corps)
    return len(trouves)


def roles(commit: str) -> int:
    lib = FRONT / "src" / "lib"
    texte = (lib / "roles.ts").read_text(encoding="utf-8")

    def table(nom: str) -> list[tuple[str, str]]:
        debut = texte.index(f"const {nom} = parAttribut({{")
        corps = texte[debut : texte.index("\n});", debut)]
        corps = re.sub(r"//[^\n]*", "", corps)
        return re.findall(r"([^\s{:,]+): \{\s*libelle: '([^']+)'", corps)

    herites = texte[texte.index("const LIBELLES_HERITES") :]
    herites = re.findall(r"\n\t([^\s:]+): '([^']+)'", herites[: herites.index("};")])
    accueil = (lib / "components" / "EnteteAccueil.svelte").read_text(encoding="utf-8")
    m = re.search(r"for \(const r of \[([^\]]+)\]\)", accueil)
    if not m:
        raise SystemExit("❌ rôles mis en avant introuvables dans EnteteAccueil.svelte")
    en_avant = re.findall(r"'([^']+)'", m.group(1))
    role, statut = table("ROLE"), table("STATUT")
    if len(role) < 4 or len(statut) < 4:
        raise SystemExit("❌ tables ROLE / STATUT introuvables dans roles.ts")

    def dico(nom: str, paires: list[tuple[str, str]]) -> str:
        return f"    static let {nom}: [String: String] = [\n" + "".join(
            f'        "{c}": "{l}",\n' for c, l in paires) + "    ]\n"

    corps = entete("front/src/lib/roles.ts et components/EnteteAccueil.svelte", commit)
    corps += "\n/// Les libellés des rôles et statuts d'un utilisateur, comme le site les écrit.\n"
    corps += "enum RolesUtilisateur {\n"
    corps += dico("libellesRole", role) + dico("libellesStatut", statut) + dico("libellesHerites", herites)
    corps += "    /// Les rôles que l'en-tête de l'accueil ajoute au statut, dans cet ordre.\n"
    corps += "    static let misEnAvant: [String] = [" + ", ".join(f'"{r}"' for r in en_avant) + "]\n}\n"
    ecrire(CHARTE / "RolesUtilisateur.swift", corps)
    return len(role) + len(statut)


def libelle_lisible(label) -> str:
    """Le libellé d'un onglet sans son pictogramme ; une constante garde son nom."""
    if isinstance(label, lecture_ts.Identifiant):
        return f"`{label}`"
    return re.sub(r"^[^\w«(]+", "", label or "").strip()


# REUSE-IgnoreStart
def parite(commit: str) -> int:
    """Chaque onglet de chaque page du site, une ligne : ce que la table de parité classe."""
    table, roles = tables_des_pages()
    lignes = []
    for p in table + roles:
        onglets = p.get("onglets") or []
        if not onglets:
            lignes.append(f"| `{p['id']}` | — | {p.get('titre') or p.get('nom')} |\n")
        for o in onglets:
            lignes.append(f"| `{p['id']}` | `{o['id']}` | {libelle_lisible(o.get('label'))} |\n")
    corps = (
        "<!--\nSPDX-FileCopyrightText: 2026 Philippe TRESSARD\n"
        "SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore\n-->\n\n"
        "# Les onglets du site\n\n"
        "GÉNÉRÉ par `scripts/generer-charte.py` — NE PAS MODIFIER À LA MAIN.\n"
        f"Source : coprofirst@{commit}, `front/src/lib/pages.ts` (`PAGES`) et "
        "`pages-roles.ts` (`PAGES_ROLES`).\n\n"
        "Chaque ligne doit être classée dans [PARITE.md](PARITE.md) — "
        "`scripts/verifier-parite.py` refuse sinon. « — » : une page sans onglets.\n\n"
        "| Page | Onglet | Libellé sur le site |\n|---|---|---|\n" + "".join(lignes)
    )
    ecrire(RACINE / "Parite" / "ONGLETS-DU-SITE.md", corps)
    return len(lignes)
# REUSE-IgnoreEnd


def main() -> None:
    commit = subprocess.run(["git", "-C", str(FRONT), "rev-parse", "--short=9", "HEAD"],
                            capture_output=True, text=True, check=True).stdout.strip()
    codes = palettes(commit)
    n_natures = natures(commit)
    n_pages = pages(commit)
    n_statuts = statuts(commit)
    n_roles = roles(commit)
    n_onglets = parite(commit)
    print(
        f"✅ coprofirst@{commit} : palettes {', '.join(codes)} ; {n_natures} natures du fil ; "
        f"{n_pages} pages ; {n_statuts} statuts ; {n_roles} rôles et statuts d'utilisateur ; "
        f"{n_onglets} onglets à classer"
    )


if __name__ == "__main__":
    main()
