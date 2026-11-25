#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Un rouge de `main` ou d'un passage planifié ouvre un ticket « CI rouge : <workflow> » (#362).

Socle `standards/07` §1 bis : le courriel de GitHub n'est pas un destinataire — il n'avait rien
fait voir en sept jours de rouge sur le site (23 au 30/10/2026) ; ici, `main` est restée rouge
neuf heures le 19/11 (#353). Le pas est le DERNIER de chaque job, `if: failure()` :

    - name: Alerte d'un rouge (scripts/signaler_rouge.py)
      if: failure()
      env:
        GH_TOKEN: ${{ github.token }}
      run: python3 -I scripts/signaler_rouge.py --signaler

Quand : un passage planifié, ou une poussée ou un lancement à la main sur `main` — jamais une
PR ni une autre branche : son auteur voit le rouge là où il travaille. Un ticket ouvert par
workflow, reconnu à son titre exact ; un échec suivant le complète, au plus une fois toutes les
`DELAI_HEURES` (standards/07 §3). Il se ferme à la main, avec le passage vert qui le prouve.

`--verifier` (lancé par `scripts/verifier-ci.py`) refuse un job sans ce pas en dernier, et un
workflow sans `issues: write`. Une seule dispense, déclarée (`DISPENSES`) : un job qui exécute
le code d'une PR au jeton en lecture seule — son rouge est signalé par le job qui le suit.

Sortie : 0 signalé ou rien à signaler, 1 envoi impossible ou écart. `--autotest`.
"""

from __future__ import annotations

import contextlib
import io
import json
import os
import pathlib
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone

RACINE = pathlib.Path(__file__).resolve().parent.parent
WORKFLOWS = RACINE / ".github" / "workflows"
PAS = "python3 -I scripts/signaler_rouge.py --signaler"
ETIQUETTE = "priorité haute"
DELAI_HEURES = 12
#: (workflow, job) → raison. Une dispense sans objet échoue.
DISPENSES = {
    ("ci.yml", "ios"): "l'agrégat requis ne tourne que sur les PR (`if: … pull_request`) : un rouge de PR se voit "
                       "sur la PR, et chaque job de main a sa propre alerte",
    ("depot-a-jour.yml", "juger"): "exécute le code des PR au jeton en lecture seule : sans droit d'écrire "
                                   "un ticket, son rouge est signalé par « agir », qui le suit toujours",
}


def titre(workflow: str) -> str:
    return f"CI rouge : {workflow}"


def decider(evenement: str, ref: str, workflow: str, ouverts: list[dict], maintenant: datetime) -> tuple[str, str]:
    """PURE : ("rien", raison) | ("creer", titre) | ("commenter", numéro)."""
    if evenement != "schedule" and not (evenement in ("push", "workflow_dispatch") and ref == "refs/heads/main"):
        return "rien", f"{evenement} sur {ref} : le rouge se voit là où l'on travaille"
    for ticket in ouverts:
        if ticket.get("title") == titre(workflow):
            vu = datetime.fromisoformat(ticket.get("updatedAt", "1970-01-01T00:00:00Z").replace("Z", "+00:00"))
            if maintenant - vu < timedelta(hours=DELAI_HEURES):
                return "rien", f"déjà signalé au ticket #{ticket['number']} il y a moins de {DELAI_HEURES} h"
            return "commenter", str(ticket["number"])
    return "creer", titre(workflow)


def corps(env: dict) -> str:
    adresse = f"{env.get('GITHUB_SERVER_URL', 'https://github.com')}/{env.get('GITHUB_REPOSITORY', '?')}"
    return (f"❌ « {env.get('GITHUB_WORKFLOW', '?')} », job `{env.get('GITHUB_JOB', '?')}`, rouge "
            f"({env.get('GITHUB_EVENT_NAME', '?')}, commit {env.get('GITHUB_SHA', '?')[:7]}) : "
            f"{adresse}/actions/runs/{env.get('GITHUB_RUN_ID', '?')}\n\nUn main rouge passe avant tout autre "
            "lot (standards/09 §8 bis). Le même test sur main avant de parler d'instabilité. Signalé par "
            "`scripts/signaler_rouge.py` (#362) ; fermer au passage vert qui le prouve.")


def signaler(env: dict, gh) -> int:
    depot, workflow = env.get("GITHUB_REPOSITORY", ""), env.get("GITHUB_WORKFLOW", "")
    if not depot or not workflow:
        print("::error::GITHUB_REPOSITORY ou GITHUB_WORKFLOW absent : rien n'a été signalé")
        return 1
    try:
        ouverts = json.loads(gh(["issue", "list", "-R", depot, "--state", "open", "--limit", "200",
                                 "--json", "number,title,updatedAt"]))
        geste, valeur = decider(env.get("GITHUB_EVENT_NAME", ""), env.get("GITHUB_REF", ""), workflow, ouverts,
                                datetime.now(timezone.utc))
        if geste == "rien":
            print(f"signaler_rouge : rien à signaler ({valeur})")
        elif geste == "commenter":
            gh(["issue", "comment", valeur, "-R", depot, "--body", corps(env)])
            print(f"signaler_rouge : ticket #{valeur} complété")
        else:
            base = ["issue", "create", "-R", depot, "--title", valeur, "--body", corps(env)]
            try:
                print(gh([*base, "--label", ETIQUETTE]).strip())
            except subprocess.CalledProcessError:
                print(gh(base).strip())  # une étiquette renommée ne tait pas l'alerte
        return 0
    except (OSError, ValueError, subprocess.CalledProcessError) as erreur:
        print(f"::error::signaler_rouge : le ticket n'a pas pu s'ouvrir ({erreur})")
        return 1


def jobs(texte: str) -> dict[str, str]:
    """Les jobs d'un workflow, au texte : de `  <job>:` à la clé suivante au même retrait."""
    bloc = texte.split("\njobs:\n", 1)[1] if "\njobs:\n" in texte else ""
    morceaux = re.split(r"^  ([A-Za-z0-9_-]+):\s*$", bloc, flags=re.M)
    return dict(zip(morceaux[1::2], morceaux[2::2]))


def ecarts(fichiers: dict[str, str]) -> list[str]:
    if not fichiers:
        return ["❓ INCONNU : aucun workflow lu"]
    fautes, servies = [], set()
    for nom, texte in sorted(fichiers.items()):
        lus = jobs(texte)
        if not lus:
            fautes.append(f"❓ INCONNU : {nom} sans job lu")
        if not re.search(r"^\s+issues: write\b", texte, re.M):
            fautes.append(f"❌ {nom} : aucun `issues: write` — le ticket ne pourrait pas s'ouvrir")
        for job, corps_job in lus.items():
            if (nom, job) in DISPENSES:
                servies.add((nom, job))
                continue
            etapes = re.split(r"^      - ", corps_job, flags=re.M)[1:]
            dernier = etapes[-1] if etapes else ""
            if PAS not in dernier or not re.search(r"^\s+if: failure\(\)", dernier, re.M):
                fautes.append(f"❌ {nom}, job « {job} » : son dernier pas n'est pas l'alerte `if: failure()` → {PAS}")
    fautes += [f"❌ dispense {n} « {j} » sans objet — la retirer"
               for n, j in sorted(set(DISPENSES) - servies) if n in fichiers]
    return fautes


def autotest() -> bool:
    t = datetime(2026, 11, 24, 12, tzinfo=timezone.utc)
    ouvert = [{"number": 7, "title": titre("CI"), "updatedAt": "2026-11-23T06:00:00Z"}]
    recent = [{"number": 7, "title": titre("CI"), "updatedAt": "2026-11-24T11:30:00Z"}]
    ok = decider("push", "refs/heads/main", "CI", [], t)[0] == "creer"
    ok &= decider("schedule", "refs/heads/main", "CI", ouvert, t) == ("commenter", "7")
    ok &= decider("schedule", "refs/heads/main", "CI", recent, t)[0] == "rien"
    ok &= decider("pull_request", "refs/pull/3/merge", "CI", [], t)[0] == "rien"
    ok &= decider("push", "refs/heads/claude/x", "CI", [], t)[0] == "rien"
    alerte = f"      - name: Alerte\n        if: failure()\n        run: {PAS}\n"
    sain = "permissions:\n  issues: write\njobs:\n  a:\n    steps:\n      - run: x\n" + alerte
    ok &= ecarts({"w.yml": sain}) == []
    ok &= len(ecarts({"w.yml": sain + "  b:\n    steps:\n      - run: y\n"})) == 1          # un job muet
    ok &= len(ecarts({"w.yml": sain.replace("        if: failure()\n", "")})) == 1          # sans la condition
    ok &= ecarts({"w.yml": sain.replace("if: failure()", "if: failure() || needs.a.result != 'success'")}) == []
    ok &= len(ecarts({"w.yml": sain + "      - run: apres\n"})) == 1                         # pas le dernier
    ok &= len(ecarts({"w.yml": sain.replace("  issues: write\n", "")})) == 1                # sans le droit
    ok &= len(ecarts({"depot-a-jour.yml": sain})) == 1                                         # dispense sans objet
    ok &= ecarts({}) != []
    sortie: list[list[str]] = []

    def gh(args: list[str]) -> str:
        sortie.append(args)
        return "[]" if args[:2] == ["issue", "list"] else "https://x/1\n"
    env = {"GITHUB_REPOSITORY": "d/r", "GITHUB_WORKFLOW": "CI", "GITHUB_EVENT_NAME": "push", "GITHUB_REF": "refs/heads/main"}
    with contextlib.redirect_stdout(io.StringIO()):
        ok &= signaler(env, gh) == 0 and sortie[-1][:2] == ["issue", "create"]
    return bool(ok)


def main() -> int:
    if sys.argv[1:] == ["--autotest"]:
        ok = autotest()
        print("✅ autotest de l'alerte d'un rouge" if ok else "❌ autotest de l'alerte d'un rouge en échec")
        return 0 if ok else 1
    if sys.argv[1:] == ["--signaler"]:
        return signaler(dict(os.environ),
                        lambda a: subprocess.run(["gh", *a], capture_output=True, text=True, check=True).stdout)
    if sys.argv[1:] == ["--verifier"]:
        fichiers = {f.name: f.read_text(encoding="utf-8") for f in sorted(WORKFLOWS.glob("*.yml"))}
        fautes = ecarts(fichiers)
        print("\n".join(fautes) if fautes else f"✅ {len(fichiers)} workflows : chaque job finit par l'alerte d'un rouge")
        return 1 if fautes else 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
