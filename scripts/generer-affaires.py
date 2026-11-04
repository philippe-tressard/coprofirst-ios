#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les tables du menu Affaires, GÉNÉRÉES depuis les sources de coprofirst (#11).

Le contrat d'API ne sert que des CODES (`CategorieTicket`, `StatutTicket`) : les
libellés, l'ordre et les teintes vivent dans le front du site. Rien ne se recopie
à la main (garde-fou de `projets.json`) ; ce script les lit :

- les CATÉGORIES d'une affaire (`CATEGORIES_TICKET`, `tickets-categories.ts`) et
  ses NATURES (`NATURES`, même fichier) ;
- les COLONNES du Kanban et la colonne de chaque statut (`KANBAN_COLS`,
  `COLONNE_PAR_STATUT_TICKET`, `MOT_COLONNE_VIDE` de `kanban.ts`), leurs teintes
  au clair (`socle.css`) et au sombre (`palette-sombre.css`) ;
- l'ORDRE des statuts, leurs GROUPES de suivi et les statuts CLOS (`tickets.ts`) ;
- les ONGLETS de la page `mes-demandes` et leur réserve (`pages.ts`).

Sortie : `CoproFirst/Fonctions/Affaires/Genere/TablesDuSite.swift` — dans le
dossier du menu, pour qu'aucune session parallèle n'y touche. Script à part de
`generer-charte.py` : relancer celui-ci régénérerait toute la charte.

Usage : python3 scripts/generer-affaires.py [chemin/vers/coprofirst/front]
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
LIB = FRONT / "src" / "lib"
STYLES = FRONT / "src" / "styles"
SORTIE = RACINE / "CoproFirst" / "Fonctions" / "Affaires" / "Genere" / "TablesDuSite.swift"

JETON = re.compile(r"--((?:kanban|teinte)-[a-z0-9-]+)\s*:\s*([^;]+);")
HEX = re.compile(r"^#([0-9a-fA-F]{6})$")
VAR = re.compile(r"^var\(--([a-z0-9-]+)\)$")


def lire(nom: str) -> str:
    return (LIB / nom).read_text(encoding="utf-8")


def bloc(texte: str, selecteur: str) -> str:
    """Le corps du premier bloc dont l'en-tête contient `selecteur`, accolades équilibrées."""
    ouverture = texte.index("{", texte.index(selecteur))
    profondeur = 0
    for i in range(ouverture, len(texte)):
        profondeur += {"{": 1, "}": -1}.get(texte[i], 0)
        if profondeur == 0:
            return texte[ouverture + 1 : i]
    raise ValueError(f"bloc non fermé : {selecteur}")


def jetons(corps: str) -> dict[str, str]:
    sans = re.sub(r"/\*.*?\*/", "", corps, flags=re.S)
    return {nom: valeur.strip() for nom, valeur in JETON.findall(sans)}


def rvba(nom: str, table: dict[str, str], vus: tuple = ()) -> str:
    """Le littéral `RVBA(…)` du jeton, en suivant les `var(--…)` ; échoue sinon."""
    valeur = table.get(nom)
    if valeur is None or nom in vus:
        raise SystemExit(f"❌ jeton --{nom} introuvable ou circulaire")
    if m := HEX.match(valeur):
        h = int(m.group(1), 16)
        return f"RVBA(0x{h >> 16 & 0xFF:02X}, 0x{h >> 8 & 0xFF:02X}, 0x{h & 0xFF:02X}, 1)"
    if m := VAR.match(valeur):
        return rvba(m.group(1), table, (*vus, nom))
    raise SystemExit(f"❌ --{nom} : valeur non portable ({valeur})")


def chaine(valeur) -> str:
    texte = str(valeur).replace("\\", "\\\\").replace('"', '\\"')
    return f'"{texte}"'


def sans_pictogramme(libelle: str) -> str:
    return re.sub(r"^[^\w«(]+", "", libelle).strip()


def booleen(valeur) -> str:
    return "true" if valeur else "false"


def table_simple(texte: str, nom: str) -> dict[str, str]:
    """`export const NOM: Record<string, string> = { cle: 'valeur', … }`."""
    m = re.search(rf"\bconst {nom}\b[^=]*=\s*\{{(.*?)\}};", texte, re.S)
    if not m:
        raise SystemExit(f"❌ {nom} introuvable")
    corps = re.sub(r"//[^\n]*", "", m.group(1))
    return dict(re.findall(r"([\wéèàù]+):\s*'([^']*)'", corps))


