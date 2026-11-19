# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Choisir le simulateur des tests : un iPhone ordinaire du runtime iOS standard le plus récent
— ou un iPad (`--ipad`), une Apple TV pour l'écran de hall (`--tv`, #218), ou une Apple Watch
(`--montre`, #226).

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

Avec `--tv` (#218), la même règle sur tvOS : un runtime tvOS standard, une « Apple TV
4K (Nᵉ generation) » à son nom d'usine, en 4K — pas sa variante « (at 1080p) » —, la
génération la plus récente.

Avec `--montre` (#226), la même règle sur watchOS : une « Apple Watch Series N (Mmm) » à son
nom d'usine — ni SE, ni Ultra —, la génération la plus récente, le plus grand boîtier d'abord.

Avec `--os X.Y` (#287), le runtime est celui de cette version, et lui seul : la CI joue
`OS_SIMULATEUR_CI` d'`outillage.env`, le poste aussi sur demande. Absent : INCONNU, avec la
commande d'installation — jamais une autre version à sa place.

`--systeme UDID OS_CI` nomme le système de l'appareil (« iOS 26.5 ») et le compare à celui
de la CI, pour le résumé d'un passage : un vert sous 27.2 ne vaut pas pour la CI, qui joue
26.5 (#287, le défaut de #279 vu en CI seule). Illisible : INCONNU, dit.

Les noms ne s'écrivent pas en dur : ils changent d'une image de runner à l'autre.
`--autotest` rejoue la règle sur la liste du poste du 11/11/2026 (deux runtimes
27.2, dont celui du seul iPhone Duo) : un contrôle qui ne refuse rien ne prouve rien.
"""

from __future__ import annotations

import json
import re
import sys

IPHONE_DE_SERIE = re.compile(r"^iPhone (?P<generation>\d+)(?P<pro> Pro)?$")
IPAD_DE_SERIE = re.compile(r"^iPad Pro 13-inch \(M(?P<generation>\d+)\)$")
APPLE_TV_DE_SERIE = re.compile(r"^Apple TV 4K \((?P<generation>\d+)(?P<suffixe>st|nd|rd|th) generation\)$")
APPLE_WATCH_DE_SERIE = re.compile(r"^Apple Watch Series (?P<generation>\d+) \((?P<boitier>\d+)mm\)$")
TYPE = "com.apple.CoreSimulator.SimDeviceType."
#: Par famille : sa plateforme, et ce que le message d'INCONNU dit chercher.
FAMILLES = {"iphone": ("iOS", "iPhone de série (« iPhone N » ou « iPhone N Pro »)"),
            "ipad": ("iOS", "iPad Pro 13 pouces de série (« iPad Pro 13-inch (MN) »)"),
            "tv": ("tvOS", "Apple TV 4K de série (« Apple TV 4K (Nᵉ generation) »)"),
            "montre": ("watchOS", "Apple Watch de série (« Apple Watch Series N (Mmm) »)")}


def runtime_standard(plateforme: str) -> re.Pattern[str]:
    """Le runtime STANDARD d'une plateforme : `…SimRuntime.iOS-27-2`, jamais celui d'un appareil."""
    return re.compile(rf"^com\.apple\.CoreSimulator\.SimRuntime\.{plateforme}-(\d+)-(\d+)(?:-(\d+))?$")


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
    if famille == "tv":
        trouve = APPLE_TV_DE_SERIE.match(nom)
        # Le type distingue la 4K de sa variante à 1080p, au même nom à « (at 1080p) » près.
        attendu = f"Apple-TV-4K-{trouve['generation']}{trouve['suffixe']}-generation-4K" if trouve else ""
        if not trouve or type_ != TYPE + attendu:
            return None
        return int(trouve["generation"]), 0
    if famille == "montre":
        trouve = APPLE_WATCH_DE_SERIE.match(nom)
        if not trouve or type_ != TYPE + f"Apple-Watch-Series-{trouve['generation']}-{trouve['boitier']}mm":
            return None
        return int(trouve["generation"]), int(trouve["boitier"])
    trouve = IPHONE_DE_SERIE.match(nom)
    if not trouve or type_ != TYPE + nom.replace(" ", "-"):
        return None
    return int(trouve["generation"]), 1 if trouve["pro"] else 0


def nombres_os(version: str) -> tuple[int, ...] | None:
    """« 26.5 » → (26, 5) ; None si ce n'est pas une version."""
    return tuple(int(n) for n in version.split(".")) if re.fullmatch(r"\d+(\.\d+){1,2}", version) else None


def choisir(liste: dict, famille: str = "iphone", systeme: str | None = None) -> tuple[int, str, str]:
    """(sortie, udid, ce qui se dit) — voir l'en-tête du module."""
    plateforme, attendu = FAMILLES[famille]
    runtime = runtime_standard(plateforme)
    voulu = nombres_os(systeme) if systeme else None
    if systeme and voulu is None:
        return 2, "", f"INCONNU : version du système illisible ({systeme!r}, attendu « X.Y »)"
    try:
        runtimes = []
        for cle, appareils in liste["devices"].items():
            version = runtime.match(cle)
            disponibles = [a for a in appareils if a.get("isAvailable", True)]
            if version and disponibles:
                runtimes.append((tuple(int(n or 0) for n in version.groups()), disponibles))
        if voulu:
            runtimes = [r for r in runtimes if r[0][:len(voulu)] == voulu]
        if not runtimes:
            demande = f" {systeme}" if systeme else ""
            return 2, "", (f"INCONNU : aucun runtime {plateforme}{demande} standard avec un appareil disponible "
                           f"(xcodebuild -downloadPlatform {plateforme}"
                           + (f" -buildVersion {systeme})" if systeme else ")"))
        version, appareils = max(runtimes, key=lambda r: r[0])
        os_ = ".".join(str(n) for n in version[:2])
        candidats = sorted(
            ((rang, a["udid"], a["name"]) for a in appareils if (rang := de_serie(a, famille)) is not None),
            key=lambda c: (-c[0][0], -c[0][1], c[1]))
    except (KeyError, TypeError, AttributeError) as erreur:
        return 2, "", f"INCONNU : liste de simctl illisible ({erreur!r})"
    if not candidats:
        presents = ", ".join(sorted(a.get("name", "?") for a in appareils)) or "aucun"
        return 2, "", (f"INCONNU : aucun {attendu} sous {plateforme} {os_} — "
                       f"présents : {presents}. En créer un, ou fixer DESTINATION.")
    _, udid, nom = candidats[0]
    return 0, udid, f"Simulateur retenu : {nom}, {plateforme} {os_} ({udid})"


def systeme_de(liste: dict, udid: str) -> str | None:
    """« iOS 26.5 » : le système du runtime qui porte l'appareil `udid`, sinon None."""
    try:
        for cle, appareils in liste["devices"].items():
            if any(a.get("udid") == udid for a in appareils):
                trouve = re.match(r"^com\.apple\.CoreSimulator\.SimRuntime\.(iOS|tvOS|watchOS)-(\d+)-(\d+)", cle)
                return f"{trouve[1]} {trouve[2]}.{trouve[3]}" if trouve else None
    except (KeyError, TypeError, AttributeError):
        return None
    return None


def ligne_systeme(joue: str | None, ci: str | None) -> str:
    """La ligne « Système » du résumé d'un passage : le système joué, celui de la CI (#287)."""
    if not joue:
        return "Système : INCONNU — la version jouée ne se lit pas (simctl)" + (f" ; la CI joue {ci}." if ci else ".")
    if not ci or nombres_os(ci) is None:
        return f"Système : {joue} joué ; celui de la CI INCONNU (OS_SIMULATEUR_CI, outillage.env)."
    if nombres_os(joue.split()[-1]) == nombres_os(ci):
        return f"Système : {joue}, celui de la CI (OS_SIMULATEUR_CI, outillage.env)."
    return (f"Système : {joue} joué ; la CI joue {ci} — un vert ici ne vaut pas pour la CI : "
            "`OS_SIMULATEUR=ci bash scripts/tests-simulateur.sh`.")


# ── Autotest ────────────────────────────────────────────────────────────────────
def _appareil(nom: str, udid: str, type_: str | None = None, disponible: bool = True) -> dict:
    return {"udid": udid, "isAvailable": disponible, "state": "Shutdown", "name": nom,
            "deviceTypeIdentifier": TYPE + (type_ or nom.replace(" ", "-"))}


_IOS = "com.apple.CoreSimulator.SimRuntime.iOS-"
_TVOS = "com.apple.CoreSimulator.SimRuntime.tvOS-"
_WATCHOS = "com.apple.CoreSimulator.SimRuntime.watchOS-"
#: Le poste, le 17/11/2026 (#226) : les cinq montres du runtime watchOS 27.2.
MONTRES_POSTE = {"devices": {_WATCHOS + "27-2": [
    _appareil("Apple Watch Series 12 (46mm)", "FEBA1967", "Apple-Watch-Series-12-46mm"),
    _appareil("Apple Watch Series 12 (42mm)", "323AB555", "Apple-Watch-Series-12-42mm"),
    _appareil("Apple Watch Ultra 4 (49mm)", "6411EF64", "Apple-Watch-Ultra-4-49mm"),
    _appareil("Apple Watch SE 3 (44mm)", "25E7FDF4", "Apple-Watch-SE-3-44mm"),
    _appareil("Apple Watch SE 3 (40mm)", "BB8C13A7", "Apple-Watch-SE-3-40mm"),
]}}
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
    #: Le poste, le 15/11/2026 (#218) : la 4K et sa variante à 1080p.
    _TVOS + "27-2": [
        _appareil("Apple TV 4K (4th generation) (at 1080p)", "2F0A1C55", "Apple-TV-4K-4th-generation-1080p"),
        _appareil("Apple TV 4K (4th generation)", "9C3E7B21", "Apple-TV-4K-4th-generation-4K"),
    ],
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
    tv = POSTE["devices"][_TVOS + "27-2"]
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
        ("aucun runtime iOS : INCONNU", {"devices": {_TVOS + "27-2": POSTE["devices"][_TVOS + "27-2"]}}, 2, ""),
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
        # --tv (#218) : la liste du poste, sa 4K et sa variante à 1080p.
        ("tv : la 4K, pas sa variante à 1080p", POSTE, 0, "9C3E7B21", "tv"),
        ("tv : la 1080p seule : INCONNU", {"devices": {_TVOS + "27-2": tv[:1]}}, 2, "", "tv"),
        ("tv : la génération la plus récente",
         {"devices": {_TVOS + "27-2": [_appareil("Apple TV 4K (3rd generation)", "A", "Apple-TV-4K-3rd-generation-4K"),
                                       tv[1]]}}, 0, "9C3E7B21", "tv"),
        ("tv : aucun runtime tvOS : INCONNU", {"devices": {_IOS + "27-2": POSTE["devices"][_IOS + "27-2"]}}, 2, "",
         "tv"),
    ]
    rate = 0
    montres = MONTRES_POSTE["devices"][_WATCHOS + "27-2"]
    cas += [
        # --montre (#226) : la liste du poste du 17/11/2026, ses cinq montres.
        ("montre : la Series la plus récente, le grand boîtier", MONTRES_POSTE, 0, "FEBA1967", "montre"),
        ("montre : ni SE ni Ultra : INCONNU", {"devices": {_WATCHOS + "27-2": montres[2:]}}, 2, "", "montre"),
        ("montre : le poste du 11/11 n'a qu'une SE : INCONNU", POSTE, 2, "", "montre"),
        ("montre : un clone renommé n'est pas une Series",
         {"devices": {_WATCHOS + "27-2": [_appareil("Apple Watch Series 12 (46mm)", "A", "Apple-Watch-SE-3-44mm")]}},
         2, "", "montre"),
        ("montre : aucun runtime watchOS : INCONNU", {"devices": {_IOS + "27-2": POSTE["devices"][_IOS + "27-2"]}}, 2,
         "", "montre"),
    ]
    # --os (#287) : le poste du 18/11/2026, la 26.5 de la CI installée à côté de la 27.2.
    deux = {"devices": {**POSTE["devices"], _IOS + "26-5": [
        _appareil("iPhone 17 (iOS 26.5, CI)", "F4E7F276", "iPhone-17"), _appareil("iPhone 17 Pro", "C1")]}}
    cas += [
        ("os : sans version, la plus récente — la 27.2", deux, 0, "8DE1DDC7", "iphone", None),
        ("os : 26.5 demandée, l'iPhone de série de la 26.5", deux, 0, "C1", "iphone", "26.5"),
        ("os : 26.5 demandée, seul un clone renommé : INCONNU",
         {"devices": {_IOS + "26-5": deux["devices"][_IOS + "26-5"][:1]}}, 2, "", "iphone", "26.5"),
        ("os : 26.4 absente, jamais une autre à sa place : INCONNU", deux, 2, "", "iphone", "26.4"),
        ("os : version illisible : INCONNU", deux, 2, "", "iphone", "ci"),
        ("os : tvOS 26.5 absente du poste : INCONNU", POSTE, 2, "", "tv", "26.5"),
    ]
    for nom, liste, sortie, udid, *famille in cas:
        obtenu, retenu, dit = choisir(liste, *famille)
        if (obtenu, retenu) != (sortie, udid) or not dit:
            print(f"❌ {nom} : sortie {obtenu}, udid {retenu!r} ({dit})")
            rate += 1
    _, _, dit = choisir(deux, "iphone", "26.4")
    if "-buildVersion 26.4" not in dit:
        print(f"❌ os : l'INCONNU d'une version absente doit dire comment l'installer ({dit})")
        rate += 1
    systemes = [
        ("système : l'appareil de la 26.5", systeme_de(deux, "C1"), "iOS 26.5"),
        ("système : l'iPhone Duo, runtime d'appareil", systeme_de(POSTE, "B1DAF8DE"), "iOS 27.2"),
        ("système : la montre", systeme_de(MONTRES_POSTE, "FEBA1967"), "watchOS 27.2"),
        ("système : udid inconnu", systeme_de(POSTE, "ZZZ"), None),
        ("système : liste illisible", systeme_de({"appareils": {}}, "C1"), None),
        ("ligne : 27.2 au poste, la CI à 26.5", ligne_systeme("iOS 27.2", "26.5"),
         "Système : iOS 27.2 joué ; la CI joue 26.5 — un vert ici ne vaut pas pour la CI : "
         "`OS_SIMULATEUR=ci bash scripts/tests-simulateur.sh`."),
        ("ligne : la version de la CI jouée", ligne_systeme("tvOS 26.5", "26.5"),
         "Système : tvOS 26.5, celui de la CI (OS_SIMULATEUR_CI, outillage.env)."),
        ("ligne : jouée illisible", ligne_systeme(None, "26.5"),
         "Système : INCONNU — la version jouée ne se lit pas (simctl) ; la CI joue 26.5."),
        ("ligne : CI illisible", ligne_systeme("iOS 27.2", ""),
         "Système : iOS 27.2 joué ; celui de la CI INCONNU (OS_SIMULATEUR_CI, outillage.env)."),
    ]
    for nom, obtenu, attendu in systemes:
        if obtenu != attendu:
            print(f"❌ {nom} : {obtenu!r}, attendu {attendu!r}")
            rate += 1
    print("✅ destination_simulateur : autotest" if rate == 0 else f"── {rate} cas en échec")
    return 0 if rate == 0 else 1


USAGE = ("usage : xcrun simctl list devices available -j | destination_simulateur.py [--ipad|--tv|--montre]"
         " [--os X.Y]\n        xcrun simctl list devices -j | destination_simulateur.py --systeme UDID OS_CI"
         "\n        destination_simulateur.py --autotest")


def main(argv: list[str]) -> int:
    arguments = argv[1:]
    if arguments == ["--autotest"]:
        return autotest()
    if len(arguments) == 3 and arguments[0] == "--systeme":
        try:
            liste = json.load(sys.stdin)
        except ValueError:
            liste = {}
        print(ligne_systeme(systeme_de(liste, arguments[1]), arguments[2]))
        return 0
    systeme = None
    if arguments[-2:-1] == ["--os"]:
        systeme, arguments = arguments[-1], arguments[:-2]
    familles = {(): "iphone", ("--ipad",): "ipad", ("--tv",): "tv", ("--montre",): "montre"}
    famille = familles.get(tuple(arguments))
    if famille is None:
        print(USAGE, file=sys.stderr)
        return 2
    try:
        liste = json.load(sys.stdin)
    except ValueError as erreur:
        print(f"❓ INCONNU : liste de simctl illisible ({erreur})", file=sys.stderr)
        return 2
    sortie, udid, dit = choisir(liste, famille, systeme)
    print(dit if sortie == 0 else f"❓ {dit}", file=sys.stderr)
    if sortie == 0:
        print(udid)
    return sortie


if __name__ == "__main__":
    sys.exit(main(sys.argv))
