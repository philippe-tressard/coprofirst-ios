#!/bin/bash
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
#
# tests-simulateur.sh — build et tests (unitaires et interface) au simulateur, pour
# la CI comme au poste. Ce que le passage dit de lui-même va au résumé du run
# ($GITHUB_STEP_SUMMARY, sinon .build/Resultats/resume.md) :
#
#   - les requêtes d'accessibilité expirées, test par test, même quand tout est
#     vert : deux d'affilée sont la marche d'avant « Lost connection » (#50) ;
#   - à l'échec, la mesure du runner (charge, mémoire, swap) et ce que le
#     simulateur a journalisé de la fin de l'app (jetsam, terminaison) ;
#   - le simulateur est démarré AVANT le build, et son démarrage attendu jusqu'au
#     bout (`simctl bootstatus -b`) : démarré par xcodebuild juste avant les tests, il
#     faisait encore ses tâches de premier démarrage pendant la première suite
#     d'interface — AccesUITests, deux à cinq fois plus lente et rouge (#48). Un
#     démarrage non confirmé arrête tout : INCONNU, jamais un test sur un simulateur
#     dont on ne sait rien ;
#   - UNE relance au plus, des seuls tests tombés, et seulement si chacun est un
#     test d'interface tombé sur une cause déclarée — la liste et le plafond font
#     foi dans scripts/bilan_tests_ui.py (CAUSES_RELANCE, PLAFOND_TESTS). La
#     relance se déclare au résumé et en annotation ; jamais une relance muette ;
#   - un passage sorti en 0 n'est vert que s'il a JOUÉ des tests : le compte se lit au
#     résumé de xcresult et se dit au résumé du run ; zéro test, ou un résumé qui ne
#     se lit pas, c'est INCONNU, sortie 2 (#96). Et CHAQUE filtre `-only-testing:` doit
#     avoir joué au moins un test, compté dans l'arbre du xcresult : deux filtres dont
#     l'un ne vise rien sortaient verts sur les tests de l'autre (#170) ;
#   - un fichier de test que le projet Xcode ne connaît pas (créé après
#     `generer-projet.sh`) arrête tout AVANT le build : INCONNU, avec la commande à
#     lancer. Le script ne régénère pas le projet lui-même : XcodeGen réécrit un projet
#     qu'Xcode peut tenir ouvert, et en CI la génération est une étape à part (#170) ;
#   - UN SEUL passage à la fois sur le poste (#108) : le script prend le verrou
#     `simulateur.verrou` du répertoire git commun — celui que partagent tous les
#     worktrees —, attend son tour en disant qui le tient et depuis quand, et le rend
#     à sa sortie. Douze sessions lançaient chacune leur passage : charge à 959 sur 12
#     cœurs, et des « Lost connection » pris pour des défauts. En CI, pas de verrou :
#     un runner, un passage. Un passage s'ARRÊTE PAR SON PID, celui de la fiche du
#     verrou (`kill "$(cat "$(git rev-parse --git-common-dir)/simulateur.verrou/pid")"`),
#     jamais par son nom : le script arrête alors ses descendants (xcodebuild ne lui
#     survit pas), éteint le simulateur s'il l'a démarré, et rend le verrou.
#
# Arguments : passés au premier `xcodebuild test`, pour un passage partiel au poste
# (`bash scripts/tests-simulateur.sh -only-testing:CoproFirstUITests/ParcoursUITests`).
# `--autotest` rejoue tout cela avec un faux xcodebuild
# (scripts/autotest-tests-simulateur.sh) : relance permise, refusée, ratée, INCONNU,
# passage vide, filtre vide, fichier de test hors projet, deux passages en même temps, verrou orphelin, arrêt par le pid. Lancé
# par verifier-depot.sh (CI et pre-commit).
set -uo pipefail
cd "$(dirname "$0")/.."

