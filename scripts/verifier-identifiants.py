# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Un `Label` qui porte un identifiant d'accessibilité est lu en UN élément (#183).

Sous iOS 26 (la CI), un `Label` qui porte lui-même `.accessibilityIdentifier` se résout
en son IMAGE, pas en son texte : l'élément n'est plus touchable et la requête du test
tourne jusqu'au délai (`EtiquetteLieu`, #177 ; ad8ab09). Le poste, en iOS 27, ne le voit
pas. La forme qui tient sur les deux : `.elementIdentifie(id, lu: texte)`
(`Commun/Composants/ElementIdentifie.swift`) — un élément qui dit ce que le texte dit,
VoiceOver y gagne une phrase. Le même trio écrit en clair est toléré.

Ce juge lit chaque expression qui commence par `Label(` ou `Label {` et la chaîne de
modificateurs qui la suit : un identifiant sans ces deux modificateurs est refusé.

Sortie : 0 conforme, 1 refus, 2 INCONNU. `--autotest` prouve que le juge refuse et laisse
passer.
"""

from __future__ import annotations

import pathlib
import re
import sys
import tempfile

RACINE = pathlib.Path(__file__).resolve().parent.parent
DEBUT = re.compile(r"^\s*Label\s*[({]")
IDENTIFIANT = ".accessibilityIdentifier("
UN_ELEMENT = ".accessibilityElement(children: .ignore)"
LIBELLE = ".accessibilityLabel("


def _expression(lignes: list[str], i: int) -> int:
    """L'indice de la dernière ligne du `Label` lui-même (parenthèses et accolades fermées)."""
    profondeur = 0
    for j in range(i, len(lignes)):
        code = re.sub(r'"(?:\\.|[^"\\])*"', '""', lignes[j])
        profondeur += code.count("(") + code.count("{") - code.count(")") - code.count("}")
        if profondeur <= 0:
            return j
    return len(lignes) - 1


def _modificateurs(lignes: list[str], fin: int) -> str:
    """La chaîne de modificateurs qui suit l'expression : `.x(…)` sur les lignes suivantes."""
    chaine, profondeur = [], 0
    for ligne in lignes[fin + 1:]:
        if profondeur == 0 and not ligne.lstrip().startswith("."):
            break
        chaine.append(ligne.strip())
        code = re.sub(r'"(?:\\.|[^"\\])*"', '""', ligne)
        profondeur = max(0, profondeur + code.count("(") + code.count("{") - code.count(")") - code.count("}"))
    return " ".join(chaine)


def refus(chemin: str, texte: str) -> list[str]:
    lignes = texte.splitlines()
    fautes = []
    for i, ligne in enumerate(lignes):
        if not DEBUT.match(ligne):
            continue
        fin = _expression(lignes, i)
        suite = " ".join(l.strip() for l in lignes[i:fin + 1]).split("Label", 1)[1] + " " + _modificateurs(lignes, fin)
        if IDENTIFIANT in suite and not (UN_ELEMENT in suite and LIBELLE in suite):
            fautes.append(f"{chemin}:{i + 1} : Label identifié lu en plusieurs éléments — .elementIdentifie(id, lu: texte)")
    return fautes


def juger(racine: pathlib.Path) -> list[str]:
    fautes = []
    for f in sorted((racine / "CoproFirst").rglob("*.swift")):
        fautes += refus(f.relative_to(racine).as_posix(), f.read_text(encoding="utf-8"))
    return fautes


def autotest() -> bool:
    fautif = 'Label("Reconnue", systemImage: "checkmark")\n    .font(.footnote)\n    .accessibilityIdentifier("x")\n'
    ferme = (
        'Label {\n    Text(nom)\n} icon: {\n    Image(systemImage: "person")\n}\n'
        '.accessibilityIdentifier("x")\n'
    )
    propre = (
        'Label(lieu, systemImage: "mappin")\n    .accessibilityElement(children: .ignore)\n'
        '    .accessibilityLabel("Lieu : \\(lieu)")\n    .accessibilityIdentifier("x")\n'
    )
    bouton = 'Button(action: f) {\n    Label("Rafraîchir", systemImage: "arrow")\n}\n.accessibilityIdentifier("x")\n'
    sans_libelle = 'Label("a", systemImage: "b")\n    .accessibilityElement(children: .ignore)\n    .accessibilityIdentifier("x")\n'
    seul = 'Label("a", systemImage: "b")\n    .font(.footnote)\nText("c").accessibilityIdentifier("x")\n'
    commun = 'Label(texte, systemImage: "lock")\n    .font(.subheadline)\n    .elementIdentifie("x", lu: texte)\n'
    ok = bool(refus("A.swift", fautif)) and bool(refus("A.swift", ferme)) and bool(refus("A.swift", sans_libelle))
    ok = ok and not refus("A.swift", propre) and not refus("A.swift", bouton) and not refus("A.swift", seul)
    ok = ok and not refus("A.swift", commun)
    with tempfile.TemporaryDirectory() as d:
        (pathlib.Path(d) / "CoproFirst").mkdir()
        (pathlib.Path(d) / "CoproFirst" / "V.swift").write_text(fautif, encoding="utf-8")
        ok = ok and len(juger(pathlib.Path(d))) == 1
    return ok


def main() -> int:
    if sys.argv[1:] == ["--autotest"]:
        print("✅ autotest des Label identifiés" if autotest() else "❌ autotest des Label identifiés en échec")
        return 0 if autotest() else 1
    if not (RACINE / "CoproFirst").is_dir():
        print("❓ CoproFirst/ introuvable : Label identifiés INCONNUS")
        return 2
    fautes = juger(RACINE)
    for faute in fautes:
        print(f"❌ {faute}")
    if fautes:
        return 1
    print("✅ tout Label identifié est lu en un élément")
    return 0


if __name__ == "__main__":
    sys.exit(main())
