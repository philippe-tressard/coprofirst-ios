#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Trois règles de la CI, lues dans `.github/workflows/ci.yml`.

1. Le job « Dépôt » n'a qu'une étape `run`, et c'est `verifier-depot.sh` (#241).

Le poste, le hook pre-commit et la CI jouent alors exactement la même chose : le
16/11/2026, #240 est passée au poste puis a rougi en CI sur `verifier-logo.sh`, une
étape que seul le job jouait. Un contrôle de plus s'ajoute DANS `verifier-depot.sh`
(ou `scripts/controles-distants.sh`), jamais en étape du job.

2. Chaque job macOS a son `timeout-minutes` et figure dans les `needs` de l'agrégat
   (`ios`, le check que la protection de `main` exige), qui juge `toJSON(needs)` en
   entier (#288). Sinon un job neuf — les échantillons, la montre — peut rougir sans
   rendre la PR rouge.

3. Une classe de tests qui se saute hors de l'iPad (`XCTSkipUnless(… == .pad`) est nommée
   en entier dans l'échantillon iPad (l'étape `APPAREIL: ipad`, #350) : le dernier lot
   d'interface tourne sur iPhone, où elle ne joue rien — sans l'échantillon, elle ne se
   jouait nulle part (`CarnetUITests`, jamais en CI jusqu'au 23/11/2026).

Lecture au texte, sans PyYAML (absent de `python3 -I` sur le runner Linux) : le bloc
du job va de `  depot:` à la clé de job suivante, au même retrait.

Usage : python3 scripts/verifier-ci.py [--autotest]
Sortie : 0 conforme, 1 refus, 2 INCONNU (workflow ou job introuvable).
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RACINE / "scripts"))
import portee  # noqa: E402  (la liste des dossiers, #341)

WORKFLOW = RACINE / ".github" / "workflows" / "ci.yml"
#: La garde d'une classe de l'iPad seul, dans son `setUp`.
IPAD_SEUL = re.compile(r"XCTSkipUnless\(\s*UIDevice\.current\.userInterfaceIdiom\s*==\s*\.pad\b")
JOB = "depot"
ATTENDU = "bash scripts/verifier-depot.sh"
AGREGAT = "ios"


def bloc_du_job(texte: str, job: str) -> list[str] | None:
    """Les lignes du job, ou None s'il n'existe pas."""
    lignes = texte.splitlines()
    try:
        debut = lignes.index(f"  {job}:")
    except ValueError:
        return None
    bloc = []
    for ligne in lignes[debut + 1:]:
        if re.match(r"^  [A-Za-z0-9_-]+:\s*$", ligne) or re.match(r"^\S", ligne):
            break
        bloc.append(ligne)
    return bloc


def refus_depot(texte: str) -> tuple[int, list[str]]:
    """Règle 1 — (code, messages) : 0 conforme, 1 refus, 2 INCONNU."""
    bloc = bloc_du_job(texte, JOB)
    if bloc is None:
        return 2, [f"❓ INCONNU : job « {JOB} » introuvable dans {WORKFLOW.name}"]
    runs = [l.split("run:", 1)[1].strip() for l in bloc if re.match(r"^\s+(- )?run:", l)]
    if runs == [ATTENDU]:
        return 0, [f"✅ job « {JOB} » : une seule étape, {ATTENDU}"]
    return 1, [
        f"❌ job « {JOB} » : {len(runs)} étape(s) run ({', '.join(runs) or 'aucune'}) — "
        f"une seule, « {ATTENDU} » ; un contrôle de plus s'ajoute dans ce script (#241)"
    ]


def jobs(texte: str) -> list[str]:
    """Les clés de job, dans l'ordre : retrait de deux espaces, sous `jobs:`."""
    lignes = texte.splitlines()
    if "jobs:" not in lignes:
        return []
    noms = []
    for ligne in lignes[lignes.index("jobs:") + 1:]:
        if re.match(r"^\S", ligne):
            break
        m = re.match(r"^  ([A-Za-z0-9_-]+):\s*$", ligne)
        if m:
            noms.append(m.group(1))
    return noms


