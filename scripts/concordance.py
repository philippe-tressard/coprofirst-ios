#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""La CONCORDANCE avec coprofirst (#20 ; standards/09 §8, règle 2 : ce qu'un client
dérive du serveur se surveille chaque jour).

Régénère TOUT ce que l'app tire de coprofirst (contrat, charte, palettes, pages et
onglets, natures du fil, rôles, tables des menus — `scripts/generer.py`) dans un
dossier jetable, depuis une version publiée, et le compare au dépôt, octet pour
octet. Juge aussi les réponses de l'API simulée contre le contrat de cette version
(`scripts/verifier-fixtures.py`) : un champ que le serveur ne sert pas est un écart.

Usage :
  python3 scripts/concordance.py               la dernière release publiée (quotidien)
  python3 scripts/concordance.py --declaree    la version que le dépôt déclare (CI) :
                                               rien n'a été retouché à la main
  python3 scripts/concordance.py --version vX.Y.Z
  options : --rapport FICHIER.md (le corps du ticket), --simuler-ecart (un écart posé
            exprès doit rendre rouge), --autotest (hors réseau).

Sortie : 0 concordant, 1 écart, 2 INCONNU — une version, une archive ou une table
illisible ne rend jamais vert.
"""

from __future__ import annotations

import argparse
import difflib
import importlib.util
import json
import pathlib
import re
import sys
import tempfile

RACINE = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RACINE / "scripts"))

import generer  # noqa: E402
from generateurs._commun import PROVENANCE, SIGNATURE  # noqa: E402
from generateurs._source import SourceIllisible, derniere_version  # noqa: E402
from generateurs.contrat import CONTRAT  # noqa: E402

LIGNES_DE_DIFF = 40
# Où vivent les fichiers générés ; un dossier caché ou de build n'est pas le dépôt.
DOSSIERS_GENERES = ("CoproFirst", "Paquets/ClientAPI", "Parite")
# Ce qui nomme la version lue (en-tête, table de PROVENANCE-OPENAPI.md). Le quotidien
# l'ignore : coprofirst publie plusieurs versions par jour, et une release qui ne change
# rien de ce que l'app tire n'est pas un écart. La CI (`--declaree`) compare à l'octet.
COMMIT_NOMME = re.compile(r"`[0-9a-f]{40}` \(`v\d+\.\d+\.\d+`\)")


def sans_provenance(texte: str) -> str:
    return COMMIT_NOMME.sub("<commit>", PROVENANCE.sub("<provenance>", texte))


def _fixtures():
    """`scripts/verifier-fixtures.py` (nom à tiret) chargé comme module : un seul juge."""
    spec = importlib.util.spec_from_file_location("verifier_fixtures", RACINE / "scripts" / "verifier-fixtures.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def candidats(racine: pathlib.Path) -> list[str]:
    return sorted(
        str(f.relative_to(racine)) for d in DOSSIERS_GENERES for f in (racine / d).rglob("*")
        if f.is_file() and not any(p.startswith(".") for p in f.relative_to(racine).parts))


def generes_du_depot(racine: pathlib.Path, fichiers: list[str]) -> dict[str, str]:
    """Chaque fichier du dépôt qui se dit GÉNÉRÉ → ce que son en-tête dit de la source."""
    declares = {}
    for relatif in fichiers:
        chemin = racine / relatif
        try:
            tete = chemin.read_text(encoding="utf-8").splitlines()[:12]
        except (OSError, UnicodeDecodeError):
            continue
        if any(SIGNATURE in ligne for ligne in tete):
            trouve = next((PROVENANCE.search(ligne) for ligne in tete if PROVENANCE.search(ligne)), None)
            declares[relatif] = trouve.group(1) if trouve else ""
    return declares


def comparer(depot: pathlib.Path, genere: pathlib.Path, ecrits: list[str], declares: dict[str, str],
             *, a_l_octet: bool = True) -> list[str]:
    """Les écarts entre le dépôt et la génération : divergent, absent, orphelin.

    `a_l_octet=False` : la ligne qui nomme la version lue ne compte pas."""
    ecarts = []
    for relatif in sorted(set(ecrits)):
        attendu, present = genere / relatif, depot / relatif
        if not present.exists():
            ecarts.append(f"`{relatif}` : absent du dépôt")
            continue
        avant, apres = present.read_text(encoding="utf-8"), attendu.read_text(encoding="utf-8")
        if not a_l_octet:
            avant, apres = sans_provenance(avant), sans_provenance(apres)
        if avant != apres:
            diff = list(difflib.unified_diff(
                avant.splitlines(), apres.splitlines(), "dépôt", "version publiée", lineterm="", n=0))
            extrait = "\n".join(diff[:LIGNES_DE_DIFF]) + ("\n…" if len(diff) > LIGNES_DE_DIFF else "")
            ecarts.append(f"`{relatif}` : diverge\n```diff\n{extrait}\n```")
    for relatif in sorted(set(declares) - set(ecrits)):
        ecarts.append(f"`{relatif}` : se dit GÉNÉRÉ, mais plus aucun générateur ne l'écrit")
    return ecarts


def version_declaree(declares: dict[str, str]) -> tuple[str | None, list[str]]:
    """La version que le dépôt déclare, une seule ; sinon les écarts qui le disent."""
    versions = sorted(set(declares.values()))
    sans = sorted(f for f, v in declares.items() if not v)
    ecarts = [f"`{f}` : l'en-tête GÉNÉRÉ ne nomme pas de version publiée" for f in sans]
    versions = [v for v in versions if v]
    if len(versions) > 1:
        ecarts.append("versions mélangées : " + ", ".join(
            f"{v} ({sum(1 for x in declares.values() if x == v)} fichiers)" for v in versions))
    return (versions[0] if len(versions) == 1 else None), ecarts


def rapport(etat: str, version: str, ecarts: list[str], motif: str = "") -> str:
    commande = f"python3 scripts/generer.py --version {version}" if version else "python3 scripts/generer.py --derniere"
    corps = f"## Concordance avec CoproFirst : {etat}\n\nVersion comparée : `{version or 'inconnue'}`.\n\n"
    if motif:
        corps += f"❓ **INCONNU** — {motif}\n\nRien n'a pu être comparé : ce n'est pas un vert.\n"
    for ecart in ecarts:
        corps += f"- {ecart}\n"
    if ecarts:
        corps += f"\nRégénérer : `{commande}`, relire le diff, puis `xcodebuild test`.\n"
    return corps[:60000]


def concordance(etiquette: str | None, declaree: bool, simuler: bool) -> tuple[int, str]:
    declares = generes_du_depot(RACINE, candidats(RACINE))
    ecarts = []
    try:
        if declaree:
            etiquette, ecarts = version_declaree(declares)
            if not etiquette:
                return (1 if ecarts else 2), rapport("écart" if ecarts else "INCONNU", "", ecarts,
                                                     "" if ecarts else "aucun fichier ne déclare sa version")
        etiquette = etiquette or derniere_version()
        with tempfile.TemporaryDirectory(prefix="concordance-") as dossier:
            sortie = pathlib.Path(dossier)
            ctx, _ = generer.executer(etiquette, sortie)
            ecrits = [str(p) for p in ctx.ecrits]
            if simuler:
                with open(sortie / ecrits[0], "a", encoding="utf-8") as f:
                    f.write("// écart simulé par concordance.py --simuler-ecart\n")
            ecarts += comparer(RACINE, sortie, ecrits, declares, a_l_octet=declaree)
            verif = _fixtures()
            juge = verif.Juge(json.loads((sortie / CONTRAT).read_text(encoding="utf-8")))
            hors_schema, illisibles = verif.juger(juge, verif.fixtures(RACINE))
            if illisibles:
                return 2, rapport("INCONNU", etiquette, ecarts, "réponse simulée illisible : " + " ; ".join(illisibles))
            ecarts += [f"API simulée : {e}" for e in hors_schema]
    except SourceIllisible as erreur:
        return 2, rapport("INCONNU", etiquette or "", [], str(erreur))
    except SystemExit as erreur:
        # Un générateur qui ne retrouve pas sa table : la source a changé de forme.
        return 2, rapport("INCONNU", etiquette or "", [], f"un générateur échoue — {erreur}")
    return (1 if ecarts else 0), rapport("écart" if ecarts else "concordant", etiquette, ecarts)


def autotest() -> None:
    """Hors réseau : un cas zéro passe, un écart posé exprès est vu, chaque forme d'écart."""
    with tempfile.TemporaryDirectory() as dossier:
        depot, genere = pathlib.Path(dossier, "depot"), pathlib.Path(dossier, "genere")
        entete = f"// {SIGNATURE}\n// Source : philippe-tressard/coprofirst v1.2.3 (commit {'a' * 40}), x.\n"
        for racine in (depot, genere):
            (racine / "A").mkdir(parents=True)
            (racine / "A" / "T.swift").write_text(entete + "let a = 1\n", encoding="utf-8")
        declares = generes_du_depot(depot, ["A/T.swift"])
        if comparer(depot, genere, ["A/T.swift"], declares) or version_declaree(declares) != ("v1.2.3", []):
            raise SystemExit("❌ autotest : le cas zéro doit passer")
        (genere / "A" / "T.swift").write_text(entete.replace("v1.2.3", "v1.2.4") + "let a = 1\n", encoding="utf-8")
        if len(comparer(depot, genere, ["A/T.swift"], declares)) != 1 or comparer(
                depot, genere, ["A/T.swift"], declares, a_l_octet=False):
            raise SystemExit("❌ autotest : une version nouvelle sans changement est un écart à l'octet seulement")
        (genere / "A" / "T.swift").write_text(entete + "let a = 2\n", encoding="utf-8")
        ecarts = comparer(depot, genere, ["A/T.swift"], declares)
        if len(ecarts) != 1 or "A/T.swift" not in ecarts[0] or "+let a = 2" not in ecarts[0]:
            raise SystemExit(f"❌ autotest : un écart posé exprès doit être vu ({ecarts})")
        (depot / "A" / "Vieux.swift").write_text(entete.replace("v1.2.3", "v1.0.0"), encoding="utf-8")
        declares = generes_du_depot(depot, ["A/T.swift", "A/Vieux.swift"])
        orphelins = comparer(depot, depot, ["A/T.swift"], declares)
        if len(orphelins) != 1 or "plus aucun générateur" not in orphelins[0]:
            raise SystemExit(f"❌ autotest : un fichier généré orphelin doit être vu ({orphelins})")
        if version_declaree(declares)[0] is not None or "mélangées" not in version_declaree(declares)[1][0]:
            raise SystemExit("❌ autotest : des versions mélangées doivent être vues")
    print("✅ autotest : cas zéro, version seule, écart posé exprès, fichier orphelin, versions mélangées")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    choix = parser.add_mutually_exclusive_group()
    choix.add_argument("--version", help="une version publiée, vX.Y.Z (défaut : la dernière)")
    choix.add_argument("--declaree", action="store_true", help="la version que le dépôt déclare")
    choix.add_argument("--autotest", action="store_true")
    parser.add_argument("--rapport", type=pathlib.Path, help="écrit le rapport (Markdown) dans ce fichier")
    parser.add_argument("--simuler-ecart", action="store_true", help="pose un écart exprès : doit rendre rouge")
    arguments = parser.parse_args()
    if arguments.autotest:
        autotest()
        return 0
    code, texte = concordance(arguments.version, arguments.declaree, arguments.simuler_ecart)
    if arguments.rapport:
        arguments.rapport.write_text(texte, encoding="utf-8")
    print(texte)
    print({0: "✅ concordant", 1: "❌ écart", 2: "❓ INCONNU"}[code])
    return code


if __name__ == "__main__":
    sys.exit(main())
