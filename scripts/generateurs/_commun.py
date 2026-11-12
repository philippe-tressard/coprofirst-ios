# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Ce que les générateurs partagent : le contexte d'une génération, et les lectures
et écritures communes à plusieurs domaines."""

from __future__ import annotations

import pathlib
import re
from dataclasses import dataclass, field

from generateurs._source import DEPOT, DEPOT_SITE, Version, fichier_du_site
from generateurs._tables import Facultatif, Parmi, Tables

CHARTE = pathlib.Path("CoproFirst/Charte")
NAVIGATION = pathlib.Path("CoproFirst/Navigation")
FONCTIONS = pathlib.Path("CoproFirst/Fonctions")
# La 1re ligne de tout fichier généré : `verifier-depot.sh` l'exige dans `Genere/`, et la
# concordance (#20) reconnaît ainsi un fichier généré que plus aucun module n'écrit.
SIGNATURE = "GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN."
# Ce que l'en-tête dit de la source ; la concordance l'ignore face à une autre version.
PROVENANCE = re.compile(r"philippe-tressard/coprofirst (v\d+\.\d+\.\d+) \(commit ([0-9a-f]{40})\)")
# Une valeur CSS qui n'est qu'un renvoi à un jeton : `var(--kanban-ag)`.
VAR_JETON = re.compile(r"^var\(--([a-z][a-z0-9-]*)\)$")


@dataclass(frozen=True)
class Contexte:
    """Une génération : les tables publiées de la version, ce qui reste extrait de son
    archive, la racine écrite."""

    racine: pathlib.Path
    sortie: pathlib.Path
    version: Version
    commit: str
    tables: Tables
    ecrits: list[pathlib.Path] = field(default_factory=list)

    @property
    def provenance(self) -> str:
        return f"{DEPOT} {self.version.etiquette} (commit {self.commit})"

    # L'en-tête que le script ÉCRIT dans chaque fichier généré : une chaîne, pas la
    # déclaration de ce module — REUSE ne doit pas la lire.
    # REUSE-IgnoreStart
    def entete(self, source: str, provenance: str | None = None) -> str:
        """`provenance` : une autre source que la version de coprofirst (`provenance_site`)."""
        return (
            f"// {SIGNATURE}\n"
            "// SPDX-FileCopyrightText: 2026 Philippe TRESSARD\n"
            "// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore\n"
            "//\n"
            "// swift-format-ignore-file\n"
            f"// Source : {provenance or self.provenance}, {source}.\n"
        )
    # REUSE-IgnoreEnd

    def ecrire(self, relatif: pathlib.Path, texte: str) -> None:
        """Écrit un fichier de l'app (chemin relatif à sa racine), en UTF-8 et fins LF."""
        chemin = self.sortie / relatif
        chemin.parent.mkdir(parents=True, exist_ok=True)
        with open(chemin, "w", encoding="utf-8", newline="\n") as f:
            f.write(texte)
        self.ecrits.append(pathlib.Path(relatif))

    @staticmethod
    def provenance_site(commit: str) -> str:
        return f"{DEPOT_SITE} (commit {commit})"

    @staticmethod
    def lire_site(commit: str, chemin: str) -> bytes:
        """Un fichier de coprofirst-site, au commit que le générateur épingle (#51)."""
        return fichier_du_site(commit, chemin)

    def table(self, nom: str, forme):
        """Une table que le site publie (`tables-clients.json`), par son nom, à la forme
        attendue — absente ou d'une autre forme, la génération s'arrête (`_tables.py`)."""
        return self.tables.lire(nom, forme)

    def lire(self, relatif: str) -> str:
        """Un fichier de l'archive de coprofirst, relatif à sa racine
        (`api/app/utils/avis.py`) : ce que le site ne publie pas en table."""
        return (self.racine / relatif).read_text(encoding="utf-8")