def refus_agregat(texte: str) -> tuple[int, list[str]]:
    """Règle 2 — chaque job macOS : un plafond, et exigé par l'agrégat qui juge tous ses needs."""
    agregat = bloc_du_job(texte, AGREGAT)
    if agregat is None:
        return 2, [f"❓ INCONNU : agrégat « {AGREGAT} » introuvable"]
    besoins = next((l.split("needs:", 1)[1].strip() for l in agregat if re.match(r"^    needs:", l)), "")
    exiges = set(re.findall(r"[A-Za-z0-9_-]+", besoins)) if besoins.startswith("[") else {besoins}
    macos = [j for j in jobs(texte) if any("runs-on: macos" in l for l in bloc_du_job(texte, j) or [])]
    if not macos:
        return 2, ["❓ INCONNU : aucun job macOS lu dans le workflow"]
    messages = []
    for job in macos:
        if job not in exiges:
            messages.append(f"❌ job macOS « {job} » absent des needs de « {AGREGAT} » : il rougirait sans rougir la PR")
        if not any(re.match(r"^    timeout-minutes: \d+", l) for l in bloc_du_job(texte, job) or []):
            messages.append(f"❌ job macOS « {job} » sans timeout-minutes : il tiendrait 6 h un exécutant rare")
    if not any("toJSON(needs)" in l for l in agregat):
        messages.append(f"❌ « {AGREGAT} » ne juge pas toJSON(needs) : un job de needs pourrait n'être lu par personne")
    if messages:
        return 1, messages
    return 0, [f"✅ {len(macos)} job(s) macOS ({', '.join(macos)}) : plafonnés et exigés par « {AGREGAT} »"]


def nommees_sur_ipad(texte: str) -> set[str]:
    """Les `-only-testing:<cible>/<Classe>` entiers des étapes `APPAREIL: ipad`."""
    nommees: set[str] = set()
    for etape in re.split(r"\n\s+- (?=name:|uses:|run:)", texte):
        if re.search(r"^\s+APPAREIL:\s*ipad\s*$", etape, re.MULTILINE):
            nommees |= set(re.findall(r"-only-testing:([A-Za-z0-9_]+/[A-Za-z0-9_]+)\s*$", etape, re.MULTILINE))
    return nommees


def classes_ipad_seul(racine: Path = RACINE) -> list[str]:
    """`<cible>/<Classe>` de chaque classe de tests qui se saute hors de l'iPad."""
    trouvees = []
    for f in portee.fichiers(racine, portee.TESTS):
        texte = f.read_text(encoding="utf-8")
        if IPAD_SEUL.search(texte):
            cible = f.relative_to(racine).parts[0]
            trouvees += [f"{cible}/{c}" for c in re.findall(r"class\s+(\w+)\s*:\s*XCTestCase", texte)]
    return sorted(trouvees)


def refus_ipad(texte: str, classes: list[str]) -> tuple[int, list[str]]:
    """Règle 3 — chaque classe de l'iPad seul est nommée dans l'échantillon iPad."""
    if not classes:
        return 2, ["❓ INCONNU : aucune classe de l'iPad seul lue (BarreLaterale, ListeEtFiche, Carnet…)"]
    nommees = nommees_sur_ipad(texte)
    manquantes = [c for c in classes if c not in nommees]
    if manquantes:
        return 1, [f"❌ {c} se saute hors de l'iPad et n'est pas nommée dans l'échantillon iPad : "
                   "elle ne se joue nulle part en CI (#350)" for c in manquantes]
    return 0, [f"✅ {len(classes)} classe(s) de l'iPad seul, toutes dans l'échantillon iPad"]


def refus(texte: str, classes: list[str] | None = None) -> tuple[int, list[str]]:
    """Les trois règles : le code le plus grave (INCONNU l'emporte sur le vert, jamais sur le refus)."""
    regles = [refus_depot, refus_agregat] + ([lambda t: refus_ipad(t, classes)] if classes is not None else [])
    codes, messages = zip(*(r(texte) for r in regles))
    code = 1 if 1 in codes else max(codes)
    return code, [m for ms in messages for m in ms]


