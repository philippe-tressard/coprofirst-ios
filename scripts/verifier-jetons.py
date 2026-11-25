#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Un jeton ne s'écrit jamais, et l'en-tête qui le porte s'écrit à UN endroit (#342).

Dans le code des quatre cibles et du paquet (`portee.CODE`), ce juge refuse :
  1. `headerFields[.authorization] =` ailleurs que dans `JetonAppareil.swift` — un second
     intercepteur divergeait déjà (la montre ne masquait pas comme l'écran de hall) ;
  2. un jeton gardé en texte : `jeton…: String` (propriété, paramètre, valeur associée) ou
     `case jeton(String…` — il se garde dans un `JetonMasque`, qui le tait partout ;
  3. un `customMirror` ailleurs que dans `JetonMasque.swift` : une seule enveloppe masquée,
     jamais un masquage réécrit type par type.

Les commentaires ne comptent pas. Sortie : 0 conforme, 1 refus, 2 INCONNU (rien de lu).
`--autotest` prouve qu'il refuse et qu'il accepte.
"""

from __future__ import annotations

import pathlib
import re
import sys
import tempfile

RACINE = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RACINE / "scripts"))
import portee  # noqa: E402  (la liste des dossiers, #341)

INTERCEPTEUR = "Paquets/ClientAPI/Sources/ClientAPI/JetonAppareil.swift"
ENVELOPPE = "Paquets/ClientAPI/Sources/ClientAPI/JetonMasque.swift"
REGLES = (
    (re.compile(r"headerFields\[\s*\.authorization\s*\]\s*=(?!=)"), INTERCEPTEUR,
     "en-tête Authorization écrit hors de JetonAppareil — passer par l'intercepteur du paquet"),
    (re.compile(r"\bjeton\w*\s*:\s*String\b|\bcase\s+jeton\w*\(\s*String\b"), None,
     "jeton gardé en texte — un JetonMasque, qui le tait dans toute trace"),
    (re.compile(r"\bcustomMirror\b"), ENVELOPPE,
     "masquage réécrit — garder la valeur dans un JetonMasque, l'unique enveloppe"),
)
COMMENTAIRE = re.compile(r"^\s*//")


def refus(chemin: str, texte: str) -> list[str]:
    fautes = []
    for numero, ligne in enumerate(texte.splitlines(), 1):
        if COMMENTAIRE.match(ligne):
            continue
        for motif, permis, message in REGLES:
            if chemin != permis and motif.search(ligne):
                fautes.append(f"{chemin}:{numero} : {message}")
    return fautes


def juger(racine: pathlib.Path) -> tuple[list[str], int]:
    fautes, lus = [], 0
    for f in portee.fichiers(racine, portee.CODE):
        fautes += refus(f.relative_to(racine).as_posix(), f.read_text(encoding="utf-8"))
        lus += 1
    return fautes, lus


def autotest() -> bool:
    fautifs = [
        ("CoproFirstWatch/C.swift", 'requete.headerFields[.authorization] = "Bearer \\(jeton)"'),
        ("CoproFirstTV/M.swift", "        let jeton: String"),
        ("CoproFirstTV/S.swift", "    func affiches(_ adresse: URL, jeton: String) async throws"),
        ("CoproFirst/M.swift", "    case liaison(adresse: URL, jeton: String, expireLe: Date)"),
        ("CoproFirstTV/R.swift", "    case jeton(String, expireLe: Date)"),
        ("CoproFirst/J.swift", "    var customMirror: Mirror { Mirror(self, children: []) }"),
    ]
    sains = [
        (INTERCEPTEUR, 'requete.headerFields[.authorization] = "Bearer \\(jeton.enClair)"'),
        (ENVELOPPE, "    public var customMirror: Mirror { Mirror(self, children: []) }"),
        ("CoproFirst/A.swift", "    #expect(requete.headerFields[.authorization] == nil)"),
        ("CoproFirst/B.swift", "    let jeton: JetonMasque"),
        ("CoproFirst/C.swift", "    var jetons: [Int: String] = [:]"),
        ("CoproFirst/D.swift", "    /// let jeton: String — l'ancienne forme"),
    ]
    ok = all(refus(c, t) for c, t in fautifs) and not any(refus(c, t) for c, t in sains)
    with tempfile.TemporaryDirectory() as d:
        racine = pathlib.Path(d)
        (racine / "CoproFirstWatch").mkdir()
        (racine / "CoproFirstWatch" / "V.swift").write_text(fautifs[0][1] + "\n", encoding="utf-8")
        ok = ok and juger(racine) == ([f"CoproFirstWatch/V.swift:1 : {REGLES[0][2]}"], 1)
    return ok


def main() -> int:
    if sys.argv[1:] == ["--autotest"]:
        ok = autotest()
        print("✅ autotest des jetons masqués" if ok else "❌ autotest des jetons masqués en échec")
        return 0 if ok else 1
    fautes, lus = juger(RACINE)
    if lus == 0:
        print("❓ INCONNU : aucun fichier Swift du code lu")
        return 2
    for faute in fautes:
        print(f"❌ {faute}")
    if fautes:
        return 1
    print(f"✅ {lus} fichiers : jetons masqués, en-tête Authorization écrit à un seul endroit")
    return 0


if __name__ == "__main__":
    sys.exit(main())
