#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Le CONTRÔLE AVANT SOUMISSION à l'App Store (#205 ; socle standards/09 §8 bis) : entre
les lots, la vitesse ; à la soumission, la cohérence maximale. Une commande, qui refuse
de continuer sur le moindre rouge — et un INCONNU est un refus, jamais un vert.

Ce qu'elle juge, sur le commit EXACT qui sera soumis (le `HEAD`, égal à `origin/main`) :
1. le clone : propre, `HEAD` = `origin/main` ;
2. la version : `MARKETING_VERSION` et `CURRENT_PROJECT_VERSION` de `project.yml` ;
   l'étiquette `vX.Y.Z` n'est sur aucun AUTRE commit, et le build monte depuis la
   dernière version étiquetée (App Store Connect refuse un build déjà envoyé) ;
3. la CI complète de ce commit (`ci.yml`) : terminée, chaque job vert, tests d'interface
   compris — une CI « documentation seule » qui les a sautés ne suffit pas ;
4. la concordance avec le contrat SERVI en production (`concordance.py --plancher`, qui
   mesure chaque installation connue) ;
5. le contrôle du dépôt (`verifier-depot.sh` : confidentialité déclarée = code, licences…) ;
6. aucun ticket ouvert marqué `bloque-soumission` (le label manquant : INCONNU) ;
7. les écrans principaux en SOMBRE et en très grand texte (`GrandTexteUITests`, au
   simulateur, captures dans `.build/Soumission/`) ;
8. ce que seul Philippe voit — captures déposées (iPhone ; iPad 13 pouces), notes de
   version, étiquette App Privacy saisie, rendu validé — se CONFIRME par `--confirme`,
   nommément ; sans confirmation : INCONNU.

La parité avec l'Android (matrice coprofirst-android#12) n'est PAS une condition : sortir
ensemble est une occasion, plus une règle (décision de Philippe, 18/11/2026). Le compte
rendu la rappelle, sans rien juger.

`--etiqueter` pose et pousse l'étiquette annotée `vX.Y.Z` sur ce commit, et seulement si
tout est vert. Rien ne se soumet ici : la soumission reste le geste de Philippe (skill
`publication-app-store`). L'étiquette posée, le compte rendu dit la déclaration à faire
dans coprofirst (`declaration`, #354) : la CI du serveur refuse toute étiquette de l'app
qui n'est pas dans `EN_CIRCULATION` (`check_versions_en_circulation.py`, coprofirst#3023).

Usage : python3 scripts/avant_soumission.py [--confirme a,b,…] [--etiqueter] [--rapport F.md]
        python3 scripts/avant_soumission.py --autotest
Sortie : 0 tout vert, 1 un rouge, 2 un INCONNU.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import subprocess
import sys

RACINE = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RACINE / "scripts"))
from generateurs import _plancher  # noqa: E402  (la version sur laquelle l'app se génère)
OK, ROUGE, INCONNU = "✅", "❌", "❓"
LABEL = "bloque-soumission"
#: Ce que seul Philippe peut voir : il le confirme, nommément (`--confirme`).
CONFIRMATIONS = {
    "captures": "captures déposées dans App Store Connect (iPhone ; iPad 13 pouces)",
    "notes": "notes de version saisies, et description à jour (fiche de la skill)",
    "confidentialite": "étiquette App Privacy saisie, égale à la fiche (confidentialite.md)",
    "rendu": "rendu validé par Philippe pour CETTE version (simulateur, iPhone, TestFlight interne)",
}


def lancer(*commande: str) -> tuple[int, str]:
    """(code, sortie) ; une commande introuvable : code 127."""
    try:
        fini = subprocess.run(commande, cwd=RACINE, capture_output=True, text=True, check=False)
    except OSError as erreur:
        return 127, str(erreur)
    return fini.returncode, (fini.stdout + fini.stderr).strip()


def version(project_yml: str) -> tuple[str, str] | None:
    """(« 1.1.0 », « 2 ») lus dans project.yml ; `None` s'ils manquent."""
    marketing = re.search(r'^\s*MARKETING_VERSION:\s*"?([0-9]+(?:\.[0-9]+){0,2})"?\s*$', project_yml, re.M)
    build = re.search(r'^\s*CURRENT_PROJECT_VERSION:\s*"?([0-9]+)"?\s*$', project_yml, re.M)
    if not marketing or not build:
        return None
    nombres = marketing[1].split(".")
    return ".".join(nombres + ["0"] * (3 - len(nombres))), build[1]


