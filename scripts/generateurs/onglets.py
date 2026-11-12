# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les PAGES et leurs ONGLETS, lus dans la table `pages` que le site publie
(`tables-clients.json` : `PAGES` et `PAGES_ROLES` étalés à leur place, libellés résolus) :

- le TITRE du fil d'activité, la section du tableau de bord que l'app ouvre en premier
  (table `titreFil`) → `PagesParDefaut.titreDuFil` ;
- l'ordre par défaut des pages, que `pages_order` de GET /config réordonne — Espace CS,
  Admin et Délégations compris : `PagesOuvertes` (Navigation/) décide ensuite qui les
  voit (#15) → `CoproFirst/Navigation/PagesParDefaut.swift` ;
- chaque onglet, une ligne, que la table de parité doit classer
  → `Parite/ONGLETS-DU-SITE.md` (scripts/verifier-parite.py) ;
- chaque onglet, sa RÉSERVE et qui porte chaque droit (`rolesDuDroit`, `statutsDuProfil`)
  → `CoproFirst/Charte/OngletsDuSite.swift` (#29).

La règle qui combine réserves et droits (`reserveAdmise`, `ongletsOuverts` de
`#lib/onglets-ouverts.ts`) est du code : elle vit, écrite une fois, dans
`CoproFirst/Navigation/OngletsOuverts.swift`. Une réserve que l'app ne connaît pas fait
échouer la génération — jamais un onglet ouvert par défaut. « Modère » (conseil ou
administration) n'est plus une population de rôles : le serveur le SERT
(`est_moderateur`, contrat 1.25.0), la table ne le publie pas.
"""

from __future__ import annotations

import pathlib

from generateurs._commun import CHARTE, NAVIGATION, SIGNATURE, chaine, pages_du_site, sans_pictogramme
from generateurs._tables import PIECE_JOINTE, source

SOURCES: list[str] = []

RESERVES = ("proprioOuCS", "nonLocataire", "operateur", "nonGestionnaire")
#: Le nom Swift de chaque population, et sa clé dans `rolesDuDroit` puis `statutsDuProfil`.
ROLES = (("rolesAdministrateur", "admin"), ("rolesOperateur", "operateur"), ("rolesProprietaire", "proprietaire"))
ROLES_ADMIN_SEUL = (("rolesAdminSeul", "adminSeul"), ("rolesSansAdminSeul", "sansAdminSeul"))
STATUTS = (("statutsLocataire", "locataire"), ("statutsGestionnaire", "gestionnaire"))


def _ensemble(valeurs: list[str]) -> str:
    return "[" + ", ".join(chaine(v) for v in valeurs) + "]"


def _populations(table: dict[str, list[str]], noms: tuple) -> str:
    return "".join(f"    static let {nom}: Set<String> = {_ensemble(table[cle])}\n" for nom, cle in noms)


def _swift(ctx, pages: list[dict]) -> tuple[str, int]:
    """Le corps Swift (sans en-tête) et le nombre d'onglets."""
    roles = ctx.table("rolesDuDroit", {cle: [str] for _, cle in ROLES + ROLES_ADMIN_SEUL})
    statuts = ctx.table("statutsDuProfil", {cle: [str] for _, cle in STATUTS})
    lignes, reservees, n = [], [], 0
    for page in pages:
        if page.get("reserveeAdmin"):
            reservees.append(page["id"])
        onglets = page.get("onglets") or []
        if not onglets:
            continue
        lignes.append(f"        {chaine(page['id'])}: [\n")
        for o in onglets:
            reserve = o.get("reserve")
            if reserve is not None and reserve not in RESERVES:
                raise SystemExit(f"❌ réserve inconnue « {reserve} » ({page['id']}/{o['id']}) — l'app doit l'apprendre")
            r = f".{reserve}" if reserve else "nil"
            lignes.append(
                f"            OngletDuSite(id: {chaine(o['id'])}, libelle: {chaine(sans_pictogramme(o['label']))}, "
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
    corps += "    /// Qui porte chaque droit : rôles (`ROLES_DU_DROIT`), statuts (`STATUTS_DU_PROFIL`).\n"
    corps += "    /// « Modère » n'est pas ici : le serveur le sert (`est_moderateur`).\n"
    corps += _populations(roles, ROLES)
    corps += "    /// `isAdminOnly` : un de ces rôles, et aucun des suivants (le compte technique).\n"
    corps += _populations(roles, ROLES_ADMIN_SEUL)
    corps += _populations(statuts, STATUTS)
    corps += "}\n"
    return corps, n


def pages(ctx) -> int:
    lignes = []
    for p in pages_du_site(ctx):
        if p["href"] is None:
            continue  # sans entrée de navigation : ni ordonnée, ni dans la barre
        lignes.append(
            f"        PageDeNavigation(id: {chaine(p['id'])}, route: {chaine(p['href'])}, "
            f"libelle: {chaine(p['navLabel'])}, titre: {chaine(p['titre'])}, icone: {chaine(p['icone'])}),\n"
        )
    corps = ctx.entete(source("pages", "titreFil"))
    corps += "\n/// Les pages de navigation du site, dans l'ordre par défaut ; `pages_order` le remplace.\n"
    corps += "enum PagesParDefaut {\n    static let toutes: [PageDeNavigation] = [\n" + "".join(lignes) + "    ]\n"
    corps += "    /// Le titre de la section du tableau de bord que le fil de l'app reprend (`TITRE_FIL`).\n"
    corps += f"    static let titreDuFil = {chaine(ctx.table('titreFil', str))}\n}}\n"
    ctx.ecrire(NAVIGATION / "PagesParDefaut.swift", corps)
    return len(lignes)


# REUSE-IgnoreStart
def parite(ctx) -> int:
    """Chaque onglet de chaque page du site, une ligne : ce que la table de parité classe."""
    lignes = []
    for p in pages_du_site(ctx):
        onglets = p.get("onglets") or []
        if not onglets:
            lignes.append(f"| `{p['id']}` | — | {p['titre']} |\n")
        for o in onglets:
            lignes.append(f"| `{p['id']}` | `{o['id']}` | {sans_pictogramme(o['label'])} |\n")
    corps = (
        "<!--\nSPDX-FileCopyrightText: 2026 Philippe TRESSARD\n"
        "SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore\n-->\n\n"
        "# Les onglets du site\n\n"
        f"{SIGNATURE}\n"
        f"Source : {ctx.provenance}, pièce jointe `{PIECE_JOINTE}` de la release (table `pages`).\n\n"
        "Chaque ligne doit être classée dans [PARITE.md](PARITE.md) — "
        "`scripts/verifier-parite.py` refuse sinon. « — » : une page sans onglets.\n\n"
        "| Page | Onglet | Libellé sur le site |\n|---|---|---|\n" + "".join(lignes)
    )
    ctx.ecrire(pathlib.Path("Parite") / "ONGLETS-DU-SITE.md", corps)
    return len(lignes)
# REUSE-IgnoreEnd


def onglets_du_site(ctx) -> int:
    corps, n = _swift(ctx, pages_du_site(ctx))
    ctx.ecrire(CHARTE / "OngletsDuSite.swift", ctx.entete(source("pages", "rolesDuDroit", "statutsDuProfil")) + corps)
    return n


def generer(ctx) -> str:
    return f"{pages(ctx)} pages ; {parite(ctx)} onglets à classer ; {onglets_du_site(ctx)} onglets et leurs réserves"
