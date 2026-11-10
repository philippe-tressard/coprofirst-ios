# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Ce que le site écrit du Paramétrage et que le contrat ne sert pas (#16) :

- le descriptif et l'adresse de chaque onglet de la page `admin` (`pages-roles.ts`) —
  l'app n'en porte que quatre, et renvoie au site pour les autres (« Sur le site ») ;
  les onglets eux-mêmes, leur ordre et leur réserve sont dans `Charte/OngletsDuSite.swift` ;
- le nom de chaque tâche planifiée, et les statuts de leur santé — libellé, aide et
  teinte (`taches.ts`), que `GET /admin/maintenance/sante` sert en codes ;
- la teinte d'un rôle et d'un statut, et l'abrégé d'un statut pour une liste dense
  (`roles.ts`) — les libellés eux-mêmes sont dans `Charte/RolesUtilisateur.swift`.

→ `CoproFirst/Fonctions/Admin/Genere/TablesAdmin.swift`.
"""

from __future__ import annotations

import re

from generateurs._commun import FONCTIONS, chaine, ecrire_table, objet, tables_des_pages

SOURCES = [
    "front/src/lib/pages-roles.ts",
    "front/src/lib/taches.ts",
    "front/src/lib/roles.ts",
]


_LITTERAL = r"'(?:[^'\\]|\\.)*'" + "|" + r'"(?:[^"\\]|\\.)*"'
_CONCATENATION = re.compile(rf"({_LITTERAL})\s*\+\s*({_LITTERAL})")


def _contenu(litteral: str) -> str:
    return re.sub(r"\\(.)", r"\1", litteral[1:-1])


def _sans_concatenation(texte: str) -> str:
    """`'a ' + "b"` → `"a b"` : `taches.ts` coupe ses aides en plusieurs littéraux, que
    la lecture des tables ne joint pas."""
    while True:
        joint = _CONCATENATION.sub(
            lambda m: '"' + (_contenu(m[1]) + _contenu(m[2])).replace("\\", "\\\\").replace('"', '\\"') + '"',
            texte, count=1)
        if joint == texte:
            return texte
        texte = joint


def _dictionnaire(nom: str, valeurs: list[tuple[str, str]], doc: str) -> str:
    return (
        f"    /// {doc}\n"
        f"    static let {nom}: [String: String] = [\n"
        + "".join(f"        {chaine(c)}: {chaine(v)},\n" for c, v in valeurs)
        + "    ]\n"
    )


def generer(ctx) -> str:
    _, roles = tables_des_pages(ctx.front)
    page = next((p for p in roles if p.get("id") == "admin"), None)
    if page is None:
        raise SystemExit("❌ la page admin a disparu de PAGES_ROLES")
    onglets = page.get("onglets") or []
    if any(not o.get("route") for o in onglets):
        raise SystemExit("❌ un onglet de la page admin n'a plus d'adresse (`route`) — l'app doit l'apprendre")
    taches = _sans_concatenation(ctx.lire("front/src/lib/taches.ts"))
    libelles = objet(taches, r"export const LIBELLE_TACHE[^=]*=\s*\{")
    statuts = objet(taches, r"parAttribut\(\{")
    for code, statut in statuts.items():
        if set(statut) != {"libelle", "aide", "classe"} or not all(isinstance(v, str) for v in statut.values()):
            raise SystemExit(f"❌ le statut de tâche « {code} » change de forme ({sorted(statut)})")
    roles_ts = ctx.lire("front/src/lib/roles.ts")
    roles = objet(roles_ts, r"const ROLE = parAttribut\(\{")
    statuts_compte = objet(roles_ts, r"const STATUT = parAttribut\(\{")
    if not all(isinstance(r.get("badge"), str) for r in [*roles.values(), *statuts_compte.values()]) \
            or not all(isinstance(s.get("abrege"), str) for s in statuts_compte.values()):
        raise SystemExit("❌ la table des rôles ou des statuts change de forme dans roles.ts")
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
                 "front/src/lib/pages-roles.ts, taches.ts, roles.ts", "TablesAdmin",
                 "Ce que le site écrit du Paramétrage et que le contrat ne sert pas.", corps)
    return (f"{len(onglets)} onglets ; {len(libelles)} tâches ; {len(statuts)} statuts de tâche ; "
            f"{len(roles)} rôles ; {len(statuts_compte)} statuts de compte")