#: Les seuls jobs qui se sautent sur un push de main : l'agrégat (`ios`), qui ne tourne
#: que sur une PR (`if: … github.event_name == 'pull_request'`) — sur main, chaque job
#: parle pour lui-même. Tout autre job sauté est un rouge.
SAUTES_PERMIS = frozenset({"Build, tests, SwiftLint"})
LOT_INTERFACE = re.compile(r"^Interface \((\d+)/(\d+)\)$")


def juger_ci(runs: list[dict], jobs: list[dict]) -> tuple[str, str]:
    """Le dernier run de ci.yml du commit, et ses jobs : tous verts, CHAQUE lot d'interface
    compris (k/N, de 1 à N) — un lot remplacé dans sa file (#235) n'a pas joué."""
    if not runs:
        return INCONNU, "aucun run de ci.yml sur ce commit"
    dernier = runs[0]
    if dernier.get("status") != "completed":
        return INCONNU, f"run {dernier.get('databaseId')} pas terminé ({dernier.get('status')})"
    if dernier.get("conclusion") != "success":
        return ROUGE, f"run {dernier.get('databaseId')} : {dernier.get('conclusion')}"
    rouges = [j["name"] for j in jobs if j.get("conclusion") != "success"
              and not (j["name"] in SAUTES_PERMIS and j.get("conclusion") == "skipped")]
    if rouges:
        return ROUGE, f"jobs non verts : {', '.join(rouges)} — relancer le run (gh run rerun)"
    lots = [LOT_INTERFACE.match(j["name"]) for j in jobs]
    lots = [(int(m[1]), int(m[2])) for m in lots if m]
    if not lots:
        return ROUGE, "aucun lot d'interface joué (CI « documentation seule ») : la CI complète manque"
    total = lots[0][1]
    if sorted(lots) != [(k, total) for k in range(1, total + 1)]:
        return ROUGE, f"lots d'interface incomplets : {sorted(k for k, _ in lots)} sur {total}"
    return OK, f"run {dernier['databaseId']} vert, {len(jobs)} jobs dont les {total} lots d'interface"


def juger_version(lue: tuple[str, str], etiquette: str, ailleurs: str | None, precedente: str,
                  avant: tuple[str, str] | None) -> tuple[str, str]:
    """L'étiquette libre, et le build au-dessus de celui de la dernière version étiquetée."""
    if ailleurs:
        return ROUGE, f"{etiquette} déjà posée sur {ailleurs} : monter MARKETING_VERSION"
    if avant is None:
        return INCONNU, "build de la dernière version étiquetée illisible"
    if int(lue[1]) <= int(avant[1]):
        return ROUGE, f"build {lue[1]} ≤ build {avant[1]} de {precedente} : monter CURRENT_PROJECT_VERSION"
    return OK, f"{lue[0]} (build {lue[1]}, après {precedente} build {avant[1]})"


def declaration(etiquette: str, plancher: str) -> str:
    """Ce que la version étiquetée doit trouver dans coprofirst (#354, coprofirst#3023)."""
    version = ".".join(etiquette.lstrip("v").split(".")[:2])
    return (f"→ À déclarer dans philippe-tressard/coprofirst : « contrat figé de coprofirst-ios {version} au "
            f"plancher {plancher} » — son entrée dans `EN_CIRCULATION` (étiquette {etiquette}) et son contrat "
            "figé. Sans elle, `check_versions_en_circulation.py` rougit toute PR du serveur ; le ticket de "
            "version ne se ferme pas avant.")


def verdict(etapes: list[tuple[str, str, str]]) -> int:
    """0 tout vert ; 1 dès un rouge ; 2 sinon dès un INCONNU."""
    etats = {etat for _, etat, _ in etapes}
    return 1 if ROUGE in etats else 2 if INCONNU in etats or not etapes else 0


