#!/bin/bash
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
#
# verifier-logo.sh [branche] — la licence du logo et son dessin sont IDENTIQUES à
# ceux de coprofirst (branche dev par défaut, lue sur GitHub) : une copie de licence
# est obligatoire, sa divergence ne l'est pas. L'icône est carrée, 1024 px, opaque.
# Sans réseau : INCONNU (sortie 2), jamais OK.
set -uo pipefail
cd "$(dirname "$0")/.."
REF=${1:-dev}
BRUT="https://raw.githubusercontent.com/philippe-tressard/coprofirst/$REF"
ICONE=CoproFirst/Ressources/Assets.xcassets/AppIcon.appiconset/icone-1024.png
ECHECS=0

comparer() { # chemin-local chemin-coprofirst
  local distant
  distant=$(mktemp)
  if ! curl -fsSL --retry 3 -o "$distant" "$BRUT/$2"; then
    echo "❓ INCONNU : $2 illisible sur coprofirst@$REF"
    rm -f "$distant"
    exit 2
  fi
  if cmp -s "$1" "$distant"; then
    echo "✅ $1 = coprofirst@$REF:$2"
  else
    echo "❌ $1 diverge de coprofirst@$REF:$2 — bash scripts/importer-logo.sh"
    ECHECS=$((ECHECS + 1))
  fi
  rm -f "$distant"
}

comparer LICENSES/LicenseRef-CoproFirst-Logo.txt LICENSES/LicenseRef-CoproFirst-Logo.txt
comparer CoproFirst/Ressources/Assets.xcassets/Logo.imageset/logo.svg front/static/favicon.svg

if command -v sips >/dev/null; then
  dims=$(sips -g pixelWidth -g pixelHeight -g hasAlpha "$ICONE" | awk '/pixel|hasAlpha/ {print $2}' | tr '\n' ' ')
  if [ "$dims" = "1024 1024 no " ]; then
    echo "✅ $ICONE : 1024×1024, opaque"
  else
    echo "❌ $ICONE : $dims (attendu 1024 1024, sans alpha)"
    ECHECS=$((ECHECS + 1))
  fi
else
  echo "❓ INCONNU : sips absent, icône non vérifiée"
  exit 2
fi
[ "$ECHECS" -eq 0 ]
