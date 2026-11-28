#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""La version est-elle PUBLIÉE ? Lu chez l'App Store, jamais déduit (#426 ; socle standards/04 §14).

Le 28/11/2026, la 1.2 était dans `project.yml` et ses builds envoyés depuis la veille, quand
le magasin servait toujours la 1.1 : la procédure s'arrêtait à l'étiquette, et rien ne disait
« pas encore publiée ». Envoyer n'est pas soumettre, soumettre n'est pas approuver, approuver
n'est pas publier (publication manuelle). Seul ce que le magasin SERT fait foi.

Ce qu'il juge, sur la fiche publique (`itunes.apple.com/lookup`, sans compte, magasin français) :
1. l'iPhone et l'iPad : la version servie est au moins la version voulue ;
2. l'Apple Watch (depuis `PLATEFORMES["montre"]`) : la fiche servie la nomme parmi ses appareils ;
3. l'Apple TV (depuis `PLATEFORMES["tv"]`) : AUCUNE source publique ne la dit (la recherche
   tvOS rend zéro résultat, même pour une app TV en ligne) — INCONNU, sauf `--confirme tv`
   quand Philippe lit dans App Store Connect « Prêt à la distribution » pour la version tvOS.
Une fiche illisible, absente ou d'une autre app : INCONNU, jamais vert.

La version voulue : celle de `project.yml` (lue par `avant_soumission.version`), ou
`--version X.Y.Z`, ou `--etiquette` (la plus haute étiquette `v*`, le mode du passage
planifié : une étiquette de moins de `DELAI_REVUE_JOURS` jours non servie est EN ATTENTE de la
revue, sortie 3 ; au-delà, un rouge, qui ouvre un ticket). Le mode planifié ne juge pas l'Apple
TV (aucune source sans compte) et le dit.

Usage : verifier_publication.py [--version X.Y.Z | --etiquette] [--confirme tv] | --autotest
Sortie : 0 publiée, 1 pas publiée, 2 INCONNU, 3 en attente de la revue (--etiquette seul).
"""

from __future__ import annotations

import argparse
import json
import pathlib
import subprocess
import sys
import time
import urllib.request

RACINE = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RACINE / "scripts"))
from avant_soumission import INCONNU, OK, ROUGE, version  # noqa: E402  (une lecture de project.yml)
from version_au_moins import comparer  # noqa: E402  (nombre par nombre : 1.10 > 1.9)

#: L'app sur le magasin : l'identifiant d'Apple et l'identifiant de paquet, comparés TOUS
#: DEUX à la fiche lue (standards/04 §44 : une clé partielle confond les homonymes).
APP_ID, PAQUET, PAYS = 6834326392, "fr.coprofirst.app", "fr"
#: Depuis quelle version chaque plateforme sort avec l'app (la 1.2, décision du 26/11/2026).
PLATEFORMES = {"montre": "1.2.0", "tv": "1.2.0"}
#: Au-delà, une étiquette non servie n'attend plus la revue d'Apple : quelque chose manque.
DELAI_REVUE_JOURS = 7


def normaliser(texte: str) -> str:
    """« v1.2 » → « 1.2.0 » ; une version illisible reste telle quelle (comparer dira INCONNU)."""
    nombres = texte.strip().removeprefix("v").split(".")
    return ".".join(nombres + ["0"] * (3 - len(nombres)))


def au_moins(minimum: str, lue: str) -> bool | None:
    code = comparer(normaliser(minimum), normaliser(lue))
    return None if code == 2 else code == 0


def lire_fiche() -> tuple[dict | None, str]:
    """La fiche servie, ou (None, la raison). Un paramètre neuf contourne le cache d'un jour."""
    adresse = f"https://itunes.apple.com/lookup?id={APP_ID}&country={PAYS}&_={int(time.time())}"
    try:
        with urllib.request.urlopen(adresse, timeout=20) as reponse:  # noqa: S310 (adresse fixe, https)
            return json.load(reponse), adresse
    except (OSError, ValueError) as erreur:
        return None, f"{adresse} : {erreur}"


def juger(voulue: str, fiche: dict | None, confirmees: set[str], avec_tv: bool = True) -> list[tuple[str, str, str]]:
    """Fonction pure (standards/04 §11) : (sujet, état, détail) pour chaque plateforme attendue."""
    resultats = (fiche or {}).get("results")
    if not isinstance(resultats, list) or len(resultats) != 1:
        return [("App Store", INCONNU, f"fiche illisible ou absente ({(fiche or {}).get('resultCount', '?')} résultat)")]
    servie = resultats[0]
    if servie.get("trackId") != APP_ID or servie.get("bundleId") != PAQUET:
        return [("App Store", INCONNU, f"fiche d'une autre app : {servie.get('trackId')} / {servie.get('bundleId')}")]
    lue = str(servie.get("version", ""))
    publiee = au_moins(voulue, lue)
    if publiee is None:
        return [("App Store", INCONNU, f"version illisible : servie « {lue} », voulue « {voulue} »")]
    lignes = [("iPhone et iPad", OK if publiee else ROUGE,
               f"{lue} servie" + ("" if publiee else f", {normaliser(voulue)} voulue : pas encore publiée"))]
    if au_moins(PLATEFORMES["montre"], voulue):
        montre = any(str(a).startswith("Watch") for a in servie.get("supportedDevices", []))
        lignes.append(("Apple Watch", OK if publiee and montre else ROUGE,
                       "la fiche servie la nomme" if montre else "la fiche servie ne nomme aucune Apple Watch"))
    if au_moins(PLATEFORMES["tv"], voulue):
        if not avec_tv:
            lignes.append(("Apple TV", "➖", "non jugée par le passage planifié : aucune source publique"))
        elif "tv" in confirmees:
            lignes.append(("Apple TV", OK, "confirmée par Philippe (App Store Connect : « Prêt à la distribution »)"))
        else:
            lignes.append(("Apple TV", INCONNU, "aucune source publique : lire la version tvOS dans App Store "
                                                "Connect, puis --confirme tv"))
    return lignes


