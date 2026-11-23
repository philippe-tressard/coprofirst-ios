# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Un hôte fictif se prend dans un nom RÉSERVÉ, jamais dans un domaine qui existe (#214).

`exemple.fr` est un vrai domaine tiers (il répond en DNS) : un test qui se trompe d'hôte
y envoie ses requêtes et ses cookies, un exemple copié par un utilisateur ses identifiants
(socle `standards/03` §8 quater ; coprofirst-android#57). Ce juge lit le code et les tests
de l'app (`portee`) et les scripts, et refuse tout domaine qui n'est ni réservé (RFC 2606,
6761 : `example.com`, `example.org`, `example.net`, `.test`, `.example`, `.invalid`,
`.localhost`), ni un vrai domaine du projet ou de ses dépendances, déclaré ci-dessous.

L'hôte d'une adresse (`https://…`) et le domaine d'un courriel (`…@…`) se jugent QUEL QUE
SOIT leur suffixe (#344) : `.exemple`, `.info` ou `.paris` ne passent plus pour réservés. Un
hôte nu dans une chaîne (`"tilleuls.example.com"`) se reconnaît à son suffixe (`NUS`) : sans
lui, `"accueil.titre"` — un identifiant d'accessibilité — serait pris pour un domaine.

Une exception se déclare avec sa raison, et échoue le jour où elle ne sert plus.

Sortie : 0 conforme, 1 refus, 2 INCONNU. `--autotest` prouve qu'il refuse et accepte.
"""

from __future__ import annotations

import pathlib
import re
import sys
import tempfile

RACINE = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RACINE / "scripts"))
import portee  # noqa: E402  (la liste des dossiers, #341)
HOTE = r"[a-z0-9-]+(?:\.[a-z0-9-]+)+"
#: L'hôte d'une adresse, le domaine d'un courriel : tout suffixe.
ADRESSE = re.compile(rf"\b[a-z][a-z0-9+.-]*://({HOTE})|[\w.+-]@({HOTE})", re.IGNORECASE)
#: Les suffixes d'un hôte nu, et `exemple`, le faux suffixe le plus tentant en français.
NUS = "fr|com|org|net|io|dev|eu|be|ch|app|info|biz|paris|co|uk|de|es|it|lu|ca|us|me|xyz|exemple"
#: Un hôte s'écrit en minuscules : `TextesReglement.exemple` est un nom Swift, pas un domaine.
DOMAINE = re.compile(rf"(?<![\w.-])((?:[a-z0-9-]+\.)+(?:{NUS}))(?![\w@-]|\.\w)")
RESERVES = re.compile(r"(^|\.)(example\.(com|org|net))$|\.(test|example|invalid|localhost)$|^127(\.\d+){3}$")
#: Les vrais domaines que l'app ou ses tests nomment exprès — rien d'autre n'y entre.
VRAIS = (
    "coprofirst.fr", "5hostachy.fr",            # le produit et ses installations connues
    "fr.coprofirst.app",                        # l'identifiant de l'app (DNS inversé)
    "github.com", "githubusercontent.com",      # le dépôt, le contrat publié
    "w3.org",                                   # espaces de noms XML et SVG
    "chat.whatsapp.com",                        # le lien d'un groupe, reconnu tel que servi
)
#: chemin → raison. Une dispense qui ne couvre plus rien échoue.
DISPENSES: dict[str, str] = {
    "scripts/verifier-hotes.py": "son autotest écrit les hôtes qu'il doit refuser",
}


def autorise(domaine: str) -> bool:
    d = domaine.lower()
    return bool(RESERVES.search(d)) or any(d == v or d.endswith("." + v) for v in VRAIS)


def refus(chemin: str, texte: str) -> list[str]:
    fautes = []
    for numero, ligne in enumerate(texte.splitlines(), 1):
        trouves = [a or c for a, c in ADRESSE.findall(ligne)]
        # Une chaîne : `"` en Swift ; en Python aussi `'` (une apostrophe de commentaire Swift n'en ouvre pas).
        if '"' in ligne or (chemin.endswith(".py") and "'" in ligne):
            trouves += DOMAINE.findall(ligne)
        for domaine in dict.fromkeys(trouves):
            if not autorise(domaine):
                fautes.append(f"{chemin}:{numero} : {domaine}")
    return fautes


def juger(racine: pathlib.Path) -> tuple[list[str], int]:
    fautes, lus, dispenses_utiles = [], 0, set()
    for f in [*portee.fichiers(racine, portee.CODE + portee.TESTS), *portee.fichiers(racine, ("scripts",), "*.py")]:
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
        'let a = URL(string: "https://x.exemple")',
        'let a = URL(string: "https://x.info/chemin")',
        'let a = "http://ailleurs.exemple"',
        'courriel = "syndic@cabinet.paris"',
        'magasin.lire("get_flux /flux", de: "a.exemple")',
        "    // voir https://glycines.exemple/aide",
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
        'let i = "accueil.titre", j = TextesReglement.exemple',
        'email: "camille.exemple@example.com"',
        "@dataclass(frozen=True)",
        'let lien = "coprofirst://ouvrir?adresse=x"',
        'let a = "https://demo.test", b = "http://localhost"',
    ]
    ok = all(refus("A.swift", f) for f in fautifs) and not any(refus("A.swift", s) for s in sains)
    ok = ok and bool(refus("a.py", "INSTALLATIONS = {'a.fr': '1.14.0'}"))   # une chaîne Python
    ok = ok and not refus("a.py", 'url = f"http://127.0.0.1:{port}/figee"')     # la boucle locale
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