def autotest() -> int:
    conforme = (
        "jobs:\n  depot:\n    runs-on: ubuntu-latest\n    steps:\n"
        "      - uses: actions/checkout@x\n      - name: Dépôt\n"
        f"        run: {ATTENDU}\n  detection:\n    steps:\n      - run: autre\n"
        "  unitaires:\n    runs-on: macos-latest\n    timeout-minutes: 70\n    steps:\n      - run: x\n"
        "  echantillons:\n    runs-on: macos-latest\n    timeout-minutes: 40\n    steps:\n      - run: x\n"
        f"  {AGREGAT}:\n    needs: [detection, unitaires, echantillons]\n    runs-on: ubuntu-latest\n"
        "    steps:\n      - env:\n          BESOINS: ${{ toJSON(needs) }}\n        run: juger\n"
    )
    deux = conforme.replace("  detection:", "      - run: bash scripts/verifier-logo.sh\n  detection:")
    autre = conforme.replace(f"run: {ATTENDU}", "run: bash scripts/autre.sh")
    bloc = conforme.replace(f"run: {ATTENDU}", f"run: |\n          {ATTENDU}")
    cas = [
        (conforme, 0, "un job conforme"),
        (deux, 1, "une deuxième étape run"),
        (autre, 1, "une étape qui n'est pas verifier-depot.sh"),
        (bloc, 1, "un bloc run: | qui pourrait enchaîner d'autres commandes"),
        (conforme.replace("  depot:", "  dépôt:"), 2, "un job introuvable"),
        (conforme.replace("unitaires, echantillons]", "unitaires]"), 1, "un job macOS hors des needs"),
        (conforme.replace("    timeout-minutes: 40\n", ""), 1, "un job macOS sans plafond"),
        (conforme.replace("${{ toJSON(needs) }}", "${{ needs.unitaires.result }}"), 1, "un agrégat qui ne juge pas tout"),
        (conforme.replace(f"  {AGREGAT}:", "  agregat:"), 2, "un agrégat introuvable"),
        (conforme.replace("macos-latest", "ubuntu-latest"), 2, "aucun job macOS"),
    ]
    etape = "      - name: iPad\n        env:\n          APPAREIL: ipad\n        run: >-\n          bash t.sh\n"
    ipad = conforme.replace("      - run: x\n  " + AGREGAT, etape + "          -only-testing:UI/CarnetUITests\n  " + AGREGAT)
    ko = [nom for texte, code, nom in cas if refus(texte)[0] != code]
    cas_ipad = [
        (ipad, ["UI/CarnetUITests"], 0, "une classe de l'iPad seul nommée"),
        (conforme, ["UI/CarnetUITests"], 1, "une classe de l'iPad seul absente"),
        (ipad.replace("CarnetUITests", "CarnetUITests/testUn"), ["UI/CarnetUITests"], 1, "un seul de ses tests nommé"),
        (ipad.replace("APPAREIL: ipad", "APPAREIL: tv"), ["UI/CarnetUITests"], 1, "nommée sur l'Apple TV"),
        (ipad, [], 2, "aucune classe lue"),
    ]
    ko += [nom for texte, classes, code, nom in cas_ipad if refus_ipad(texte, classes)[0] != code]
    for nom in ko:
        print(f"❌ autotest : {nom} mal jugé")
    return 1 if ko else 0


def main() -> int:
    if sys.argv[1:] == ["--autotest"]:
        return autotest()
    if not WORKFLOW.is_file():
        print(f"❓ INCONNU : {WORKFLOW} absent")
        return 2
    code, messages = refus(WORKFLOW.read_text(encoding="utf-8"), classes_ipad_seul())
    print("\n".join(messages))
    return code


if __name__ == "__main__":
    sys.exit(main())
