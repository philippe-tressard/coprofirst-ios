#!/bin/bash
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
#
# controles-distants.sh — les contrôles du dépôt qui lisent coprofirst ou demandent un
# outil tiers. Appelé par verifier-depot.sh seul (#241) : le poste, le hook pre-commit
# et le job « Dépôt » de la CI jouent exactement la même chose. Le 16/11/2026, #240
# était verte au poste et rouge en CI sur le logo, une étape que seul le job jouait.
#
#   1. écart au plancher : tout ce qui se génère depuis coprofirst, régénéré et comparé
#      à l'octet, API simulée comprise (scripts/concordance.py --plancher, #20) ;
#   2. le logo et sa licence identiques à coprofirst (scripts/verifier-logo.sh, #133),
#      comparés et recopiés à l'étiquette du plancher, jamais à une branche ;
#   3. REUSE, à la version d'outillage.env : sur le runner, installée à cette version ;
#      au poste, absente ou autre, INCONNU avec la commande d'installation.
#
# Sortie : 0 vert, 1 rouge, 2 INCONNU (sans réseau, sans reuse) — jamais vert.
set -uo pipefail
cd "$(dirname "$0")/.."
source outillage.env

ROUGES=0
INCONNUS=0
juger() { # libellé code
  case $2 in
    0) ;;
    2) echo "❓ INCONNU : $1"; INCONNUS=$((INCONNUS + 1)) ;;
    *) echo "❌ $1"; ROUGES=$((ROUGES + 1)) ;;
  esac
}

SORTIE=$(python3 -I scripts/concordance.py --plancher 2>&1)
code=$?
[ "$code" -eq 0 ] || echo "$SORTIE"
juger "écart au plancher (python3 -I scripts/concordance.py --plancher)" "$code"

# Le logo se compare et se recopie à l'étiquette du plancher (scripts/plancher.sh),
# jamais à une branche : `dev` de coprofirst disparaît à chaque mise en production,
# et le job « Dépôt » rougissait au hasard (#133). Venu de verifier-depot.sh (500 lignes).
REF_LOGO='REF=${1:-$(bash scripts/plancher.sh)}'
# $1 : le fichier à lire. Rend le motif du refus, ou rien.
refus_ref_logo() { grep -qF "$REF_LOGO" "$1" || echo "la référence par défaut n'est pas le plancher (scripts/plancher.sh)"; }
autotest_ref_logo() {
  local d ok=0
  d=$(mktemp -d) || return 1
  printf 'REF=${1:-dev}\n' > "$d/branche"
  printf '%s || exit 2\n' "$REF_LOGO" > "$d/plancher"
  [ -n "$(refus_ref_logo "$d/branche")" ] || ok=1
  [ -z "$(refus_ref_logo "$d/plancher")" ] || ok=1
  rm -rf "${d:?}"
  return $ok
}
autotest_ref_logo; juger "controles-distants.sh : autotest de la référence du logo" $?
for f in scripts/verifier-logo.sh scripts/importer-logo.sh; do
  motif=$(refus_ref_logo "$f")
  [ -z "$motif" ] || juger "$f : $motif" 1
done

SORTIE=$(bash scripts/verifier-logo.sh 2>&1)
code=$?
[ "$code" -eq 0 ] || echo "$SORTIE"
juger "logo et sa licence (bash scripts/verifier-logo.sh)" "$code"

PAQUET="reuse[charset-normalizer]==$REUSE_VERSION"
REUSE=$(command -v reuse || true)
if [ -z "$REUSE" ] && [ "${GITHUB_ACTIONS:-}" = true ]; then
  python3 -m venv "$RUNNER_TEMP/reuse" \
    && "$RUNNER_TEMP/reuse/bin/pip" install --quiet --disable-pip-version-check "$PAQUET" \
    && REUSE="$RUNNER_TEMP/reuse/bin/reuse"
fi
if [ -z "$REUSE" ]; then
  juger "reuse absent — pipx install '$PAQUET'" 2
elif ! "$REUSE" --version | head -1 | grep -qx "reuse, version $REUSE_VERSION"; then
  juger "reuse $("$REUSE" --version | head -1) au lieu de $REUSE_VERSION — pipx install --force '$PAQUET'" 2
else
  SORTIE=$("$REUSE" lint 2>&1)
  code=$?
  [ "$code" -eq 0 ] || { echo "$SORTIE"; code=1; }
  juger "reuse lint" "$code"
fi

[ "$ROUGES" -eq 0 ] || exit 1
[ "$INCONNUS" -eq 0 ] || exit 2
echo "✅ plancher sans écart, logo identique à coprofirst, REUSE $REUSE_VERSION conforme"
