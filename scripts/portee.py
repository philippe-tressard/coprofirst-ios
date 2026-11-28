#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""La portée des contrôles du code Swift : UNE liste des dossiers, lue par chacun (#341).

L'app a quatre cibles (l'iPhone, l'écran de hall sur Apple TV #218, l'Apple Watch et son
widget #226) et leurs tests. Chaque juge statique et SwiftLint lisaient leur propre liste,
écrite en dur pour l'iPhone seul : une cible neuve échappait aux règles par son dossier.

Ici, la liste ; les juges l'importent (`import portee`), `.swiftlint.yml` la recopie (YAML ne
sait pas importer) et ce script en garde l'égalité. Ce qu'il refuse :
  1. un fichier Swift suivi hors de tout dossier déclaré (une cible neuve s'y déclare) ;
  2. un dossier de `CODE` ou `TESTS` que `.swiftlint.yml` ne lit pas, ou l'inverse ;
  3. un juge `scripts/verifier-*.py` qui parcourt un dossier écrit en dur au lieu de cette
     liste ;
  4. une dispense qui ne sert plus (son dossier n'a plus de fichier Swift).

`--motif code` rend le motif des chemins du code de l'app (`verifier-depot.sh` le lit).
Sortie : 0 conforme, 1 refus, 2 INCONNU (git illisible). `--autotest` prouve qu'il refuse.
"""

from __future__ import annotations

import pathlib
import re
import subprocess
import sys
import tempfile

RACINE = pathlib.Path(__file__).resolve().parent.parent

#: Le code des quatre cibles et le client d'API.
CODE = ("CoproFirst", "CoproFirstTV", "CoproFirstWatch", "CoproFirstWatchWidget", "Paquets/ClientAPI/Sources")
#: Leurs tests.
TESTS = (
    "CoproFirstTests", "CoproFirstUITests", "CoproFirstTVTests", "CoproFirstTVUITests", "CoproFirstWatchTests",
    "CoproFirstWatchUITests", "Paquets/ClientAPI/Tests",
)
#: Lus par SwiftLint seul : le manifeste du paquet.
MANIFESTES = ("Paquets/ClientAPI/Package.swift",)
#: chemin → raison : hors de SwiftLint et des juges. Une dispense sans fichier Swift échoue.
DISPENSES = {
    "scripts": "deux outils du poste (`swift scripts/rendre-*.swift`), qui dessinent l'icône et un "
               "symbole : leurs lignes sont des tracés, rien n'en entre dans l'app",
}

#: Un juge qui choisit lui-même son dossier : `racine / "CoproFirst…"` parcouru, un tuple
#: `DOSSIERS = (`, ou `git ls-files … "CoproFirst…"`.
EN_DUR = re.compile(
    r"""\(\s*\w+\s*/\s*"CoproFirst\w*"\s*\)\s*\.r?glob|^DOSSIERS\s*=\s*\(|"ls-files"[^\]\n]*"CoproFirst""",
    re.MULTILINE)


def sous(chemin: str, dossier: str) -> bool:
    return chemin == dossier or chemin.startswith(dossier + "/")


def fichiers(racine: pathlib.Path, dossiers: tuple[str, ...], motif: str = "*.swift") -> list[pathlib.Path]:
    """Les fichiers de ces dossiers, triés — le parcours que chaque juge fait."""
    trouves: list[pathlib.Path] = []
    for dossier in dossiers:
        if (racine / dossier).is_dir():
            trouves += (racine / dossier).rglob(motif)
    return sorted(trouves)


def motif_code() -> str:
    """Le motif bash (`[[ =~ ]]`, grep -E) des fichiers Swift du code de l'app."""
    return "^(" + "|".join(re.escape(d) for d in CODE) + r")/.*\.swift$"


def inclus_swiftlint(texte: str) -> list[str]:
    bloc = re.search(r"^included:\n((?:[ \t]+-[^\n]*\n)+)", texte, re.MULTILINE)
    return [ligne.split("-", 1)[1].strip() for ligne in bloc.group(1).splitlines()] if bloc else []


def refus(suivis: list[str], swiftlint: str, juges: dict[str, str]) -> list[str]:
    declares = CODE + TESTS + MANIFESTES
    fautes = [f"{f} : hors de tout dossier déclaré — l'ajouter à CODE ou TESTS (scripts/portee.py)"
              for f in suivis if not any(sous(f, d) for d in declares + tuple(DISPENSES))]
    lus = inclus_swiftlint(swiftlint)
    fautes += [f".swiftlint.yml : {d} n'est pas lu (included)" for d in declares if d not in lus]
    fautes += [f".swiftlint.yml : {d} lu sans être déclaré dans scripts/portee.py" for d in lus if d not in declares]
    fautes += [f"{chemin} : parcourt un dossier écrit en dur — portee.CODE ou portee.TESTS"
               for chemin, texte in sorted(juges.items()) if EN_DUR.search(texte)]
    fautes += [f"dispense {d} : plus aucun fichier Swift — la retirer"
               for d in DISPENSES if not any(sous(f, d) for f in suivis)]
    return fautes


def autotest() -> bool:
    lint = "included:\n" + "".join(f"  - {d}\n" for d in CODE + TESTS + MANIFESTES) + "excluded:\n  - .build\n"
    sains = ["CoproFirst/A.swift", "CoproFirstWatchWidget/W.swift", "scripts/rendre-icone.swift"]
    juge_sain = "for f in portee.fichiers(racine, portee.CODE):\n    (racine / \"CoproFirst\").mkdir()\n"
    cas = [
        (refus(sains, lint, {"a.py": juge_sain}), False),
        (refus(sains + ["CoproFirstVision/V.swift"], lint, {}), True),          # une cible neuve
        (refus(sains, lint.replace("  - CoproFirstTV\n", ""), {}), True),        # SwiftLint ne la lit pas
        (refus(sains, lint, {"a.py": 'for f in (racine / "CoproFirst").rglob("*.swift"):'}), True),
        (refus(sains, lint, {"a.py": 'DOSSIERS = ("CoproFirst", "CoproFirstTests")'}), True),
        (refus(sains, lint, {"a.py": '["git", "ls-files", "--cached", "CoproFirst"]'}), True),
        (refus(sains[:2], lint, {}), True),                                       # dispense sans objet
    ]
    ok = all(bool(fautes) == attendu for fautes, attendu in cas)
    ok = ok and re.search(motif_code(), "CoproFirstWatchWidget/W.swift") is not None
    ok = ok and re.search(motif_code(), "CoproFirstTests/T.swift") is None
    with tempfile.TemporaryDirectory() as d:
        (pathlib.Path(d) / "CoproFirstTV" / "S").mkdir(parents=True)
        (pathlib.Path(d) / "CoproFirstTV" / "S" / "V.swift").write_text("", encoding="utf-8")
        ok = ok and [f.name for f in fichiers(pathlib.Path(d), CODE)] == ["V.swift"]
    return ok


def main() -> int:
    if sys.argv[1:] == ["--motif", "code"]:
        print(motif_code())
        return 0
    if sys.argv[1:] == ["--autotest"]:
        ok = autotest()
        print("✅ autotest de la portée des contrôles" if ok else "❌ autotest de la portée des contrôles en échec")
        return 0 if ok else 1
    sortie = subprocess.run(["git", "ls-files", "--cached", "*.swift"], cwd=RACINE, capture_output=True, text=True)
    suivis = sortie.stdout.splitlines()
    if sortie.returncode != 0 or not suivis:
        print("❓ INCONNU : git ne rend aucun fichier Swift")
        return 2
    juges = {f.relative_to(RACINE).as_posix(): f.read_text(encoding="utf-8")
             for f in sorted((RACINE / "scripts").glob("verifier-*.py"))}
    fautes = refus(suivis, (RACINE / ".swiftlint.yml").read_text(encoding="utf-8"), juges)
    for faute in fautes:
        print(f"❌ {faute}")
    if fautes:
        return 1
    print(f"✅ portée des contrôles : {len(CODE) + len(TESTS)} dossiers Swift, lus par SwiftLint et les juges")
    return 0


if __name__ == "__main__":
    sys.exit(main())
