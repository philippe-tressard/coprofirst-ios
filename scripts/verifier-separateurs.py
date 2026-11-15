# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Un séparateur se rattache au mot qui le SUIT (#188, règle du site : coprofirst#2360).

Le site écrit ses trois séparateurs par une constante, `SEPARATEUR` de
`front/src/lib/separateurs.ts` : une espace SÉCABLE avant, INSÉCABLE après, pour que la
ligne se coupe devant le séparateur et jamais après. L'app la reçoit GÉNÉRÉE, la table
`Separateur` (`scripts/generateurs/separateurs.py`).

Ce juge refuse, dans le code Swift de l'app :

- un séparateur suivi d'une espace ORDINAIRE — il finit la ligne quand elle se coupe :
  « · » et « → » partout (`" · "`, `"\\(debut) → \\(fin)"`) ; « — » quand il JOINT deux
  valeurs (`separator: " — "`, `"\\(a) — \\(b)"`, `" — échéance…"`). Le tiret d'une INCISE
  (« votre compte — validation, rôle — vous parvient ») n'est pas un `SEPARATEUR` : la
  typographie y lie chaque tiret au texte qu'il encadre, il reste permis ;
- la RECOPIE de la constante (`" ·\\u{00A0}"`) : elle se lit dans la table générée.

Restent permis : les commentaires, les fichiers générés (`Genere/`) et les textes SERVIS
recopiés par la simulation (`Fixtures*.swift`, `Apercu+*.swift`, `ServiceSimule*.swift`).

Sortie : 0 conforme, 1 refus. `--autotest` prouve que le juge refuse et laisse passer.
"""

from __future__ import annotations

import pathlib
import re
import sys
import tempfile

RACINE = pathlib.Path(__file__).resolve().parent.parent
DOSSIERS = ("CoproFirst",)
# Un séparateur du site entre deux espaces ordinaires (U+0020) : l'espace d'après doit
# être insécable — `Separateur.point`, `.tiret` ou `.fleche`.
SECABLES = (
    re.compile(r" [·→] "),
    # Le tiret qui joint : au bord d'un littéral, ou contre une interpolation.
    re.compile(r'(?:"|\)) — | — (?:"|\\\()'),
)
# La constante elle-même, écrite à la main (échappée ou en caractère).
RECOPIE = re.compile(r"[·—→](?:\\u\{0*A0\}|\u00a0)", re.IGNORECASE)
COMMENTAIRE = re.compile(r"^\s*//")
DISPENSES = (re.compile(r"/Genere/"), re.compile(r"/(?:Fixtures|Apercu\+|ServiceSimule)[^/]*\.swift$"))


def refus(chemin: str, texte: str) -> list[str]:
    """Les lignes fautives d'un fichier, « chemin:ligne : extrait »."""
    if not chemin.endswith(".swift") or any(d.search(chemin) for d in DISPENSES):
        return []
    fautes = []
    for numero, ligne in enumerate(texte.splitlines(), 1):
        if COMMENTAIRE.match(ligne):
            continue
        # Le code seul : ce qui suit `//` hors d'une chaîne est un commentaire de fin de ligne.
        code = ligne.split(" // ")[0]
        if '"' not in code:
            continue
        if any(m.search(code) for m in SECABLES):
            fautes.append(f"{chemin}:{numero} : séparateur suivi d'une espace sécable — {ligne.strip()[:90]}")
        elif RECOPIE.search(code):
            fautes.append(f"{chemin}:{numero} : séparateur recopié — {ligne.strip()[:90]}")
    return fautes


def juger(racine: pathlib.Path) -> list[str]:
    fautes = []
    for dossier in DOSSIERS:
        for f in sorted((racine / dossier).rglob("*.swift")):
            fautes += refus(f.relative_to(racine).as_posix(), f.read_text(encoding="utf-8"))
    return fautes


def autotest() -> bool:
    cas = {
        ("CoproFirst/A.swift", 'let s = morceaux.joined(separator: " · ")'): True,
        ("CoproFirst/A.swift", 'Text("\\(a) — \\(b)")'): True,
        ("CoproFirst/A.swift", 'let d = "\\(debut) → \\(fin)"'): True,
        ("CoproFirst/A.swift", 'let s = morceaux.joined(separator: Separateur.point)'): False,
        ("CoproFirst/A.swift", 'return " — échéance \\(date)"'): True,
        ("CoproFirst/A.swift", '.joined(separator: " — ")'): True,
        ("CoproFirst/A.swift", '(Text("Ce qui a manqué — ").bold()'): True,
        ("CoproFirst/A.swift", 'static let point = " ·\\u{00A0}"'): True,
        ("CoproFirst/A.swift", 'let f = " →\u00a0"'): True,
        ("CoproFirst/A.swift", '"Ce qui concerne votre compte — validation, rôle — vous parvient."'): False,
        ("CoproFirst/A.swift", '"Hors ligne\\(Separateur.tiret)à jour"'): False,
        ("CoproFirst/A.swift", "    /// « résident · Conseil syndical »"): False,
        ("CoproFirst/A.swift", 'let n = 1 // « a · b »'): False,
        ("CoproFirst/M/Genere/T.swift", 'static let x = "a · b"'): False,
        ("CoproFirst/M/FixturesM.swift", '"titre": "Tous · du périmètre seulement",'): False,
        ("CoproFirst/Donnees/Apercu+Lecture.swift", '"titre": "Tous · du périmètre"'): False,
        ("CoproFirst/Donnees/ServiceSimule+Detail.swift", '"\\(nom) — texte fictif"'): False,
    }
    ok = all(bool(refus(chemin, texte)) == attendu for (chemin, texte), attendu in cas.items())
    with tempfile.TemporaryDirectory() as d:
        (pathlib.Path(d) / "CoproFirst").mkdir()
        (pathlib.Path(d) / "CoproFirst" / "V.swift").write_text('let s = " · "\n', encoding="utf-8")
        ok = ok and len(juger(pathlib.Path(d))) == 1
    return ok


def main() -> int:
    if sys.argv[1:] == ["--autotest"]:
        if autotest():
            print("✅ autotest des séparateurs")
            return 0
        print("❌ autotest des séparateurs en échec")
        return 1
    fautes = juger(RACINE)
    if not (RACINE / "CoproFirst").is_dir():
        print("❓ CoproFirst/ introuvable : séparateurs INCONNUS")
        return 2
    for faute in fautes:
        print(f"❌ {faute} → Separateur.point, .tiret ou .fleche (table générée)")
    if fautes:
        return 1
    print("✅ séparateurs du site générés, aucun recopié")
    return 0


if __name__ == "__main__":
    sys.exit(main())
