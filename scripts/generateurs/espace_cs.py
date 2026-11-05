# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Ce que le site écrit de l'Espace conseil syndical et que le contrat ne sert pas (#15) :

- le descriptif de chaque onglet de la page `espace-cs` (`pages-roles.ts`) — les onglets
  eux-mêmes, leur ordre et leur réserve sont dans `Charte/OngletsDuSite.swift` ;
- les civilités d'une fiche de l'annuaire (`CIVILITES` de `CarteMembre.svelte`).

→ `CoproFirst/Fonctions/EspaceCS/Genere/TablesEspaceCS.swift`.
"""

from __future__ import annotations

import pathlib
import re

from generateurs._commun import tables_des_pages

SOURCES = [
    "front/src/lib/pages-roles.ts",
    "front/src/lib/components/CarteMembre.svelte",
]

SORTIE = pathlib.Path("CoproFirst/Fonctions/EspaceCS/Genere/TablesEspaceCS.swift")


def _chaine(valeur: str) -> str:
    return '"' + str(valeur).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


# L'en-tête que le module ÉCRIT : une chaîne, pas sa déclaration — REUSE ne doit pas la lire.
# « GÉNÉRÉ » en 1re ligne : `verifier-depot.sh` l'exige d'un fichier de `Fonctions/<Menu>/Genere/`.
# REUSE-IgnoreStart
def _entete(ctx) -> str:
    return (
        "// GÉNÉRÉ par scripts/generer-charte.py — NE PAS MODIFIER À LA MAIN.\n"
        "// SPDX-FileCopyrightText: 2026 Philippe TRESSARD\n"
        "// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore\n"
        "//\n"
        "// swift-format-ignore-file\n"
        f"// Source : coprofirst@{ctx.commit}, front/src/lib/pages-roles.ts, components/CarteMembre.svelte.\n"
    )
# REUSE-IgnoreEnd


def _civilites(front: pathlib.Path) -> list[str]:
    texte = (front / "src/lib/components/CarteMembre.svelte").read_text(encoding="utf-8")
    m = re.search(r"export const CIVILITES = \[([^\]]*)\]", texte)
    if not m:
        raise SystemExit("❌ CIVILITES introuvable dans CarteMembre.svelte — l'app doit l'apprendre")
    return re.findall(r"'([^']+)'", m.group(1))


def generer(ctx) -> str:
    _, roles = tables_des_pages(ctx.front)
    page = next((p for p in roles if p.get("id") == "espace-cs"), None)
    if page is None:
        raise SystemExit("❌ la page espace-cs a disparu de PAGES_ROLES")
    descriptifs = [(o["id"], o["descriptif"]) for o in page.get("onglets") or [] if o.get("descriptif")]
    civilites = _civilites(ctx.front)
    corps = _entete(ctx)
    corps += "// swiftlint:disable line_length\n\n"
    corps += "/// Ce que le site écrit de l'Espace conseil syndical et que le contrat ne sert pas.\n"
    corps += "enum TablesEspaceCS {\n"
    corps += "    /// Le descriptif de chaque onglet de la page `espace-cs` (texte du site).\n"
    corps += "    static let descriptifs: [String: String] = [\n"
    corps += "".join(f"        {_chaine(i)}: {_chaine(d)},\n" for i, d in descriptifs)
    corps += "    ]\n"
    corps += "    /// Les civilités d'une fiche de l'annuaire, dans l'ordre du site (`CIVILITES`).\n"
    corps += "    static let civilites: [String] = [" + ", ".join(_chaine(c) for c in civilites) + "]\n"
    corps += "}\n// swiftlint:enable line_length\n"
    ctx.ecrire(SORTIE, corps)
    return f"{len(descriptifs)} descriptifs d'onglets ; {len(civilites)} civilités"
