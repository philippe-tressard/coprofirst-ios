#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
#
# Un toucher des tests d'interface passe par le point commun (#217) : `app.toucher(élément)`
# (CoproFirstUITests/Attente.swift) attend qu'il soit à l'écran, touchable et immobile — un
# `tap()` direct partait trop tôt et ne faisait rien, sans erreur. Les `tap()` directs qui
# restent sont une dette au PLAFOND, qui ne fait que baisser : un de plus échoue, un de moins
# aussi (baisser le plafond dans le même lot). Une classe convertie n'en a plus aucun.
# Un balayage de côté aussi (#183) : aucun `swipeLeft()`/`swipeRight()` direct — un onglet
# s'amène par `app.toucher` ou `app.amenerDansSaRangee`, une ligne se balaie par `app.balayer`.
# Un onglet se touche JUSQU'À SON EFFET, `app.toucher(_:jusqua:)` : nu, un toucher perdu sous
# charge laissait la page d'avant, sans reprise (#183, PR #332). Le juge, scripts/touchers_onglets.py
# (#334), lit l'appel entier et reconnaît un identifiant à segment `onglet`, préfixé ou non, et
# une variable nommée `onglet…`. Hors de sa vue, et dit : un onglet trouvé par son libellé en
# ligne ou rangé dans une variable nommée autrement — la convention de nom le rend visible.
# Appelé par scripts/verifier-depot.sh. Sortie : 0 conforme, 1 refus.
set -uo pipefail
cd "$(dirname "$0")/.."

PLAFOND_TAP=106
POINT_ATTENTE=CoproFirstUITests/Attente.swift
CLASSES_TOUCHER="CoproFirstUITests/AccesUITests.swift CoproFirstUITests/SuppressionCompteUITests.swift
CoproFirstUITests/HistoriqueUITests.swift
CoproFirstUITests/PrestatairesAffaireUITests.swift
CoproFirstUITests/PrestatairesUITests.swift
CoproFirstUITests/HorsLigneUITests.swift CoproFirstUITests/ConnexionUITests.swift
CoproFirstUITests/BarreLateraleUITests.swift
CoproFirstUITests/CartesDuFilUITests.swift CoproFirstUITests/SaisieAffaireUITests.swift
CoproFirstUITests/MessagesAffaireUITests.swift"

# $@ : les fichiers à lire. Rend le nombre de `tap()` directs hors commentaires.
compter_tap() { cat "$@" /dev/null | grep -E '\.tap\(\)' | grep -vcE '^[[:space:]]*///?' ; }
compter_balayages() { cat "$@" /dev/null | grep -E '\.swipe(Left|Right)\(\)' | grep -vcE '^[[:space:]]*///?' ; }

autotest() {
  local d ok=0
  d=$(mktemp -d) || return 1
  printf '        app.boutons["x"].tap()\n        // un .tap() direct se nomme ici\n        app.toucher(y)\n' > "$d/a"
  [ "$(compter_tap "$d/a")" = 1 ] || ok=1
  [ "$(compter_tap)" = 0 ] || ok=1
  printf '        onglet.swipeLeft()\n        // un swipeRight() se nomme ici\n' > "$d/b"
  [ "$(compter_balayages "$d/b")" = 1 ] || ok=1
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
# shellcheck disable=SC2086
BALAYAGES=$(compter_balayages $FICHIERS)
[ "$BALAYAGES" = 0 ] || { echo "❌ $BALAYAGES swipeLeft()/swipeRight() directs — app.toucher, app.balayer, $POINT_ATTENTE"; fautes=1; }
# Son autotest est joué par verifier-depot.sh, comme celui de tout script à `--autotest`.
command -v python3 >/dev/null || { echo "❌ INCONNU : python3 absent, touchers d'onglet non lus (#334)"; exit 1; }
# shellcheck disable=SC2086
python3 -I scripts/touchers_onglets.py $FICHIERS || fautes=1
[ "$fautes" = 0 ] || exit 1
echo "✅ touchers au point commun ($TAPS tap() directs au plafond)"
