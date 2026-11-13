# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les PAGES et leurs ONGLETS, lus dans `tables-clients.json` de la release (#128) :

- `pages` (`PAGES` de `front/src/lib/pages.ts`, `PAGES_ROLES` étalées à leur place,
  libellés résolus) : l'ordre par défaut des pages, que `pages_order` de GET /config
  réordonne — `PagesOuvertes` (Navigation/) décide ensuite qui les voit (#15)
  → `CoproFirst/Navigation/PagesParDefaut.swift` ;
- `titreFil` (`TITRE_FIL` de `flux.ts`) : le TITRE du fil d'activité, la section du
  tableau de bord que l'app ouvre en premier → `PagesParDefaut.titreDuFil` ;
- chaque onglet, une ligne, que la table de parité doit classer
  → `Parite/ONGLETS-DU-SITE.md` (scripts/verifier-parite.py) ;
- chaque onglet, sa RÉSERVE, et qui porte chaque droit : `rolesDuDroit`
  (`ROLES_DU_DROIT` de `roles.ts`, que lisent les dérivées de `stores/auth.ts`),
  `statutsDuProfil` (`STATUTS_DU_PROFIL`) → `CoproFirst/Charte/OngletsDuSite.swift` (#29).

Le modérateur (conseil syndical ou administration) n'est plus une liste de rôles : le
serveur le SERT (`est_moderateur`, coprofirst#2633), et `isProprioOuCS` du site est
« un rôle de `proprietaire`, ou modérateur servi ». L'app le lit de même.

La règle qui combine réserves et droits (`reserveAdmise`, `ongletsOuverts` de
`#lib/onglets-ouverts.ts`) est du code : elle vit, écrite une fois, dans
`CoproFirst/Navigation/OngletsOuverts.swift`. Une réserve que l'app ne connaît pas fait
échouer la génération — jamais un onglet ouvert par défaut.
"""

from __future__ import annotations

import pathlib
import re

from generateurs._commun import CHARTE, NAVIGATION, SIGNATURE

SOURCES: list[str] = []  # lu dans tables-clients.json de la release (#128), pas dans les sources

RESERVES = ("proprioOuCS", "nonLocataire", "operateur", "nonGestionnaire")


def _pages(ctx) -> list[dict]:
    """`pages` publiée : une liste de pages, chacune avec son `id`."""
    pages = ctx.table("pages")
    if not isinstance(pages, list) or not all(isinstance(p, dict) and "id" in p for p in pages):
        raise SystemExit("❌ tables-clients.json : « pages » n'est pas une liste de pages — l'app doit l'apprendre")
    return pages


def _liste(ctx, table: str, cle: str) -> list[str]:
    """`table[cle]` publiée, une liste de chaînes non vide."""
    valeur = ctx.table(table)
    liste = valeur.get(cle) if isinstance(valeur, dict) else None
    if not isinstance(liste, list) or not liste or not all(isinstance(v, str) for v in liste):
        raise SystemExit(f"❌ tables-clients.json : {table}.{cle} absente ou de forme inattendue — l'app doit l'apprendre")
    return liste


def _sans_picto(label: str | None) -> str:
    """Le libellé d'un onglet sans son pictogramme de tête."""
    return re.sub(r"^[^\w«(]+", "", label or "").strip()


def _swift_texte(texte: str) -> str:
    return texte.replace('"', '\\"')


def _ensemble(valeurs: list[str]) -> str:
    return "[" + ", ".join(f'"{v}"' for v in valeurs) + "]"


def _swift(ctx, pages: list[dict]) -> tuple[str, int]:
    """Le corps Swift (sans en-tête) et le nombre d'onglets."""
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
                f'            OngletDuSite(id: "{o["id"]}", libelle: "{_swift_texte(_sans_picto(o.get("label")))}", '
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
    corps += "    /// Qui porte chaque droit : rôles (`ROLES_DU_DROIT`, que lit `aRole` de `stores/auth.ts`),\n"
    corps += "    /// statuts (`STATUTS_DU_PROFIL` de `roles.ts`). Le modérateur n'y est pas : il est servi\n"
    corps += "    /// (`est_moderateur`) ; `isProprioOuCS` = un de `rolesProprietaire`, ou modérateur.\n"
    corps += f"    static let rolesAdministrateur: Set<String> = {_ensemble(_liste(ctx, 'rolesDuDroit', 'admin'))}\n"
    corps += f"    static let rolesOperateur: Set<String> = {_ensemble(_liste(ctx, 'rolesDuDroit', 'operateur'))}\n"
    corps += f"    static let rolesProprietaire: Set<String> = {_ensemble(_liste(ctx, 'rolesDuDroit', 'proprietaire'))}\n"
    corps += "    /// `isAdminOnly` : un de ces rôles, et aucun des suivants (le compte technique).\n"
    corps += f"    static let rolesAdminSeul: Set<String> = {_ensemble(_liste(ctx, 'rolesDuDroit', 'adminSeul'))}\n"
    corps += f"    static let rolesSansAdminSeul: Set<String> = {_ensemble(_liste(ctx, 'rolesDuDroit', 'sansAdminSeul'))}\n"
    statuts_locataire = _liste(ctx, "statutsDuProfil", "locataire")
    corps += f"    static let statutsLocataire: Set<String> = {_ensemble(statuts_locataire)}\n"
    statuts_gestionnaire = _liste(ctx, "statutsDuProfil", "gestionnaire")
    corps += f"    static let statutsGestionnaire: Set<String> = {_ensemble(statuts_gestionnaire)}\n"
    corps += "}\n"
    return corps, n


def titre_du_fil(ctx) -> str:
    """« Fil d'activité » : le titre de la section du fil, au tableau de bord du site."""
    titre = ctx.table("titreFil")
    if not isinstance(titre, str) or not titre.strip():
        raise SystemExit(f"❌ tables-clients.json : titreFil n'est pas un titre : {titre!r}")
    return _swift_texte(titre.strip())


def pages(ctx) -> int:
    lignes = []
    for p in _pages(ctx):
        if p.get("href") is None:
            continue  # sans entrée de navigation : ni ordonnée, ni dans la barre
        lignes.append(
            f'        PageDeNavigation(id: "{p["id"]}", route: "{p["href"]}", '
            f'libelle: "{p["navLabel"]}", titre: "{p["titre"]}", icone: "{p["icone"]}"),\n'
        )
    corps = ctx.entete(f"{ctx.source_table('pages')} et {ctx.source_table('titreFil')} (tables-clients.json)")
    corps += "\n/// Les pages de navigation du site, dans l'ordre par défaut ; `pages_order` le remplace.\n"
    corps += "enum PagesParDefaut {\n    static let toutes: [PageDeNavigation] = [\n" + "".join(lignes) + "    ]\n"
    corps += "    /// Le titre de la section du tableau de bord que le fil de l'app reprend (`.titre-fil`).\n"
    corps += f'    static let titreDuFil = "{titre_du_fil(ctx)}"\n}}\n'
    ctx.ecrire(NAVIGATION / "PagesParDefaut.swift", corps)
    return len(lignes)


# REUSE-IgnoreStart
def parite(ctx) -> int:
    """Chaque onglet de chaque page du site, une ligne : ce que la table de parité classe."""
    lignes = []
    for p in _pages(ctx):
        onglets = p.get("onglets") or []
        if not onglets:
            lignes.append(f"| `{p['id']}` | — | {p.get('titre') or p.get('nom')} |\n")
        for o in onglets:
            lignes.append(f"| `{p['id']}` | `{o['id']}` | {_sans_picto(o.get('label'))} |\n")
    corps = (
        "<!--\nSPDX-FileCopyrightText: 2026 Philippe TRESSARD\n"
        "SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore\n-->\n\n"
        "# Les onglets du site\n\n"
        f"{SIGNATURE}\n"
        f"Source : {ctx.provenance}, `{ctx.source_table('pages')}` (tables-clients.json).\n\n"
        "Chaque ligne doit être classée dans [PARITE.md](PARITE.md) — "
        "`scripts/verifier-parite.py` refuse sinon. « — » : une page sans onglets.\n\n"
        "| Page | Onglet | Libellé sur le site |\n|---|---|---|\n" + "".join(lignes)
    )
    ctx.ecrire(pathlib.Path("Parite") / "ONGLETS-DU-SITE.md", corps)
    return len(lignes)
# REUSE-IgnoreEnd


def onglets_du_site(ctx) -> int:
    corps, n = _swift(ctx, _pages(ctx))
    source = ", ".join(ctx.source_table(t) for t in ("pages", "rolesDuDroit", "statutsDuProfil"))
    ctx.ecrire(CHARTE / "OngletsDuSite.swift", ctx.entete(f"{source} (tables-clients.json)") + corps)
    return n


def generer(ctx) -> str:
    return f"{pages(ctx)} pages ; {parite(ctx)} onglets à classer ; {onglets_du_site(ctx)} onglets et leurs réserves"
