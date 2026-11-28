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
3. l'Apple TV (depuis `PLATEFORMES["tv"]`, aucune version tant qu'elle vaut None) : la fiche tvOS (`entity=tvSoftware`) sert au moins
   la version voulue — elle a sa propre version, ses appareils `AppleTV…` (témoins du
   28/11/2026 : Infuse et Netflix y rendent leur version tvOS ; CoproFirst, zéro résultat).
Une fiche iPhone illisible, absente ou d'une autre app : INCONNU, jamais vert ; une fiche tvOS
vide quand la fiche iPhone se lit : l'Apple TV n'est pas publiée (rouge).

La version voulue : celle de `project.yml` (lue par `avant_soumission.version`), ou
`--version X.Y.Z`, ou `--etiquette` (la plus haute étiquette `v*`, le mode du passage
planifié : une étiquette de moins de `DELAI_REVUE_JOURS` jours non servie est EN ATTENTE de la
revue, sortie 3 ; au-delà, un rouge, qui ouvre un ticket).

Usage : verifier_publication.py [--version X.Y.Z | --etiquette] | --autotest
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
#: Depuis quelle version chaque plateforme sort avec l'app ; None : aucune version publiée ne
#: l'embarque encore, elle n'est pas exigée. La montre sort avec la 1.2 ; l'Apple TV en a été
#: écartée par Philippe le 28/11/2026 (décision « B », #427) : sa version s'écrit ici le jour
#: où une version tvOS est soumise (#429).
PLATEFORMES: dict[str, str | None] = {"montre": "1.2.0", "tv": None}
#: Au-delà, une étiquette non servie n'attend plus la revue d'Apple : quelque chose manque.
DELAI_REVUE_JOURS = 7


def normaliser(texte: str) -> str:
    """« v1.2 » → « 1.2.0 » ; une version illisible reste telle quelle (comparer dira INCONNU)."""
    nombres = texte.strip().removeprefix("v").split(".")
    return ".".join(nombres + ["0"] * (3 - len(nombres)))


def au_moins(minimum: str, lue: str) -> bool | None:
    code = comparer(normaliser(minimum), normaliser(lue))
    return None if code == 2 else code == 0


def lire_fiche(entite: str = "software") -> tuple[dict | None, str]:
    """La fiche servie (`software` : iPhone et iPad ; `tvSoftware` : Apple TV), ou (None, la
    raison). Un paramètre neuf contourne le cache d'un jour (`max-age=86400`)."""
    adresse = (f"https://itunes.apple.com/lookup?id={APP_ID}&country={PAYS}&entity={entite}"
               f"&_={int(time.time())}")
    try:
        with urllib.request.urlopen(adresse, timeout=20) as reponse:  # noqa: S310 (adresse fixe, https)
            return json.load(reponse), adresse
    except (OSError, ValueError) as erreur:
        return None, f"{adresse} : {erreur}"


def _servie(fiche: dict | None) -> tuple[dict | None, str]:
    """(la fiche de CETTE app, « ») ou (None, la raison de l'INCONNU)."""
    resultats = (fiche or {}).get("results")
    if not isinstance(resultats, list) or len(resultats) != 1:
        return None, f"fiche illisible ou absente ({(fiche or {}).get('resultCount', '?')} résultat)"
    servie = resultats[0]
    if servie.get("trackId") != APP_ID or servie.get("bundleId") != PAQUET:
        return None, f"fiche d'une autre app : {servie.get('trackId')} / {servie.get('bundleId')}"
    return servie, ""


def _appareil(servie: dict, prefixe: str) -> bool:
    return any(str(a).startswith(prefixe) for a in servie.get("supportedDevices", []))


def exigee(plateforme: str, voulue: str, plateformes: dict[str, str | None]) -> bool:
    """La plateforme sort-elle avec la version voulue ? None : aucune version ne l'embarque."""
    depuis = plateformes.get(plateforme)
    return depuis is not None and bool(au_moins(depuis, voulue))


def juger(voulue: str, fiche: dict | None, fiche_tv: dict | None,
          plateformes: dict[str, str | None] = PLATEFORMES) -> list[tuple[str, str, str]]:
    """Fonction pure (standards/04 §11) : (sujet, état, détail) pour chaque plateforme attendue."""
    servie, raison = _servie(fiche)
    if servie is None:
        return [("App Store", INCONNU, raison)]
    lue = str(servie.get("version", ""))
    publiee = au_moins(voulue, lue)
    if publiee is None:
        return [("App Store", INCONNU, f"version illisible : servie « {lue} », voulue « {voulue} »")]
    lignes = [("iPhone et iPad", OK if publiee else ROUGE,
               f"{lue} servie" + ("" if publiee else f", {normaliser(voulue)} voulue : pas encore publiée"))]
    if exigee("montre", voulue, plateformes):
        montre = _appareil(servie, "Watch")
        lignes.append(("Apple Watch", OK if publiee and montre else ROUGE,
                       "la fiche servie la nomme" if montre else "la fiche servie ne nomme aucune Apple Watch"))
    if exigee("tv", voulue, plateformes):
        lignes.append(("Apple TV", *juger_tv(voulue, fiche_tv)))
    return lignes