XCODEBUILD=${XCODEBUILD:-xcodebuild}
XCRUN=${XCRUN:-xcrun}
MESURER=${MESURER:-1}
RESULTATS=${RESULTATS:-.build/Resultats}
PROJET=${PROJET:-CoproFirst.xcodeproj}
SOURCES_TESTS=${SOURCES_TESTS:-CoproFirstTests CoproFirstUITests}
A_ETEINDRE=""
# Le verrou du poste : prendre_verrou, rendre_verrou.
source scripts/verrou-simulateur.sh

# Les descendants de $1, les plus lointains d'abord — par filiation, jamais par nom.
descendants() {
  local p
  for p in $(pgrep -P "$1" 2>/dev/null); do
    descendants "$p"
    DESCENDANTS="$DESCENDANTS $p"
  done
}

# À la sortie, quelle qu'elle soit : plus aucun descendant (un xcodebuild orphelin
# continuait de charger le poste, #108), le simulateur éteint si ce passage l'a
# démarré, le verrou rendu s'il est le sien.
sortir() {
  DESCENDANTS=""
  descendants $$
  [ -z "$DESCENDANTS" ] || kill $DESCENDANTS 2>/dev/null
  [ -z "$A_ETEINDRE" ] || "$XCRUN" simctl shutdown "$A_ETEINDRE" > /dev/null 2>&1
  rendre_verrou
}

