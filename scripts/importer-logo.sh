#!/bin/bash
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
#
# importer-logo.sh [ref] — le logo de CoproFirst et sa licence, recopiés À
# L'IDENTIQUE depuis coprofirst, lus sur GitHub à l'étiquette du PLANCHER par défaut
# (scripts/plancher.sh, #133 ; le clone local d'une autre session peut être en
# retard, et on n'en change pas la branche), puis les images rendues depuis le dessin :
# l'icône de l'iPhone, celle de la montre (#226), l'icône en couches et l'étagère de
# l'Apple TV (#320) — la table de scripts/images_logo.py, qui écrit aussi les catalogues
# de l'Apple TV et de la montre. Un logo plus récent
# que le plancher s'importe sur décision : `[ref]`.
#
# Le logo n'est pas sous l'AGPL : LicenseRef-CoproFirst-Logo (MARQUE.md de
# coprofirst, PR coprofirst#2474) couvre l'app iOS publiée par son auteur.
# Redimensionner et poser sur le fond qu'exige l'icône n'est pas une modification ;
# changer le dessin ou ses couleurs en est une. verifier-logo.sh tient l'identité.
set -euo pipefail
cd "$(dirname "$0")/.."
REF=${1:-$(bash scripts/plancher.sh)}
BRUT="https://raw.githubusercontent.com/philippe-tressard/coprofirst/$REF"
ASSETS=CoproFirst/Ressources/Assets.xcassets

curl -fsSL --retry 3 -o LICENSES/LicenseRef-CoproFirst-Logo.txt "$BRUT/LICENSES/LicenseRef-CoproFirst-Logo.txt"
curl -fsSL --retry 3 -o "$ASSETS/Logo.imageset/logo.svg" "$BRUT/front/static/favicon.svg"

TRAVAIL=$(mktemp -d)
trap 'rm -rf "$TRAVAIL"' EXIT
swiftc -O scripts/rendre-icone.swift -o "$TRAVAIL/rendre-icone"
python3 -I scripts/images_logo.py --catalogue
python3 -I scripts/images_logo.py --liste | while IFS=$'\t' read -r chemin largeur hauteur part mode; do
  if [ "$mode" = icone ]; then
    "$TRAVAIL/rendre-icone" "$ASSETS/Logo.imageset/logo.svg" "$chemin" "$largeur"
  else
    "$TRAVAIL/rendre-icone" "$ASSETS/Logo.imageset/logo.svg" "$chemin" "$largeur" "$hauteur" "$part" "$mode"
  fi
done
python3 -I scripts/images_logo.py --verifier
echo "✅ logo et licence recopiés depuis coprofirst@$REF"
