# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Lire le front de coprofirst À UNE VERSION PUBLIÉE, et écrire un fichier `Genere/`.

Ce que les générateurs d'un menu partagent (#15) : la révision épinglée lue par
`git show` (ni `dev`, ni un arbre modifié), un littéral TypeScript ou Svelte relu
par `lecture_ts`, une couleur de la charte rendue en `RVBA(…)`, et l'en-tête qui
fait d'un fichier un fichier généré (`verifier-depot.sh` le réclame en 1re ligne).

⚠️ `generer-affaires.py`, `generer-acces-prestataires.py` et
`generer-communaute-profil.py` écrivent encore chacun leur copie de ces fonctions :
à ramener ici, dans un lot à part.
"""

from __future__ import annotations

import os
import pathlib
import re
import subprocess

import lecture_ts

RACINE = pathlib.Path(__file__).resolve().parents[1]
RACINE_COPROFIRST = os.environ.get("COPROFIRST_RACINE", "/Volumes/Data/Dev/5hostachy")
# La version PUBLIÉE de coprofirst que les installations font tourner.
REVISION = os.environ.get("COPROFIRST_REVISION", "v3.61.0")
HEX = re.compile(r"^#([0-9a-fA-F]{6})$")
JETON_CSS = re.compile(r"--([a-z0-9-]+)\s*:\s*([^;]+);")


def git(*args: str) -> str:
    return subprocess.run(["git", "-C", RACINE_COPROFIRST, *args], capture_output=True, text=True,
                          check=True).stdout


def commit() -> str:
    return git("rev-parse", f"{REVISION}^{{commit}}").strip()


def front(chemin: str) -> str:
    """Un fichier de `front/` (`src/lib/pages.ts`…), tel qu'il est À LA RÉVISION épinglée."""
    return git("show", f"{REVISION}:front/{chemin}")


def chaine(valeur) -> str:
    """Un littéral de chaîne Swift."""
    texte = str(valeur).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    return f'"{texte}"'


def sans_pictogramme(libelle: str) -> str:
    return re.sub(r"^[^\w«(]+", "", libelle).strip()


def objet(texte: str, motif: str) -> dict:
    """L'objet littéral `{ … }` qui suit la première occurrence de `motif` (une expression
    régulière), lu par `lecture_ts` — mêmes règles que ses tables."""
    m = re.search(motif, texte)
    if not m:
        raise SystemExit(f"❌ {motif} introuvable")
    return lecture_ts._Lecteur(lecture_ts._jetons(texte[texte.index("{", m.end() - 1):])).objet()


def tableau(texte: str, nom: str) -> list:
    return lecture_ts.table(texte, nom)


def jetons_css(feuille: str, selecteur: str | None = None) -> dict[str, str]:
    """Les jetons `--nom: valeur;` d'une feuille (ceux du bloc `selecteur` s'il est donné),
    commentaires retirés."""
    texte = re.sub(r"/\*.*?\*/", "", feuille, flags=re.S)
    if selecteur is not None:
        debut = texte.index("{", texte.index(selecteur))
        profondeur, fin = 0, debut
        for fin in range(debut, len(texte)):
            profondeur += {"{": 1, "}": -1}.get(texte[fin], 0)
            if profondeur == 0:
                break
        texte = texte[debut:fin]
    return {nom: valeur.strip() for nom, valeur in JETON_CSS.findall(texte)}


def rvba(valeur: str, origine: str) -> str:
    """Le littéral `RVBA(…)` d'une couleur hexadécimale ; échoue sur toute autre forme."""
    m = HEX.match(valeur)
    if not m:
        raise SystemExit(f"❌ {origine} : couleur non portable ({valeur})")
    h = int(m.group(1), 16)
    return f"RVBA(0x{h >> 16 & 0xFF:02X}, 0x{h >> 8 & 0xFF:02X}, 0x{h & 0xFF:02X}, 1)"


# L'en-tête que le script ÉCRIT dans le fichier généré : une chaîne, pas la
# déclaration de ce module — REUSE ne doit pas la lire.
# REUSE-IgnoreStart
def entete(script: str, sources: str) -> str:
    # La 1re ligne dit « GÉNÉRÉ » : verifier-depot.sh n'admet de couleur dans Genere/ qu'à ce prix.
    return (
        f"// GÉNÉRÉ par scripts/{script} — NE PAS MODIFIER À LA MAIN.\n"
        "// SPDX-FileCopyrightText: 2026 Philippe TRESSARD\n"
        "// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore\n"
        "//\n"
        "// swift-format-ignore-file\n"
        f"// Source : philippe-tressard/coprofirst {REVISION} (commit {commit()}),\n"
        f"//   {sources}\n"
    )


# REUSE-IgnoreEnd


def ecrire(relatif: str, script: str, sources: str, corps: str, imports: str = "") -> None:
    """Écrit `CoproFirst/…` (relatif à la racine de l'app), en UTF-8 et fins LF."""
    chemin = RACINE / relatif
    longues = any(len(ligne) > 120 for ligne in corps.splitlines())
    # SwiftLint refuse une désactivation superflue : elle n'encadre que ce qui la demande.
    texte = entete(script, sources) + (f"\n{imports}" if imports else "") + "\n"
    texte += ("// swiftlint:disable line_length\n" + corps + "// swiftlint:enable line_length\n") if longues else corps
    chemin.parent.mkdir(parents=True, exist_ok=True)
    with open(chemin, "w", encoding="utf-8", newline="\n") as f:
        f.write(texte)
    print(f"✅ coprofirst {REVISION} → {relatif}")
