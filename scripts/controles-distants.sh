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
#   2. le logo et sa licence identiques à coprofirst (scripts/verifier-logo.sh, #133) ;
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
