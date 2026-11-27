# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Une PR qui ne touche que la documentation n'occupe pas les exécutants macOS (#204).

Chaque exécution de la CI prenait 4 jobs macOS, servis à 2 ou 3 à la fois : le 15/11/2026,
sept exécutions attendaient en file, dont une PR qui ne changeait que `CLAUDE.md`. Ce
script lit la liste des fichiers changés (un chemin par ligne, sur l'entrée standard) et
dit si TOUS sont de la documentation :

- un fichier `*.md`, où qu'il soit ;
- tout fichier sous `docs/` ;
- tout fichier sous `.claude/`, sauf un script (`.sh`, `.py`) : un hook s'exécute.

Sortie : `macos=false` (documentation seule : build et tests sautés) ou `macos=true`.
Défaut fermé : une liste vide ou illisible donne `macos=true` — un saut ne se justifie que
par une liste lue. `--autotest` prouve qu'un fichier `.swift` relance bien les jobs macOS.
"""

from __future__ import annotations

import re
import sys

DOCUMENTATION = (
    re.compile(r"\.md$"),
    re.compile(r"^docs/"),
    re.compile(r"^\.claude/(?!.*\.(?:sh|py)$)"),
)


def documentation_seule(chemins: list[str]) -> bool:
    """Vrai si la liste n'est pas vide et que chaque chemin est de la documentation."""
    chemins = [c.strip() for c in chemins if c.strip()]
    return bool(chemins) and all(any(m.search(c) for m in DOCUMENTATION) for c in chemins)


def autotest() -> bool:
    cas = {
        ("CLAUDE.md",): True,
        ("README.md", "Parite/PARITE.md", "docs/guide.html"): True,
        (".claude/skills/swiftui-patterns/SKILL.md", ".claude/coprofirst-ios-preflight.md"): True,
        ("CLAUDE.md", "CoproFirst/Fonctions/FAQ/FAQView.swift"): False,
        ("CoproFirst/Commun/Composants/RangeesQuiPassent.swift",): False,
        (".claude/hooks/session-start.sh",): False,
        (".claude/bin/outil.py",): False,
        ("scripts/verifier-depot.sh",): False,
        (".github/workflows/ci.yml",): False,
        (".github/actions/preparer-macos/action.yml",): False,
        ("project.yml",): False,
        ("LICENSES/LicenseRef-CoproFirst-AppStore.txt",): False,
        (): False,
    }
    return all(documentation_seule(list(chemins)) == attendu for chemins, attendu in cas.items())


def main() -> int:
    if sys.argv[1:] == ["--autotest"]:
        ok = autotest()
        print("✅ autotest de la détection « documentation seule »" if ok else "❌ autotest de la détection en échec")
        return 0 if ok else 1
    seule = documentation_seule(sys.stdin.read().splitlines())
    print(f"macos={'false' if seule else 'true'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
