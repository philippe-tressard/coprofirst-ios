#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les images rendues depuis le logo de CoproFirst : UNE table, lue pour les rendre et pour
les juger (#320).

L'iPhone a son icône (1024 px, opaque). L'Apple TV a la sienne, EN COUCHES — une couche
arrière opaque (le fond blanc de la tuile du logo) et une couche avant (le logo, sans fond),
que tvOS fait bouger l'une sur l'autre sous le focus —, en deux jeux : celui de l'écran
d'accueil (400 × 240 et son @2x) et celui de l'App Store (1280 × 768) ; puis l'image de
l'étagère (Top Shelf, 1920 × 720) et sa variante large (2320 × 720), chacune avec son @2x.
Le dessin n'est jamais découpé en couches : ce serait le modifier (sa licence).

  --liste       une ligne par image à rendre : `chemin<TAB>largeur<TAB>hauteur<TAB>part<TAB>mode`
                (lue par scripts/importer-logo.sh, qui appelle scripts/rendre-icone.swift) ;
  --catalogue   écrit les Contents.json du catalogue de l'Apple TV depuis cette table ;
  --verifier    juge chaque PNG (largeur, hauteur, opacité lues dans l'en-tête, sans macOS :
                le job « Dépôt » tourne sur Linux) et les Contents.json (= ceux que la table
                écrit). Lu par scripts/verifier-logo.sh ;
  --autotest    prouve qu'il refuse et accepte.

Sortie : 0 conforme, 1 écart, 2 INCONNU (un PNG illisible ou absent).
"""

from __future__ import annotations

import json
import pathlib
import struct
import sys
import tempfile

RACINE = pathlib.Path(__file__).resolve().parents[1]
CONFORME, ECART, INCONNU = 0, 1, 2

IPHONE = "CoproFirst/Ressources/Assets.xcassets/AppIcon.appiconset/icone-1024.png"
TV = "CoproFirstTV/Ressources/Assets.xcassets"
MARQUE = f"{TV}/App Icon & Top Shelf Image.brandassets"
#: La part de la hauteur que prend le logo : l'icône garde une marge que tvOS rogne au focus,
#: l'étagère est un bandeau où le logo reste à sa place de marque.
PART_ICONE, PART_ETAGERE = 0.6, 0.5

#: (dossier dans la marque, rôle, taille @1x, échelles)
PILES = [
    ("App Icon - App Store.imagestack", "primary-app-icon", (1280, 768), (1,)),
    ("App Icon.imagestack", "primary-app-icon", (400, 240), (1, 2)),
]
ETAGERES = [
    ("Top Shelf Image Wide.imageset", "top-shelf-image-wide", (2320, 720), (1, 2)),
    ("Top Shelf Image.imageset", "top-shelf-image", (1920, 720), (1, 2)),
]
#: Les couches, de l'avant vers l'arrière : (nom, part du logo, mode).
COUCHES = [("Front", PART_ICONE, "transparent"), ("Back", 0, "fond")]
INFO = {"author": "xcode", "version": 1}


def nom(echelle: int, base: str) -> str:
    return f"{base}.png" if echelle == 1 else f"{base}@{echelle}x.png"


def images() -> list[tuple[str, int, int, float, str]]:
    """(chemin, largeur, hauteur, part, mode) — `icone` : carrée, opaque, logo plein cadre."""
    rendus = [(IPHONE, 1024, 1024, 1.0, "icone")]
    for pile, _, (l, h), echelles in PILES:
        for couche, part, mode in COUCHES:
            for e in echelles:
                chemin = f"{MARQUE}/{pile}/{couche}.imagestacklayer/Content.imageset/{nom(e, couche.lower())}"
                rendus.append((chemin, l * e, h * e, part, mode))
    for dossier, _, (l, h), echelles in ETAGERES:
        rendus += [(f"{MARQUE}/{dossier}/{nom(e, 'etagere')}", l * e, h * e, PART_ETAGERE, "fond") for e in echelles]
    return rendus


def imageset(base: str, echelles: tuple[int, ...]) -> dict:
    return {"images": [{"filename": nom(e, base), "idiom": "tv", "scale": f"{e}x"} for e in echelles], "info": INFO}


def catalogue() -> dict[str, dict]:
    """Chemin d'un Contents.json → son contenu."""
    fichiers = {f"{TV}/Contents.json": {"info": INFO}}
    fichiers[f"{MARQUE}/Contents.json"] = {"assets": [
        {"filename": d, "idiom": "tv", "role": r, "size": f"{l}x{h}"} for d, r, (l, h), _ in PILES + ETAGERES],
        "info": INFO}
    for pile, _, _, echelles in PILES:
        fichiers[f"{MARQUE}/{pile}/Contents.json"] = {
            "info": INFO, "layers": [{"filename": f"{c}.imagestacklayer"} for c, _, _ in COUCHES]}
        for couche, _, _ in COUCHES:
            dossier = f"{MARQUE}/{pile}/{couche}.imagestacklayer"
            fichiers[f"{dossier}/Contents.json"] = {"info": INFO}
            fichiers[f"{dossier}/Content.imageset/Contents.json"] = imageset(couche.lower(), echelles)
    for dossier, _, _, echelles in ETAGERES:
        fichiers[f"{MARQUE}/{dossier}/Contents.json"] = imageset("etagere", echelles)
    return fichiers


def ecrit(contenu: dict) -> str:
    """La forme d'Xcode : deux espaces, « clé : valeur »."""
    return json.dumps(contenu, indent=2, ensure_ascii=False).replace('": ', '" : ') + "\n"


def entete(octets: bytes) -> tuple[int, int, bool] | None:
    """Largeur, hauteur, et « a un canal alpha » (type de couleur 4 ou 6, ou un bloc tRNS)."""
    if octets[:8] != b"\x89PNG\r\n\x1a\n" or octets[12:16] != b"IHDR":
        return None
    largeur, hauteur = struct.unpack(">II", octets[16:24])
    alpha, i = octets[25] in (4, 6), 8
    while i + 8 <= len(octets):
        taille, bloc = struct.unpack(">I4s", octets[i:i + 8])
        alpha = alpha or bloc == b"tRNS"
        i += 12 + taille
    return largeur, hauteur, alpha


def juger(racine: pathlib.Path) -> tuple[list[str], list[str]]:
    """(écarts, illisibles). Une image opaque n'a pas d'alpha ; une couche avant en a un."""
    fautes, illisibles = [], []
    for chemin, largeur, hauteur, _, mode in images():
        fichier = racine / chemin
        lu = entete(fichier.read_bytes()) if fichier.is_file() else None
        if lu is None:
            illisibles.append(f"{chemin} absent ou n'est pas un PNG lisible")
            continue
        attendu = (largeur, hauteur, mode == "transparent")
        if lu != attendu:
            fautes.append(f"{chemin} : {lu[0]}×{lu[1]}, alpha {lu[2]} (attendu {largeur}×{hauteur}, alpha {attendu[2]})"
                          " — bash scripts/importer-logo.sh")
    for chemin, contenu in catalogue().items():
        fichier = racine / chemin
        if not fichier.is_file() or fichier.read_text(encoding="utf-8") != ecrit(contenu):
            fautes.append(f"{chemin} ≠ la table de scripts/images_logo.py — python3 scripts/images_logo.py --catalogue")
    rangs = {str(f.relative_to(racine)) for f in (racine / TV).rglob("*.png")} if (racine / TV).is_dir() else set()
    for orphelin in sorted(rangs - {c for c, *_ in images()}):
        fautes.append(f"{orphelin} : une image du catalogue que la table ne rend pas")
    return fautes, illisibles


def png(largeur: int, hauteur: int, alpha: bool) -> bytes:
    """L'en-tête seul d'un PNG : de quoi éprouver le juge."""
    ihdr = struct.pack(">IIBBBBB", largeur, hauteur, 8, 6 if alpha else 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR" + ihdr + b"\0\0\0\0"


def autotest() -> bool:
    def poser(racine: pathlib.Path, change: dict[str, tuple[int, int, bool] | None]) -> None:
        for chemin, largeur, hauteur, _, mode in images():
            valeur = change.get(chemin, (largeur, hauteur, mode == "transparent"))
            if valeur is not None:
                (racine / chemin).parent.mkdir(parents=True, exist_ok=True)
                (racine / chemin).write_bytes(png(*valeur))
        for chemin, contenu in catalogue().items():
            (racine / chemin).parent.mkdir(parents=True, exist_ok=True)
            (racine / chemin).write_text(ecrit(contenu), encoding="utf-8")

    avant = next(c for c, *_, m in images() if m == "transparent")
    etagere = next(c for c, *_ in images() if "Top Shelf Image.imageset" in c)
    cas = [
        ("conforme", {}, None, CONFORME),
        ("icône de l'iPhone transparente", {IPHONE: (1024, 1024, True)}, None, ECART),
        ("étagère aux dimensions fausses", {etagere: (1920, 1080, False)}, None, ECART),
        ("couche avant sans transparence", {avant: (400, 240, False)}, None, ECART),
        ("image absente", {etagere: None}, None, INCONNU),
        ("Contents.json modifié", {}, f"{MARQUE}/Contents.json", ECART),
        ("image orpheline", {}, f"{MARQUE}/orpheline.png", ECART),
    ]
    reussi = True
    for libelle, change, touche, attendu in cas:
        with tempfile.TemporaryDirectory() as dossier:
            racine = pathlib.Path(dossier)
            poser(racine, change)
            if touche:
                (racine / touche).write_bytes(png(1, 1, False) if touche.endswith(".png") else b"{}\n")
            fautes, illisibles = juger(racine)
            obtenu = INCONNU if illisibles else ECART if fautes else CONFORME
        if obtenu != attendu:
            print(f"❌ autotest « {libelle} » : attendu {attendu}, obtenu {obtenu}")
            reussi = False
    return reussi


def main(arguments: list[str]) -> int:
    if arguments == ["--liste"]:
        for chemin, largeur, hauteur, part, mode in images():
            print(f"{chemin}\t{largeur}\t{hauteur}\t{part}\t{mode}")
        return CONFORME
    if arguments == ["--catalogue"]:
        for chemin, contenu in catalogue().items():
            (RACINE / chemin).parent.mkdir(parents=True, exist_ok=True)
            (RACINE / chemin).write_text(ecrit(contenu), encoding="utf-8")
        print(f"✅ {len(catalogue())} Contents.json écrits sous {TV}")
        return CONFORME
    if arguments == ["--autotest"]:
        if not autotest():
            return ECART
        print("✅ autotest de images_logo.py : refuse et accepte comme prévu")
        return CONFORME
    if arguments != ["--verifier"]:
        print(__doc__)
        return INCONNU
    fautes, illisibles = juger(RACINE)
    for ligne in illisibles:
        print(f"❓ INCONNU : {ligne}")
    for ligne in fautes:
        print(f"❌ {ligne}")
    if illisibles:
        return INCONNU
    if fautes:
        return ECART
    print(f"✅ images du logo : {len(images())} PNG aux dimensions et à l'opacité de la table,"
          f" {len(catalogue())} Contents.json")
    return CONFORME


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
