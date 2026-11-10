# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""La CHARTE de ce que l'app affiche, hors couleurs :

- les NATURES du fil : libellé, teinte et pictogramme de chaque type d'élément, lus
  dans la table `NATURES` de `front/src/lib/flux.ts` → `CoproFirst/Charte/NaturesDuFil.swift` ;
- les STATUTS d'une affaire, libellé et pastille (`STATUTS_TICKET` et ses deux
  compléments de `front/src/lib/tickets.ts`) → `CoproFirst/Charte/StatutsAffaire.swift` ;
- les RÔLES et STATUTS d'un utilisateur (`ROLE`, `STATUT`, `LIBELLES_HERITES` de
  `front/src/lib/roles.ts`) et les rôles que l'en-tête de l'accueil met en avant
  (`EnteteAccueil.svelte`) → `CoproFirst/Charte/RolesUtilisateur.swift` ;
- la LISTE BLANCHE du texte riche : balises et attributs (`ALLOWED_TAGS`,
  `ALLOWED_ATTR` de `front/src/lib/sanitize.ts`), schémas de lien (`SCHEMAS_URL` de
  `api/app/utils/html_sur.py`, dont `BALISES` doit égaler `ALLOWED_TAGS`)
  → `CoproFirst/Charte/BalisesDuSite.swift` (#22).
"""

from __future__ import annotations

import re

import lecture_ts
from generateurs._commun import CHARTE, propriete

SOURCES = [
    "front/src/lib/flux.ts",
    "front/src/lib/tickets.ts",
    "front/src/lib/roles.ts",
    "front/src/lib/components/EnteteAccueil.svelte",
    "front/src/lib/sanitize.ts",
    "api/app/utils/html_sur.py",
]


def natures_du_fil(ctx) -> list[tuple[str, str, str, str, str]]:
    """`(type, libelle, couleur, fond, icone)` de chaque rubrique de `NATURES` (`flux.ts`) —
    lue ici seulement : `pictogrammes.py` en tire les pictogrammes à embarquer."""
    texte = (ctx.front / "src" / "lib" / "flux.ts").read_text(encoding="utf-8")
    trouvees = re.findall(
        r"\n\t([a-z_]+): \{\s*libelle: '([^']*)',\s*couleur: 'var\(--([a-z-]+)\)',"
        r"\s*fond: 'var\(--([a-z-]+)\)',\s*icone: '([^']*)'",
        texte,
    )
    if not trouvees:
        raise SystemExit("❌ table NATURES introuvable dans flux.ts")
    return trouvees


def natures(ctx) -> int:
    trouvees = natures_du_fil(ctx)
    corps = ctx.entete("front/src/lib/flux.ts (NATURES)")
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
    texte = (ctx.front / "src" / "lib" / "tickets.ts").read_text(encoding="utf-8")
    debut = texte.index("export const STATUTS_TICKET")
    fin = texte.index("export const STATUT_TICKET_LABELS", debut)
    table = texte[debut:fin]
    trouves = re.findall(r"value: '([^']+)',\s*label: '([^']+)',.*?badge: '([^']+)'", table, re.S)
    trouves += re.findall(r"\n\t([^\s:]+): \{ label: '([^']+)', badge: '([^']+)' \}", table)
    if len(trouves) < 6:
        raise SystemExit("❌ STATUTS_TICKET introuvable dans tickets.ts")
    corps = ctx.entete("front/src/lib/tickets.ts (STATUTS_TICKET et compléments)")
    corps += "\n/// Le libellé et la pastille de chaque statut d'une affaire, comme le site les écrit.\n"
    corps += "enum StatutsAffaire {\n    static let parCode: [String: (libelle: String, pastille: String)] = [\n"
    corps += "".join(f'        "{v}": ("{l}", "{b}"),\n' for v, l, b in trouves)
    corps += "    ]\n}\n"
    ctx.ecrire(CHARTE / "StatutsAffaire.swift", corps)
    return len(trouves)


def roles(ctx) -> int:
    lib = ctx.front / "src" / "lib"
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

    corps = ctx.entete("front/src/lib/roles.ts et components/EnteteAccueil.svelte")
    corps += "\n/// Les libellés des rôles et statuts d'un utilisateur, comme le site les écrit.\n"
    corps += "enum RolesUtilisateur {\n"
    corps += dico("libellesRole", role) + dico("libellesStatut", statut) + dico("libellesHerites", herites)
    corps += "    /// Les rôles que l'en-tête de l'accueil ajoute au statut, dans cet ordre.\n"
    corps += "    static let misEnAvant: [String] = [" + ", ".join(f'"{r}"' for r in en_avant) + "]\n}\n"
    ctx.ecrire(CHARTE / "RolesUtilisateur.swift", corps)
    return len(role) + len(statut)


def balises(ctx) -> int:
    sanitize = (ctx.front / "src" / "lib" / "sanitize.ts").read_text(encoding="utf-8")
    tags, attrs = (lecture_ts.table(sanitize, nom) for nom in ("ALLOWED_TAGS", "ALLOWED_ATTR"))
    html_sur = (ctx.front.parent / "api" / "app" / "utils" / "html_sur.py").read_text(encoding="utf-8")
    m = re.search(r"^BALISES = frozenset\((.*?)^\)", html_sur, re.S | re.M)
    s = re.search(r"^SCHEMAS_URL = frozenset\(\{(.*?)\}\)", html_sur, re.M)
    if not m or not s:
        raise SystemExit("❌ BALISES ou SCHEMAS_URL introuvable dans api/app/utils/html_sur.py")
    if set(re.findall(r'"([a-z0-9]+)"', m.group(1))) != set(tags):
        raise SystemExit("❌ html_sur.BALISES diverge de sanitize.ts ALLOWED_TAGS — à signaler à coprofirst")
    schemas = sorted(re.findall(r'"([a-z]+)"', s.group(1)))
    if len(tags) < 10 or not schemas:
        raise SystemExit("❌ liste blanche du texte riche illisible")

    def ensemble(valeurs: list[str]) -> str:
        return "[" + ", ".join(f'"{v}"' for v in valeurs) + "]"

    corps = ctx.entete("front/src/lib/sanitize.ts (ALLOWED_TAGS, ALLOWED_ATTR) et api/app/utils/html_sur.py")
    corps += "\n/// La liste blanche du texte riche du site : ce que l'app rend, et rien d'autre (#22).\n"
    corps += "enum BalisesDuSite {\n"
    corps += f"    static let balises: Set<String> = {ensemble(tags)}\n"
    corps += f"    static let attributs: Set<String> = {ensemble(attrs)}\n"
    corps += "    /// Les schémas d'un lien touchable (`SCHEMAS_URL`, appliqué par l'API).\n"
    corps += f"    static let schemasDeLien: Set<String> = {ensemble(schemas)}\n}}\n"
    ctx.ecrire(CHARTE / "BalisesDuSite.swift", corps)
    return len(tags)


def generer(ctx) -> str:
    return (
        f"{natures(ctx)} natures du fil ; {statuts(ctx)} statuts ; "
        f"{roles(ctx)} rôles et statuts d'utilisateur ; {balises(ctx)} balises de texte riche"
    )
