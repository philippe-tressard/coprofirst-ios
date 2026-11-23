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
- `verifier-app <journal de l'app> <journal des tests>` — l'APP jouée, de même : en Debug, elle
  dit au lancement, au journal du simulateur, l'empreinte des sources de `CoproFirst/`
  (`EmpreinteApp.swift`, même règle d'écriture). Les tests d'interface joués, elle doit paraître
  et être celle du source ; sinon (tests unitaires seuls), elle ne doit pas en contredire.
  Un correctif ou un mutant de l'app se jugeait sinon, sans le savoir, sur l'app d'avant.
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
# L'app : toutes ses sources, sous-dossiers compris ; le fichier écrit, à côté de la simulation.
DOSSIER_APP = "CoproFirst"
FICHIER_APP = "Donnees/EmpreinteApp.swift"
LIGNE_APP = "Empreinte de l'app jouée : "
MOTIF_APP = re.compile(re.escape(LIGNE_APP) + r"([0-9a-f]{16})")

ENTETE = """// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

// Écrit par scripts/empreinte_tests.py, jamais à la main ni versionné (#328).
enum EmpreinteSources {
    static let valeur = "{valeur}"
}
"""

ENTETE_APP = """// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

// Écrit par scripts/empreinte_tests.py, jamais à la main ni versionné (#328). Dite au
// lancement par `LancementSimule.direLEmpreinte()` : Debug seul, rien en Release.
#if DEBUG
enum EmpreinteApp {
    static let valeur = "{valeur}"
}
#endif
"""


def empreinte(dossier: pathlib.Path, fichier: str = FICHIER, motif: str = "*.swift") -> str:
    """Les 16 premiers chiffres du SHA-256 des sources (chemin relatif et contenu, dans
    l'ordre des chemins), hors le fichier écrit."""
    somme = hashlib.sha256()
    for f in sorted(dossier.glob(motif)):
        nom = f.relative_to(dossier).as_posix()
        if nom == fichier:
            continue
        somme.update(nom.encode() + b"\0" + f.read_bytes() + b"\0")
    return somme.hexdigest()[:16]


def _ecrire(dossier: pathlib.Path, fichier: str, motif: str, entete: str) -> str:
    valeur = empreinte(dossier, fichier, motif)
    cible = dossier / fichier
    texte = entete.replace("{valeur}", valeur)
    if not cible.exists() or cible.read_text(encoding="utf-8") != texte:
        cible.write_text(texte, encoding="utf-8")
    return valeur


def ecrire(dossier: pathlib.Path) -> str:
    return _ecrire(dossier, FICHIER, "*.swift", ENTETE)


def ecrire_app(dossier: pathlib.Path) -> str:
    return _ecrire(dossier, FICHIER_APP, "**/*.swift", ENTETE_APP)


def _lire(journal: pathlib.Path) -> str | None:
    try:
        return journal.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None


def verifier(journal: pathlib.Path, dossier: pathlib.Path) -> tuple[int, str]:
    attendue = empreinte(dossier)
    texte = _lire(journal)
    if texte is None:
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


def verifier_app(journal_app: pathlib.Path, journal_tests: pathlib.Path,
                 dossier: pathlib.Path) -> tuple[int, str]:
    attendue = empreinte(dossier, FICHIER_APP, "**/*.swift")
    app, tests = _lire(journal_app), _lire(journal_tests)
    if app is None or tests is None:
        return 2, "INCONNU — journal illisible : l'app jouée ne se prouve pas"
    vues = set(MOTIF_APP.findall(app))
    if not vues and SUITE not in tests:
        return 0, "sans objet — aucun test d'interface n'a lancé l'app"
    if not vues:
        return 2, f"INCONNU — l'app jouée n'a pas dit son empreinte au journal du simulateur (attendue {attendue})"
    if vues != {attendue}:
        autres = ", ".join(sorted(vues - {attendue}))
        return 2, f"INCONNU — app jouée {autres}, source {attendue} : une app périmée a joué (#328)"
    return 0, f"celle du source (empreinte {attendue})"


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
    erreurs += autotest_app()
    for e in erreurs:
        print(f"❌ {e}", file=sys.stderr)
    if not erreurs:
        print("✅ empreinte_tests.py : le binaire joué se prouve, un périmé ou un muet rend INCONNU")
    return 1 if erreurs else 0


def autotest_app() -> list[str]:
    """L'app jouée : sous-dossiers compris, une app périmée ou muette rend INCONNU (#328)."""
    erreurs = []
    with tempfile.TemporaryDirectory() as d:
        dossier = pathlib.Path(d)
        (dossier / "Donnees").mkdir()
        (dossier / "Donnees/B.swift").write_text("let b = 1\n", encoding="utf-8")
        valeur = ecrire_app(dossier)
        if f'"{valeur}"' not in (dossier / FICHIER_APP).read_text(encoding="utf-8") or ecrire_app(dossier) != valeur:
            erreurs.append("app : l'empreinte écrite change l'empreinte, ou ne s'écrit pas")
        app, tests = dossier / "app.log", dossier / "tests.log"
        tests.write_text(f"{SUITE}\n", encoding="utf-8")
        app.write_text(f"CoproFirst: {LIGNE_APP}{valeur}\n", encoding="utf-8")
        if verifier_app(app, tests, dossier)[0] != 0:
            erreurs.append("app : celle du source n'est pas reconnue")
        app.write_text("", encoding="utf-8")
        if verifier_app(app, tests, dossier)[0] != 2:
            erreurs.append("app : une app muette, des tests d'interface joués, n'est pas INCONNU")
        tests.write_text("Test Suite 'CoproFirstTests.xctest' started\n", encoding="utf-8")
        if verifier_app(app, tests, dossier)[0] != 0:
            erreurs.append("app : un passage des seuls tests unitaires n'est pas sans objet")
        (dossier / "Donnees/B.swift").write_text("let b = 2\n", encoding="utf-8")  # un sous-dossier change
        app.write_text(f"{LIGNE_APP}{valeur}\n", encoding="utf-8")
        code, motif = verifier_app(app, tests, dossier)
        if code != 2 or "périmée" not in motif:
            erreurs.append("app : une app périmée (source d'un sous-dossier changé) n'est pas INCONNU")
        if verifier_app(dossier / "absent.log", tests, dossier)[0] != 2:
            erreurs.append("app : un journal absent n'est pas INCONNU")
    return erreurs


def main(arguments: list[str]) -> int:
    if arguments[:1] == ["--autotest"]:
        return autotest()
    if arguments[:1] == ["ecrire"]:
        # Sans dossier : les tests ET l'app, les deux fichiers que le build compile.
        if len(arguments) == 1:
            ecrire_app(pathlib.Path(DOSSIER_APP))
        print(ecrire(pathlib.Path(arguments[1] if len(arguments) > 1 else DOSSIER)))
        return 0
    if arguments[:1] == ["verifier"] and len(arguments) >= 2:
        code, motif = verifier(pathlib.Path(arguments[1]), pathlib.Path(arguments[2] if len(arguments) > 2 else DOSSIER))
        print(motif)
        return code
    if arguments[:1] == ["verifier-app"] and len(arguments) >= 3:
        dossier = pathlib.Path(arguments[3] if len(arguments) > 3 else DOSSIER_APP)
        code, motif = verifier_app(pathlib.Path(arguments[1]), pathlib.Path(arguments[2]), dossier)
        print(motif)
        return code
    print("usage : empreinte_tests.py ecrire [dossier] | verifier <journal> [dossier]"
          " | verifier-app <journal de l'app> <journal des tests> [dossier] | --autotest", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
