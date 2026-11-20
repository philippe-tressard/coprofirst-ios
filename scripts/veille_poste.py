# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Le Mac s'est-il mis en veille pendant le passage ? Lu dans `pmset -g log`.

    python3 -I scripts/veille_poste.py <début> <fin>     (secondes depuis l'époque)
    python3 -I scripts/veille_poste.py --autotest

Le 20/11/2026 (#322), une passe de `tests-simulateur.sh` a joué de 07:23 à 08:24 sur un
poste en « Maintenance Sleep » presque tout ce temps : HistoriqueUITests à 1531 et 1727 s
(20 à 130 s en CI), « Timed out while synthesizing event », des trous de 400 à 940 s dans
le journal — la durée exacte des veilles. Le test était accusé ; c'était le poste.
`tests-simulateur.sh` empêche la veille (`caffeinate`), et ce script dit au résumé si
elle a eu lieu quand même : un rouge sous veille n'est pas un défaut du test.

Sortie : 0 aucune veille ; 1 et la liste (heure, durée) ; 2 (INCONNU) si le journal ne se
lit pas — jamais « aucune veille » sur ce qu'on n'a pas lu. `PMSET_JOURNAL` remplace
`pmset -g log` par un fichier (l'autotest de tests-simulateur.sh).
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
from datetime import datetime

#: « 2026-11-20 07:31:46 +0100 Sleep  …  Using AC (Charge:0%) 923 secs »
VEILLE = re.compile(r"^(?P<quand>\d{4}-\d\d-\d\d \d\d:\d\d:\d\d [+-]\d{4}) Sleep\s.*?(?P<duree>\d+) secs\s*$")


def veilles(journal: str, debut: float, fin: float) -> list[tuple[str, int]]:
    """Chaque veille entrée entre `debut` et `fin` : (heure, durée en secondes)."""
    trouvees = []
    for ligne in journal.splitlines():
        if m := VEILLE.match(ligne):
            quand = datetime.strptime(m["quand"], "%Y-%m-%d %H:%M:%S %z")
            if debut <= quand.timestamp() <= fin:
                trouvees.append((quand.strftime("%H:%M:%S"), int(m["duree"])))
    return trouvees


def dire(trouvees: list[tuple[str, int]]) -> tuple[int, str]:
    if not trouvees:
        return 0, "aucune veille du poste pendant le passage"
    total = sum(d for _, d in trouvees)
    liste = ", ".join(f"{h} ({d} s)" for h, d in trouvees)
    return 1, f"{len(trouvees)} veille(s) du poste pendant le passage, {total} s en tout : {liste}"


def lire_journal() -> str | None:
    if chemin := os.environ.get("PMSET_JOURNAL"):
        try:
            with open(chemin, encoding="utf-8", errors="replace") as f:
                return f.read()
        except OSError:
            return None
    try:
        fait = subprocess.run(["pmset", "-g", "log"], capture_output=True, text=True, timeout=60, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return fait.stdout if fait.returncode == 0 else None


# ── Autotest ────────────────────────────────────────────────────────────────────
#: Extrait réel de `pmset -g log` du 20/11/2026 (raccourci aux colonnes lues).
JOURNAL_REEL = """\
2026-11-20 07:21:11 +0100 DarkWake            \tDarkWake from Deep Idle [CDNPB] : due to SMC.OutboxNotEmpty Using AC (Charge:0%) 195 secs
2026-11-20 07:24:26 +0100 Sleep               \tEntering Sleep state due to 'Maintenance Sleep':TCPKeepAlive=active Using AC (Charge:0%) 409 secs
2026-11-20 07:31:46 +0100 Sleep               \tEntering Sleep state due to 'Maintenance Sleep':TCPKeepAlive=active Using AC (Charge:0%) 923 secs
2026-11-20 07:31:48 +0100 Wake Requests       \t[process=dasd request=SleepService deltaSecs=961]
2026-11-20 08:24:43 +0100 Wake                \tWake from Deep Idle [CDNVA] : due to SMC.OutboxNotEmpty Using AC (Charge:0%)
"""


def _epoque(texte: str) -> float:
    return datetime.strptime(texte, "%Y-%m-%d %H:%M:%S %z").timestamp()


def autotest() -> int:
    rates = []
    debut, fin = _epoque("2026-11-20 07:23:15 +0100"), _epoque("2026-11-20 08:24:53 +0100")
    sortie, motif = dire(veilles(JOURNAL_REEL, debut, fin))
    if sortie != 1 or "2 veille(s)" not in motif or "1332 s" not in motif or "07:31:46 (923 s)" not in motif:
        rates.append(f"la passe du 20/11 sous veille : {sortie} ({motif})")
    # Une veille AVANT le passage ne le concerne pas.
    if dire(veilles(JOURNAL_REEL, _epoque("2026-11-20 07:40:00 +0100"), fin))[0] != 0:
        rates.append("une veille d'avant le passage lui est comptée")
    if dire(veilles("", debut, fin))[0] != 0:
        rates.append("un journal sans veille en dit une")
    for r in rates:
        print(f"❌ {r}")
    print("✅ veille_poste : autotest" if not rates else f"── {len(rates)} cas en échec")
    return 0 if not rates else 1


def main(argv: list[str]) -> int:
    if argv == ["--autotest"]:
        return autotest()
    try:
        debut, fin = (float(a) for a in argv)
    except ValueError:
        print("usage : veille_poste.py <début> <fin> | --autotest", file=sys.stderr)
        return 2
    journal = lire_journal()
    if journal is None:
        print("INCONNU : le journal d'alimentation (pmset -g log) ne se lit pas")
        return 2
    sortie, motif = dire(veilles(journal, debut, fin))
    print(motif)
    return sortie


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
