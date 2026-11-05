# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les PAGES et leurs ONGLETS, lus dans `PAGES` (`front/src/lib/pages.ts`) et
`PAGES_ROLES` (`pages-roles.ts`) :

- l'ordre par défaut des pages, que `pages_order` de GET /config réordonne — celles de
  `PAGES`, puis celles de `PAGES_ROLES` (Espace CS, Admin, Délégations), comme `PAGES`
  les étale : `PagesOuvertes` (Navigation/) décide ensuite qui les voit (#15)
  → `CoproFirst/Navigation/PagesParDefaut.swift` ;
- chaque onglet, une ligne, que la table de parité doit classer
  → `Parite/ONGLETS-DU-SITE.md` (scripts/verifier-parite.py) ;
- chaque onglet, sa RÉSERVE et qui porte chaque droit (`stores/auth.ts`, `roles.ts`)
  → `CoproFirst/Charte/OngletsDuSite.swift` (#29).

La règle qui combine réserves et droits (`reserveAdmise`, `ongletsOuverts` de
`#lib/onglets-ouverts.ts`) est du code : elle vit, écrite une fois, dans
`CoproFirst/Navigation/OngletsOuverts.swift`. Une réserve que l'app ne connaît pas fait
échouer la génération — jamais un onglet ouvert par défaut.
"""

from __future__ import annotations

import pathlib
import re

import lecture_ts
from generateurs._commun import CHARTE, NAVIGATION, tables_des_pages

SOURCES = [
    "front/src/lib/pages.ts",
    "front/src/lib/pages-roles.ts",
    "front/src/lib/archives.ts",
    "front/src/lib/stores/auth.ts",
    "front/src/lib/roles.ts",
]

RESERVES = ("proprioOuCS", "nonLocataire", "operateur", "nonGestionnaire")


def _bloc(texte: str, debut: str) -> str:
    """Le texte d'une déclaration, de `debut` jusqu'au premier `;` hors chaîne."""
    i = texte.index(debut)
    return texte[i : texte.index(";", i)]


def _roles(auth: str, derivee: str) -> list[str]:
    """Les rôles qu'une dérivée de `stores/auth.ts` passe à `aRole`."""
    bloc = _bloc(auth, f"export const {derivee} = derived(")
    m = re.search(r"aRole\(\$u,([^)]*)\)", bloc)
    if not m:
        raise SystemExit(f"❌ {derivee} : appel à aRole introuvable dans stores/auth.ts")
    return re.findall(r"'([^']+)'", m.group(1))


def _statuts(roles_ts: str, fonction: str) -> list[str]:
    """Les statuts qu'une fonction de `roles.ts` compare par `statutDe(p) === '…'`."""
    bloc = _bloc(roles_ts, f"export const {fonction} = ")
    statuts = re.findall(r"statutDe\(p\) === '([^']+)'", bloc)
    if not statuts:
        raise SystemExit(f"❌ {fonction} : comparaison de statut introuvable dans roles.ts")
    return statuts


def _constante(lib: pathlib.Path, nom: str) -> str:
    """Le texte d'une constante de libellé (`TITRE_ARCHIVES`), pictogramme retiré."""
    for fichier in sorted(lib.glob("*.ts")):
        m = re.search(rf"export const {nom} = [`'](.*?)[`'];", fichier.read_text(encoding="utf-8"))
        if m:
            return re.sub(r"^\$\{[A-Z_]+\}\s*", "", m.group(1))
    raise SystemExit(f"❌ constante de libellé {nom} introuvable dans front/src/lib")


def _libelle(lib: pathlib.Path, label) -> str:
    if isinstance(label, lecture_ts.Identifiant):
        label = _constante(lib, label)
    return re.sub(r"^[^\w«(]+", "", label or "").strip().replace('"', '\\"')


def _admin_seul(auth: str) -> tuple[list[str], list[str]]:
    """`isAdminOnly` de `stores/auth.ts` : les rôles qu'il exige (`aRole`), puis ceux qui
    l'annulent (`!aRole`, réunis) — « le compte technique de l'installation »."""
    bloc = _bloc(auth, "export const isAdminOnly = derived(")
    exiges = re.findall(r"(?<!!)aRole\(\$u,([^)]*)\)", bloc)
    annules = re.findall(r"!aRole\(\$u,([^)]*)\)", bloc)
    if len(exiges) != 1 or not annules:
        raise SystemExit("❌ isAdminOnly : forme inattendue dans stores/auth.ts — l'app doit l'apprendre")
    return re.findall(r"'([^']+)'", exiges[0]), [r for a in annules for r in re.findall(r"'([^']+)'", a)]


def _ensemble(valeurs: list[str]) -> str:
    return "[" + ", ".join(f'"{v}"' for v in valeurs) + "]"


def _swift(front: pathlib.Path, pages: list[dict]) -> tuple[str, int]:
    """Le corps Swift (sans en-tête) et le nombre d'onglets."""
    lib = front / "src" / "lib"
    auth = (lib / "stores" / "auth.ts").read_text(encoding="utf-8")
    roles_ts = (lib / "roles.ts").read_text(encoding="utf-8")
    lignes, reservees, n = [], [], 0
    for page in pages:
        if page.get("reserveeAdmin"):
            reservees.append(page["id"])
        onglets = page.get("onglets") or []
        if not onglets:
            continue
        lignes.append(f'        "{page["id"]}": [\n')
        for o in onglets:
            reserve = o.get("reserve")
            if reserve is not None and reserve not in RESERVES:
                raise SystemExit(f"❌ réserve inconnue « {reserve} » ({page['id']}/{o['id']}) — l'app doit l'apprendre")
            r = f".{reserve}" if reserve else "nil"
            lignes.append(
                f'            OngletDuSite(id: "{o["id"]}", libelle: "{_libelle(lib, o.get("label"))}", '
                f"reserve: {r}, ouvertOperateur: {'true' if o.get('ouvertOperateur') else 'false'}),\n"
            )
            n += 1
        lignes.append("        ],\n")
    corps = "\n/// Les onglets de chaque page du site, dans leur ordre, avec leur réserve (#29).\n"
    corps += "/// La règle qui en décide l'ouverture : `OngletsDuSite.ouverts` (Navigation/OngletsOuverts.swift).\n"
    corps += "enum OngletsDuSite {\n"
    corps += "    static let parPage: [String: [OngletDuSite]] = [\n" + "".join(lignes) + "    ]\n\n"
    corps += "    /// Les pages de l'administration : un non-administrateur n'y ouvre que les onglets\n"
    corps += "    /// `ouvertOperateur`, s'il est opérateur.\n"
    corps += f"    static let pagesReserveesAdmin: Set<String> = {_ensemble(reservees)}\n\n"
    corps += "    /// Qui porte chaque droit : rôles (`aRole` de `stores/auth.ts`), statuts (`roles.ts`).\n"
    corps += f"    static let rolesAdministrateur: Set<String> = {_ensemble(_roles(auth, 'isAdmin'))}\n"
    corps += f"    static let rolesOperateur: Set<String> = {_ensemble(_roles(auth, 'isOperateur'))}\n"
    corps += f"    static let rolesProprioOuCS: Set<String> = {_ensemble(_roles(auth, 'isProprioOuCS'))}\n"
    corps += f"    static let rolesCS: Set<String> = {_ensemble(_roles(auth, 'isCS'))}\n"
    exiges, annules = _admin_seul(auth)
    corps += "    /// `isAdminOnly` : un de ces rôles, et aucun des suivants (le compte technique).\n"
    corps += f"    static let rolesAdminSeul: Set<String> = {_ensemble(exiges)}\n"
    corps += f"    static let rolesSansAdminSeul: Set<String> = {_ensemble(annules)}\n"
    corps += f"    static let statutsLocataire: Set<String> = {_ensemble(_statuts(roles_ts, 'estLocataire'))}\n"
    corps += f"    static let statutsGestionnaire: Set<String> = {_ensemble(_statuts(roles_ts, 'estGestionnaire'))}\n"
    corps += "}\n"
    return corps, n


def pages(ctx) -> int:
    lignes = []
    table, roles = tables_des_pages(ctx.front)
    for p in table + roles:
        if p.get("href") is None:
            continue  # sans entrée de navigation : ni ordonnée, ni dans la barre
        lignes.append(
            f'        PageDeNavigation(id: "{p["id"]}", route: "{p["href"]}", '
            f'libelle: "{p["navLabel"]}", titre: "{p["titre"]}", icone: "{p["icone"]}"),\n'
        )
    corps = ctx.entete("front/src/lib/pages.ts (PAGES) et pages-roles.ts (PAGES_ROLES)")
    corps += "\n/// Les pages de navigation du site, dans l'ordre par défaut ; `pages_order` le remplace.\n"
    corps += "enum PagesParDefaut {\n    static let toutes: [PageDeNavigation] = [\n" + "".join(lignes) + "    ]\n}\n"
    ctx.ecrire(NAVIGATION / "PagesParDefaut.swift", corps)
    return len(lignes)


def libelle_lisible(label) -> str:
    """Le libellé d'un onglet sans son pictogramme ; une constante garde son nom."""
    if isinstance(label, lecture_ts.Identifiant):
        return f"`{label}`"
    return re.sub(r"^[^\w«(]+", "", label or "").strip()


# REUSE-IgnoreStart
def parite(ctx) -> int:
    """Chaque onglet de chaque page du site, une ligne : ce que la table de parité classe."""
    table, roles = tables_des_pages(ctx.front)
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
        f"Source : coprofirst@{ctx.commit}, `front/src/lib/pages.ts` (`PAGES`) et "
        "`pages-roles.ts` (`PAGES_ROLES`).\n\n"
        "Chaque ligne doit être classée dans [PARITE.md](PARITE.md) — "
        "`scripts/verifier-parite.py` refuse sinon. « — » : une page sans onglets.\n\n"
        "| Page | Onglet | Libellé sur le site |\n|---|---|---|\n" + "".join(lignes)
    )
    ctx.ecrire(pathlib.Path("Parite") / "ONGLETS-DU-SITE.md", corps)
    return len(lignes)
# REUSE-IgnoreEnd


def onglets_du_site(ctx) -> int:
    table, roles = tables_des_pages(ctx.front)
    corps, n = _swift(ctx.front, table + roles)
    source = "front/src/lib/pages.ts, pages-roles.ts, stores/auth.ts et roles.ts"
    ctx.ecrire(CHARTE / "OngletsDuSite.swift", ctx.entete(source) + corps)
    return n


def generer(ctx) -> str:
    return f"{pages(ctx)} pages ; {parite(ctx)} onglets à classer ; {onglets_du_site(ctx)} onglets et leurs réserves"
