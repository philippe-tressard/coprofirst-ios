# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Ce que les générateurs partagent : le contexte d'une génération, et les lectures
et écritures communes à plusieurs domaines."""

from __future__ import annotations

import pathlib
import re
from dataclasses import dataclass, field

import lecture_ts
from generateurs._source import DEPOT, DEPOT_SITE, Version, fichier_du_site

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

    def lire(self, relatif: str) -> str:
        """Un fichier de coprofirst, relatif à sa racine (`front/src/lib/pages.ts`)."""
        return (self.racine / relatif).read_text(encoding="utf-8")

    def table(self, nom: str):
        """Une table que coprofirst PUBLIE pour ses clients (`tables-clients.json`, jointe à
        chaque release depuis v3.88.0, coprofirst#2634) : sa `valeur`, telle que servie.

        La lecture par motif dans les sources du site (`lire` + `lecture_ts`) ne vaut plus
        que pour ce que le fichier ne publie pas (#128). Une table absente, ou un format que
        ce script ne connaît pas, arrête la génération : la source a changé de forme."""
        tables = _tables_clients(self.version)
        if nom not in tables:
            raise SystemExit(f"❌ tables-clients.json de {self.version.etiquette} : table « {nom} » absente")
        return tables[nom]["valeur"]

    def source_table(self, nom: str) -> str:
        """Le fichier du site dont la table est tirée (`front/src/lib/bail.ts#ETATS_BAIL`)."""
        self.table(nom)
        source = _tables_clients(self.version)[nom].get("source")
        return source if isinstance(source, str) else "tables-clients.json"

    def provenance_tables(self, *noms: str) -> str:
        """L'en-tête « Source : » d'une table générée : le fichier du site de chaque table
        publiée lue, puis « (tables-clients.json) »."""
        return ", ".join(self.source_table(n) for n in noms) + " (tables-clients.json)"


_TABLES: dict[str, dict] = {}
#: La version MAJEURE de `tables-clients.json` que ces générateurs savent lire : une
#: majeure de plus annonce une table retirée ou une forme qui recule (`RETRAITS` côté serveur).
FORMAT_TABLES = 1


def _tables_clients(version: Version) -> dict:
    if version.etiquette not in _TABLES:
        import json

        try:
            lu = json.loads(version.piece_jointe("tables-clients.json"))
            majeure = int(str(lu["version"]).split(".")[0])
            tables = lu["tables"]
        except (ValueError, KeyError, TypeError) as erreur:
            raise SystemExit(f"❌ tables-clients.json de {version.etiquette} illisible ({erreur})") from erreur
        if lu.get("format") != FORMAT_TABLES or majeure != FORMAT_TABLES:
            raise SystemExit(
                f"❌ tables-clients.json de {version.etiquette} : format {lu.get('format')}, version {lu['version']} "
                f"— ces générateurs lisent le format {FORMAT_TABLES}, version {FORMAT_TABLES}.x")
        _TABLES[version.etiquette] = tables
    return _TABLES[version.etiquette]


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


# Une déclaration CSS `--nom: valeur;` (les jetons de la charte).
JETON_CSS = re.compile(r"--([a-z][a-z0-9-]*)\s*:\s*([^;]+);")


def bloc_css(texte: str, selecteur: str) -> str:
    """Le corps du premier bloc dont l'en-tête contient `selecteur`, accolades équilibrées."""
    debut = texte.index(selecteur)
    ouverture = texte.index("{", debut)
    profondeur = 0
    for i in range(ouverture, len(texte)):
        if texte[i] == "{":
            profondeur += 1
        elif texte[i] == "}":
            profondeur -= 1
            if profondeur == 0:
                return texte[ouverture + 1 : i]
    raise ValueError(f"bloc non fermé : {selecteur}")


def jetons_css(corps: str) -> dict[str, str]:
    """Les jetons `--nom: valeur` d'un bloc CSS, commentaires retirés."""
    sans = re.sub(r"/\*.*?\*/", "", corps, flags=re.S)
    return {nom: valeur.strip() for nom, valeur in JETON_CSS.findall(sans)}


def jetons_du_socle(ctx: Contexte) -> dict[str, str]:
    """Les jetons de la charte (`:root` de `front/src/styles/socle.css`)."""
    return jetons_css(bloc_css(ctx.lire("front/src/styles/socle.css"), ":root,"))


def chaine(valeur) -> str:
    """Un littéral de chaîne Swift."""
    texte = str(valeur).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    return f'"{texte}"'


def booleen(valeur) -> str:
    return "true" if valeur else "false"


def sans_pictogramme(libelle: str) -> str:
    """Un libellé du site sans l'émoji qui le précède."""
    return re.sub(r"^[^\w«(]+", "", libelle).strip()


def objet(texte: str, motif: str) -> dict:
    """L'objet littéral `{ … }` qui suit la première occurrence de `motif` (une expression
    régulière), lu par `lecture_ts` — mêmes règles que ses tables."""
    m = re.search(motif, texte)
    if not m:
        raise SystemExit(f"❌ {motif} introuvable")
    return lecture_ts._Lecteur(lecture_ts._jetons(texte[texte.index("{", m.end() - 1):])).objet()


def camel(nom: str) -> str:
    morceaux = nom.split("-")
    return morceaux[0] + "".join(m.capitalize() for m in morceaux[1:])


def propriete(jeton: str) -> str:
    """`color-primary` → `primary`, `fil-rouge-fond` → `filRougeFond`, `kanban-ag` → `kanbanAg`."""
    return camel(jeton[len("color-"):]) if jeton.startswith("color-") else camel(jeton)


