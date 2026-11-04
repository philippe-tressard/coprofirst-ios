# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Ce que les générateurs partagent : le contexte d'une génération, et les lectures
communes à plusieurs domaines."""

from __future__ import annotations

import pathlib
from dataclasses import dataclass

import lecture_ts

CHARTE = pathlib.Path("CoproFirst/Charte")
NAVIGATION = pathlib.Path("CoproFirst/Navigation")


@dataclass(frozen=True)
class Contexte:
    """Une génération : le `front/` de coprofirst lu, la racine de l'app écrite, le commit."""

    front: pathlib.Path
    sortie: pathlib.Path
    commit: str

    # L'en-tête que le script ÉCRIT dans chaque fichier généré : une chaîne, pas la
    # déclaration de ce module — REUSE ne doit pas la lire.
    # REUSE-IgnoreStart
    def entete(self, source: str) -> str:
        return (
            "// SPDX-FileCopyrightText: 2026 Philippe TRESSARD\n"
            "// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore\n"
            "//\n"
            "// GÉNÉRÉ par scripts/generer-charte.py — NE PAS MODIFIER À LA MAIN.\n"
            "// swift-format-ignore-file\n"
            f"// Source : coprofirst@{self.commit}, {source}.\n"
        )
    # REUSE-IgnoreEnd

    def ecrire(self, relatif: pathlib.Path, texte: str) -> None:
        """Écrit un fichier de l'app (chemin relatif à sa racine), en UTF-8 et fins LF."""
        chemin = self.sortie / relatif
        chemin.parent.mkdir(parents=True, exist_ok=True)
        with open(chemin, "w", encoding="utf-8", newline="\n") as f:
            f.write(texte)


def camel(nom: str) -> str:
    morceaux = nom.split("-")
    return morceaux[0] + "".join(m.capitalize() for m in morceaux[1:])


def propriete(jeton: str) -> str:
    """`color-primary` → `primary`, `fil-rouge-fond` → `filRougeFond`."""
    return camel(jeton[len("color-"):]) if jeton.startswith("color-") else camel(jeton)


def tables_des_pages(front: pathlib.Path) -> tuple[list[dict], list[dict]]:
    """`PAGES` (sans l'étalement `...PAGES_ROLES`) et `PAGES_ROLES`, lues par lecture_ts."""
    lib = front / "src" / "lib"
    return (lecture_ts.table((lib / "pages.ts").read_text(encoding="utf-8"), "PAGES"),
            lecture_ts.table((lib / "pages-roles.ts").read_text(encoding="utf-8"), "PAGES_ROLES"))