def etapes(confirmees: set[str]) -> tuple[list[tuple[str, str, str]], str | None, str]:
    """Les huit jugements, le numéro de version (s'il se lit) et le commit."""
    faites: list[tuple[str, str, str]] = []
    _, sha = lancer("git", "rev-parse", "HEAD")
    code_f, _ = lancer("git", "fetch", "--quiet", "--tags", "origin", "main")
    _, distant = lancer("git", "rev-parse", "origin/main")
    _, sale = lancer("git", "status", "--porcelain")
    if code_f != 0:
        faites.append(("clone", INCONNU, "origin injoignable"))
    elif sale or sha != distant:
        faites.append(("clone", ROUGE, "copie modifiée, ou HEAD ≠ origin/main : on soumet le commit publié"))
    else:
        faites.append(("clone", OK, f"HEAD = origin/main = {sha[:7]}, propre"))

    lue = version((RACINE / "project.yml").read_text(encoding="utf-8"))
    etiquette = f"v{lue[0]}" if lue else None
    if not lue:
        faites.append(("version", INCONNU, "MARKETING_VERSION ou CURRENT_PROJECT_VERSION illisible"))
    else:
        _, porte = lancer("git", "rev-list", "-n", "1", etiquette)
        ailleurs = porte and not porte.startswith("fatal") and porte != sha
        code_t, precedente = lancer("git", "describe", "--tags", "--abbrev=0", "--match", "v[0-9]*", f"{sha}^")
        _, ancien_yml = lancer("git", "show", f"{precedente}:project.yml") if code_t == 0 else (1, "")
        avant = version(ancien_yml) if code_t == 0 else None
        faites.append(("version", *juger_version(lue, etiquette, porte[:7] if ailleurs else None, precedente, avant)))

    code, sortie = lancer("gh", "run", "list", "--workflow", "ci.yml", "--commit", sha,
                          "--json", "databaseId,status,conclusion", "--limit", "1")
    try:
        runs = json.loads(sortie) if code == 0 else None
        jobs = []
        if runs:
            code_j, sortie_j = lancer("gh", "run", "view", str(runs[0]["databaseId"]), "--json", "jobs")
            jobs = json.loads(sortie_j)["jobs"] if code_j == 0 else []
        faites.append(("CI complète", *juger_ci(runs, jobs)) if runs is not None
                      else ("CI complète", INCONNU, f"gh illisible : {sortie[:120]}"))
    except (ValueError, KeyError) as erreur:
        faites.append(("CI complète", INCONNU, f"réponse de gh illisible ({erreur!r})"))

    for nom, commande in [("concordance avec la production", ("python3", "-I", "scripts/concordance.py", "--plancher")),
                          ("contrôle du dépôt", ("bash", "scripts/verifier-depot.sh"))]:
        code, sortie = lancer(*commande)
        derniere = sortie.splitlines()[-1][:160] if sortie else ""
        faites.append((nom, OK if code == 0 else INCONNU if code == 2 else ROUGE, derniere))

    code, sortie = lancer("gh", "label", "list", "--search", LABEL, "--json", "name")
    code_i, ouverts = lancer("gh", "issue", "list", "--state", "open", "--label", LABEL, "--json", "number")
    try:
        existe = code == 0 and any(l["name"] == LABEL for l in json.loads(sortie))
        bloquants = [i["number"] for i in json.loads(ouverts)] if code_i == 0 else None
    except ValueError:
        existe, bloquants = False, None
    faites.append(("tickets bloquants", INCONNU if not existe or bloquants is None else ROUGE if bloquants else OK,
                   f"label {LABEL} absent ou gh illisible" if not existe or bloquants is None
                   else f"ouverts : {', '.join(f'#{n}' for n in bloquants)}" if bloquants else "aucun"))

    code, sortie = lancer("env", "TEST_RUNNER_THEME=sombre", "TEST_RUNNER_CAPTURES=.build/Soumission",
                          "bash", "scripts/tests-simulateur.sh", "-only-testing:CoproFirstUITests/GrandTexteUITests")
    faites.append(("sombre et très grand texte", OK if code == 0 else INCONNU if code == 2 else ROUGE,
                   "GrandTexteUITests vert, captures dans .build/Soumission" if code == 0 else sortie[-160:]))

    manquantes = [c for c in CONFIRMATIONS if c not in confirmees]
    faites.append(("vu par Philippe", OK if not manquantes else INCONNU,
                   "tout confirmé" if not manquantes
                   else "à confirmer (--confirme) : " + " ; ".join(f"{c} — {CONFIRMATIONS[c]}" for c in manquantes)))
    return faites, etiquette, sha


