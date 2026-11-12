# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Ce que le site écrit du Paramétrage et que le contrat ne sert pas (#16) :

- le descriptif et l'adresse de chaque onglet de la page `admin` (table `pages`) —
  l'app n'en porte que quatre, et renvoie au site pour les autres (« Sur le site ») ;
  les onglets eux-mêmes, leur ordre et leur réserve sont dans `Charte/OngletsDuSite.swift` ;
- le nom de chaque tâche planifiée (`libellesTache`), et les statuts de leur santé —
  libellé, aide et teinte (`statutsTache`), que `GET /admin/maintenance/sante` sert en codes ;
- la teinte d'un rôle et d'un statut, et l'abrégé d'un statut pour une liste dense
  (`attributsRole`, `attributsStatut`) — les libellés eux-mêmes sont dans
  `Charte/RolesUtilisateur.swift`.

→ `CoproFirst/Fonctions/Admin/Genere/TablesAdmin.swift`.
"""

from __future__ import annotations

from generateurs._commun import ATTRIBUTS, FONCTIONS, chaine, dictionnaire, ecrire_table, page_du_site
from generateurs._tables import source

SOURCES: list[str] = []


def generer(ctx) -> str:
    onglets = page_du_site(ctx, "admin").get("onglets") or []
    if not onglets or any(not o.get("route") for o in onglets):
        raise SystemExit("❌ un onglet de la page admin n'a plus d'adresse (`route`) — l'app doit l'apprendre")
    libelles = ctx.table("libellesTache", {str: str})
    statuts = ctx.table("statutsTache", {str: {"libelle": str, "aide": str, "classe": str}})
    roles = ctx.table("attributsRole", ATTRIBUTS)
    statuts_compte = ctx.table("attributsStatut", {str: {"libelle": str, "badge": str, "abrege": str}})
    corps = (
        dictionnaire("descriptifs", "Le descriptif de chaque onglet de la page `admin` (texte du site).",
                     {o["id"]: o["descriptif"] for o in onglets if o.get("descriptif")})
        + dictionnaire("routes", "L'adresse de chaque onglet sur le site, sous celle de la résidence.",
                       {o["id"]: o["route"] for o in onglets})
        + dictionnaire("libellesTache", "Le nom de chaque tâche planifiée (`LIBELLE_TACHE`), par son code servi.",
                       libelles)
        + dictionnaire("libellesStatut", "Le libellé de chaque statut de santé d'une tâche.",
                       {c: s["libelle"] for c, s in statuts.items()})
        + dictionnaire("aidesStatut", "Ce que chaque statut veut dire, en une phrase du site.",
                       {c: s["aide"] for c, s in statuts.items()})
        + dictionnaire("teintesStatut", "La teinte de chaque statut : la classe `badge-*` du site (`PastilleTeinte`).",
                       {c: s["classe"] for c, s in statuts.items()})
        + dictionnaire("teintesRole", "La teinte d'un rôle (`BADGE_ROLE`) ; gris pour une clé inconnue.",
                       {c: r["badge"] for c, r in roles.items()})
        + dictionnaire("teintesStatutCompte",
                       "La teinte d'un statut de compte (`BADGE_STATUT`) ; gris pour une clé inconnue.",
                       {c: r["badge"] for c, r in statuts_compte.items()})
        + dictionnaire("abregesStatutCompte",
                       "Un statut de compte abrégé, pour une liste dense (`LIBELLES_STATUT_ABREGE`).",
                       {c: r["abrege"] for c, r in statuts_compte.items()})
        + "    /// Les statuts de compte dans l'ordre du site : le filtre « Type » des utilisateurs.\n"
        + f"    static let ordreStatutsCompte: [String] = [{', '.join(chaine(c) for c in statuts_compte)}]\n"
    )
    ecrire_table(ctx, FONCTIONS / "Admin" / "Genere" / "TablesAdmin.swift",
                 source("pages", "libellesTache", "statutsTache", "attributsRole", "attributsStatut"), "TablesAdmin",
                 "Ce que le site écrit du Paramétrage et que le contrat ne sert pas.", corps)
    return (f"{len(onglets)} onglets ; {len(libelles)} tâches ; {len(statuts)} statuts de tâche ; "
            f"{len(roles)} rôles ; {len(statuts_compte)} statuts de compte")
