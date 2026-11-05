# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Ce que les générateurs partagent : le contexte d'une génération, et les lectures
et écritures communes à plusieurs domaines."""

from __future__ import annotations

import pathlib
import re
from dataclasses import dataclass, field

import lecture_ts
from generateurs._source import DEPOT, Version

CHARTE = pathlib.Path("CoproFirst/Charte")
NAVIGATION = pathlib.Path("CoproFirst/Navigation")
FONCTIONS = pathlib.Path("CoproFirst/Fonctions")
# La 1re ligne de tout fichier généré : `verifier-depot.sh` l'exige dans `Genere/`, et la
# concordance (#20) reconnaît ainsi un fichier généré que plus aucun module n'écrit.
SIGNATURE = "GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN."
# Ce que l'en-tête dit de la source ; la concordance l'ignore face à une autre version.
PROVENANCE = re.compile(r"philippe-tressard/coprofirst (v\d+\.\d+\.\d+) \(commit ([0-9a-f]{40})\)")


@dataclass(frozen=True)
class Contexte:
    """Une génération : l'arbre de coprofirst extrait de la version, la racine écrite."""

    racine: pathlib.Path
    sortie: pathlib.Path
    version: Version
    commit: str
    ecrits: list[pathlib.Path] = field(default_factory=list)

    @property
    def front(self) -> pathlib.Path:
        return self.racine / "front"

    @property
    def provenance(self) -> str:
        return f"{DEPOT} {self.version.etiquette} (commit {self.commit})"

    # L'en-tête que le script ÉCRIT dans chaque fichier généré : une chaîne, pas la
    # déclaration de ce module — REUSE ne doit pas la lire.
    # REUSE-IgnoreStart
    def entete(self, source: str) -> str:
        return (
            f"// {SIGNATURE}\n"
            "// SPDX-FileCopyrightText: 2026 Philippe TRESSARD\n"
            "// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore\n"
            "//\n"
            "// swift-format-ignore-file\n"
            f"// Source : {self.provenance}, {source}.\n"
        )
    # REUSE-IgnoreEnd

    def ecrire(self, relatif: pathlib.Path, texte: str) -> None:
        """Écrit un fichier de l'app (chemin relatif à sa racine), en UTF-8 et fins LF."""
        chemin = self.sortie / relatif
        chemin.parent.mkdir(parents=True, exist_ok=True)
        with open(chemin, "w", encoding="utf-8", newline="\n") as f:
            f.write(texte)
        self.ecrits.append(pathlib.Path(relatif))

    def lire(self, relatif: str) -> str:
        """Un fichier de coprofirst, relatif à sa racine (`front/src/lib/pages.ts`)."""
        return (self.racine / relatif).read_text(encoding="utf-8")


def ecrire_table(ctx: Contexte, relatif: pathlib.Path, source: str, nom: str, doc: str, corps: str,
                 *, swiftui: bool = False, lignes_longues: bool = False) -> None:
    """Une table d'un menu (`Fonctions/<Menu>/Genere/`) : un `enum` de constantes.

    `lignes_longues` suspend la longueur de ligne de SwiftLint pour le fichier (une
    entrée par ligne, sans retour) ; ne l'ajouter que là où une ligne la dépasse —
    `superfluous_disable_command` refuse sinon."""
    texte = ctx.entete(source)
    if lignes_longues:
        texte += "// swiftlint:disable line_length\n"
    texte += "\n" + ("import SwiftUI\n\n" if swiftui else "")
    texte += f"/// {doc}\nenum {nom} {{\n{corps}}}\n"
    if lignes_longues:
        texte += "// swiftlint:enable line_length\n"
    ctx.ecrire(relatif, texte)


def chaine(valeur) -> str:
    """Un littéral de chaîne Swift."""
    texte = str(valeur).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    return f'"{texte}"'


def booleen(valeur) -> str:
    return "true" if valeur else "false"


def sans_pictogramme(libelle: str) -> str:
    """Un libellé du site sans l'émoji qui le précède."""
    return re.sub(r"^[^\w«(]+", "", libelle).strip()


def camel(nom: str) -> str:
    morceaux = nom.split("-")
    return morceaux[0] + "".join(m.capitalize() for m in morceaux[1:])


def propriete(jeton: str) -> str:
    """`color-primary` → `primary`, `fil-rouge-fond` → `filRougeFond`, `kanban-ag` → `kanbanAg`."""
    return camel(jeton[len("color-"):]) if jeton.startswith("color-") else camel(jeton)


def tables_des_pages(front: pathlib.Path) -> tuple[list[dict], list[dict]]:
    """`PAGES` (sans l'étalement `...PAGES_ROLES`) et `PAGES_ROLES`, lues par lecture_ts."""
    lib = front / "src" / "lib"
    return (lecture_ts.table((lib / "pages.ts").read_text(encoding="utf-8"), "PAGES"),
            lecture_ts.table((lib / "pages-roles.ts").read_text(encoding="utf-8"), "PAGES_ROLES"))
