# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""L'empreinte des sources des tests d'interface, compilée dans le binaire JOUÉ (#328).

Le 22/11/2026, au poste, un passage a joué l'app de test du passage PRÉCÉDENT (un mutant,
ses traces au journal) alors que le source était restauré, recompilé, et le binaire
construit juste : il s'est dit vert. Un passage ne prouve donc rien du code qu'il juge tant
qu'il ne prouve pas le binaire qu'il a joué (standards/04).

- `ecrire [dossier]` — l'empreinte (SHA-256 des `*.swift` du dossier, chemin et contenu,
  hors le fichier écrit) dans `EmpreinteSources.swift`, que la cible compile : le binaire
  porte l'empreinte des sources dont il est fait. Le fichier ne change que si elle change.
- `verifier <journal> [dossier]` — le binaire joué imprime son empreinte au chargement
  (`EmpreinteDesTests`, principal du paquet de tests) ; elle doit être celle du source.
  Sortie 0 si toutes les lignes du journal la disent, ou si le paquet des tests d'interface
  n'a pas joué (un passage des seuls tests unitaires) ; 2 (INCONNU) si une autre paraît —
  un binaire périmé — ou si aucune ne paraît.
- `--autotest` — un journal qui dit l'empreinte passe, un autre binaire ou un journal muet
  rend INCONNU, et l'empreinte suit le contenu (pas la date) des sources.
"""

import hashlib
import pathlib
import re
import sys
import tempfile

DOSSIER = "CoproFirstUITests"
FICHIER = "EmpreinteSources.swift"
LIGNE = "Empreinte des tests jouée : "
MOTIF = re.compile(re.escape(LIGNE) + r"([0-9a-f]{16})")
SUITE = "Test Suite 'CoproFirstUITests.xctest' started"

ENTETE = """// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

// Écrit par scripts/empreinte_tests.py, jamais à la main ni versionné (#328).
enum EmpreinteSources {
    static let valeur = "{valeur}"
}
"""


def empreinte(dossier: pathlib.Path) -> str:
    """Les 16 premiers chiffres du SHA-256 des sources, dans l'ordre des chemins."""
    somme = hashlib.sha256()
    for f in sorted(dossier.glob("*.swift")):
        if f.name == FICHIER:
            continue
        somme.update(f.name.encode() + b"\0" + f.read_bytes() + b"\0")
    return somme.hexdigest()[:16]


def ecrire(dossier: pathlib.Path) -> str:
    valeur = empreinte(dossier)
    cible = dossier / FICHIER
    texte = ENTETE.replace("{valeur}", valeur)
    if not cible.exists() or cible.read_text(encoding="utf-8") != texte:
        cible.write_text(texte, encoding="utf-8")
    return valeur


def verifier(journal: pathlib.Path, dossier: pathlib.Path) -> tuple[int, str]:
    attendue = empreinte(dossier)
    try:
        texte = journal.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return 2, f"INCONNU — journal illisible ({journal}) : le binaire joué ne se prouve pas"
    vues = set(MOTIF.findall(texte))
    if not vues and SUITE not in texte:
        return 0, "sans objet — le paquet des tests d'interface n'a pas joué"
    if not vues:
        return 2, f"INCONNU — le binaire joué n'a pas dit son empreinte (attendue {attendue})"
    if vues != {attendue}:
        autres = ", ".join(sorted(vues - {attendue}))
        return 2, f"INCONNU — binaire joué {autres}, source {attendue} : un binaire périmé a joué (#328)"
    return 0, f"celui du source (empreinte {attendue})"


def autotest() -> int:
    erreurs = []
    with tempfile.TemporaryDirectory() as d:
        dossier = pathlib.Path(d)
        (dossier / "A.swift").write_text("let a = 1\n", encoding="utf-8")
        valeur = ecrire(dossier)
        if f'"{valeur}"' not in (dossier / FICHIER).read_text(encoding="utf-8"):
            erreurs.append("l'empreinte n'est pas écrite dans le fichier compilé")
        if ecrire(dossier) != valeur:
            erreurs.append("le fichier écrit change l'empreinte")
        journal = dossier / "tests.log"
        journal.write_text(f"{SUITE}\n{LIGNE}{valeur}\n", encoding="utf-8")
        if verifier(journal, dossier)[0] != 0:
            erreurs.append("le binaire du source n'est pas reconnu")
        journal.write_text(f"{SUITE}\n** TEST SUCCEEDED **\n", encoding="utf-8")
        if verifier(journal, dossier)[0] != 2:
            erreurs.append("un journal muet n'est pas INCONNU")
        journal.write_text("Test Suite 'CoproFirstTests.xctest' started\n** TEST SUCCEEDED **\n", encoding="utf-8")
        if verifier(journal, dossier)[0] != 0:
            erreurs.append("un passage des seuls tests unitaires n'est pas sans objet")
        (dossier / "A.swift").write_text("let a = 2\n", encoding="utf-8")  # le mutant restauré
        journal.write_text(f"{LIGNE}{valeur}\n", encoding="utf-8")
        code, motif = verifier(journal, dossier)
        if code != 2 or "périmé" not in motif:
            erreurs.append("un binaire périmé n'est pas INCONNU")
        journal.write_text(f"{LIGNE}{valeur}\n{LIGNE}{empreinte(dossier)}\n", encoding="utf-8")
        if verifier(journal, dossier)[0] != 2:
            erreurs.append("deux binaires dans un passage ne sont pas INCONNU")
        if verifier(dossier / "absent.log", dossier)[0] != 2:
            erreurs.append("un journal absent n'est pas INCONNU")
    for e in erreurs:
        print(f"❌ {e}", file=sys.stderr)
    if not erreurs:
        print("✅ empreinte_tests.py : le binaire joué se prouve, un périmé ou un muet rend INCONNU")
    return 1 if erreurs else 0


def main(arguments: list[str]) -> int:
    if arguments[:1] == ["--autotest"]:
        return autotest()
    if arguments[:1] == ["ecrire"]:
        print(ecrire(pathlib.Path(arguments[1] if len(arguments) > 1 else DOSSIER)))
        return 0
    if arguments[:1] == ["verifier"] and len(arguments) >= 2:
        code, motif = verifier(pathlib.Path(arguments[1]), pathlib.Path(arguments[2] if len(arguments) > 2 else DOSSIER))
        print(motif)
        return code
    print("usage : empreinte_tests.py ecrire [dossier] | verifier <journal> [dossier] | --autotest", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
