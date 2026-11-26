#!/bin/bash
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
#
# verifier-logo.sh [ref] — la licence du logo et son dessin sont IDENTIQUES à ceux
# de coprofirst, lus sur GitHub à l'étiquette du PLANCHER par défaut
# (scripts/plancher.sh) : une version publiée, jamais une branche — `dev` y est
# supprimée à chaque mise en production, et la CI rougissait au hasard (#133).
# Une copie de licence est obligatoire, sa divergence ne l'est pas. Les images rendues
# du dessin ont les dimensions et l'opacité de leur table. Sans réseau ou référence introuvable : INCONNU (sortie 2),
# jamais OK.
set -uo pipefail
cd "$(dirname "$0")/.."
REF=${1:-$(bash scripts/plancher.sh)} || exit 2
BRUT="https://raw.githubusercontent.com/philippe-tressard/coprofirst/$REF"
ECHECS=0

comparer() { # chemin-local chemin-coprofirst
  local distant
  distant=$(mktemp)
  # Chaque tentative bornée à 20 s, nommée à l'expiration (#293) ; la borne de
  # controles-distants.sh coupe le reste.
  if ! curl -fsSL --retry 3 --max-time 20 -o "$distant" "$BRUT/$2"; then
    echo "❓ INCONNU : $2 illisible sur coprofirst@$REF (ou plus de 20 s par tentative)"
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

# Les images rendues depuis le dessin — l'icône de l'iPhone, l'icône en couches et l'étagère
# de l'Apple TV (#320) — et le catalogue de l'Apple TV, jugés sur UNE table
# (scripts/images_logo.py) : dimensions et opacité lues dans l'en-tête PNG, en Python, et non
# par `sips` (macOS seul) — le job « Dépôt » tourne sur Linux (#204). Illisible : INCONNU.
python3 -I scripts/images_logo.py --verifier
case $? in
  0) ;;
  2) exit 2 ;;
  *) ECHECS=$((ECHECS + 1)) ;;
esac
[ "$ECHECS" -eq 0 ]