def constante(texte: str, nom: str) -> str:
    m = re.search(rf"\bconst {nom}\s*=\s*'([^']*)'", texte)
    if not m:
        raise SystemExit(f"❌ {nom} introuvable")
    return m.group(1)


# L'en-tête que le script ÉCRIT dans le fichier généré : une chaîne, pas la
# déclaration de ce script — REUSE ne doit pas la lire.
# REUSE-IgnoreStart
def entete(provenance: str) -> str:
    # La 1re ligne dit « GÉNÉRÉ » : verifier-depot.sh n'admet de couleur dans Genere/ qu'à ce prix.
    return (
        "// GÉNÉRÉ par scripts/generer-affaires.py — NE PAS MODIFIER À LA MAIN.\n"
        "// SPDX-FileCopyrightText: 2026 Philippe TRESSARD\n"
        "// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore\n"
        "//\n"
        "// swift-format-ignore-file\n"
        "// swiftlint:disable line_length\n"
        f"// Source : {provenance}\n"
        "//   front/src/lib/tickets-categories.ts, kanban.ts, tickets.ts, pages.ts ;\n"
        "//   front/src/styles/socle.css et palette-sombre.css.\n"
    )


# REUSE-IgnoreEnd


def categories() -> str:
    lignes = []
    for c in lecture_ts.table(lire("tickets-categories.ts"), "CATEGORIES_TICKET"):
        lignes.append(
            f"        CategorieAffaire(code: {chaine(c['value'])}, libelle: {chaine(c['label'])}, "
            f"emoji: {chaine(c['emoji'])}, description: {chaine(c['description'])}, "
            f"carnet: {booleen(c.get('carnet'))}, reserveCS: {booleen(c.get('reserveCS'))}, "
            f"enTete: {booleen(c.get('enTete'))}),\n"
        )
    natures = [
        f"        NatureAffaire(code: {chaine(n['val'])}, libelle: {chaine(n['libelle'])}, "
        f"emoji: {chaine(n['emoji'])}),\n"
        for n in lecture_ts.table(lire("tickets-categories.ts"), "NATURES")
    ]
    return (
        "    /// Les catégories, dans l'ordre du site (fréquence attendue) — `CATEGORIES_TICKET`.\n"
        "    static let categories: [CategorieAffaire] = [\n" + "".join(lignes) + "    ]\n"
        "    /// Les natures d'une affaire, dans l'ordre du filtre — `NATURES`.\n"
        "    static let natures: [NatureAffaire] = [\n" + "".join(natures) + "    ]\n"
    )


def kanban() -> str:
    texte = lire("kanban.ts")
    clair = jetons(bloc((STYLES / "socle.css").read_text(encoding="utf-8"), ":root,"))
    sombre = {**clair, **jetons(bloc((STYLES / "palette-sombre.css").read_text(encoding="utf-8"),
                                     ":root[data-theme='dark']"))}
    lignes = []
    for c in lecture_ts.table(texte, "KANBAN_COLS"):
        jeton = VAR.match(c["color"]).group(1)
        lignes.append(
            f"        ColonneKanban(id: {chaine(c['id'])}, libelle: {chaine(c['label'])}, "
            f"libelleCourt: {chaine(c['labelCourt'])},\n"
            f"                      teinte: Color(clair: {rvba(jeton, clair)}, sombre: {rvba(jeton, sombre)})),\n"
        )
    par_statut = table_simple(texte, "COLONNE_PAR_STATUT_TICKET")
    return (
        "    /// Les colonnes du Kanban — ces colonnes SONT le workflow (`KANBAN_COLS`).\n"
        "    static let colonnesKanban: [ColonneKanban] = [\n" + "".join(lignes) + "    ]\n"
        "    /// Statut d'une affaire → sa colonne ; un statut absent sort l'affaire du tableau.\n"
        "    static let colonneParStatut: [String: String] = [\n"
        + "".join(f"        {chaine(s)}: {chaine(c)},\n" for s, c in par_statut.items())
        + "    ]\n"
        f"    /// Ce qu'une colonne vide affiche (`MOT_COLONNE_VIDE`).\n"
        f"    static let colonneVide = {chaine(constante(texte, 'MOT_COLONNE_VIDE'))}\n"
    )