# Ce que le simulateur a dit de la fin de l'app : tuée (jetsam), terminée, ou rien —
# rien, c'est l'app vivante et figée, pas morte.
fin_de_l_app() {
  local udid=${DESTINATION##*id=}
  "$XCRUN" simctl spawn "$udid" log show --last 45m --style compact --predicate \
    'eventMessage CONTAINS "fr.coprofirst.app" AND (eventMessage CONTAINS[c] "jetsam" OR eventMessage CONTAINS[c] "terminat" OR eventMessage CONTAINS[c] "exited")' \
    2>/dev/null | grep -v '^Timestamp' | tail -n 12
}

# Le simulateur démarré, attendu jusqu'à la fin de son démarrage, AVANT le build : ses
# tâches de premier démarrage se font pendant la compilation, pas pendant les tests.
demarrer_simulateur() {
  local udid=${DESTINATION##*id=}
  # Déjà démarré (par Xcode, par Philippe) : il n'est pas à ce passage, qui le laisse.
  "$XCRUN" simctl list devices booted 2>/dev/null | grep -q "$udid" || A_ETEINDRE=$udid
  if ! "$XCRUN" simctl bootstatus "$udid" -b > /dev/null 2>&1; then
    echo "❌ simulateur $udid : démarrage non confirmé (simctl bootstatus) — INCONNU, aucun test joué." >&2
    return 1
  fi
  echo "Simulateur $udid démarré avant le build ($(date -u +%H:%M:%S) UTC)."
}

# Un fichier de test que le projet ne référence pas ne se compile pas : ses tests ne
# jouent pas, et le filtre qui les vise resterait vide (#170). Comparé par le nom du
# fichier, tel que XcodeGen l'écrit au projet (« /* AccesUITests.swift */ »).
hors_projet() {
  local pbx=$PROJET/project.pbxproj f manquants=""
  if [ ! -f "$pbx" ]; then
    echo "INCONNU : $pbx absent — bash scripts/generer-projet.sh, puis relancer."
    return 2
  fi
  # shellcheck disable=SC2086 # SOURCES_TESTS : des dossiers, séparés par des espaces.
  while IFS= read -r f; do
    grep -qF "/* ${f##*/} */" "$pbx" || manquants="$manquants $f"
  done < <(find $SOURCES_TESTS -name '*.swift' 2>/dev/null | sort)
  [ -z "$manquants" ] && return 0
  echo "INCONNU : fichier(s) de test absent(s) du projet Xcode :$manquants — bash scripts/generer-projet.sh, puis relancer. Aucun test joué."
  return 2
}

# Les filtres -only-testing de la ligne de commande, un par ligne (`:X` ou `X` à part).
filtres_de() {
  local arg suivant=""
  for arg in "$@"; do
    if [ -n "$suivant" ]; then
      echo "$arg"; suivant=""
    elif [ "$arg" = -only-testing ]; then
      suivant=1
    elif [[ $arg == -only-testing:* ]]; then
      echo "${arg#-only-testing:}"
    fi
  done
}

# Chaque filtre a-t-il joué ? Le compte par filtre se lit dans l'arbre du xcresult (#170).
verifier_filtres() {
  local filtres=() ligne
  while IFS= read -r ligne; do [ -z "$ligne" ] || filtres+=("$ligne"); done < <(filtres_de "$@")
  [ "${#filtres[@]}" -gt 0 ] || return 0
  if ! "$XCRUN" xcresulttool get test-results tests --path "$RESULTATS/tests.xcresult" --compact \
      > "$RESULTATS/arbre.json" 2>/dev/null; then
    echo "Filtres : INCONNU — l'arbre des tests de xcresult ne se lit pas, rien ne prouve que chaque filtre a joué."
    return 2
  fi
  ligne=$(python3 -I scripts/bilan_tests_ui.py filtres "$RESULTATS/arbre.json" "${filtres[@]}")
  local sortie=$?
  echo "Filtres : $ligne"
  return "$sortie"
}

mesurer() {
  [ "$MESURER" = 1 ] || { echo "Mesure du runner : sautée (MESURER=0)."; return; }
  local fin
  echo "### Mesure du runner à l'échec"
  echo "- durée du passage : $1 s"
  echo "- cœurs, mémoire : $(sysctl -n hw.ncpu 2>/dev/null || echo INCONNU) cœurs, $(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1073741824 )) Go"
  echo "- charge (1, 5, 15 min) : $(sysctl -n vm.loadavg 2>/dev/null || echo INCONNU)"
  echo "- mémoire libre : $(memory_pressure -Q 2>/dev/null | grep -oE '[0-9]+%' | head -1 || echo INCONNU)"
  echo "- swap : $(sysctl -n vm.swapusage 2>/dev/null || echo INCONNU)"
  fin=$(fin_de_l_app)
  if [ -n "$fin" ]; then
    printf -- '- fin de l'"'"'app au journal du simulateur :\n\n```\n%s\n```\n' "$fin"
  else
    echo "- fin de l'app au journal du simulateur : aucune trace (ni jetsam ni terminaison)"
  fi
  echo
}

# xcodebuild, son journal à l'écran et dans $1, et sa sortie pour code de retour. En
# arrière-plan et attendu par `wait` : un signal (l'arrêt par le pid) est alors traité
# tout de suite — bash le garderait jusqu'à la fin d'une commande de premier plan.
lancer() {
  local journal=$1
  shift
  rm -f "$RESULTATS/code"
  { "$XCODEBUILD" "$@" 2>&1; echo $? > "$RESULTATS/code"; } | tee "$journal" &
  wait $!
  return "$(cat "$RESULTATS/code" 2>/dev/null || echo 2)"
}

# Le résumé de $1.xcresult, écrit dans $2 ; sortie non nulle s'il ne se lit pas.
resumer() {
  "$XCRUN" xcresulttool get test-results summary --path "$RESULTATS/$1.xcresult" --compact \
    > "$RESULTATS/$2" 2>/dev/null
}

passer() {
  local RESUME=${GITHUB_STEP_SUMMARY:-$RESULTATS/resume.md} motif
  rm -rf "$RESULTATS" && mkdir -p "$RESULTATS" || return 2
  if [ -z "${DESTINATION:-}" ]; then
    DESTINATION=$(bash scripts/destination-simulateur.sh) || return 1
  fi
  if ! motif=$(hors_projet); then
    echo "❌ $motif" >&2
    echo "## Tests au simulateur" >> "$RESUME"
    echo "Projet : $motif" >> "$RESUME"
    return 2
  fi
  echo "Destination : $DESTINATION"
  demarrer_simulateur || return 1
  local communs=(
    -project "$PROJET" -scheme CoproFirst -destination "$DESTINATION"
    -derivedDataPath .build/DerivedData -skipPackagePluginValidation
    -onlyUsePackageVersionsFromResolvedFile CODE_SIGNING_ALLOWED=NO
  )
  local debut=$SECONDS code seuls decision
  lancer "$RESULTATS/tests.log" test "${communs[@]}" "$@" -resultBundlePath "$RESULTATS/tests.xcresult"
  code=$?
  echo "## Tests au simulateur" >> "$RESUME"
  python3 -I scripts/bilan_tests_ui.py lenteurs "$RESULTATS/tests.log" "$RESUME"
  if [ "$code" -eq 0 ]; then
    # Sortie 0 ne suffit pas : un filtre qui ne vise rien sort en 0 sans rien jouer (#96).
    if ! resumer tests resume.json; then
      echo "Tests joués : INCONNU — le résumé de xcresult ne se lit pas, rien ne prouve un test joué." >> "$RESUME"
      return 2
    fi
    motif=$(python3 -I scripts/bilan_tests_ui.py joues "$RESULTATS/resume.json")
    decision=$?
    echo "Tests joués : $motif" >> "$RESUME"
    [ "$decision" -eq 0 ] || return "$decision"
    verifier_filtres "$@" >> "$RESUME"
    return $?
  fi

  mesurer $((SECONDS - debut)) >> "$RESUME"
  if ! resumer tests resume.json; then
    echo "Relance : aucune — INCONNU, le résumé de xcresult ne se lit pas." >> "$RESUME"
    return "$code"
  fi
  seuls=$(python3 -I scripts/bilan_tests_ui.py decider "$RESULTATS/resume.json" 2> "$RESULTATS/motif.txt")
  decision=$?
  motif=$(cat "$RESULTATS/motif.txt")
  if [ "$decision" -ne 0 ]; then
    echo "Relance : aucune — $motif" >> "$RESUME"
    return "$code"
  fi

  echo "::warning title=Relance déclarée (#50)::$motif — relancé une fois, seuls ces tests."
  echo "**Relance déclarée (#50)** : $motif — une fois, seuls ces tests." >> "$RESUME"
  local relance=()
  while IFS= read -r ligne; do relance+=("$ligne"); done <<< "$seuls"
  lancer "$RESULTATS/relance.log" test-without-building "${communs[@]}" "${relance[@]}" \
    -resultBundlePath "$RESULTATS/relance.xcresult"
  code=$?
  python3 -I scripts/bilan_tests_ui.py lenteurs "$RESULTATS/relance.log" "$RESUME"
  if [ "$code" -ne 0 ]; then
    echo "Relance : rouge à son tour — le run échoue." >> "$RESUME"
    return "$code"
  fi
  # Sortie 0 ne suffit pas : un -only-testing qui ne vise rien sort en 0 sans rien jouer.
  motif=""
  if resumer relance relance.json \
      && motif=$(python3 -I scripts/bilan_tests_ui.py relance-verte "$RESULTATS/relance.json" "${#relance[@]}"); then
    echo "Relance : verte ($motif). Le run passe, et cette ligne reste : la cause se suit au ticket #50." >> "$RESUME"
    return 0
  fi
  echo "Relance : non prouvée — ${motif:-INCONNU, résumé de la relance illisible}. Le run échoue." >> "$RESUME"
  return 1
}

if [ "${1:-}" = "--autotest" ]; then
  source scripts/autotest-tests-simulateur.sh
  autotest
  exit $?
fi
trap sortir EXIT
trap 'exit 143' TERM
trap 'exit 130' INT
trap 'exit 129' HUP
prendre_verrou || exit $?
passer "$@"
code=$?
[ -n "${GITHUB_STEP_SUMMARY:-}" ] || cat "$RESULTATS/resume.md" 2>/dev/null
exit "$code"
