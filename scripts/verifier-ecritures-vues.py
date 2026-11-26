#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Ce que la skill `swiftui-patterns` interdit d'écrire dans le code de l'app (#345 à #348).

Les règles qu'elle énonce et que rien ne tenait (audit du 23/11/2026) :

- **formats** : une date, un nombre, un montant s'écrivent par `FormatsDuSite`, fr-FR et fuseau
  de Paris — jamais `.formatted(`, `format: .dateTime`, `format: .number`, un `DateFormatter` ou
  un `NumberFormatter` hors de `Commun/Texte/` (#346 : onze formats écrits dans des écrans, trois
  au fuseau de l'appareil) ;
- **mesures** : un rayon de coin et un cadre de 44 pt se lisent dans `Mise` (`Charte/`) — jamais
  `cornerRadius: <nombre>` ni `frame(… 44 …)` hors de `Charte/` (#347). Les petits espacements
  (`spacing:`, `padding`) restent libres : la skill le dit ;
- **lectures à la main** : l'API se lit par le client généré — jamais `.data(from:` ou
  `.data(for:` d'une `URLSession` hors des lectures nommées ici, ni le préfixe `"api/` hors de
  `ClientCoproFirst.swift` (#345 : le logo demandé à la main) ;
- **recopies** (#348) : un lien `mailto:` ou `tel:` se forme par `LienDeContact` ; le chemin
  d'une affaire se lit dans la table générée (`CheminDuSite.affaires`), jamais `"/tickets…"`
  écrit ; une feuille de saisie se pose dans `FeuilleDeSaisie`, jamais son squelette recopié
  (la phrase d'erreur en tête de formulaire en est la signature) ;
- **dépliages** (#384) : un en-tête qui déplie dit son état et son indication par
  `.depliage(…)` — jamais une indication « Déplie… / Replie… » écrite sur place, sans l'état
  que les tests d'interface lisent (`deplier(_:)`).

Une divergence légitime se déclare dans `EXCEPTIONS` : le fichier, la règle, le NOMBRE de lignes
qu'elle couvre et sa raison. Une ligne de plus est refusée ; une de moins aussi — l'exception
ne sert plus autant, son nombre baisse (plafond décroissant). Les tests (ils écrivent les valeurs
attendues), les fichiers générés (`Genere/`) et les commentaires ne sont pas lus.

Sortie : 0 conforme, 1 refus, 2 INCONNU (moins de `PLANCHER` fichiers lus). `--autotest`.
"""

from __future__ import annotations

import pathlib
import re
import sys
import tempfile

RACINE = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RACINE / "scripts"))
import portee  # noqa: E402  (la liste des dossiers, #341)

#: En deçà, la portée a cassé : INCONNU, jamais conforme (standards/04).
PLANCHER = 100

REGLES: dict[str, tuple[re.Pattern[str], str, str]] = {
    # règle : (motif, dossier où elle est permise, la consigne)
    "formats": (
        re.compile(r"\.formatted\(|format:\s*\.(?:dateTime|number)\b|\b(?:Date|Number)Formatter\("),
        "CoproFirst/Commun/Texte/",
        "par FormatsDuSite (Commun/Texte/FormatsDuSite.swift), fr-FR et fuseau de Paris",
    ),
    "mesures": (
        re.compile(r"cornerRadius:\s*\d|\.frame\([^)]*\b44\b"),
        "CoproFirst/Charte/",
        "par Mise (Charte/Charte.swift) : rayon, rayonTuile, cible, medaillon…",
    ),
    "lectures": (
        re.compile(r"\.data\((?:from|for):|\"/?api/"),
        "Paquets/ClientAPI/Sources/ClientAPI/ClientCoproFirst.swift",
        "par le client généré (ServiceAPI.client, ou clientPublic pour une route publique)",
    ),
    "contacts": (
        re.compile(r"\"(?:mailto|tel):"),
        "CoproFirst/Commun/Composants/LienDeContact.swift",
        "par LienDeContact.courriel(_:) ou .appel(_:)",
    ),
    "chemins": (
        re.compile(r"\"/?tickets(?:[/\"]|\\\()"),
        "CoproFirst/Navigation/PagesParDefaut.swift",
        "par CheminDuSite.affaires, .affaire(_:), .adresse(affaire:sur:) — la route générée",
    ),
    "feuilles": (
        re.compile(r"MessageErreur\(texte: erreur\)\.listRowInsets"),
        "CoproFirst/Commun/Composants/FeuilleDeSaisie.swift",
        "par FeuilleDeSaisie(titre:erreur:) { … } barre: { BoutonsFeuille(…) }",
    ),
    "depliages": (
        re.compile(r"accessibilityHint\([^)]*(?:\"(?:Déplie|Replie)|\.(?:deplier|replier)\b)"),
        "CoproFirst/Commun/Composants/Depliage.swift",
        "par .depliage(ouvert:deplier:replier:) — l'état en valeur, que deplier(_:) lit",
    ),
}

#: (fichier, règle) → (nombre de lignes, raison). Une raison dit pourquoi, et depuis quand.
EXCEPTIONS: dict[tuple[str, str], tuple[int, str]] = {
    ("CoproFirst/Donnees/ElementDuFil.swift", "formats"): (
        2, "les en-têtes du fil (« LUNDI 2 NOVEMBRE ») suivent `Chronologie.calendrier`, qui range "
           "le fil au fuseau de l'APPAREIL : les écrire à Paris décalerait le jour d'un appareil "
           "hors de France — à trancher avec le rangement lui-même (#346, 24/11/2026)"),
    ("CoproFirst/Donnees/Apercu.swift", "formats"): (
        1, "des données SIMULÉES : un horodatage ISO, comme le serveur sérialise ses colonnes "
           "(24/11/2026)"),
    ("CoproFirst/Fonctions/Communaute/Formulaires.swift", "formats"): (
        1, "le prix d'une annonce en SAISIE : le champ lit ce que tape le clavier de l'appareil, "
           "ce n'est pas un affichage (24/11/2026)"),
    ("Paquets/ClientAPI/Sources/ClientAPI/ClientCoproFirst.swift", "formats"): (
        1, "le transcodeur des dates de l'API (ISO 8601) : ce qui part au serveur, pas un affichage "
           "(24/11/2026)"),
    ("CoproFirst/Commun/Composants/LogoResidence.swift", "mesures"): (
        1, "l'arrondi du logo, proportionné à son cadre (5 pt pour 44), pas un rayon de carte "
           "(24/11/2026)"),
    ("CoproFirst/Donnees/ServiceSimule+Logo.swift", "mesures"): (
        1, "le DESSIN du logo d'une résidence simulée (UIBezierPath), pas une vue (24/11/2026)"),
    ("CoproFirst/Entree/EnSavoirPlus/EnSavoirPlusView.swift", "mesures"): (
        2, "la carte de présentation d'« En savoir plus », plus ronde que les cartes de liste : "
           "le rendu validé de l'accueil (24/11/2026)"),
    ("CoproFirst/Fonctions/EspaceCS/Reporting/RepartitionCroisee.swift", "mesures"): (
        3, "les barres d'un graphique (4 et 2 pt), à l'échelle de leur épaisseur (24/11/2026)"),
    ("CoproFirst/Fonctions/Residence/Apercu+Residence.swift", "chemins"): (
        2, "des entrées SIMULÉES du carnet, à la forme que sert le serveur (`lien`) (24/11/2026)"),
    ("CoproFirst/Entree/Contenu/Vitrine.swift", "lectures"): (
        1, "`contenu.json` du SITE coprofirst.fr, pas l'API d'une installation (#51)"),
    ("CoproFirst/Session/PreuveAASA.swift", "lectures"): (
        1, "`/.well-known/apple-app-site-association`, la preuve d'un hôte : pas une route du "
           "contrat (#82)"),
    ("CoproFirst/Session/ServiceAPI+Detail.swift", "lectures"): (
        1, "les photos et pièces jointes de `/uploads/`, servies hors du contrat, derrière la "
           "session (forward_auth)"),
}

COMMENTAIRE = re.compile(r"^\s*//")


def lignes_fautives(chemin: str, texte: str) -> dict[str, list[str]]:
    """Par règle, les lignes d'un fichier qui l'enfreignent, « chemin:ligne : extrait »."""
    fautes: dict[str, list[str]] = {}
    if "/Genere/" in chemin:
        return fautes
    for numero, ligne in enumerate(texte.splitlines(), 1):
        if COMMENTAIRE.match(ligne):
            continue
        code = ligne.split(" // ")[0]
        for nom, (motif, permis, _) in REGLES.items():
            if motif.search(code) and not chemin.startswith(permis):
                fautes.setdefault(nom, []).append(f"{chemin}:{numero} : {ligne.strip()[:90]}")
    return fautes


def juger(racine: pathlib.Path) -> tuple[int, list[str]]:
    """Le nombre de fichiers lus, et les refus."""
    refus: list[str] = []
    trouvees: dict[tuple[str, str], list[str]] = {}
    lus = 0
    for f in portee.fichiers(racine, portee.CODE):
        lus += 1
        chemin = f.relative_to(racine).as_posix()
        for nom, lignes in lignes_fautives(chemin, f.read_text(encoding="utf-8")).items():
            trouvees[(chemin, nom)] = lignes
    for cle, lignes in sorted(trouvees.items()):
        declare = EXCEPTIONS.get(cle, (0, ""))[0]
        if len(lignes) > declare:
            consigne = REGLES[cle[1]][2]
            refus += [f"❌ {cle[1]} : {ligne} → {consigne}" for ligne in lignes]
    for cle, (nombre, _) in sorted(EXCEPTIONS.items()):
        lues = len(trouvees.get(cle, []))
        if lues < nombre:
            refus.append(f"❌ exception {cle[1]} de {cle[0]} : {nombre} déclarées, {lues} lues — la baisser")
    return lus, refus


def autotest() -> bool:
    cas = {
        ("CoproFirst/V.swift", "Text(date, format: .dateTime.day())"): {"formats"},
        ("CoproFirst/V.swift", "Text(n, format: .number)"): {"formats"},
        ("CoproFirst/V.swift", "LabeledContent(t, value: n.formatted())"): {"formats"},
        ("CoproFirst/V.swift", "let f = DateFormatter()"): {"formats"},
        ("CoproFirst/Commun/Texte/FormatsDuSite.swift", "valeur.formatted(style)"): set(),
        ("CoproFirst/V.swift", "Text(FormatsDuSite.nombre(n))"): set(),
        ("CoproFirst/V.swift", ".background(c, in: .rect(cornerRadius: 10, style: .continuous))"): {"mesures"},
        ("CoproFirst/V.swift", "RoundedRectangle(cornerRadius: 22)"): {"mesures"},
        ("CoproFirst/V.swift", ".frame(width: 44, height: 44)"): {"mesures"},
        ("CoproFirst/V.swift", ".clipShape(.rect(cornerRadius: Mise.rayon))"): set(),
        ("CoproFirst/V.swift", ".frame(width: 144)"): set(),
        ("CoproFirst/Charte/Charte.swift", ".frame(width: 44)"): set(),
        ("CoproFirst/V.swift", 'let a = adresse.appending(path: "api/config/logo.png")'): {"lectures"},
        ("CoproFirst/V.swift", "let (d, r) = try await session.data(from: url)"): {"lectures"},
        ("CoproFirst/V.swift", "try await session.data(for: requete)"): {"lectures"},
        ("Paquets/ClientAPI/Sources/ClientAPI/ClientCoproFirst.swift", 'appending(path: "api")'): set(),
        ("CoproFirst/V.swift", 'URL(string: "mailto:\\(email)")'): {"contacts"},
        ("CoproFirst/V.swift", 'URL(string: "tel:\\(chiffres)")'): {"contacts"},
        ("CoproFirst/V.swift", 'adresse.appending(path: "tickets/\\(id)")'): {"chemins"},
        ("CoproFirst/V.swift", 'lien.hasPrefix("/tickets/")'): {"chemins"},
        ("CoproFirst/V.swift", 'static let routeAffaires = "/tickets"'): {"chemins"},
        ("CoproFirst/V.swift", 'Text("Mes tickets")'): set(),
        ("CoproFirst/V.swift", "Section { MessageErreur(texte: erreur).listRowInsets(EdgeInsets()) }"): {"feuilles"},
        ("CoproFirst/V.swift", '.accessibilityHint(ouvert ? "Replie l\'exercice" : "Déplie l\'exercice")'): {"depliages"},
        ("CoproFirst/V.swift", ".accessibilityHint(ouvert ? Textes.replier : Textes.deplier)"): {"depliages"},
        ("CoproFirst/V.swift", '.accessibilityHint("Ouvre la fiche")'): set(),
        ("CoproFirst/V.swift", "    // Text(n, format: .number) en commentaire"): set(),
        ("CoproFirst/M/Genere/T.swift", "Text(n, format: .number)"): set(),
    }
    ok = all(set(lignes_fautives(chemin, texte)) == attendu for (chemin, texte), attendu in cas.items())
    with tempfile.TemporaryDirectory() as d:
        racine = pathlib.Path(d)
        (racine / "CoproFirst").mkdir()
        (racine / "CoproFirst" / "V.swift").write_text("Text(n, format: .number)\n", encoding="utf-8")
        # Une exception déclarée dont le fichier n'a plus la ligne : refusée (à baisser).
        _, refus = juger(racine)
        ok = ok and any("V.swift" in r for r in refus) and any("la baisser" in r for r in refus)
    return ok


def main() -> int:
    if sys.argv[1:] == ["--autotest"]:
        if autotest():
            print("✅ autotest des écritures des vues")
            return 0
        print("❌ autotest des écritures des vues en échec")
        return 1
    lus, refus = juger(RACINE)
    if lus < PLANCHER:
        print(f"❓ {lus} fichiers Swift lus (moins de {PLANCHER}) : écritures des vues INCONNUES")
        return 2
    for ligne in refus:
        print(ligne)
    if refus:
        return 1
    print(f"✅ formats, mesures, lectures, contacts, chemins, feuilles et dépliages par leur point commun ({lus} fichiers, {len(EXCEPTIONS)} exceptions)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
