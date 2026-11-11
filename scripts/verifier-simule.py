#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""La simulation ne part pas en production (#84) : dans le code de l'app (`CoproFirst/`),
tout ce qui nomme la simulation — `ServiceSimule`, ses magasins, ses jeux de données
(`Fixtures…`), l'argument `-api-simulee` — se trouve dans un bloc `#if DEBUG`.

Les tests d'interface tournent en Debug : ils gardent l'API simulée ; un build Release
ne la compile pas, et l'exécutable n'en contient plus les données.

Le juge lit le code, pas les commentaires (une documentation peut nommer
`ServiceSimule`). Une branche `#else` d'un `#if DEBUG` est hors du bloc. Un `#if` non
refermé rend INCONNU (sortie 2), jamais conforme.

Usage : python3 scripts/verifier-simule.py [--autotest]
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
# `simul` couvre ServiceSimule, MagasinSimuleCS, AccesSimules, profilSimule,
# -api-simulee… ; `Fixtures` les jeux de données servis par la simulation.
SYMBOLE = re.compile(r"(?i:simul)|\bFixtures[A-Z]")


class NonRefermé(Exception):
    pass


def code_seul(ligne: str) -> str:
    """La ligne sans son commentaire : `//` en tête, ou précédé d'une espace
    (une adresse `https://` n'en a pas)."""
    if ligne.lstrip().startswith("//"):
        return ""
    return re.split(r"\s//", ligne, maxsplit=1)[0]


def fautes(texte: str) -> list[tuple[int, str]]:
    """Les lignes de code qui nomment la simulation hors d'un bloc `#if DEBUG`."""
    pile: list[tuple[bool, bool]] = []  # (ce #if est DEBUG, la ligne courante est en Debug)
    trouvees = []
    for numero, ligne in enumerate(texte.splitlines(), 1):
        directive = ligne.strip()
        en_debug = pile[-1][1] if pile else False
        if directive.startswith("#if"):
            debug = directive.split("//")[0].strip() == "#if DEBUG"
            pile.append((debug, True if debug else en_debug))
            continue
        if directive.startswith(("#else", "#elseif")) and pile:
            debug, _ = pile[-1]
            parent = pile[-2][1] if len(pile) > 1 else False
            if debug:
                pile[-1] = (debug, parent)
            continue
        if directive.startswith("#endif"):
            if not pile:
                raise NonRefermé(f"ligne {numero} : #endif sans #if")
            pile.pop()
            continue
        if not en_debug and SYMBOLE.search(code_seul(ligne)):
            trouvees.append((numero, ligne.strip()))
    if pile:
        raise NonRefermé("#if non refermé")
    return trouvees


def autotest() -> bool:
    """Dans les deux sens : un contrôle qui ne refuse rien ne prouve rien."""
    cas = {
        # Fautifs.
        "let s = ServiceSimule()\n": 1,
        'arguments.contains("-api-simulee")\n': 1,
        "#if DEBUG\nlet a = 1\n#else\nlet s = ServiceSimule()\n#endif\n": 1,
        "#if os(iOS)\nlet f = FixturesAcces.lus()\n#endif\n": 1,
        "#if DEBUG\n#endif\nextension ServiceSimule: X {}\n": 1,
        # Conformes.
        "#if DEBUG\nlet s = ServiceSimule()\n#endif\n": 0,
        "#if DEBUG\n#if os(iOS)\nlet f = FixturesAcces.lus()\n#endif\n#endif\n": 0,
        "/// Réalisé par `ServiceSimule`.\nlet a = 1 // ServiceSimule\n": 0,
        'let u = URL(string: "https://exemple.fr")!\n': 0,
    }
    for texte, attendu in cas.items():
        if len(fautes(texte)) != attendu:
            print(f"❌ autotest : {texte!r} → {len(fautes(texte))} faute(s), attendu {attendu}")
            return False
    try:
        fautes("#if DEBUG\nlet s = ServiceSimule()\n")
        print("❌ autotest : un #if non refermé passe")
        return False
    except NonRefermé:
        pass
    print("✅ autotest : la simulation hors de #if DEBUG est refusée")
    return True


def main() -> int:
    if "--autotest" in sys.argv[1:]:
        return 0 if autotest() else 1
    sortie = subprocess.run(
        ["git", "ls-files", "--cached", "CoproFirst"], cwd=RACINE, capture_output=True, text=True)
    fichiers = [f for f in sortie.stdout.splitlines() if f.endswith(".swift")]
    if sortie.returncode != 0 or not fichiers:
        print("❓ INCONNU : aucun fichier Swift de l'app lu")
        return 2
    echecs = 0
    for chemin in fichiers:
        fichier = RACINE / chemin
        if not fichier.is_file():
            continue
        try:
            trouvees = fautes(fichier.read_text(encoding="utf-8"))
        except NonRefermé as erreur:
            print(f"❓ INCONNU : {chemin} : {erreur}")
            return 2
        for numero, ligne in trouvees:
            print(f"❌ {chemin}:{numero} : la simulation hors de #if DEBUG — {ligne}")
            echecs += 1
    if echecs:
        return 1
    print(f"✅ simulation sous #if DEBUG seulement ({len(fichiers)} fichiers Swift)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
