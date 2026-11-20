# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Le runner des tests d'interface a-t-il démarré ? Lu dans le journal de `xcodebuild test`.

    python3 -I scripts/demarrage_runner.py <journal>

Le 19/11/2026 (#50, run 44569208311, essai 1, lot 2/5 de #299), le runner n'a jamais
démarré : « Timed out waiting for AX loaded notification », puis « The test runner failed
to initialize for UI testing », et AUCUN test joué. Rien de l'app n'a été jugé : le
passage se rejoue une fois, déclaré (`scripts/tests-simulateur.sh`). Dès qu'un test a
démarré, ce n'est plus un démarrage raté — la décision revient à `bilan_tests_ui.py
decider` (ses causes, son plafond).

Sortie : 0 et la cause (un démarrage raté, aucun test joué) ; 1 et le motif sinon ;
2 (INCONNU) si le journal ne se lit pas — jamais une relance sur ce qu'on n'a pas lu.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from bilan_tests_ui import DEBUT_TEST  # noqa: E402  (le même repère de début de test)

#: Le message de xcodebuild quand le runner ne s'initialise pas ; sa cause suit.
RATE = "The test runner failed to initialize for UI testing"
CAUSE = re.compile(re.escape(RATE) + r"\. \(Underlying Error: (?P<cause>[^)]*)\)")


def demarrage(journal: str) -> tuple[int, str]:
    if DEBUT_TEST.search(journal):
        return 1, "des tests ont démarré : ce n'est pas un démarrage raté du runner"
    if RATE not in journal:
        return 1, "le runner n'a pas signalé d'échec d'initialisation"
    trouve = CAUSE.search(journal)
    cause = trouve["cause"] if trouve else "cause non dite"
    return 0, f"runner de tests jamais initialisé ({cause}), aucun test joué"


# ── Autotest ────────────────────────────────────────────────────────────────────
#: L'extrait réel du journal du 19/11/2026 (run 44569208311, job 135719399078).
RATE_REEL = """\
CoproFirstUITests-Runner[21345:62325] [Default] Failed to initialize for UI testing: Error Domain=XCTDaemonErrorDomain Code=18 "Timed out waiting for AX loaded notification"
\tCoproFirstUITests-Runner (21345) encountered an error (The test runner failed to initialize for UI testing. (Underlying Error: Timed out waiting for AX loaded notification))
** TEST FAILED **
"""
DEBUT = "Test Case '-[CoproFirstUITests.AccesUITests testLesQuatreOngletsSOuvrent]' started.\n"


def autotest() -> int:
    rates = []
    sortie, motif = demarrage(RATE_REEL)
    if sortie != 0 or "AX loaded notification" not in motif:
        rates.append(f"le démarrage raté du 19/11 : {sortie} ({motif})")
    # Un runner qui tombe APRÈS des tests joués : la décision est ailleurs (bilan_tests_ui).
    if demarrage(DEBUT + RATE_REEL)[0] != 1:
        rates.append("un échec d'initialisation après un test démarré ne rejoue pas le passage")
    if demarrage("** TEST FAILED **\n")[0] != 1:
        rates.append("un échec sans le message du runner ne rejoue rien")
    for r in rates:
        print(f"❌ {r}")
    print("✅ demarrage_runner : autotest" if not rates else f"── {len(rates)} cas en échec")
    return 0 if not rates else 1


def main(argv: list[str]) -> int:
    if argv == ["--autotest"]:
        return autotest()
    if len(argv) != 1:
        print("usage : demarrage_runner.py <journal> | --autotest", file=sys.stderr)
        return 2
    try:
        journal = Path(argv[0]).read_text(encoding="utf-8", errors="replace")
    except OSError as erreur:
        print(f"INCONNU : journal illisible ({erreur})")
        return 2
    sortie, motif = demarrage(journal)
    print(motif)
    return sortie


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