def autotest() -> int:
    """Un contrôle qui ne refuse rien ne prouve rien : chaque cas dans les deux sens."""
    rate = []
    if version('    MARKETING_VERSION: "1.1"\n    CURRENT_PROJECT_VERSION: "2"\n') != ("1.1.0", "2"):
        rate.append("version 1.1 / build 2")
    if version("    MARKETING_VERSION: \n") is not None:
        rate.append("version absente : None")
    interface = {"name": "Interface (1/1)", "conclusion": "success"}
    vert = {"databaseId": 1, "status": "completed", "conclusion": "success"}
    cas = [
        ([], [], INCONNU), ([{**vert, "status": "in_progress"}], [], INCONNU),
        ([{**vert, "conclusion": "failure"}], [], ROUGE),
        ([vert], [{"name": "Unitaires", "conclusion": "success"}], ROUGE),
        ([vert], [interface, {"name": "Unitaires", "conclusion": "failure"}], ROUGE),
        ([vert], [interface, {"name": "Documentation seule ?", "conclusion": "skipped"}], ROUGE),
        ([vert], [interface, {"name": "Build, tests, SwiftLint", "conclusion": "skipped"}], OK),
        ([vert], [interface, {"name": "Interface (2/2)", "conclusion": "success"}], ROUGE),
        ([vert], [{"name": "Interface (1/2)", "conclusion": "success"},
                  {"name": "Interface (2/2)", "conclusion": "cancelled"}], ROUGE),
        ([vert], [{"name": "Interface (2/2)", "conclusion": "success"},
                  {"name": "Interface (1/2)", "conclusion": "success"}], OK),
    ]
    for runs, jobs, attendu in cas:
        if juger_ci(runs, jobs)[0] != attendu:
            rate.append(f"CI {runs} {jobs} : {attendu} attendu")
    for args, attendu in [((("1.2.0", "3"), "v1.2.0", None, "v1.1.0", ("1.1.0", "2")), OK),
                          ((("1.2.0", "2"), "v1.2.0", None, "v1.1.0", ("1.1.0", "2")), ROUGE),
                          ((("1.1.0", "3"), "v1.1.0", "4a3ffa7", "v1.1.0", ("1.1.0", "2")), ROUGE),
                          ((("1.2.0", "3"), "v1.2.0", None, "v1.1.0", None), INCONNU)]:
        if juger_version(*args)[0] != attendu:
            rate.append(f"version {args} : {attendu} attendu")
    texte = declaration("v1.2.0", "v3.121.2")
    if not all(m in texte for m in ("coprofirst-ios 1.2 au plancher v3.121.2", "EN_CIRCULATION", "v1.2.0")):
        rate.append(f"déclaration : {texte}")
    for etats, attendu in [([OK, OK], 0), ([OK, INCONNU], 2), ([INCONNU, ROUGE], 1), ([], 2)]:
        if verdict([("x", e, "") for e in etats]) != attendu:
            rate.append(f"verdict {etats} : {attendu} attendu")
    for r in rate:
        print(f"❌ autotest : {r}")
    print("✅ avant_soumission : autotest" if not rate else f"── {len(rate)} cas en échec")
    return 1 if rate else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--autotest", action="store_true")
    parser.add_argument("--confirme", default="", help=f"ce que Philippe a vu : {','.join(CONFIRMATIONS)}")
    parser.add_argument("--etiqueter", action="store_true", help="tout vert : pose et pousse vX.Y.Z")
    parser.add_argument("--rapport", type=pathlib.Path, help="écrit le compte rendu (Markdown) dans ce fichier")
    args = parser.parse_args()
    if args.autotest:
        return autotest()
    inconnues = {c for c in args.confirme.split(",") if c} - set(CONFIRMATIONS)
    if inconnues:
        print(f"❓ --confirme : {', '.join(sorted(inconnues))} inconnu(s) ; permis : {', '.join(CONFIRMATIONS)}")
        return 2
    faites, etiquette, sha = etapes({c for c in args.confirme.split(",") if c})
    sortie = verdict(faites)
    lignes = [f"## Contrôle avant soumission — {etiquette or '?'} sur {sha[:7]}", "", "| Étape | État | Détail |",
              "|---|---|---|", *(f"| {n} | {e} | {d.replace('|', '/')} |" for n, e, d in faites), ""]
    if sortie == 0 and args.etiqueter and etiquette:
        code, texte = lancer("git", "tag", "-a", etiquette, sha, "-m", f"Version {etiquette[1:]} soumise (contrôle #205)")
        code = code or lancer("git", "push", "origin", etiquette)[0]
        lignes.append(f"Étiquette {etiquette} posée et poussée." if code == 0 else f"❌ étiquette : {texte}")
        if code == 0:
            lignes.append(declaration(etiquette, _plancher.VERSION))
        sortie = sortie if code == 0 else 1
    lignes.append("Parité avec l'Android : une occasion de sortir ensemble, pas une condition (18/11/2026) — "
                  "matrice coprofirst-android#12.")
    lignes.append({0: "✅ tout est vert : la soumission peut être proposée à Philippe.",
                   1: "❌ un rouge : rien ne se soumet.", 2: "❓ un INCONNU : rien ne se soumet."}[sortie])
    print("\n".join(lignes))
    if args.rapport:
        args.rapport.write_text("\n".join(lignes) + "\n", encoding="utf-8")
    return sortie


if __name__ == "__main__":
    sys.exit(main())
