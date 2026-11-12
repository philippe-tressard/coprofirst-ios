# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""La CHARTE de ce que l'app affiche, hors couleurs — lue dans les tables que le site
publie (`tables-clients.json`) :

- les NATURES du fil : libellé, teinte et pictogramme de chaque type d'élément
  (`naturesDuFil`) → `CoproFirst/Charte/NaturesDuFil.swift` ;
- les STATUTS d'une affaire, leur pastille seule — le libellé est servi, #105
  (`statutsTicket` et ses deux compléments, `statutsTicketHistoriques` et
  `statutsTicketSansCycle`) → `CoproFirst/Charte/StatutsAffaire.swift` ;
- les RÔLES et STATUTS d'un utilisateur (`attributsRole`, `attributsStatut`,
  `libellesHerites`) et les rôles que l'en-tête de l'accueil met en avant
  (`rolesMisEnAvant`) → `CoproFirst/Charte/RolesUtilisateur.swift` ;
- la LISTE BLANCHE du texte riche : balises et attributs (`balisesAdmises`,
  `attributsAdmis`), schémas de lien (`SCHEMAS_URL` de `api/app/utils/html_sur.py`, dont
  `BALISES` doit égaler les balises admises) → `CoproFirst/Charte/BalisesDuSite.swift` (#22) ;
- les MESURES du site que `Mise` confronte aux siennes (`MESURES`, jetons de longueur de
  `jetonsCharte`) → `CoproFirst/Charte/MesuresDuSite.swift` (#85).
"""

from __future__ import annotations

import re

from generateurs._commun import ATTRIBUTS, CHARTE, chaine, dictionnaire, jeton_de, jetons_de_la_charte, propriete
from generateurs._tables import source

# `html_sur.py` est un fichier de l'API : le site ne le publie pas en table (#128).
SOURCES = ["api/app/utils/html_sur.py"]

# Les jetons de longueur du site qu'une mesure de l'app (`Mise`) confronte : jeton → nom
# Swift. Une mesure de `Mise` sans jeton ici est PROPRE À iOS, déclarée dans
# `CoproFirstTests/MesuresTests.swift` (#85).
MESURES = {"radius": "rayon"}
# 1 rem = 16 pt : la racine du site vaut 100 % de la taille du navigateur, 16 px par défaut.
LONGUEUR = re.compile(r"^([0-9]*\.?[0-9]+)(rem|px)$")


def natures_du_fil(ctx) -> list[tuple[str, str, str, str, str]]:
    """`(type, libelle, couleur, fond, icone)` de chaque rubrique de `naturesDuFil`, teintes
    en jetons — lue ici seulement : `pictogrammes.py` en tire les pictogrammes à embarquer."""
    table = ctx.table("naturesDuFil", {str: {"libelle": str, "couleur": str, "fond": str, "icone": str}})
    return [(type_, n["libelle"], jeton_de(n["couleur"], f"naturesDuFil.{type_}.couleur"),
             jeton_de(n["fond"], f"naturesDuFil.{type_}.fond"), n["icone"]) for type_, n in table.items()]


def natures(ctx) -> int:
    trouvees = natures_du_fil(ctx)
    corps = ctx.entete(source("naturesDuFil"))
    corps += "\n/// Ce que le fil montre de chaque type d'élément : libellé, teinte, pictogramme (Lucide).\n"
    corps += "enum NaturesDuFil {\n    static let parType: [String: NatureDuFil] = [\n"
    for type_, libelle, couleur, fond, icone in trouvees:
        corps += (
            f"        {chaine(type_)}: NatureDuFil(libelle: {chaine(libelle)}, couleur: \\.{propriete(couleur)}, "
            f"fond: \\.{propriete(fond)}, icone: {chaine(icone)}),\n"
        )
    corps += "    ]\n}\n"
    ctx.ecrire(CHARTE / "NaturesDuFil.swift", corps)
    return len(trouvees)


def statuts(ctx) -> int:
    """La pastille des statuts du cycle, dans leur ordre, puis de ceux que le site garde hors
    du cycle. Le LIBELLÉ d'un statut est servi (`statut_libelle`, #105) : seule la teinte se
    génère."""
    trouves = [(s["value"], s["badge"]) for s in ctx.table("statutsTicket", [{"value": str, "badge": str}])]
    for complement in ("statutsTicketHistoriques", "statutsTicketSansCycle"):
        trouves += [(code, s["badge"]) for code, s in ctx.table(complement, {str: {"badge": str}}).items()]
    codes = [code for code, _ in trouves]
    if len(set(codes)) != len(codes):
        raise SystemExit(f"❌ un statut d'affaire est décrit deux fois dans les tables du site : {codes}")
    corps = ctx.entete(source("statutsTicket", "statutsTicketHistoriques", "statutsTicketSansCycle"))
    corps += "\n/// La pastille de chaque statut d'une affaire (sa classe `badge-*`), comme le site l'écrit.\n"
    corps += "enum StatutsAffaire {\n    static let pastilles: [String: String] = [\n"
    corps += "".join(f"        {chaine(v)}: {chaine(b)},\n" for v, b in trouves)
    corps += "    ]\n}\n"
    ctx.ecrire(CHARTE / "StatutsAffaire.swift", corps)
    return len(trouves)


def roles(ctx) -> int:
    role, statut = ctx.table("attributsRole", ATTRIBUTS), ctx.table("attributsStatut", ATTRIBUTS)
    herites = ctx.table("libellesHerites", {str: str})
    en_avant = ctx.table("rolesMisEnAvant", [str])
    inconnus = [r for r in en_avant if r not in role]
    if inconnus:
        raise SystemExit(f"❌ rolesMisEnAvant cite des rôles sans libellé : {inconnus}")

    corps = ctx.entete(source("attributsRole", "attributsStatut", "libellesHerites", "rolesMisEnAvant"))
    corps += "\n/// Les libellés des rôles et statuts d'un utilisateur, comme le site les écrit.\n"
    corps += "enum RolesUtilisateur {\n"
    corps += dictionnaire("libellesRole", None, {c: r["libelle"] for c, r in role.items()})
    corps += dictionnaire("libellesStatut", None, {c: s["libelle"] for c, s in statut.items()})
    corps += dictionnaire("libellesHerites", None, herites)
    corps += "    /// Les rôles que l'en-tête de l'accueil ajoute au statut, dans cet ordre.\n"
    corps += "    static let misEnAvant: [String] = [" + ", ".join(chaine(r) for r in en_avant) + "]\n}\n"
    ctx.ecrire(CHARTE / "RolesUtilisateur.swift", corps)
    return len(role) + len(statut)


def balises(ctx) -> int:
    tags, attrs = ctx.table("balisesAdmises", [str]), ctx.table("attributsAdmis", [str])
    html_sur = ctx.lire(SOURCES[0])
    m = re.search(r"^BALISES = frozenset\((.*?)^\)", html_sur, re.S | re.M)
    s = re.search(r"^SCHEMAS_URL = frozenset\(\{(.*?)\}\)", html_sur, re.M)
    if not m or not s:
        raise SystemExit("❌ BALISES ou SCHEMAS_URL introuvable dans api/app/utils/html_sur.py")
    if set(re.findall(r'"([a-z0-9]+)"', m.group(1))) != set(tags):
        raise SystemExit("❌ html_sur.BALISES diverge de la table balisesAdmises — à signaler à coprofirst")
    schemas = sorted(re.findall(r'"([a-z]+)"', s.group(1)))
    if len(tags) < 10 or not schemas:
        raise SystemExit("❌ liste blanche du texte riche illisible")

    def ensemble(valeurs: list[str]) -> str:
        return "[" + ", ".join(chaine(v) for v in valeurs) + "]"

    corps = ctx.entete(f"{source('balisesAdmises', 'attributsAdmis')} et api/app/utils/html_sur.py")
    corps += "\n/// La liste blanche du texte riche du site : ce que l'app rend, et rien d'autre (#22).\n"
    corps += "enum BalisesDuSite {\n"
    corps += f"    static let balises: Set<String> = {ensemble(tags)}\n"
    corps += f"    static let attributs: Set<String> = {ensemble(attrs)}\n"
    corps += "    /// Les schémas d'un lien touchable (`SCHEMAS_URL`, appliqué par l'API).\n"
    corps += f"    static let schemasDeLien: Set<String> = {ensemble(schemas)}\n}}\n"
    ctx.ecrire(CHARTE / "BalisesDuSite.swift", corps)
    return len(tags)


def mesures(ctx) -> int:
    socle = jetons_de_la_charte(ctx)
    corps = ctx.entete(f"{source('jetonsCharte')} — jetons de longueur")
    corps += "\nimport CoreGraphics\n\n"
    corps += "/// Les mesures du site que l'app confronte aux siennes (`Mise`, #85), en points\n"
    corps += "/// (1 rem = 16 pt). `MesuresTests` refuse un écart non déclaré.\n"
    corps += "enum MesuresDuSite {\n"
    for jeton, nom in MESURES.items():
        m = LONGUEUR.match(socle.get(jeton, ""))
        if not m:
            raise SystemExit(f"❌ --{jeton} introuvable ou hors de rem/px dans jetonsCharte : {socle.get(jeton)!r}")
        points = float(m.group(1)) * (16 if m.group(2) == "rem" else 1)
        corps += f"    /// `--{jeton}: {socle[jeton]}`\n    static let {nom}: CGFloat = {points:g}\n"
    corps += "}\n"
    ctx.ecrire(CHARTE / "MesuresDuSite.swift", corps)
    return len(MESURES)


def generer(ctx) -> str:
    return (
        f"{natures(ctx)} natures du fil ; {statuts(ctx)} statuts ; "
        f"{roles(ctx)} rôles et statuts d'utilisateur ; {balises(ctx)} balises de texte riche ; "
        f"{mesures(ctx)} mesure(s) du site"
    )