def verdict(lignes: list[tuple[str, str, str]]) -> int:
    etats = [e for _, e, _ in lignes]
    return 1 if ROUGE in etats else 2 if INCONNU in etats or not etats else 0


def etiquette_recente() -> tuple[str, float] | None:
    """(« v1.2.0 », âge en jours) de la plus haute étiquette `v*`, ou None."""
    fini = subprocess.run(["git", "for-each-ref", "--sort=-v:refname", "--count=1",
                           "--format=%(refname:short) %(creatordate:unix)", "refs/tags/v*"],
                          cwd=RACINE, capture_output=True, text=True, check=False)
    morceaux = fini.stdout.split()
    if fini.returncode != 0 or len(morceaux) != 2 or not morceaux[1].isdigit():
        return None
    return morceaux[0], (time.time() - int(morceaux[1])) / 86400


def autotest() -> int:
    """Chaque cas dans les deux sens (standards/04 §46), hors réseau."""
    def fiche(v: str = "1.2", appareils: tuple = ("iPhone17-iPhone17", "Watch7-Watch7"), **autre) -> dict:
        return {"resultCount": 1, "results": [{"trackId": APP_ID, "bundleId": PAQUET, "version": v,
                                                "supportedDevices": list(appareils), **autre}]}
    cas = [
        ("1.1.0", fiche("1.1"), set(), True, 0), ("1.2.0", fiche("1.1"), set(), True, 1),
        ("1.2.0", fiche("1.2"), {"tv"}, True, 0), ("1.2.0", fiche("1.2"), set(), True, 2),
        ("1.2.0", fiche("1.2"), set(), False, 0), ("1.2.0", fiche("1.3"), {"tv"}, True, 0),
        ("1.2.0", fiche("1.2", ("iPhone17-iPhone17",)), {"tv"}, True, 1),
        ("1.1.0", fiche("1.1", ("iPhone17-iPhone17",)), set(), True, 0),
        ("1.10.0", fiche("1.9"), {"tv"}, True, 1),
        ("1.2.0", None, {"tv"}, True, 2), ("1.2.0", {"resultCount": 0, "results": []}, {"tv"}, True, 2),
        ("1.2.0", fiche("1.2", trackId=1), {"tv"}, True, 2),
        ("1.2.0", fiche("1.2", bundleId="app.autre.test"), {"tv"}, True, 2),
        ("1.2.0", fiche("deux"), {"tv"}, True, 2),
    ]
    rate = [f"{v} / {f and f['results'][0]['version'] if f and f.get('results') else f} / {c} / tv={t} : {a} attendu"
            for v, f, c, t, a in cas if verdict(juger(v, f, c, t)) != a]
    if normaliser("v1.2") != "1.2.0" or normaliser("1.2.3") != "1.2.3":
        rate.append("normaliser")
    for r in rate:
        print(f"❌ autotest : {r}")
    print("✅ verifier_publication : autotest" if not rate else f"── {len(rate)} cas en échec")
    return 1 if rate else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    groupe = parser.add_mutually_exclusive_group()
    groupe.add_argument("--version", help="la version voulue (défaut : celle de project.yml)")
    groupe.add_argument("--etiquette", action="store_true", help="la plus haute étiquette v* (passage planifié)")
    parser.add_argument("--confirme", default="", help="tv : Philippe a lu la version tvOS « Prêt à la distribution »")
    parser.add_argument("--autotest", action="store_true")
    args = parser.parse_args()
    if args.autotest:
        return autotest()
    confirmees = {c for c in args.confirme.split(",") if c}
    if confirmees - {"tv"}:
        print(f"❓ --confirme : {', '.join(sorted(confirmees - {'tv'}))} inconnu(s) ; permis : tv")
        return 2
    age = None
    if args.etiquette:
        lue = etiquette_recente()
        if lue is None:
            print("❓ INCONNU — aucune étiquette v* lisible (le clone a-t-il ses étiquettes ?)")
            return 2
        voulue, age = lue
    elif args.version:
        voulue = args.version
    else:
        lue = version((RACINE / "project.yml").read_text(encoding="utf-8"))
        if lue is None:
            print("❓ INCONNU — MARKETING_VERSION illisible dans project.yml")
            return 2
        voulue = lue[0]
    fiche, source = lire_fiche()
    lignes = juger(voulue, fiche, confirmees, avec_tv=not args.etiquette)
    sortie = verdict(lignes)
    print(f"## Publication de CoproFirst {normaliser(voulue)} sur l'App Store ({PAYS})\n")
    print("| Plateforme | État | Détail |\n|---|---|---|")
    print("\n".join(f"| {s} | {e} | {d} |" for s, e, d in lignes))
    if fiche is None:
        print(f"\nLecture impossible : {source}")
    if sortie == 1 and age is not None and age < DELAI_REVUE_JOURS:
        print(f"\n⏳ {voulue} étiquetée il y a {age:.1f} j : en attente de la revue ou de la publication "
              f"(rouge au-delà de {DELAI_REVUE_JOURS} j).")
        return 3
    print("\n" + {0: "✅ PUBLIÉE : le magasin sert la version voulue.",
                  1: "❌ PAS PUBLIÉE : le magasin ne sert pas la version voulue. Où elle en est : "
                     "App Store Connect (skill publication-app-store, « De bout en bout »).",
                  2: "❓ INCONNU : rien ne permet de dire « publiée »."}[sortie])
    return sortie


if __name__ == "__main__":
    sys.exit(main())
