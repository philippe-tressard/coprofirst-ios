#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""La santé de `main` (#353) : ses dernières poussées, et un ticket au-delà d'un seuil de rouges.

Du 17 au 22/11/2026, `main` a été rouge 9 fois sur 40 poussées, dont quatre fois le job requis
« Dépôt », neuf heures durant, sans que rien ne le signale : chaque rouge était vu par la
session qui fusionnait, jamais leur somme. Ce juge, joué chaque jour par
`.github/workflows/sante-main.yml`, lit les `FENETRE` dernières poussées de `main` dont la CI
a conclu (`gh run list … --json`) et décide, sur une fonction pure :

- une poussée ANNULÉE (remplacée par la suivante, file par lot de #235) n'est ni verte ni rouge :
  elle ne compte pas, mais le rapport la nomme — une fusion sans CI verte à elle ;
- `SEUIL` rouges ou plus parmi les poussées jugées : ticket ouvert, ou tenu à jour s'il l'est ;
- moins : le ticket ouvert se ferme, en citant le run ;
- moins de `MINIMUM` poussées jugées, ou une conclusion inconnue : INCONNU — rien ne se ferme.

Le ticket se reconnaît à son étiquette ET à son titre (`TITRE`), comme ceux de la concordance
(#93). Usage :
  gh run list … --json conclusion,headSha,databaseId,createdAt | sante_main.py decider N_TICKET
      (sortie `cle=valeur` pour $GITHUB_OUTPUT ; le rapport en Markdown sur --rapport FICHIER)
  gh issue list --label sante-main --json number,title | sante_main.py choisir
  sante_main.py titre      (le titre du ticket à ouvrir)
  sante_main.py --autotest
"""

from __future__ import annotations

import json
import os
import sys
from dataclasses import dataclass

FENETRE = 20
SEUIL = 3
MINIMUM = 10
ETIQUETTE = "sante-main"
TITRE = "main : trop de rouges sur ses dernières poussées"
ROUGES = {"failure", "timed_out", "startup_failure"}
VERTS = {"success"}
NEUTRES = {"cancelled", "skipped"}


@dataclass(frozen=True)
class Bilan:
    verdict: str  # vert | rouge | inconnu
    ticket: str  # ouvrir | mettre-a-jour | fermer | rien
    rouges: list[dict]
    annulees: list[dict]
    jugees: int


def bilan(runs: list[dict], ticket_ouvert: bool) -> Bilan:
    """`runs` : du plus récent au plus ancien, comme `gh run list` les rend."""
    conclues = [r for r in runs if r.get("conclusion")]
    inconnues = [r for r in conclues if r["conclusion"] not in ROUGES | VERTS | NEUTRES]
    jugees = [r for r in conclues if r["conclusion"] in ROUGES | VERTS][:FENETRE]
    rouges = [r for r in jugees if r["conclusion"] in ROUGES]
    depuis = jugees[-1]["createdAt"] if jugees else ""
    annulees = [r for r in conclues if r["conclusion"] in NEUTRES and r.get("createdAt", "") >= depuis]
    if inconnues or len(jugees) < MINIMUM:
        return Bilan("inconnu", "rien", rouges, annulees, len(jugees))
    if len(rouges) >= SEUIL:
        return Bilan("rouge", "mettre-a-jour" if ticket_ouvert else "ouvrir", rouges, annulees, len(jugees))
    return Bilan("vert", "fermer" if ticket_ouvert else "rien", rouges, annulees, len(jugees))


def rapport(b: Bilan, depot: str) -> str:
    lien = lambda r: f"[`{r['headSha'][:7]}`](https://github.com/{depot}/actions/runs/{r['databaseId']})"  # noqa: E731
    lignes = [f"**{len(b.rouges)} rouge(s)** sur les {b.jugees} dernières poussées de `main` jugées "
              f"(seuil : {SEUIL} sur {FENETRE}) — verdict : {b.verdict}.", ""]
    lignes += [f"- ❌ {lien(r)} ({r['conclusion']}, {r['createdAt']})" for r in b.rouges]
    if b.annulees:
        lignes += ["", f"Fusions sans CI verte à elles (annulées, remplacées par la suivante) : "
                   + ", ".join(lien(r) for r in b.annulees) + "."]
    lignes += ["", "Chaque rouge : le même test sur `main` avant de parler d'instabilité ; un ticket par "
               "test qui revient (#353)."]
    return "\n".join(lignes) + "\n"


def choisir(tickets: list[dict]) -> str:
    return next((str(t["number"]) for t in tickets if t.get("title") == TITRE), "")


def autotest() -> bool:
    def runs(*conclusions: str) -> list[dict]:
        return [{"conclusion": c, "headSha": f"{i:07x}", "databaseId": i, "createdAt": f"2026-11-{30 - i:02d}"}
                for i, c in enumerate(conclusions)]
    vert = runs(*["success"] * 12)
    cas = [
        (bilan(vert, False), ("vert", "rien")),
        (bilan(vert, True), ("vert", "fermer")),
        (bilan(runs("failure", "failure", "timed_out", *["success"] * 9), False), ("rouge", "ouvrir")),
        (bilan(runs("failure", "failure", "timed_out", *["success"] * 9), True), ("rouge", "mettre-a-jour")),
        (bilan(runs("failure", "cancelled", "cancelled", "failure", *["success"] * 9), True), ("vert", "fermer")),
        (bilan(runs(*["success"] * 5), True), ("inconnu", "rien")),                  # trop peu jugé
        (bilan(runs("action_required", *["success"] * 12), True), ("inconnu", "rien")),  # conclusion inconnue
        (bilan(runs(*["success"] * 20, "failure", "failure", "failure"), False), ("vert", "rien")),  # hors fenêtre
    ]
    ok = all((b.verdict, b.ticket) == attendu for b, attendu in cas)
    annule = bilan(runs("success", "cancelled", *["success"] * 11), False)
    ok = ok and len(annule.annulees) == 1 and "annulées" in rapport(annule, "d/r")
    ok = ok and choisir([{"number": 5, "title": "autre"}, {"number": 9, "title": TITRE}]) == "9"
    return ok and choisir([{"number": 5, "title": "autre"}]) == ""


def main() -> int:
    args = sys.argv[1:]
    if args == ["--autotest"]:
        ok = autotest()
        print("✅ autotest de la santé de main" if ok else "❌ autotest de la santé de main en échec")
        return 0 if ok else 1
    if args == ["titre"]:
        print(TITRE)
        return 0
    if args == ["choisir"]:
        print(choisir(json.load(sys.stdin)))
        return 0
    if args[:1] == ["decider"] and len(args) in (2, 4) and (len(args) == 2 or args[2] == "--rapport"):
        try:
            runs = json.load(sys.stdin)
        except json.JSONDecodeError:
            runs = []
        b = bilan(runs, bool(args[1]))
        if len(args) == 4:
            with open(args[3], "w", encoding="utf-8") as f:
                f.write(rapport(b, os.environ.get("GITHUB_REPOSITORY", "philippe-tressard/coprofirst-ios")))
        print(f"verdict={b.verdict}\nticket={b.ticket}")
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