def statuts() -> str:
    texte = lire("tickets.ts")
    ordre = [s["value"] for s in lecture_ts.table(texte, "STATUTS_TICKET")]
    clos = lecture_ts.table(texte, "STATUTS_TICKET_CLOS")
    groupes = [
        f"        GroupeDeSuivi(code: {chaine(g['value'])}, libelle: {chaine(sans_pictogramme(g['label']))}, "
        f"statuts: [{', '.join(chaine(s) for s in g['statuts'])}]),\n"
        for g in lecture_ts.table(texte, "GROUPES_SUIVI")
    ]
    return (
        "    /// Les statuts du cycle d'une affaire, dans l'ordre du site (`STATUTS_TICKET`).\n"
        f"    static let ordreDesStatuts: [String] = [{', '.join(chaine(s) for s in ordre)}]\n"
        "    /// Une affaire close ne demande plus de suivi (`STATUTS_TICKET_CLOS`).\n"
        f"    static let statutsClos: Set<String> = [{', '.join(chaine(s) for s in clos)}]\n"
        "    /// Des statuts que le filtre « Suivi » réunit sous une option (`GROUPES_SUIVI`).\n"
        "    static let groupesDeSuivi: [GroupeDeSuivi] = [\n" + "".join(groupes) + "    ]\n"
        f"    /// La catégorie d'une actualité (`CATEGORIE_ACTUALITE`).\n"
        f"    static let categorieActualite = {chaine(constante(texte, 'CATEGORIE_ACTUALITE'))}\n"
    )


def onglets() -> str:
    page = next(p for p in lecture_ts.table(lire("pages.ts"), "PAGES") if p["id"] == "mes-demandes")
    titre_archives = sans_pictogramme(re.sub(r"\$\{[^}]*\}", "", re.search(
        r"\bTITRE_ARCHIVES\s*=\s*`([^`]*)`", lire("archives.ts")).group(1)))
    lignes = []
    for o in page["onglets"]:
        label = o["label"]
        libelle = titre_archives if isinstance(label, lecture_ts.Identifiant) else sans_pictogramme(label)
        reserve = f"{chaine(o['reserve'])}" if o.get("reserve") else "nil"
        lignes.append(f"        OngletAffaires(id: {chaine(o['id'])}, libelle: {chaine(libelle)}, reserve: {reserve}),\n")
    return (
        "    /// Les onglets de la page `mes-demandes`, et la réserve de chacun (`pages.ts`).\n"
        "    static let onglets: [OngletAffaires] = [\n" + "".join(lignes) + "    ]\n"
    )


SOURCES = [
    "src/lib/tickets-categories.ts", "src/lib/kanban.ts", "src/lib/tickets.ts", "src/lib/pages.ts",
    "src/lib/archives.ts", "src/styles/socle.css", "src/styles/palette-sombre.css",
]


def provenance() -> str:
    """Le commit COMPLET de coprofirst, sa branche — et le refus d'un arbre modifié :
    le fichier généré doit répondre à un commit, comme PROVENANCE-OPENAPI.md."""
    def git(*args: str) -> str:
        return subprocess.run(["git", "-C", str(FRONT), *args], capture_output=True, text=True,
                              check=True).stdout.strip()
    sales = git("status", "--porcelain", "--", *SOURCES)
    if sales:
        raise SystemExit(f"❌ sources modifiées dans coprofirst, rien n'est écrit :\n{sales}")
    return f"philippe-tressard/coprofirst@{git('rev-parse', 'HEAD')} (branche {git('branch', '--show-current')}),"


def main() -> None:
    source = provenance()
    corps = entete(source) + "\nimport SwiftUI\n\n/// Ce que le site écrit des affaires et que le contrat ne sert pas.\nenum TablesDuSite {\n"
    # Une ligne par entrée, sans retour : SwiftLint suspend la longueur, puis la rétablit.
    corps += categories() + kanban() + statuts() + onglets() + "}\n// swiftlint:enable line_length\n"
    SORTIE.parent.mkdir(parents=True, exist_ok=True)
    with open(SORTIE, "w", encoding="utf-8", newline="\n") as f:
        f.write(corps)
    print(f"✅ {source} → {SORTIE.relative_to(RACINE)}")


if __name__ == "__main__":
    main()
