#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""La table de parité, jugée : chaque onglet du site a un état, et l'app dit vrai.

Trois fichiers se confrontent (#10) :

- `Parite/ONGLETS-DU-SITE.md`, GÉNÉRÉ depuis coprofirst (scripts/generer.py) :
  chaque onglet de chaque page du site ;
- `Parite/PARITE.md`, tenu à la main : l'état de chacun — « fait », « prévu »
  (avec son ticket) ou « site seulement » ;
- `CoproFirst/Navigation/RegistreDesMenus.swift` : les menus que l'app sait ouvrir.

Refusé : un onglet du site absent de la table (une page neuve sur le site doit être
classée), une ligne de la table qui n'existe plus sur le site, un état inconnu, un
« prévu » sans ticket, un doublon ; une page dite « fait » que le registre n'ouvre
pas, un menu du registre que le site ne connaît pas ou qu'il réserve au site.

Usage : python3 scripts/verifier-parite.py [--autotest]
Sortie : 0 conforme, 1 refus, 2 INCONNU (un fichier manque ou ne se lit pas).
"""

from __future__ import annotations

import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parents[1]
ONGLETS = RACINE / "Parite" / "ONGLETS-DU-SITE.md"
TABLE = RACINE / "Parite" / "PARITE.md"
REGISTRE = RACINE / "CoproFirst" / "Navigation" / "RegistreDesMenus.swift"

ETATS = ("fait", "prévu", "site seulement")
LIGNE = re.compile(r"^\|\s*`([^`]+)`\s*\|\s*(?:`([^`]+)`|—)\s*\|(.*)\|\s*$")
# Une entrée du registre : `"mes-demandes": AffairesView.self,` — une ligne par menu.
ENTREE = re.compile(r'^\s*"([a-z0-9_-]+)"\s*:\s*[A-Za-z_]\w*\.self\s*,', re.M)


def lignes(texte: str) -> list[tuple[str, str, list[str]]]:
    """Les lignes de tableau `| `page` | `onglet` ou — | … |` : (page, onglet, cellules)."""
    sortie = []
    for brute in texte.splitlines():
        m = LIGNE.match(brute)
        if m:
            cellules = [c.strip() for c in m.group(3).split("|")]
            sortie.append((m.group(1), m.group(2) or "—", cellules))
    return sortie


def juger(onglets: str, table: str, registre: str) -> list[str]:
    """Les refus, en clair ; une liste vide = conforme."""
    refus = []
    site = {(p, o) for p, o, _ in lignes(onglets)}
    if not site:
        return ["ONGLETS-DU-SITE.md ne liste aucun onglet — illisible ?"]
    classes: dict[tuple[str, str], str] = {}
    for page, onglet, cellules in lignes(table):
        cle = (page, onglet)
        etat = cellules[0] if cellules else ""
        ticket = cellules[1] if len(cellules) > 1 else ""
        nom = f"{page} / {onglet}"
        if cle in classes:
            refus.append(f"{nom} : classé deux fois")
        if etat not in ETATS:
            refus.append(f"{nom} : état « {etat} » — attendu {', '.join(ETATS)}")
        if etat == "prévu" and not re.fullmatch(r"#\d+", ticket):
            refus.append(f"{nom} : « prévu » sans ticket (#N)")
        if cle not in site:
            refus.append(f"{nom} : n'existe pas sur le site (ONGLETS-DU-SITE.md) — retirer la ligne")
        classes[cle] = etat
    for cle in sorted(site - classes.keys()):
        refus.append(f"{cle[0]} / {cle[1]} : onglet du site non classé — l'ajouter à PARITE.md")

    menus = ENTREE.findall(registre)
    if not menus:
        refus.append("RegistreDesMenus.swift : aucune entrée lue — format changé ?")
    pages_faites = {p for (p, _), e in classes.items() if e == "fait"}
    for page in sorted(pages_faites - set(menus)):
        refus.append(f"{page} : dit « fait » dans PARITE.md, mais le registre ne l'ouvre pas")
    for page in menus:
        etats = {e for (p, _), e in classes.items() if p == page}
        if not etats:
            refus.append(f"{page} : dans le registre, inconnu de PARITE.md")
        elif etats == {"site seulement"}:
            refus.append(f"{page} : dans le registre, alors que PARITE.md le réserve au site")
    if len(menus) != len(set(menus)):
        refus.append("RegistreDesMenus.swift : un menu inscrit deux fois")
    return refus


def autotest() -> None:
    """Contre-épreuve : chaque refus se déclenche sur le cas qui le mérite."""
    site = "| `a` | — | A |\n| `b` | `x` | X |\n| `b` | `y` | Y |\n"
    bonne = "| `a` | — | fait | | |\n| `b` | `x` | prévu | #3 | |\n| `b` | `y` | site seulement | | |\n"
    registre = '    "a": VueA.self,\n'
    assert juger(site, bonne, registre) == [], juger(site, bonne, registre)
    cas = {
        "non classé": bonne.replace("| `b` | `y` | site seulement | | |\n", ""),
        "n'existe pas": bonne + "| `c` | — | fait | | |\n",
        "état": bonne.replace("site seulement", "plus tard"),
        "sans ticket": bonne.replace("#3", ""),
        "deux fois": bonne + "| `a` | — | fait | | |\n",
    }
    for attendu, table in cas.items():
        assert any(attendu in r for r in juger(site, table, registre)), attendu
    assert any("ne l'ouvre pas" in r for r in juger(site, bonne, '    "b": VueB.self,\n'))
    assert any("réserve au site" in r
               for r in juger(site, bonne.replace("| `b` | `x` | prévu | #3 |", "| `b` | `x` | site seulement | |"),
                              registre + '    "b": VueB.self,\n'))
    assert any("inconnu" in r for r in juger(site, bonne, registre + '    "z": VueZ.self,\n'))
    assert any("aucune entrée" in r for r in juger(site, bonne, "// vide\n"))
    print("✅ verifier-parite : autotest (9 refus déclenchés, cas conforme accepté)")


def main() -> int:
    if "--autotest" in sys.argv:
        autotest()
        return 0
    try:
        textes = [f.read_text(encoding="utf-8") for f in (ONGLETS, TABLE, REGISTRE)]
    except OSError as e:
        print(f"❓ INCONNU : parité non jugée — {e}")
        return 2
    refus = juger(*textes)
    for r in refus:
        print(f"❌ parité : {r}")
    if refus:
        return 1
    etats = [c[0] for _, _, c in lignes(textes[1])]
    print("✅ parité : " + ", ".join(f"{etats.count(e)} {e}" for e in ETATS))
    return 0


if __name__ == "__main__":
    sys.exit(main())
