# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Lire un passage de `xcodebuild test` : ce qui est tombé, pourquoi, et si une relance est permise.

Appelé par `scripts/tests-simulateur.sh` (#50). Deux lectures :

- `lenteurs <journal>` — les requêtes d'accessibilité qui ont expiré, test par test.
  XCTest attend environ 30 s la photographie de l'arbre d'accessibilité de l'app,
  et réessaie deux fois (« (retry 1) », « (retry 2) ») ; une troisième expiration
  devient « Lost connection to the application ». Mesuré le 05/11/2026 : une
  expiration isolée paraît dans la moitié des runs, toutes branches confondues ;
  deux d'affilée, rarement — sauf sur une branche qui alourdit l'app. Les deux
  d'affilée se signalent donc, même sur un run vert : c'est la marche d'avant
  l'échec.
- `decider <résumé.json>` — le résumé de `xcresulttool get test-results summary`.
  Une relance n'est permise que si CHAQUE échec est un test d'interface tombé sur
  une cause déclarée dans `CAUSES_RELANCE`, et pas plus de `PLAFOND_TESTS` tests.
  Imprime alors un `-only-testing:` par test (sortie 0) ; sinon le motif du refus
  (sortie 1) ; un résumé illisible rend INCONNU (sortie 2), jamais une relance.
- `relance-verte <résumé.json> <n>` — la relance ne compte verte que si son résumé
  dit les n tests rejoués et passés.

`--autotest` rejoue les deux lectures sur des extraits de journaux réels (runs
42066224812 et 41940166154) : un contrôle qui ne refuse rien ne prouve rien.
"""

from __future__ import annotations

import json
import re
import sys

#: La seule liste des causes qui ouvrent droit à UNE relance — ajouter une cause
#: demande une mesure (un run qui la montre) et son ticket. #50 : la perte de
#: connexion après trois requêtes d'accessibilité expirées, l'app vivante.
CAUSES_RELANCE = {
    "Lost connection to the application": "perte de connexion à l'app (trois requêtes d'accessibilité expirées)",
}
#: Au-delà, ce n'est plus un accroc du runner : le run reste rouge.
PLAFOND_TESTS = 2
CIBLE_INTERFACE = "CoproFirstUITests"

DEBUT_TEST = re.compile(r"Test Case '-\[(?P<cible>\w+)\.(?P<classe>\w+) (?P<methode>\w+)\]' started")
NOUVEL_ESSAI = re.compile(r"\(retry (?P<rang>\d+)\)\s*$")
#: « AccesUITests/testSignalerPerduPuisDeclarer() » : un autre format ne se relance pas,
#: le `-only-testing:` qui en sortirait pourrait ne viser aucun test.
IDENTIFIANT = re.compile(r"^\w+/\w+\(\)$")


def cause_declaree(texte: str) -> str | None:
    """Le nom de la cause déclarée que porte ce message d'échec, ou None."""
    for motif, nom in CAUSES_RELANCE.items():
        if motif in texte:
            return nom
    return None


def decider(resume: dict) -> tuple[int, str, list[str]]:
    """(sortie, motif, -only-testing) — voir l'en-tête du module."""
    try:
        echecs = resume["testFailures"]
        nombre = int(resume["failedTests"])
        lus = [(e["targetName"], e["testIdentifierString"], e["failureText"]) for e in echecs]
    except (KeyError, TypeError, ValueError) as erreur:
        return 2, f"INCONNU : résumé de xcresult illisible ({erreur!r})", []
    if resume.get("result") != "Failed" or not lus:
        return 1, "aucun test en échec au résumé : l'échec vient d'ailleurs (build, lancement)", []
    tests = sorted({(cible, ident) for cible, ident, _ in lus})
    if len(tests) != nombre:
        return 2, f"INCONNU : {nombre} test(s) en échec au résumé, {len(tests)} dans sa liste", []
    for cible, ident, texte in lus:
        if cible != CIBLE_INTERFACE:
            return 1, f"{cible}/{ident} n'est pas un test d'interface", []
        if not IDENTIFIANT.match(ident):
            return 2, f"INCONNU : identifiant de test inattendu ({ident!r})", []
        if cause_declaree(texte) is None:
            return 1, f"{ident} est tombé pour une autre raison : {texte.splitlines()[0][:160]}", []
    if len(tests) > PLAFOND_TESTS:
        return 1, f"{len(tests)} tests tombés (plafond {PLAFOND_TESTS}) : ce n'est plus un accroc du runner", []
    cause = cause_declaree(lus[0][2])
    seuls = [f"-only-testing:{cible}/{ident.removesuffix('()')}" for cible, ident in tests]
    return 0, f"{cause} — {', '.join(i for _, i in tests)}", seuls


def relance_verte(resume: dict, attendus: int) -> tuple[bool, str]:
    """La relance est verte si son résumé compte exactement les tests relancés, tous passés.

    Un `-only-testing:` qui ne vise rien sort en 0 sans avoir rien joué : la sortie
    de xcodebuild ne suffit pas à dire vert.
    """
    try:
        passes, rates, resultat = int(resume["passedTests"]), int(resume["failedTests"]), resume["result"]
    except (KeyError, TypeError, ValueError) as erreur:
        return False, f"INCONNU : résumé de la relance illisible ({erreur!r})"
    if resultat == "Passed" and rates == 0 and passes == attendus:
        return True, f"{passes} test(s) rejoué(s), tous verts"
    return False, f"relance : {resultat}, {passes} passé(s) et {rates} en échec pour {attendus} relancé(s)"


def lenteurs(journal: str) -> dict[str, int]:
    """Par test : le rang du dernier nouvel essai d'une requête (1 ou 2), s'il y en a eu."""
    courant, rangs = "?", {}
    for ligne in journal.splitlines():
        if m := DEBUT_TEST.search(ligne):
            courant = f"{m['classe']}/{m['methode']}"
        elif m := NOUVEL_ESSAI.search(ligne):
            rangs[courant] = max(rangs.get(courant, 0), int(m["rang"]))
    return rangs


def rendre_lenteurs(rangs: dict[str, int]) -> tuple[list[str], list[str]]:
    """(lignes du résumé en Markdown, annotations GitHub)."""
    if not rangs:
        return ["Requêtes d'accessibilité : aucune n'a expiré."], []
    resume = ["| Test | Requêtes d'accessibilité expirées d'affilée (au moins) |", "|---|---|"]
    annotations = []
    for test, rang in sorted(rangs.items()):
        resume.append(f"| `{test}` | {rang}{' ⚠️ au bord de la perte de connexion' if rang >= 2 else ''} |")
        if rang >= 2:
            annotations.append(
                f"::warning title=Requêtes d'accessibilité expirées ({test})::"
                f"{rang} requêtes d'affilée ont expiré (~30 s chacune) ; à la suivante, "
                "« Lost connection to the application ». Un écran trop lourd à photographier ? (#50)")
    return resume, annotations


# ── Autotest ────────────────────────────────────────────────────────────────────
PERTE = ("Failed to get matching snapshots: Lost connection to the application (pid 22209). "
         "(Underlying Error: Impossible de communiquer avec une application d’aide.)")
JOURNAL = """\
Test Case '-[CoproFirstUITests.AccesUITests testLesQuatreOngletsSOuvrent]' started.
    t =    10.20s     Checking existence of `"onglet.badges" Any`
Test Case '-[CoproFirstUITests.AccesUITests testSignalerPerduPuisDeclarer]' started.
    t =    67.20s     Checking existence of `"acces.declarer.code" Any`
    t =    99.66s     Checking existence of `"acces.declarer.code" Any` (retry 1)
    t =   132.22s     Checking existence of `"acces.declarer.code" Any` (retry 2)
Test Case '-[CoproFirstUITests.AffairesUITests testUneCarteOuvreSonDetail]' started.
    t =    46.83s     Find the "FAQ" Any (retry 1)
"""


def _resume(*echecs: tuple[str, str, str], nombre: int | None = None) -> dict:
    return {
        "result": "Failed" if echecs else "Passed",
        "failedTests": len({(c, i) for c, i, _ in echecs}) if nombre is None else nombre,
        "testFailures": [
            {"targetName": c, "testIdentifierString": i, "failureText": t, "testName": i} for c, i, t in echecs],
    }


def autotest() -> int:
    acces = (CIBLE_INTERFACE, "AccesUITests/testSignalerPerduPuisDeclarer()", PERTE)
    affaires = (CIBLE_INTERFACE, "AffairesUITests/testLeFiltreSuiviNeGardeQueSonEtat()", PERTE)
    cas = [
        ("une perte de connexion : relance", _resume(acces), 0,
         ["-only-testing:CoproFirstUITests/AccesUITests/testSignalerPerduPuisDeclarer"]),
        ("deux, au plafond : relance", _resume(acces, affaires), 0, None),
        ("trois : refus", _resume(acces, affaires, (CIBLE_INTERFACE, "ResidenceUITests/testX()", PERTE)), 1, []),
        ("une assertion à côté : refus",
         _resume(acces, (CIBLE_INTERFACE, "AccesUITests/testSignalerPerduPuisDeclarer()", "XCTAssertTrue failed")),
         1, []),
        ("un test unitaire : refus", _resume(("CoproFirstTests", "AccesTests/unTest()", PERTE)), 1, []),
        ("rien en échec : refus", _resume(), 1, []),
        ("comptes discordants : INCONNU", _resume(acces, nombre=3), 2, []),
        ("résumé illisible : INCONNU", {"result": "Failed"}, 2, []),
        ("identifiant inattendu : INCONNU", _resume((CIBLE_INTERFACE, "testSansClasse()", PERTE)), 2, []),
    ]
    rate = 0
    for nom, resume, sortie, seuls in cas:
        obtenu, motif, liste = decider(resume)
        if obtenu != sortie or (seuls is not None and liste != seuls):
            print(f"❌ {nom} : sortie {obtenu} ({motif}), {liste}")
            rate += 1
    for passes, rates, resultat, attendu in [(1, 0, "Passed", True), (0, 0, "Passed", False),
                                             (1, 1, "Failed", False), (2, 0, "Passed", False)]:
        verte, motif = relance_verte({"passedTests": passes, "failedTests": rates, "result": resultat}, 1)
        if verte != attendu:
            print(f"❌ relance_verte({passes}, {rates}, {resultat}) : {verte} ({motif})")
            rate += 1
    rangs = lenteurs(JOURNAL)
    if rangs != {"AccesUITests/testSignalerPerduPuisDeclarer": 2, "AffairesUITests/testUneCarteOuvreSonDetail": 1}:
        print(f"❌ lenteurs : {rangs}")
        rate += 1
    _, annotations = rendre_lenteurs(rangs)
    if len(annotations) != 1 or "testSignalerPerduPuisDeclarer" not in annotations[0]:
        print(f"❌ une seule annotation attendue, pour deux expirations d'affilée : {annotations}")
        rate += 1
    print("✅ bilan_tests_ui : autotest" if rate == 0 else f"── {rate} cas en échec")
    return 0 if rate == 0 else 1


def main(argv: list[str]) -> int:
    if argv[1:] == ["--autotest"]:
        return autotest()
    if len(argv) == 3 and argv[1] == "decider":
        try:
            with open(argv[2], encoding="utf-8") as f:
                resume = json.load(f)
        except (OSError, ValueError) as erreur:
            print(f"INCONNU : résumé de xcresult illisible ({erreur})", file=sys.stderr)
            return 2
        sortie, motif, seuls = decider(resume)
        print(motif, file=sys.stderr)
        print("\n".join(seuls))
        return sortie
    if len(argv) == 4 and argv[1] == "relance-verte":
        try:
            with open(argv[2], encoding="utf-8") as f:
                verte, motif = relance_verte(json.load(f), int(argv[3]))
        except (OSError, ValueError) as erreur:
            verte, motif = False, f"INCONNU : résumé de la relance illisible ({erreur})"
        print(motif)
        return 0 if verte else 1
    if len(argv) == 4 and argv[1] == "lenteurs":
        with open(argv[2], encoding="utf-8", errors="replace") as f:
            lignes, annotations = rendre_lenteurs(lenteurs(f.read()))
        with open(argv[3], "a", encoding="utf-8") as f:
            f.write("\n".join(lignes) + "\n\n")
        print("\n".join(annotations))
        return 0
    print("usage : bilan_tests_ui.py --autotest | decider <résumé.json> | relance-verte <résumé.json> <n> "
          "| lenteurs <journal> <résumé.md>",
          file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
