#!/bin/bash
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
#
# filtres-lot.sh — les filtres `xcodebuild` du lot d'interface `$LOT` sur `$DERNIER` (#243),
# un par ligne, lus par le job « Interface » de .github/workflows/ci.yml (sorti du workflow
# avec #408, pour qu'il tienne sous 500 lignes). Les lots 1 à N-1 jouent les classes de leur
# `LOT_k` ; le DERNIER joue tout le reste — une classe neuve y tombe d'office.
#
# INCONNU (sortie 2, `::error::`) : un `LOT_` au rang du dernier (il ne se jouerait jamais
# comme tel), un `LOT_` absent ou vide, une classe absente de CoproFirstUITests (renommée,
# elle ne se jouerait plus nulle part, sans bruit), une classe nommée dans deux lots (elle
# jouerait deux fois et fausserait l'équilibre).
set -uo pipefail
cd "$(dirname "$0")/.."

: "${LOT:?}" "${DERNIER:?}"
filtres=()
[ "$LOT" = "$DERNIER" ] && filtres+=(-only-testing:CoproFirstUITests)
liste=LOT_$DERNIER
[ -z "${!liste:-}" ] || { echo "::error::$liste nommé, mais le lot $DERNIER joue le reste" >&2; exit 2; }
vues=" "
for nomme in $(seq 1 $((DERNIER - 1))); do
  liste=LOT_$nomme
  [ -n "${!liste:-}" ] || { echo "::error::$liste absent ou vide : la matrice compte $DERNIER lots" >&2; exit 2; }
  for classe in ${!liste}; do
    grep -qE "class $classe([^[:alnum:]_]|$)" CoproFirstUITests/*.swift \
      || { echo "::error::$liste nomme $classe, absente de CoproFirstUITests" >&2; exit 2; }
    case "$vues" in *" $classe "*) echo "::error::$classe nommée dans deux lots" >&2; exit 2 ;; esac
    vues="$vues$classe "
    if [ "$LOT" = "$nomme" ]; then
      filtres+=("-only-testing:CoproFirstUITests/$classe")
    elif [ "$LOT" = "$DERNIER" ]; then
      filtres+=("-skip-testing:CoproFirstUITests/$classe")
    fi
  done
done
printf '%s\n' ${filtres[@]+"${filtres[@]}"}
