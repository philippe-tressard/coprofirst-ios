# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Ce qu'est une PHOTO parmi les pièces jointes, et le nom qu'on montre d'un fichier :
les règles du site (`front/src/lib/fichiers.ts` : `EXTENSIONS_IMAGE`, `PREFIXE_UUID`,
`typeFichier`) → `CoproFirst/Charte/FichiersDuSite.swift`, lu par `Fichiers`
(Commun/Session/) et `PiecesJointes` (Commun/PiecesJointes/).

Écrite à la main, la liste des extensions d'image avait divergé du site (ni `.avif`,
ni `.heif`, ni `.bmp`, ni `.tiff`) : une telle photo serait tombée parmi les documents.

Depuis v3.105.0, le motif d'image et le préfixe se lisent dans `constantes-clients.json`
(`motifImage`, `prefixeStockage`, #239) ; depuis v3.106.0, les familles d'AFFICHAGE de
`typeFichier` (JPEG → JPG, XLSX → EXCEL…) dans `tables-clients.json`
(`famillesAffichageFichiers`, coprofirst#2798) — à ne pas confondre avec `famillesFichiers`,
les familles de téléversement. `fichiers.ts` ne se lit plus.
"""

from __future__ import annotations

import re

from generateurs._commun import CHARTE, chaine, ecrire_table

SOURCES: list[str] = []


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
    image, prefixe = ctx.constante("motifImage"), ctx.constante("prefixeStockage")
    m = re.fullmatch(r"\\\.\(([^)]*)\)\$", image.get("motif", "")) if image.get("ignorerCasse") else None
    if not m:
        raise SystemExit(f"❌ motifImage : forme inattendue ({image!r}) — l'app doit l'apprendre")
    images = _alternatives(m.group(1))
    p = re.fullmatch(r"\^\[0-9a-f\]\{(\d+)\}_", prefixe.get("motif", "")) if prefixe.get("ignorerCasse") else None
    if not p:
        raise SystemExit(f"❌ prefixeStockage : forme inattendue ({prefixe!r}) — l'app doit l'apprendre")
    publiees = ctx.table("famillesAffichageFichiers")
    if not isinstance(publiees, dict) or not publiees or not all(
            isinstance(c, str) and isinstance(v, str) for c, v in publiees.items()):
        raise SystemExit(f"❌ famillesAffichageFichiers : forme inattendue ({publiees!r}) — l'app doit l'apprendre")
    familles = list(publiees.items())
    liste = ", ".join(chaine(e) for e in images)
    table = "".join(f"        {chaine(cle)}: {chaine(valeur)},\n" for cle, valeur in familles)
    corps = (
        "    /// Les extensions d'une image affichable en vignette (`motifImage`).\n"
        f"    static let extensionsImage: Set<String> = [{liste}]\n\n"
        "    /// Le préfixe que le serveur ajoute au nom téléversé : tant de chiffres\n"
        "    /// hexadécimaux, puis « _ » (`prefixeStockage`) — retiré du nom montré.\n"
        f"    static let longueurPrefixe = {int(p.group(1))}\n\n"
        "    /// L'extension en capitales, ramenée à sa famille (`typeFichier`).\n"
        "    static let familles: [String: String] = [\n"
        + table
        + "    ]\n"
    )
    source = (f"{ctx.provenance_constantes('motifImage', 'prefixeStockage')}, "
              f"{ctx.provenance_tables('famillesAffichageFichiers')}")
    ecrire_table(ctx, CHARTE / "FichiersDuSite.swift", source, "FichiersDuSite",
                 "Les pièces jointes comme le site les range et les nomme.", corps)
    return f"{len(images)} extensions d'image, {len(familles)} familles"
