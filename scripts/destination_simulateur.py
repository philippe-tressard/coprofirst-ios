# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Choisir le simulateur des tests : un iPhone ordinaire du runtime iOS standard le plus récent.

Appelé par `scripts/destination-simulateur.sh`, qui lui passe sur l'entrée standard
la sortie de `xcrun simctl list devices available -j`. Imprime l'udid retenu (sortie
0) et dit lequel sur la sortie d'erreur ; un choix impossible rend INCONNU (sortie
2), jamais un appareil au hasard (#112).

La règle, dans l'ordre :

1. le runtime : un runtime iOS STANDARD (`…SimRuntime.iOS-27-2`), le plus récent qui
   porte un appareil disponible — les versions se comparent en nombres, pas en
   texte. Un runtime propre à un appareil (`iOS-27-2-iPhone19-4`, celui de
   l'« iPhone Duo ») n'en est pas un : trié en tête, il envoyait tout passage sans
   DESTINATION sur un appareil où le bouton retour ne se trouve pas ;
2. l'appareil : un iPhone de série à son nom d'usine, « iPhone 18 » ou « iPhone 18
   Pro » — ni Max, ni Plus, ni Air, ni « e », ni pliable, ni un clone renommé par une
   session (« iPhone 18 Pro (#12 residence) »), dont l'état appartient à celle-ci ;
3. entre plusieurs : la génération la plus récente, le Pro d'abord (l'appareil de
   référence du poste), puis l'udid — le même choix d'un passage à l'autre.

Avec `--ipad` (#220), l'appareil est un iPad Pro 13 pouces de série, « iPad Pro
13-inch (M5) » — la taille des captures exigées par l'App Store —, la puce la plus
récente d'abord ; même runtime, mêmes refus (clone renommé, variante « (16GB) »).

Les noms ne s'écrivent pas en dur : ils changent d'une image de runner à l'autre.
`--autotest` rejoue la règle sur la liste du poste du 11/11/2026 (deux runtimes
27.2, dont celui du seul iPhone Duo) : un contrôle qui ne refuse rien ne prouve rien.
"""

from __future__ import annotations

import json
import re
import sys

RUNTIME_STANDARD = re.compile(r"^com\.apple\.CoreSimulator\.SimRuntime\.iOS-(\d+)-(\d+)(?:-(\d+))?$")
IPHONE_DE_SERIE = re.compile(r"^iPhone (?P<generation>\d+)(?P<pro> Pro)?$")
IPAD_DE_SERIE = re.compile(r"^iPad Pro 13-inch \(M(?P<generation>\d+)\)$")
TYPE = "com.apple.CoreSimulator.SimDeviceType."
#: Ce que le message d'INCONNU dit chercher, par famille.
ATTENDU = {"iphone": "iPhone de série (« iPhone N » ou « iPhone N Pro »)",
           "ipad": "iPad Pro 13 pouces de série (« iPad Pro 13-inch (MN) »)"}


def de_serie(appareil: dict, famille: str = "iphone") -> tuple[int, int] | None:
    """(génération, 1 pour un Pro) d'un appareil de série de la famille, à son nom d'usine, sinon None."""
    nom = appareil.get("name", "")
    type_ = appareil.get("deviceTypeIdentifier", "")
    # Le type confirme le nom : un appareil renommé « iPhone 18 Pro » n'en devient pas un.
    if famille == "ipad":
        trouve = IPAD_DE_SERIE.match(nom)
        # Le type d'un iPad Pro porte sa mémoire (`…-M5-12GB`) ; le nom, seulement la variante haute.
        if not trouve or not re.fullmatch(re.escape(TYPE) + rf"iPad-Pro-13-inch-M{trouve['generation']}(-\d+GB)?",
                                          type_):
            return None
        return int(trouve["generation"]), 1
    trouve = IPHONE_DE_SERIE.match(nom)
    if not trouve or type_ != TYPE + nom.replace(" ", "-"):
        return None
    return int(trouve["generation"]), 1 if trouve["pro"] else 0


def choisir(liste: dict, famille: str = "iphone") -> tuple[int, str, str]:
    """(sortie, udid, ce qui se dit) — voir l'en-tête du module."""
    try:
        runtimes = []
        for cle, appareils in liste["devices"].items():
            version = RUNTIME_STANDARD.match(cle)
            disponibles = [a for a in appareils if a.get("isAvailable", True)]
            if version and disponibles:
                runtimes.append((tuple(int(n or 0) for n in version.groups()), disponibles))
        if not runtimes:
            return 2, "", ("INCONNU : aucun runtime iOS standard avec un appareil disponible "
                           "(xcodebuild -downloadPlatform iOS)")
        version, appareils = max(runtimes, key=lambda r: r[0])
        ios = ".".join(str(n) for n in version[:2])
        candidats = sorted(
            ((rang, a["udid"], a["name"]) for a in appareils if (rang := de_serie(a, famille)) is not None),
            key=lambda c: (-c[0][0], -c[0][1], c[1]))
    except (KeyError, TypeError, AttributeError) as erreur:
        return 2, "", f"INCONNU : liste de simctl illisible ({erreur!r})"
    if not candidats:
        presents = ", ".join(sorted(a.get("name", "?") for a in appareils)) or "aucun"
        return 2, "", (f"INCONNU : aucun {ATTENDU[famille]} sous iOS {ios} — "
                       f"présents : {presents}. En créer un, ou fixer DESTINATION.")
    _, udid, nom = candidats[0]
    return 0, udid, f"Simulateur retenu : {nom}, iOS {ios} ({udid})"


# ── Autotest ────────────────────────────────────────────────────────────────────
def _appareil(nom: str, udid: str, type_: str | None = None, disponible: bool = True) -> dict:
    return {"udid": udid, "isAvailable": disponible, "state": "Shutdown", "name": nom,
            "deviceTypeIdentifier": TYPE + (type_ or nom.replace(" ", "-"))}


_IOS = "com.apple.CoreSimulator.SimRuntime.iOS-"
#: Le poste, le 11/11/2026 : l'ordre et les noms de `simctl list devices available -j`.
POSTE = {"devices": {
    _IOS + "27-2": [
        _appareil("iPhone 18 Pro", "8DE1DDC7"),
        _appareil("iPhone 18 Pro (#12 residence)", "033241F8", "iPhone-18-Pro"),
        _appareil("iPhone 18 Pro Max", "6A07E5E0"),
        _appareil("iPhone 17e", "A9CBD473"),
        _appareil("iPhone Air", "33E1DBB5"),
        _appareil("iPhone 17", "CB9882FE"),
        _appareil("iPad mini (A20 Pro)", "3F8369CD", "iPad-mini-A20-Pro"),
    ],
    "com.apple.CoreSimulator.SimRuntime.watchOS-27-2": [
        _appareil("Apple Watch SE 3 (44mm)", "25E7FDF4", "Apple-Watch-SE-3-44mm")],
    _IOS + "27-2-iPhone19-4": [_appareil("iPhone Duo", "B1DAF8DE")],
}}
#: Le poste, le 15/11/2026 : les mêmes iPhone, et les six iPad du runtime 27.2 (#220).
IPAD_POSTE = {"devices": {**POSTE["devices"], _IOS + "27-2": [
    *(a for a in POSTE["devices"][_IOS + "27-2"] if not a["name"].startswith("iPad")),
    _appareil("iPad mini (A20 Pro)", "3F8369CD", "iPad-mini-A20-Pro"),
    _appareil("iPad Pro 13-inch (M5)", "00D2C9B9", "iPad-Pro-13-inch-M5-12GB"),
    _appareil("iPad Pro 11-inch (M5)", "0B8E685F", "iPad-Pro-11-inch-M5-12GB"),
    _appareil("iPad Air 13-inch (M4)", "AB4F5FD5", "iPad-Air-13-inch-M4"),
    _appareil("iPad Air 11-inch (M4)", "3A4E5E5E", "iPad-Air-11-inch-M4"),
    _appareil("iPad (A16)", "8A1443BC", "iPad-A16"),
]}}


def autotest() -> int:
    seul_le_duo = {"devices": {_IOS + "27-2-iPhone19-4": POSTE["devices"][_IOS + "27-2-iPhone19-4"]}}
    hors_serie = [a for a in POSTE["devices"][_IOS + "27-2"] if a["name"] not in ("iPhone 18 Pro", "iPhone 17")]
    sans_serie = {"devices": {_IOS + "27-2": hors_serie}}
    cas = [
        ("le poste : l'iPhone 18 Pro, pas l'iPhone Duo du second runtime", POSTE, 0, "8DE1DDC7"),
        ("l'iPhone Duo seul : INCONNU", seul_le_duo, 2, ""),
        ("ni Max, ni e, ni Air, ni clone renommé : INCONNU", sans_serie, 2, ""),
        ("les versions se comparent en nombres : 27 après 9",
         {"devices": {_IOS + "9-3": [_appareil("iPhone 6", "A")], _IOS + "27-2": [_appareil("iPhone 18", "B")]}},
         0, "B"),
        ("la génération d'abord, puis le Pro, puis l'udid",
         {"devices": {_IOS + "27-2": [_appareil("iPhone 17 Pro", "A"), _appareil("iPhone 18", "D"),
                                      _appareil("iPhone 18 Pro", "C"), _appareil("iPhone 18 Pro", "B")]}}, 0, "B"),
        ("un appareil indisponible ne compte pas",
         {"devices": {_IOS + "27-2": [_appareil("iPhone 18 Pro", "A", disponible=False), _appareil("iPhone 17", "B")]}},
         0, "B"),
        ("un runtime plus récent mais vide ne masque pas le précédent",
         {"devices": {_IOS + "28-0": [], _IOS + "27-2": [_appareil("iPhone 18", "A")]}}, 0, "A"),
        ("renommé « iPhone 18 Pro » sans en être un : INCONNU",
         {"devices": {_IOS + "27-2": [_appareil("iPhone 18 Pro", "A", "iPhone-Duo")]}}, 2, ""),
        ("aucun runtime iOS : INCONNU", {"devices": {"com.apple.CoreSimulator.SimRuntime.tvOS-27-2": []}}, 2, ""),
        ("liste illisible : INCONNU", {"appareils": {}}, 2, ""),
        # --ipad (#220) : la liste du poste du 15/11/2026, ses six iPad.
        ("iPad : le 13 pouces de série, ni Air, ni 11 pouces, ni mini, ni l'iPhone", IPAD_POSTE, 0, "00D2C9B9", "ipad"),
        ("iPad : la puce la plus récente, puis l'udid",
         {"devices": {_IOS + "27-2": [_appareil("iPad Pro 13-inch (M4)", "A", "iPad-Pro-13-inch-M4-8GB"),
                                      _appareil("iPad Pro 13-inch (M5)", "C", "iPad-Pro-13-inch-M5-12GB"),
                                      _appareil("iPad Pro 13-inch (M5)", "B", "iPad-Pro-13-inch-M5")]}},
         0, "B", "ipad"),
        ("iPad : renommé « iPad Pro 13-inch (M5) » sans en être un : INCONNU",
         {"devices": {_IOS + "27-2": [_appareil("iPad Pro 13-inch (M5)", "A", "iPad-Air-13-inch-M4")]}}, 2, "", "ipad"),
        ("iPad : variante « (16GB) » et clone renommé refusés : INCONNU",
         {"devices": {_IOS + "27-2": [_appareil("iPad Pro 13-inch (M5) (16GB)", "A", "iPad-Pro-13-inch-M5-16GB"),
                                      _appareil("iPad Pro 13-inch (M5) (#3)", "B", "iPad-Pro-13-inch-M5-12GB")]}},
         2, "", "ipad"),
        ("iPad : le poste du 11/11 n'a qu'un iPad mini : INCONNU", POSTE, 2, "", "ipad"),
        ("iPhone : les iPad du 15/11 ne changent rien au choix", IPAD_POSTE, 0, "8DE1DDC7"),
    ]
    rate = 0
    for nom, liste, sortie, udid, *famille in cas:
        obtenu, retenu, dit = choisir(liste, *famille)
        if (obtenu, retenu) != (sortie, udid) or not dit:
            print(f"❌ {nom} : sortie {obtenu}, udid {retenu!r} ({dit})")
            rate += 1
    print("✅ destination_simulateur : autotest" if rate == 0 else f"── {rate} cas en échec")
    return 0 if rate == 0 else 1


def main(argv: list[str]) -> int:
    if argv[1:] == ["--autotest"]:
        return autotest()
    if argv[1:] not in ([], ["--ipad"]):
        print("usage : xcrun simctl list devices available -j | destination_simulateur.py [--ipad] | --autotest",
              file=sys.stderr)
        return 2
    famille = "ipad" if argv[1:] == ["--ipad"] else "iphone"
    try:
        liste = json.load(sys.stdin)
    except ValueError as erreur:
        print(f"❓ INCONNU : liste de simctl illisible ({erreur})", file=sys.stderr)
        return 2
    sortie, udid, dit = choisir(liste, famille)
    print(dit if sortie == 0 else f"❓ {dit}", file=sys.stderr)
    if sortie == 0:
        print(udid)
    return sortie


if __name__ == "__main__":
    sys.exit(main(sys.argv))
