# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Ce qu'est une PHOTO parmi les pièces jointes, et le nom qu'on montre d'un fichier :
les règles du site (`front/src/lib/fichiers.ts` : `EXTENSIONS_IMAGE`, `PREFIXE_UUID`,
`typeFichier`) → `CoproFirst/Charte/FichiersDuSite.swift`, lu par `Fichiers`
(Commun/Session/) et `PiecesJointes` (Commun/PiecesJointes/).

Écrite à la main, la liste des extensions d'image avait divergé du site (ni `.avif`,
ni `.heif`, ni `.bmp`, ni `.tiff`) : une telle photo serait tombée parmi les documents.
"""

from __future__ import annotations

import re

from generateurs._commun import CHARTE, chaine, ecrire_table

SOURCES = ["front/src/lib/fichiers.ts"]


def _alternatives(motif: str) -> list[str]:
    """`jpe?g|png|tiff?` → jpg, jpeg, png, tif, tiff : le seul quantificateur admis est
    `?` sur une lettre ; tout autre motif arrête la génération plutôt que de deviner."""
    extensions: list[str] = []
    for brin in motif.split("|"):
        if not re.fullmatch(r"(?:[a-z0-9]\??)+", brin):
            raise SystemExit(f"❌ EXTENSIONS_IMAGE : « {brin} » n'est pas une extension lisible")
        variantes = [""]
        for lettre, facultative in re.findall(r"([a-z0-9])(\?)?", brin):
            variantes = [v + lettre for v in variantes] + (variantes if facultative else [])
        extensions += variantes
    return sorted(set(extensions))


def generer(ctx) -> str:
    texte = ctx.lire(SOURCES[0])
    m = re.search(r"const EXTENSIONS_IMAGE = /\\\.\(([^)]*)\)\$/i;", texte)
    if not m:
        raise SystemExit("❌ EXTENSIONS_IMAGE introuvable dans fichiers.ts")
    images = _alternatives(m.group(1))
    p = re.search(r"const PREFIXE_UUID = /\^\[0-9a-f\]\{(\d+)\}_/i;", texte)
    if not p:
        raise SystemExit("❌ PREFIXE_UUID introuvable dans fichiers.ts")
    f = re.search(r"const FAMILLES: Record<string, string> = \{([^}]*)\}", texte)
    if not f:
        raise SystemExit("❌ FAMILLES (typeFichier) introuvable dans fichiers.ts")
    familles = re.findall(r"(\w+): '([^']+)'", f.group(1))
    if not familles:
        raise SystemExit("❌ FAMILLES (typeFichier) est vide")
    liste = ", ".join(chaine(e) for e in images)
    table = "".join(f"        {chaine(cle)}: {chaine(valeur)},\n" for cle, valeur in familles)
    corps = (
        "    /// Les extensions d'une image affichable en vignette (`EXTENSIONS_IMAGE`).\n"
        f"    static let extensionsImage: Set<String> = [{liste}]\n\n"
        "    /// Le préfixe que le serveur ajoute au nom téléversé : tant de chiffres\n"
        "    /// hexadécimaux, puis « _ » (`PREFIXE_UUID`) — retiré du nom montré.\n"
        f"    static let longueurPrefixe = {int(p.group(1))}\n\n"
        "    /// L'extension en capitales, ramenée à sa famille (`typeFichier`).\n"
        "    static let familles: [String: String] = [\n"
        + table
        + "    ]\n"
    )
    ecrire_table(ctx, CHARTE / "FichiersDuSite.swift", "front/src/lib/fichiers.ts (EXTENSIONS_IMAGE, "
                 "PREFIXE_UUID, typeFichier)", "FichiersDuSite",
                 "Les pièces jointes comme le site les range et les nomme.", corps)
    return f"{len(images)} extensions d'image, {len(familles)} familles"
