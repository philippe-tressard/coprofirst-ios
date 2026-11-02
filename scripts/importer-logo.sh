#!/bin/bash
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
#
# importer-logo.sh [branche] — le logo de CoproFirst et sa licence, recopiés À
# L'IDENTIQUE depuis coprofirst (branche dev par défaut, lue sur GitHub : le clone
# local d'une autre session peut être en retard, et on n'en change pas la branche),
# puis l'icône de l'app rendue depuis le dessin.
#
# Le logo n'est pas sous l'AGPL : LicenseRef-CoproFirst-Logo (MARQUE.md de
# coprofirst, PR coprofirst#2474) couvre l'app iOS publiée par son auteur.
# Redimensionner et poser sur le fond qu'exige l'icône n'est pas une modification ;
# changer le dessin ou ses couleurs en est une. verifier-logo.sh tient l'identité.
set -euo pipefail
cd "$(dirname "$0")/.."
REF=${1:-dev}
BRUT="https://raw.githubusercontent.com/philippe-tressard/coprofirst/$REF"
ASSETS=CoproFirst/Ressources/Assets.xcassets

curl -fsSL --retry 3 -o LICENSES/LicenseRef-CoproFirst-Logo.txt "$BRUT/LICENSES/LicenseRef-CoproFirst-Logo.txt"
curl -fsSL --retry 3 -o "$ASSETS/Logo.imageset/logo.svg" "$BRUT/front/static/favicon.svg"

TRAVAIL=$(mktemp -d)
trap 'rm -rf "$TRAVAIL"' EXIT
swiftc -O scripts/rendre-icone.swift -o "$TRAVAIL/rendre-icone"
"$TRAVAIL/rendre-icone" "$ASSETS/Logo.imageset/logo.svg" "$ASSETS/AppIcon.appiconset/icone-1024.png" 1024
echo "✅ logo et licence recopiés depuis coprofirst@$REF"
