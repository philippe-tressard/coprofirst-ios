#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
#
# Un toucher des tests d'interface passe par le point commun (#217) : `app.toucher(élément)`
# (CoproFirstUITests/Attente.swift) attend qu'il soit à l'écran, touchable et immobile — un
# `tap()` direct partait trop tôt et ne faisait rien, sans erreur. Les `tap()` directs qui
# restent sont une dette au PLAFOND, qui ne fait que baisser : un de plus échoue, un de moins
# aussi (baisser le plafond dans le même lot). Une classe convertie n'en a plus aucun.
# Appelé par scripts/verifier-depot.sh. Sortie : 0 conforme, 1 refus.
set -uo pipefail
cd "$(dirname "$0")/.."

PLAFOND_TAP=113
POINT_ATTENTE=CoproFirstUITests/Attente.swift
CLASSES_TOUCHER="CoproFirstUITests/AccesUITests.swift CoproFirstUITests/SuppressionCompteUITests.swift
CoproFirstUITests/HistoriqueUITests.swift
CoproFirstUITests/PrestatairesAffaireUITests.swift
CoproFirstUITests/PrestatairesUITests.swift
CoproFirstUITests/HorsLigneUITests.swift CoproFirstUITests/ConnexionUITests.swift
CoproFirstUITests/BarreLateraleUITests.swift
CoproFirstUITests/CartesDuFilUITests.swift CoproFirstUITests/SaisieAffaireUITests.swift"

# $@ : les fichiers à lire. Rend le nombre de `tap()` directs hors commentaires.
compter_tap() { cat "$@" /dev/null | grep -E '\.tap\(\)' | grep -vcE '^[[:space:]]*///?' ; }

autotest() {
  local d ok=0
  d=$(mktemp -d) || return 1
  printf '        app.boutons["x"].tap()\n        // un .tap() direct se nomme ici\n        app.toucher(y)\n' > "$d/a"
  [ "$(compter_tap "$d/a")" = 1 ] || ok=1
  [ "$(compter_tap)" = 0 ] || ok=1
  rm -rf "${d:?}"
  return $ok
}

autotest || { echo "❌ autotest du compte des tap() directs en échec"; exit 1; }
FICHIERS=$(git ls-files 'CoproFirstUITests/*.swift' | grep -vx "$POINT_ATTENTE")
[ -n "$FICHIERS" ] || { echo "❌ INCONNU : aucun test d'interface à lire"; exit 1; }
# shellcheck disable=SC2086
TAPS=$(compter_tap $FICHIERS)
fautes=0
if [ "$TAPS" -gt "$PLAFOND_TAP" ]; then
  echo "❌ $TAPS tap() directs dans les tests d'interface, plafond $PLAFOND_TAP — app.toucher(élément), $POINT_ATTENTE"
  fautes=1
elif [ "$TAPS" -lt "$PLAFOND_TAP" ]; then
  echo "❌ $TAPS tap() directs : baisser PLAFOND_TAP à $TAPS dans scripts/verifier-touchers.sh"
  fautes=1
fi
for f in $CLASSES_TOUCHER; do
  [ -f "$f" ] || { echo "❌ $f, déclarée convertie, n'existe plus"; fautes=1; continue; }
  [ "$(compter_tap "$f")" = 0 ] || { echo "❌ $f est convertie : aucun tap() direct — app.toucher(élément)"; fautes=1; }
done
[ "$fautes" = 0 ] || exit 1
echo "✅ touchers au point commun ($TAPS tap() directs au plafond)"