def ecrire_table(ctx: Contexte, relatif: pathlib.Path, source: str, nom: str, doc: str, corps: str,
                 *, swiftui: bool = False, provenance: str | None = None) -> None:
    """Une table d'un menu (`Fonctions/<Menu>/Genere/`) : un `enum` de constantes.

    Une entrée par ligne, sans retour : si une ligne dépasse 120 colonnes, la longueur de
    ligne de SwiftLint est suspendue pour le fichier — et seulement alors, car
    `superfluous_disable_command` refuse une suspension qui ne sert à rien."""
    lignes_longues = any(len(ligne) > 120 for ligne in corps.splitlines())
    texte = ctx.entete(source, provenance)
    if lignes_longues:
        texte += "// swiftlint:disable line_length\n"
    texte += "\n" + ("import SwiftUI\n\n" if swiftui else "")
    texte += f"/// {doc}\nenum {nom} {{\n{corps}}}\n"
    if lignes_longues:
        texte += "// swiftlint:enable line_length\n"
    ctx.ecrire(relatif, texte)


def jetons(regle: dict[str, str]) -> dict[str, str]:
    """Les jetons d'une règle CSS publiée (`{"--color-primary": "#1e3a5f", …}`), sans leurs
    deux tirets ; une propriété qui n'est pas un jeton (`color-scheme`) n'en est pas un."""
    return {nom[2:]: valeur.strip() for nom, valeur in regle.items() if nom.startswith("--")}


def jetons_de_la_charte(ctx: Contexte) -> dict[str, str]:
    """Les jetons de la charte (`jetonsCharte` : le `:root` de `socle.css`)."""
    return jetons(ctx.table("jetonsCharte", {str: str}))


# Une page du site (`pages` : `PAGES` et `PAGES_ROLES` étalés à leur place, libellés résolus).
ONGLET = {"id": str, "label": str, "route": Facultatif(str), "descriptif": Facultatif(str),
          "reserve": Facultatif(str), "ouvertOperateur": Facultatif(bool)}
PAGE = {"id": str, "href": Parmi(str, None), "nom": str, "titre": str, "navLabel": str, "icone": str,
        "descriptif": Facultatif(str), "reserveeAdmin": Facultatif(bool), "onglets": Facultatif([ONGLET])}


def pages_du_site(ctx: Contexte) -> list[dict]:
    """Les pages du site, dans son ordre, chacune avec ses onglets (`pages`)."""
    return ctx.table("pages", [PAGE])


def page_du_site(ctx: Contexte, identifiant: str) -> dict:
    """Une page par son `id` ; disparue, la génération s'arrête."""
    page = next((p for p in pages_du_site(ctx) if p["id"] == identifiant), None)
    if page is None:
        raise SystemExit(f"❌ la page {identifiant} a disparu de la table « pages »")
    return page


# Deux formes que beaucoup de tables du site partagent : une option (code et libellé), et
# un code en clair (libellé et classe `badge-*`).
OPTION = {"val": str, "label": str}
ATTRIBUTS = {str: {"libelle": str, "badge": str}}


def teintes(nom: str, doc: str, entrees: list[tuple[str, str, str]]) -> str:
    """Une table Swift `[code: LibelleTeinte(libellé, classe badge-*)]`."""
    lignes = "".join(f"        {chaine(c)}: LibelleTeinte({chaine(l)}, {chaine(b)}),\n" for c, l, b in entrees)
    return f"    /// {doc}\n    static let {nom}: [String: LibelleTeinte] = [\n{lignes}    ]\n"


def couples(nom: str, doc: str, entrees: list[tuple[str, str]]) -> str:
    """Une liste Swift ordonnée `[(code, libellé)]`."""
    lignes = "".join(f"        ({chaine(c)}, {chaine(l)}),\n" for c, l in entrees)
    return f"    /// {doc}\n    static let {nom}: [(code: String, libelle: String)] = [\n{lignes}    ]\n"


def dictionnaire(nom: str, doc: str | None, entrees: dict[str, str]) -> str:
    """Un dictionnaire Swift `[String: String]`, dans l'ordre du site ; `doc` : sa ligne de
    documentation, s'il en a une."""
    lignes = "".join(f"        {chaine(c)}: {chaine(v)},\n" for c, v in entrees.items())
    tete = f"    /// {doc}\n" if doc else ""
    return f"{tete}    static let {nom}: [String: String] = [\n{lignes}    ]\n"


def jeton_de(valeur: str, origine: str) -> str:
    """`var(--fil-rouge)` → `fil-rouge` : une teinte du site est un jeton, jamais une valeur."""
    m = VAR_JETON.match(valeur)
    if not m:
        raise SystemExit(f"❌ {origine} : « {valeur} » n'est pas un jeton `var(--…)`")
    return m.group(1)


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
