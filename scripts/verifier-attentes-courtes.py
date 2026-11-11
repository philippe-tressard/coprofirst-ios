#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Aucune attente de moins de 5 s écrite sur place dans les tests d'interface (#147).

Sur un runner chargé, une requête d'accessibilité met 1 à 2 s : un délai de 3 s tombe
sans que l'app ait tort (#123, #102 ; main 865eed4 rouge le 11/11/2026 sur la cloche).
Une attente rend la main dès que l'élément est là : un plafond large ne coûte rien à un
test vert. Les attentes positives passent donc au plafond commun (`Attente.plafond`,
`CoproFirstUITests/Attente.swift`).

Deux sortes d'attente courte restent légitimes, et se DÉCLARENT par un commentaire sur
la ligne qui les précède — `// sonde courte : <raison>` :
  - la sonde suivie d'un défilement : l'élément n'existe qu'une fois ramené à l'écran,
    et 30 s d'attente coûteraient 30 s à chaque élément sous le pli ;
  - la preuve d'absence : le délai est le temps laissé à ce qui s'ouvrirait à tort.
Une déclaration qui ne précède plus d'attente courte échoue : l'exception a cessé de
servir.

Les autres sont tenues par un PLAFOND décroissant, jamais relevé : `AccesUITests.swift`
attend la branche de #123, qui le réécrit. Un compte sous le plafond échoue aussi —
le plafond se baisse dans le même commit.

Usage :
  python3 scripts/verifier-attentes-courtes.py            juge le dépôt
  python3 scripts/verifier-attentes-courtes.py --autotest prouve qu'il refuse et accepte

Sortie : 0 conforme, 1 écart, 2 INCONNU (aucun test à juger).
"""

from __future__ import annotations

import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parents[1]
TESTS = "CoproFirstUITests"
#: Les attentes courtes non déclarées qui restent : il baisse, il ne monte jamais (#147).
PLAFOND = 7
CONFORME, ECART, INCONNU = 0, 1, 2

COURTE = re.compile(r"\.waitFor(Non)?Existence\(timeout: [0-4](\.[0-9]+)?\)")
DECLARATION = re.compile(r"^\s*// sonde courte : \S")
COMMENTAIRE = re.compile(r"^\s*//")


def juger_fichier(nom: str, texte: str) -> tuple[list[str], list[str]]:
    """Rend (attentes non déclarées, fautes) d'un fichier de tests."""
    lignes = texte.splitlines()
    libres, fautes = [], []
    for rang, ligne in enumerate(lignes):
        if DECLARATION.match(ligne):
            suivante = lignes[rang + 1] if rang + 1 < len(lignes) else ""
            if not COURTE.search(suivante):
                fautes.append(f"{nom}:{rang + 1} : « sonde courte » déclarée sans attente courte dessous — la retirer")
            continue
        if COMMENTAIRE.match(ligne) or not COURTE.search(ligne):
            continue
        if not (rang > 0 and DECLARATION.match(lignes[rang - 1])):
            libres.append(f"{nom}:{rang + 1}")
    return libres, fautes


def juger(fichiers: dict[str, str], plafond: int) -> tuple[list[str], str]:
    if not fichiers:
        raise LookupError(f"aucun fichier de {TESTS} à juger")
    libres, fautes = [], []
    for nom, texte in sorted(fichiers.items()):
        l, f = juger_fichier(nom, texte)
        libres += l
        fautes += f
    if len(libres) > plafond:
        fautes.append(
            f"{len(libres)} attentes de moins de 5 s écrites sur place, plafond {plafond} : timeout: Attente.plafond, "
            f"ou « // sonde courte : <raison> » au-dessus — {', '.join(libres)}")
    elif len(libres) < plafond:
        fautes.append(f"{len(libres)} attentes courtes non déclarées, sous le plafond {plafond} : "
                      f"baisser PLAFOND à {len(libres)} dans {pathlib.Path(__file__).name}")
    declarees = sum(1 for t in fichiers.values() for l in t.splitlines() if DECLARATION.match(l))
    return fautes, f"attentes courtes : {len(libres)} au plafond {plafond}, {declarees} sondes déclarées"


def autotest() -> bool:
    positive = "        XCTAssertTrue(x.waitForExistence(timeout: 3))\n"
    sonde = "        // sonde courte : sous le pli, on défile\n        _ = x.waitForExistence(timeout: 1)\n"
    cas = [
        ("au plafond commun", {"A": "        XCTAssertTrue(x.waitForExistence(timeout: Attente.plafond))\n"}, 0, CONFORME),
        ("une attente courte de plus que le plafond", {"A": positive}, 0, ECART),
        ("une disparition courte", {"A": "        XCTAssertTrue(x.waitForNonExistence(timeout: 2))\n"}, 0, ECART),
        ("une sonde déclarée", {"A": sonde}, 0, CONFORME),
        ("une déclaration qui ne sert plus", {"A": "        // sonde courte : rien\n" + positive.replace("3", "30")},
         0, ECART),
        ("une déclaration trop loin", {"A": "        // sonde courte : x\n\n" + positive}, 0, ECART),
        ("au plafond", {"A": positive, "B": positive}, 2, CONFORME),
        ("sous le plafond, sans le baisser", {"A": positive}, 2, ECART),
        ("une attente citée en commentaire", {"A": "        // jamais waitForExistence(timeout: 3)\n"}, 0, CONFORME),
        ("rien à juger", {}, 0, INCONNU),
    ]
    reussi = True
    for nom, fichiers, plafond, attendu in cas:
        try:
            fautes, _ = juger(fichiers, plafond)
            obtenu = ECART if fautes else CONFORME
        except LookupError:
            obtenu = INCONNU
        if obtenu != attendu:
            print(f"❌ autotest « {nom} » : attendu {attendu}, obtenu {obtenu}")
            reussi = False
    return reussi


def main(arguments: list[str]) -> int:
    if arguments == ["--autotest"]:
        if not autotest():
            return ECART
        print("✅ autotest de verifier-attentes-courtes.py : refuse et accepte comme prévu")
        return CONFORME
    if arguments:
        print(__doc__)
        return INCONNU
    fichiers = {str(p.relative_to(RACINE)): p.read_text(encoding="utf-8")
                for p in sorted((RACINE / TESTS).glob("*.swift"))}
    try:
        fautes, bilan = juger(fichiers, PLAFOND)
    except LookupError as erreur:
        print(f"❓ INCONNU : {erreur}")
        return INCONNU
    for faute in fautes:
        print(f"❌ {faute}")
    if fautes:
        return ECART
    print(f"✅ {bilan}")
    return CONFORME


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
