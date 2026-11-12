# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""La CHARTE de ce que l'app affiche, hors couleurs — lue dans `tables-clients.json` de
la release (#128), sauf l'API Python, que le fichier ne publie pas :

- les NATURES du fil : libellé, teinte et pictogramme de chaque type d'élément
  (`naturesDuFil`) → `CoproFirst/Charte/NaturesDuFil.swift` ;
- les STATUTS d'une affaire, leur pastille seule — le libellé est servi, #105
  (`statutsTicket` et ses deux compléments, `statutsTicketHistoriques`,
  `statutsTicketSansCycle`) → `CoproFirst/Charte/StatutsAffaire.swift` ;
- les RÔLES et STATUTS d'un utilisateur (`attributsRole`, `attributsStatut`,
  `libellesHerites`) et les rôles que l'en-tête de l'accueil met en avant
  (`rolesMisEnAvant`) → `CoproFirst/Charte/RolesUtilisateur.swift` ;
- la LISTE BLANCHE du texte riche : balises et attributs (`balisesAdmises`,
  `attributsAdmis`), schémas de lien (`SCHEMAS_URL` de `api/app/utils/html_sur.py`, lu
  par motif, dont `BALISES` doit égaler `balisesAdmises`)
  → `CoproFirst/Charte/BalisesDuSite.swift` (#22) ;
- les MESURES du site que `Mise` confronte aux siennes (`MESURES`, jetons de longueur de
  `jetonsCharte`) → `CoproFirst/Charte/MesuresDuSite.swift` (#85).
"""

from __future__ import annotations

import re

from generateurs._commun import CHARTE, propriete

# Seule l'API Python reste lue dans les sources : `tables-clients.json` ne publie que le front (#128).
SOURCES = ["api/app/utils/html_sur.py"]

# Les jetons de longueur du site qu'une mesure de l'app (`Mise`) confronte : jeton → nom
# Swift. Une mesure de `Mise` sans jeton ici est PROPRE À iOS, déclarée dans
# `CoproFirstTests/MesuresTests.swift` (#85).
MESURES = {"radius": "rayon"}
# 1 rem = 16 pt : la racine du site vaut 100 % de la taille du navigateur, 16 px par défaut.
LONGUEUR = re.compile(r"^([0-9]*\.?[0-9]+)(rem|px)$")


#: La teinte d'une nature du fil : un jeton de la charte, `var(--fil-rouge)`.
JETON = re.compile(r"^var\(--([a-z0-9-]+)\)$")


def _sources(ctx, *noms: str) -> str:
    """L'en-tête « Source : » d'un fichier tiré de tables publiées."""
    return ", ".join(ctx.source_table(nom) for nom in noms) + " (tables-clients.json)"


def natures_du_fil(ctx) -> list[tuple[str, str, str, str, str]]:
    """`(type, libelle, couleur, fond, icone)` de chaque rubrique de `naturesDuFil` —
    lue ici seulement : `pictogrammes.py` en tire les pictogrammes à embarquer."""
    trouvees = []
    for type_, n in ctx.table("naturesDuFil").items():
        couleur, fond = (JETON.match(str(n.get(cle, ""))) for cle in ("couleur", "fond"))
        if not couleur or not fond or not n.get("libelle") or not n.get("icone"):
            raise SystemExit(f"❌ naturesDuFil : la rubrique {type_} n'a pas la forme attendue ({n!r})")
        trouvees.append((type_, n["libelle"], couleur.group(1), fond.group(1), n["icone"]))
    if not trouvees:
        raise SystemExit("❌ naturesDuFil vide dans tables-clients.json")
    return trouvees


def natures(ctx) -> int:
    trouvees = natures_du_fil(ctx)
    corps = ctx.entete(_sources(ctx, "naturesDuFil"))
    corps += "\n/// Ce que le fil montre de chaque type d'élément : libellé, teinte, pictogramme (Lucide).\n"
    corps += "enum NaturesDuFil {\n    static let parType: [String: NatureDuFil] = [\n"
    for type_, libelle, couleur, fond, icone in trouvees:
        corps += (
            f'        "{type_}": NatureDuFil(libelle: "{libelle}", couleur: \\.{propriete(couleur)}, '
            f'fond: \\.{propriete(fond)}, icone: "{icone}"),\n'
        )
    corps += "    ]\n}\n"
    ctx.ecrire(CHARTE / "NaturesDuFil.swift", corps)
    return len(trouvees)


def statuts(ctx) -> int:
    noms = ("statutsTicket", "statutsTicketHistoriques", "statutsTicketSansCycle")
    cycle, historiques, sans_cycle = (ctx.table(nom) for nom in noms)
    trouves = [(s["value"], s["badge"]) for s in cycle]
    trouves += [(v, s["badge"]) for table in (historiques, sans_cycle) for v, s in table.items()]
    if len(trouves) < 6:
        raise SystemExit("❌ statutsTicket : moins de six statuts dans tables-clients.json")
    corps = ctx.entete(_sources(ctx, *noms))
    # Le LIBELLÉ d'un statut est servi (`statut_libelle`, #105) : seule la teinte se génère.
    corps += "\n/// La pastille de chaque statut d'une affaire (sa classe `badge-*`), comme le site l'écrit.\n"
    corps += "enum StatutsAffaire {\n    static let pastilles: [String: String] = [\n"
    corps += "".join(f'        "{v}": "{b}",\n' for v, b in trouves)
    corps += "    ]\n}\n"
    ctx.ecrire(CHARTE / "StatutsAffaire.swift", corps)
    return len(trouves)


def roles(ctx) -> int:
    noms = ("attributsRole", "attributsStatut", "libellesHerites", "rolesMisEnAvant")
    role, statut = ([(c, a["libelle"]) for c, a in ctx.table(nom).items()] for nom in noms[:2])
    herites = list(ctx.table("libellesHerites").items())
    en_avant = ctx.table("rolesMisEnAvant")
    if len(role) < 4 or len(statut) < 4:
        raise SystemExit("❌ attributsRole / attributsStatut : moins de quatre entrées dans tables-clients.json")
    if not en_avant or not all(r in dict(role) for r in en_avant):
        raise SystemExit(f"❌ rolesMisEnAvant : {en_avant!r} n'est pas une liste de rôles d'attributsRole")

    def dico(nom: str, paires: list[tuple[str, str]]) -> str:
        return f"    static let {nom}: [String: String] = [\n" + "".join(
            f'        "{c}": "{l}",\n' for c, l in paires) + "    ]\n"

    corps = ctx.entete(_sources(ctx, *noms))
    corps += "\n/// Les libellés des rôles et statuts d'un utilisateur, comme le site les écrit.\n"
    corps += "enum RolesUtilisateur {\n"
    corps += dico("libellesRole", role) + dico("libellesStatut", statut) + dico("libellesHerites", herites)
    corps += "    /// Les rôles que l'en-tête de l'accueil ajoute au statut, dans cet ordre.\n"
    corps += "    static let misEnAvant: [String] = [" + ", ".join(f'"{r}"' for r in en_avant) + "]\n}\n"
    ctx.ecrire(CHARTE / "RolesUtilisateur.swift", corps)
    return len(role) + len(statut)


def balises(ctx) -> int:
    tags, attrs = ctx.table("balisesAdmises"), ctx.table("attributsAdmis")
    html_sur = ctx.lire(SOURCES[0])
    m = re.search(r"^BALISES = frozenset\((.*?)^\)", html_sur, re.S | re.M)
    s = re.search(r"^SCHEMAS_URL = frozenset\(\{(.*?)\}\)", html_sur, re.M)
    if not m or not s:
        raise SystemExit("❌ BALISES ou SCHEMAS_URL introuvable dans api/app/utils/html_sur.py")
    if set(re.findall(r'"([a-z0-9]+)"', m.group(1))) != set(tags):
        raise SystemExit("❌ html_sur.BALISES diverge de balisesAdmises (ALLOWED_TAGS) — à signaler à coprofirst")
    schemas = sorted(re.findall(r'"([a-z]+)"', s.group(1)))
    if len(tags) < 10 or not schemas:
        raise SystemExit("❌ liste blanche du texte riche illisible")

    def ensemble(valeurs: list[str]) -> str:
        return "[" + ", ".join(f'"{v}"' for v in valeurs) + "]"

    corps = ctx.entete(f"{_sources(ctx, 'balisesAdmises', 'attributsAdmis')} et {SOURCES[0]}")
    corps += "\n/// La liste blanche du texte riche du site : ce que l'app rend, et rien d'autre (#22).\n"
    corps += "enum BalisesDuSite {\n"
    corps += f"    static let balises: Set<String> = {ensemble(tags)}\n"
    corps += f"    static let attributs: Set<String> = {ensemble(attrs)}\n"
    corps += "    /// Les schémas d'un lien touchable (`SCHEMAS_URL`, appliqué par l'API).\n"
    corps += f"    static let schemasDeLien: Set<String> = {ensemble(schemas)}\n}}\n"
    ctx.ecrire(CHARTE / "BalisesDuSite.swift", corps)
    return len(tags)


def mesures(ctx) -> int:
    jetons = ctx.table("jetonsCharte")
    corps = ctx.entete(_sources(ctx, "jetonsCharte") + ", jetons de longueur")
    corps += "\nimport CoreGraphics\n\n"
    corps += "/// Les mesures du site que l'app confronte aux siennes (`Mise`, #85), en points\n"
    corps += "/// (1 rem = 16 pt). `MesuresTests` refuse un écart non déclaré.\n"
    corps += "enum MesuresDuSite {\n"
    for jeton, nom in MESURES.items():
        valeur = jetons.get(f"--{jeton}", "")
        m = LONGUEUR.match(valeur)
        if not m:
            raise SystemExit(f"❌ --{jeton} introuvable ou hors de rem/px dans jetonsCharte : {valeur!r}")
        points = float(m.group(1)) * (16 if m.group(2) == "rem" else 1)
        corps += f"    /// `--{jeton}: {valeur}`\n    static let {nom}: CGFloat = {points:g}\n"
    corps += "}\n"
    ctx.ecrire(CHARTE / "MesuresDuSite.swift", corps)
    return len(MESURES)


def generer(ctx) -> str:
    return (
        f"{natures(ctx)} natures du fil ; {statuts(ctx)} statuts ; "
        f"{roles(ctx)} rôles et statuts d'utilisateur ; {balises(ctx)} balises de texte riche ; "
        f"{mesures(ctx)} mesure(s) du site"
    )
