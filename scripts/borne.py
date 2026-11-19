# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Lancer une commande sous une limite de temps qui COUPE : son groupe de processus entier.

    python3 -I scripts/borne.py SECONDES LIBELLE -- commande [arguments…]

Le 18/11/2026 (#293), `concordance.py` est resté figé 32 min au poste, et
`timeout 600 bash scripts/verifier-depot.sh` ne l'a pas arrêté : le signal touchait le
bash parent, l'enfant python continuait. Ici la commande tourne dans sa PROPRE session
(donc son propre groupe) ; à l'expiration, tout le groupe reçoit TERM, puis KILL après
un délai de grâce — aucun descendant ne survit, sauf celui qui ouvrirait lui-même une
nouvelle session (aucun des contrôles distants ne le fait).

Sortie : celle de la commande, ou 2 (INCONNU) à l'expiration — jamais 0, même si la
commande allait finir bien (standards/04 §1). Un TERM, INT ou HUP reçu par ce lanceur
coupe aussi le groupe, puis sort en 128 + signal.

La durée de l'étape s'écrit sur la sortie d'erreur (`⏱ LIBELLE : N s`) : une lenteur se
mesure, elle ne se devine pas (#293, `reuse lint` donné à plus de 6 min).

`--autotest` lance de vrais processus : la coupure d'un petit-enfant, un enfant qui
ignore TERM, le TERM reçu par le lanceur, et les sorties transmises.
"""

from __future__ import annotations

import os
import signal
import subprocess
import sys
import tempfile
import time

GRACE = 5.0
INCONNU = 2


def verdict(code: int, expire: bool) -> int:
    """La sortie du lanceur : INCONNU à l'expiration, quel que soit le code ; sinon celui de la commande."""
    return INCONNU if expire else code


def message_expiration(libelle: str, limite: float) -> str:
    return (f"❓ INCONNU : {libelle} — plus de {limite:g} s, arrêté avec tous ses descendants "
            "(groupe de processus) : rien n'a été jugé, ce n'est pas un vert.")


def _tuer_groupe(pgid: int, processus: subprocess.Popen, grace: float) -> None:
    """TERM au groupe, puis KILL au groupe après `grace` s — même si le chef est déjà mort."""
    for sig, attente in ((signal.SIGTERM, grace), (signal.SIGKILL, grace)):
        try:
            os.killpg(pgid, sig)
        except ProcessLookupError:
            return
        try:
            processus.wait(timeout=attente)
        except subprocess.TimeoutExpired:
            continue
        # Le chef est mort ; un descendant peut vivre encore : le groupe reçoit la suite.
        if sig == signal.SIGTERM:
            time.sleep(0.2)


def borner(limite: float, libelle: str, commande: list[str], grace: float = GRACE) -> int:
    debut = time.monotonic()
    processus = subprocess.Popen(commande, start_new_session=True)
    pgid = processus.pid  # chef de sa propre session, donc de son groupe

    def interrompre(signum, _frame):
        _tuer_groupe(pgid, processus, grace)
        sys.exit(128 + signum)

    for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        signal.signal(sig, interrompre)
    expire = False
    try:
        code = processus.wait(timeout=limite)
    except subprocess.TimeoutExpired:
        expire = True
        code = -1
    # Le chef a fini ou expiré : ses descendants restés dans le groupe ne lui survivent pas.
    _tuer_groupe(pgid, processus, grace)
    duree = time.monotonic() - debut
    if expire:
        print(message_expiration(libelle, limite), file=sys.stderr)
    print(f"⏱ {libelle} : {duree:.0f} s", file=sys.stderr)
    return verdict(code, expire)


# ── Autotest ────────────────────────────────────────────────────────────────────
def _vivant(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    # Un zombie n'est plus un processus qui travaille.
    etat = subprocess.run(["ps", "-o", "stat=", "-p", str(pid)], capture_output=True, text=True).stdout
    return bool(etat.strip()) and not etat.strip().startswith("Z")


def _pid_ecrit(fichier: str, attente: float = 5.0) -> int:
    fin = time.monotonic() + attente
    while time.monotonic() < fin:
        try:
            with open(fichier, encoding="utf-8") as f:
                texte = f.read().strip()
            if texte:
                return int(texte)
        except (FileNotFoundError, ValueError):
            pass
        time.sleep(0.05)
    raise SystemExit(f"❌ autotest : {fichier} jamais écrit")


def _lancer(limite: float, script: str, journal: str, grace: float = 1.0) -> subprocess.Popen:
    """Le lanceur lui-même, dans un processus à part, comme l'appelle controles-distants.sh.

    Sa sortie d'erreur va dans un FICHIER : un descendant survivant tiendrait un tube
    ouvert, et l'autotest d'un lanceur fautif resterait figé au lieu de rougir."""
    with open(journal, "w", encoding="utf-8") as sortie:
        return subprocess.Popen(
            [sys.executable, "-I", __file__, "--grace", str(grace), str(limite), "étape d'essai", "--",
             "bash", "-c", script], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=sortie)


def _finir(lanceur: subprocess.Popen, journal: str) -> tuple[int | None, str]:
    """(sortie du lanceur, ce qu'il a écrit) ; None s'il n'a pas fini en 30 s."""
    try:
        code = lanceur.wait(timeout=30)
    except subprocess.TimeoutExpired:
        lanceur.kill()
        code = None
    with open(journal, encoding="utf-8") as f:
        return code, f.read()


def _attendre_mort(pid: int, attente: float = 5.0) -> bool:
    fin = time.monotonic() + attente
    while time.monotonic() < fin:
        if not _vivant(pid):
            return True
        time.sleep(0.05)
    return False


def autotest() -> int:
    rates = []
    if verdict(0, True) != INCONNU or verdict(1, True) != INCONNU or verdict(0, False) != 0 or verdict(3, False) != 3:
        rates.append("verdict : une expiration doit rendre INCONNU, jamais le code de la commande")
    with tempfile.TemporaryDirectory(prefix="borne-") as d:
        f, j = os.path.join(d, "pid"), os.path.join(d, "journal")
        cas = [
            # Le cas du 18/11 : un enfant figé derrière un parent qui attend.
            ("petit-enfant figé", f"sleep 300 & echo $! > {f}; wait", 1.0),
            # Un enfant qui ignore TERM : KILL après la grâce.
            ("enfant sourd à TERM", f"trap '' TERM; (trap '' TERM; sleep 300) & echo $! > {f}; wait", 1.0),
        ]
        for nom, script, limite in cas:
            os.path.exists(f) and os.remove(f)
            debut = time.monotonic()
            lanceur = _lancer(limite, script, j)
            pid = _pid_ecrit(f)
            code, erreur = _finir(lanceur, j)
            if code != INCONNU or "INCONNU" not in erreur:
                rates.append(f"{nom} : sortie {code} (attendu {INCONNU}), message {erreur!r}")
            if not _attendre_mort(pid):
                rates.append(f"{nom} : le descendant {pid} survit à l'expiration")
                os.kill(pid, signal.SIGKILL)
            if time.monotonic() - debut > 15:
                rates.append(f"{nom} : la coupure a pris plus de 15 s")
        # Le lanceur reçoit TERM (un `timeout` extérieur, un arrêt à la main) : le groupe suit.
        os.remove(f)
        lanceur = _lancer(300, f"sleep 300 & echo $! > {f}; wait", j)
        pid = _pid_ecrit(f)
        lanceur.send_signal(signal.SIGTERM)
        code, _ = _finir(lanceur, j)
        if code != 128 + signal.SIGTERM:
            rates.append(f"TERM reçu : sortie {code} (attendu {128 + signal.SIGTERM})")
        if not _attendre_mort(pid):
            rates.append(f"TERM reçu : le descendant {pid} survit au lanceur")
            os.kill(pid, signal.SIGKILL)
        # Sous la limite, le code de la commande passe tel quel, et la durée se dit.
        for code in (0, 1, 2):
            rendu, erreur = _finir(_lancer(30, f"exit {code}", j), j)
            if rendu != code or "⏱ étape d'essai :" not in erreur or "INCONNU" in erreur:
                rates.append(f"sortie {code} sous la limite : rendu {rendu}, message {erreur!r}")
    for r in rates:
        print(f"❌ {r}")
    print("✅ borne : autotest" if not rates else f"── {len(rates)} cas en échec")
    return 0 if not rates else 1


def main(argv: list[str]) -> int:
    if argv == ["--autotest"]:
        return autotest()
    grace = GRACE
    if argv[:1] == ["--grace"] and len(argv) > 1:
        grace, argv = float(argv[1]), argv[2:]
    if len(argv) < 4 or argv[2] != "--":
        print("usage : borne.py [--grace S] SECONDES LIBELLE -- commande [arguments…] | --autotest", file=sys.stderr)
        return INCONNU
    try:
        limite = float(argv[0])
    except ValueError:
        print(f"❓ INCONNU : limite illisible ({argv[0]!r})", file=sys.stderr)
        return INCONNU
    return borner(limite, argv[1], argv[3:], grace)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
