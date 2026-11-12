# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Ce que le site écrit du Paramétrage et que le contrat ne sert pas (#16), lu dans
`tables-clients.json` de la release (#128) :

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

from generateurs._commun import FONCTIONS, chaine, ecrire_table

SOURCES: list[str] = []  # lu dans tables-clients.json de la release (#128), pas dans les sources

#: Les tables publiées que ce module lit, dans l'ordre de l'en-tête.
TABLES = ("pages", "libellesTache", "statutsTache", "attributsRole", "attributsStatut")


def _dictionnaire(nom: str, valeurs: list[tuple[str, str]], doc: str) -> str:
    return (
        f"    /// {doc}\n"
        f"    static let {nom}: [String: String] = [\n"
        + "".join(f"        {chaine(c)}: {chaine(v)},\n" for c, v in valeurs)
        + "    ]\n"
    )


def generer(ctx) -> str:
    page = next((p for p in ctx.table("pages") if p.get("id") == "admin"), None)
    if page is None:
        raise SystemExit("❌ la page admin a disparu de la table pages")
    onglets = page.get("onglets") or []
    if any(not o.get("route") for o in onglets):
        raise SystemExit("❌ un onglet de la page admin n'a plus d'adresse (`route`) — l'app doit l'apprendre")
    libelles = ctx.table("libellesTache")
    if not isinstance(libelles, dict) or not all(isinstance(v, str) for v in libelles.values()):
        raise SystemExit("❌ la table libellesTache change de forme")
    statuts = ctx.table("statutsTache")
    for code, statut in statuts.items():
        if set(statut) != {"libelle", "aide", "classe"} or not all(isinstance(v, str) for v in statut.values()):
            raise SystemExit(f"❌ le statut de tâche « {code} » change de forme ({sorted(statut)})")
    roles = ctx.table("attributsRole")
    statuts_compte = ctx.table("attributsStatut")
    if not all(isinstance(r.get("badge"), str) for r in [*roles.values(), *statuts_compte.values()]) \
            or not all(isinstance(s.get("abrege"), str) for s in statuts_compte.values()):
        raise SystemExit("❌ la table attributsRole ou attributsStatut change de forme")
    corps = (
        _dictionnaire("descriptifs", [(o["id"], o["descriptif"]) for o in onglets if o.get("descriptif")],
                      "Le descriptif de chaque onglet de la page `admin` (texte du site).")
        + _dictionnaire("routes", [(o["id"], o["route"]) for o in onglets],
                        "L'adresse de chaque onglet sur le site, sous celle de la résidence.")
        + _dictionnaire("libellesTache", list(libelles.items()),
                        "Le nom de chaque tâche planifiée (`LIBELLE_TACHE`), par son code servi.")
        + _dictionnaire("libellesStatut", [(c, s["libelle"]) for c, s in statuts.items()],
                        "Le libellé de chaque statut de santé d'une tâche.")
        + _dictionnaire("aidesStatut", [(c, s["aide"]) for c, s in statuts.items()],
                        "Ce que chaque statut veut dire, en une phrase du site.")
        + _dictionnaire("teintesStatut", [(c, s["classe"]) for c, s in statuts.items()],
                        "La teinte de chaque statut : la classe `badge-*` du site (`PastilleTeinte`).")
        + _dictionnaire("teintesRole", [(c, r["badge"]) for c, r in roles.items()],
                        "La teinte d'un rôle (`BADGE_ROLE`) ; gris pour une clé inconnue.")
        + _dictionnaire("teintesStatutCompte", [(c, r["badge"]) for c, r in statuts_compte.items()],
                        "La teinte d'un statut de compte (`BADGE_STATUT`) ; gris pour une clé inconnue.")
        + _dictionnaire("abregesStatutCompte", [(c, r["abrege"]) for c, r in statuts_compte.items()],
                        "Un statut de compte abrégé, pour une liste dense (`LIBELLES_STATUT_ABREGE`).")
        + "    /// Les statuts de compte dans l'ordre du site : le filtre « Type » des utilisateurs.\n"
        + f"    static let ordreStatutsCompte: [String] = [{', '.join(chaine(c) for c in statuts_compte)}]\n"
    )
    ecrire_table(ctx, FONCTIONS / "Admin" / "Genere" / "TablesAdmin.swift",
                 ", ".join(ctx.source_table(n) for n in TABLES) + " (tables-clients.json)", "TablesAdmin",
                 "Ce que le site écrit du Paramétrage et que le contrat ne sert pas.", corps)
    return (f"{len(onglets)} onglets ; {len(libelles)} tâches ; {len(statuts)} statuts de tâche ; "
            f"{len(roles)} rôles ; {len(statuts_compte)} statuts de compte")
