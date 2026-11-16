# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Un hôte fictif se prend dans un nom RÉSERVÉ, jamais dans un domaine qui existe (#214).

`exemple.fr` est un vrai domaine tiers (il répond en DNS) : un test qui se trompe d'hôte
y envoie ses requêtes et ses cookies, un exemple copié par un utilisateur ses identifiants
(socle `standards/03` §8 quater ; coprofirst-android#57). Ce juge lit les chaînes du code
et des tests de l'app et refuse tout domaine qui n'est ni réservé (RFC 2606, 6761 :
`example.com`, `example.org`, `example.net`, `.test`, `.example`, `.invalid`,
`.localhost`), ni un vrai domaine du projet ou de ses dépendances, déclaré ci-dessous.

Une exception se déclare avec sa raison, et échoue le jour où elle ne sert plus.

Sortie : 0 conforme, 1 refus, 2 INCONNU. `--autotest` prouve qu'il refuse et accepte.
"""

from __future__ import annotations

import pathlib
import re
import sys
import tempfile

RACINE = pathlib.Path(__file__).resolve().parent.parent
DOSSIERS = ("CoproFirst", "CoproFirstTests", "CoproFirstUITests", "Paquets/ClientAPI/Sources", "Paquets/ClientAPI/Tests")
DOMAINE = re.compile(r"(?<![\w.-])((?:[a-z0-9-]+\.)+(?:fr|com|org|net|io|dev|eu|be|ch|app))(?![\w-]|\.\w)", re.IGNORECASE)
RESERVES = re.compile(r"(^|\.)(example\.(com|org|net))$|\.(test|example|invalid|localhost)$")
#: Les vrais domaines que l'app ou ses tests nomment exprès — rien d'autre n'y entre.
VRAIS = (
    "coprofirst.fr", "5hostachy.fr",            # le produit et ses installations connues
    "fr.coprofirst.app",                        # l'identifiant de l'app (DNS inversé)
    "github.com", "githubusercontent.com",      # le dépôt, le contrat publié
    "w3.org",                                   # espaces de noms XML et SVG
    "chat.whatsapp.com",                        # le lien d'un groupe, reconnu tel que servi
)
#: chemin → raison. Une dispense qui ne couvre plus rien échoue.
DISPENSES: dict[str, str] = {}


def autorise(domaine: str) -> bool:
    d = domaine.lower()
    return bool(RESERVES.search(d)) or any(d == v or d.endswith("." + v) for v in VRAIS)


def refus(chemin: str, texte: str) -> list[str]:
    fautes = []
    for numero, ligne in enumerate(texte.splitlines(), 1):
        if '"' not in ligne and "@" not in ligne:
            continue
        for domaine in DOMAINE.findall(ligne):
            if not autorise(domaine):
                fautes.append(f"{chemin}:{numero} : {domaine}")
    return fautes


def juger(racine: pathlib.Path) -> tuple[list[str], int]:
    fautes, lus, dispenses_utiles = [], 0, set()
    for dossier in DOSSIERS:
        if not (racine / dossier).is_dir():
            continue
        for f in sorted((racine / dossier).rglob("*.swift")):
            chemin = f.relative_to(racine).as_posix()
            trouves = refus(chemin, f.read_text(encoding="utf-8"))
            lus += 1
            if chemin in DISPENSES:
                if trouves:
                    dispenses_utiles.add(chemin)
                continue
            fautes += trouves
    for chemin in sorted(set(DISPENSES) - dispenses_utiles):
        if (racine / chemin).exists():
            fautes.append(f"{chemin} : dispensé sans plus porter de domaine fictif — retirer la dispense")
    return fautes, lus


def autotest() -> bool:
    fautifs = [
        'let r = URL(string: "https://tilleuls.exemple.fr")!',
        'email: "contact@ascenseurs.exemple.fr"',
        'let a = "https://inconnue.exemple.org/"',
        'let site = "residence-des-chenes.fr"',
    ]
    sains = [
        'let r = URL(string: "https://tilleuls.example.com")!',
        'email: "contact@ascenseurs.example.com"',
        'let a = "https://pirate.example/x", b = "c.test", d = "x.invalid"',
        'let demo = "https://demo.coprofirst.fr", p = "https://5hostachy.fr"',
        'let id = "fr.coprofirst.app.notifications"',
        'let svg = "http://www.w3.org/2000/svg"',
        "    // Self.fr n'est pas une chaîne",
        'let id = "GUX8KASNTG.fr.coprofirst.autre"',
    ]
    ok = all(refus("A.swift", f) for f in fautifs) and not any(refus("A.swift", s) for s in sains)
    with tempfile.TemporaryDirectory() as d:
        racine = pathlib.Path(d)
        (racine / "CoproFirst").mkdir()
        (racine / "CoproFirst" / "V.swift").write_text(fautifs[0] + "\n", encoding="utf-8")
        ok = ok and len(juger(racine)[0]) == 1
    return ok


def main() -> int:
    if sys.argv[1:] == ["--autotest"]:
        ok = autotest()
        print("✅ autotest des hôtes fictifs" if ok else "❌ autotest des hôtes fictifs en échec")
        return 0 if ok else 1
    fautes, lus = juger(RACINE)
    if lus == 0:
        print("❓ INCONNU : aucun fichier Swift à juger")
        return 2
    for faute in fautes:
        print(f"❌ {faute} — un nom réservé (example.com, .test…) ou un vrai domaine déclaré")
    if fautes:
        return 1
    print(f"✅ {lus} fichiers : aucun hôte fictif hors des noms réservés")
    return 0


if __name__ == "__main__":
    sys.exit(main())