def juger_tv(voulue: str, fiche_tv: dict | None) -> tuple[str, str]:
    if fiche_tv is None:
        return INCONNU, "fiche tvOS illisible"
    if fiche_tv.get("resultCount") == 0 and fiche_tv.get("results") == []:
        return ROUGE, "aucune version tvOS servie : pas encore publiée"
    servie, raison = _servie(fiche_tv)
    if servie is None:
        return INCONNU, raison
    lue = str(servie.get("version", ""))
    publiee = au_moins(voulue, lue)
    if publiee is None:
        return INCONNU, f"version tvOS illisible : « {lue} »"
    if not _appareil(servie, "AppleTV"):
        return INCONNU, f"fiche tvOS {lue} sans appareil Apple TV"
    return (OK, f"{lue} servie") if publiee else (ROUGE, f"{lue} servie, {normaliser(voulue)} voulue")


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
    tv = fiche("1.2", ("AppleTV4-AppleTV4",))
    vide = {"resultCount": 0, "results": []}
    cas = [
        ("1.1.0", fiche("1.1"), vide, 0), ("1.2.0", fiche("1.1"), vide, 1),
        ("1.2.0", fiche("1.2"), tv, 0), ("1.2.0", fiche("1.3"), fiche("1.3", ("AppleTV4-AppleTV4",)), 0),
        ("1.2.0", fiche("1.2"), vide, 1), ("1.2.0", fiche("1.2"), fiche("1.1", ("AppleTV4-AppleTV4",)), 1),
        ("1.2.0", fiche("1.2"), None, 2), ("1.2.0", fiche("1.2"), fiche("1.2"), 2),
        ("1.2.0", fiche("1.2"), fiche("1.2", ("AppleTV4-AppleTV4",), trackId=1), 2),
        ("1.2.0", fiche("1.2", ("iPhone17-iPhone17",)), tv, 1),
        ("1.1.0", fiche("1.1", ("iPhone17-iPhone17",)), None, 0),
        ("1.10.0", fiche("1.9"), tv, 1),
        ("1.2.0", None, tv, 2), ("1.2.0", vide, tv, 2),
        ("1.2.0", fiche("1.2", trackId=1), tv, 2),
        ("1.2.0", fiche("1.2", bundleId="app.autre.test"), tv, 2),
        ("1.2.0", fiche("deux"), tv, 2),
    ]
    avec_tv = {"montre": "1.2.0", "tv": "1.2.0"}
    rate = [f"{v} / {f} / tv={ft} : {a} attendu" for v, f, ft, a in cas if verdict(juger(v, f, ft, avec_tv)) != a]
    # Sans version tvOS (la 1.2, décision « B ») : la fiche tvOS vide ne rougit rien, la montre reste exigée.
    sans_tv = {"montre": "1.2.0", "tv": None}
    for v, f, ft, a in [("1.2.0", fiche("1.2"), vide, 0), ("1.2.0", fiche("1.2"), None, 0),
                        ("1.2.0", fiche("1.1"), vide, 1), ("1.2.0", fiche("1.2", ("iPhone17-iPhone17",)), vide, 1)]:
        lignes = juger(v, f, ft, sans_tv)
        if verdict(lignes) != a or any(s == "Apple TV" for s, _, _ in lignes):
            rate.append(f"sans TV : {v} / {f} / tv={ft} : {a} attendu, sans ligne Apple TV")
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
    parser.add_argument("--autotest", action="store_true")
    args = parser.parse_args()
    if args.autotest:
        return autotest()
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
    fiche_tv, source_tv = lire_fiche("tvSoftware")
    lignes = juger(voulue, fiche, fiche_tv)
    sortie = verdict(lignes)
    print(f"## Publication de CoproFirst {normaliser(voulue)} sur l'App Store ({PAYS})\n")
    print("| Plateforme | État | Détail |\n|---|---|---|")
    print("\n".join(f"| {s} | {e} | {d} |" for s, e, d in lignes))
    for lu, origine in ((fiche, source), (fiche_tv, source_tv)):
        if lu is None:
            print(f"\nLecture impossible : {origine}")
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
