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
#   - UNE relance au plus, des seuls tests tombés, et seulement si chacun est un
#     test d'interface tombé sur une cause déclarée — la liste et le plafond font
#     foi dans scripts/bilan_tests_ui.py (CAUSES_RELANCE, PLAFOND_TESTS). La
#     relance se déclare au résumé et en annotation ; jamais une relance muette.
#
# Arguments : passés au premier `xcodebuild test`, pour un passage partiel au poste
# (`bash scripts/tests-simulateur.sh -only-testing:CoproFirstUITests/ParcoursUITests`).
# `--autotest` rejoue la décision avec un faux xcodebuild : relance permise, refusée,
# ratée, INCONNU. Lancé par verifier-depot.sh (CI et pre-commit).
set -uo pipefail
cd "$(dirname "$0")/.."

XCODEBUILD=${XCODEBUILD:-xcodebuild}
XCRUN=${XCRUN:-xcrun}
MESURER=${MESURER:-1}
RESULTATS=${RESULTATS:-.build/Resultats}

# Ce que le simulateur a dit de la fin de l'app : tuée (jetsam), terminée, ou rien —
# rien, c'est l'app vivante et figée, pas morte.
fin_de_l_app() {
  local udid=${DESTINATION##*id=}
  "$XCRUN" simctl spawn "$udid" log show --last 45m --style compact --predicate \
    'eventMessage CONTAINS "fr.coprofirst.app" AND (eventMessage CONTAINS[c] "jetsam" OR eventMessage CONTAINS[c] "terminat" OR eventMessage CONTAINS[c] "exited")' \
    2>/dev/null | grep -v '^Timestamp' | tail -n 12
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

passer() {
  local RESUME=${GITHUB_STEP_SUMMARY:-$RESULTATS/resume.md}
  rm -rf "$RESULTATS" && mkdir -p "$RESULTATS" || return 2
  if [ -z "${DESTINATION:-}" ]; then
    DESTINATION=$(bash scripts/destination-simulateur.sh) || return 1
  fi
  echo "Destination : $DESTINATION"
  local communs=(
    -project CoproFirst.xcodeproj -scheme CoproFirst -destination "$DESTINATION"
    -derivedDataPath .build/DerivedData -skipPackagePluginValidation
    -onlyUsePackageVersionsFromResolvedFile CODE_SIGNING_ALLOWED=NO
  )
  local debut=$SECONDS code
  "$XCODEBUILD" test "${communs[@]}" "$@" -resultBundlePath "$RESULTATS/tests.xcresult" 2>&1 | tee "$RESULTATS/tests.log"
  code=${PIPESTATUS[0]}
  echo "## Tests au simulateur" >> "$RESUME"
  python3 -I scripts/bilan_tests_ui.py lenteurs "$RESULTATS/tests.log" "$RESUME"
  [ "$code" -eq 0 ] && return 0

  mesurer $((SECONDS - debut)) >> "$RESUME"
  local seuls motif decision
  if ! "$XCRUN" xcresulttool get test-results summary --path "$RESULTATS/tests.xcresult" --compact \
      > "$RESULTATS/resume.json" 2>/dev/null; then
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
  "$XCODEBUILD" test-without-building "${communs[@]}" "${relance[@]}" \
    -resultBundlePath "$RESULTATS/relance.xcresult" 2>&1 | tee "$RESULTATS/relance.log"
  code=${PIPESTATUS[0]}
  python3 -I scripts/bilan_tests_ui.py lenteurs "$RESULTATS/relance.log" "$RESUME"
  if [ "$code" -ne 0 ]; then
    echo "Relance : rouge à son tour — le run échoue." >> "$RESUME"
    return "$code"
  fi
  # Sortie 0 ne suffit pas : un -only-testing qui ne vise rien sort en 0 sans rien jouer.
  motif=""
  if "$XCRUN" xcresulttool get test-results summary --path "$RESULTATS/relance.xcresult" --compact \
      > "$RESULTATS/relance.json" 2>/dev/null \
      && motif=$(python3 -I scripts/bilan_tests_ui.py relance-verte "$RESULTATS/relance.json" "${#relance[@]}"); then
    echo "Relance : verte ($motif). Le run passe, et cette ligne reste : la cause se suit au ticket #50." >> "$RESUME"
    return 0
  fi
  echo "Relance : non prouvée — ${motif:-INCONNU, résumé de la relance illisible}. Le run échoue." >> "$RESUME"
  return 1
}

# ── Autotest : un faux xcodebuild, qui sert aussi de faux xcrun ────────────────
autotest() {
  local d rate=0
  d=$(mktemp -d) || return 2
  cat > "$d/faux" <<'FAUX'
#!/bin/bash
echo "$*" >> "$FAUX_DOSSIER/appels"
case "$1" in
  test) cat "$FAUX_DOSSIER/journal"; exit "$(cat "$FAUX_DOSSIER/sortie-test")" ;;
  test-without-building) exit "$(cat "$FAUX_DOSSIER/sortie-relance")" ;;
  xcresulttool)
    case "$*" in *relance.xcresult*) f=resume-relance.json ;; *) f=resume.json ;; esac
    [ -f "$FAUX_DOSSIER/$f" ] && cat "$FAUX_DOSSIER/$f" ;;
  *) exit 1 ;;
esac
FAUX
  chmod +x "$d/faux"
  local perte='Failed to get matching snapshots: Lost connection to the application (pid 22209).'
  local acces='{"targetName":"CoproFirstUITests","testIdentifierString":"AccesUITests/testSignalerPerduPuisDeclarer()","failureText":"'$perte'","testName":"t"}'
  local assertion='{"targetName":"CoproFirstUITests","testIdentifierString":"AffairesUITests/testUn()","failureText":"XCTAssertTrue failed","testName":"t"}'
  local vert='{"result":"Passed","failedTests":0,"passedTests":1,"testFailures":[]}'
  local vide='{"result":"Passed","failedTests":0,"passedTests":0,"testFailures":[]}'
  # $1 nom, $2 sortie du 1er passage, $3 résumé JSON (vide : illisible), $4 sortie de
  # la relance, $5 sortie attendue, $6 relance attendue (oui/non), $7 résumé de la relance
  scenario() {
    rm -f "$d/appels" "$d/resume.json" "$d/resume-relance.json"
    [ -z "${7:-}" ] || echo "$7" > "$d/resume-relance.json"
    printf "Test Case '-[CoproFirstUITests.AccesUITests testSignalerPerduPuisDeclarer]' started.\n" > "$d/journal"
    echo "$2" > "$d/sortie-test"
    echo "$4" > "$d/sortie-relance"
    [ -z "$3" ] || echo "$3" > "$d/resume.json"
    local sortie relancee=non
    FAUX_DOSSIER=$d XCODEBUILD=$d/faux XCRUN=$d/faux MESURER=0 DESTINATION='platform=iOS Simulator,id=X' \
      RESULTATS=$d/r GITHUB_STEP_SUMMARY=$d/resume.md passer > "$d/sortie.txt" 2>&1
    sortie=$?
    grep -q '^test-without-building' "$d/appels" 2>/dev/null && relancee=oui
    if [ "$sortie" != "$5" ] || [ "$relancee" != "$6" ]; then
      echo "❌ $1 : sortie $sortie (attendu $5), relance $relancee (attendu $6)"; rate=$((rate + 1))
    fi
  }
  scenario "vert d'emblée" 0 "" 0 0 non
  scenario "perte de connexion, relance verte" 65 '{"result":"Failed","failedTests":1,"testFailures":['"$acces"']}' 0 0 oui "$vert"
  if ! grep -q -- '-only-testing:CoproFirstUITests/AccesUITests/testSignalerPerduPuisDeclarer' "$d/appels" \
      || ! grep -q 'Relance déclarée' "$d/resume.md" || ! grep -q '::warning' "$d/sortie.txt"; then
    echo "❌ la relance ne vise pas le seul test tombé, ou ne se déclare pas"; rate=$((rate + 1))
  fi
  scenario "perte de connexion, relance rouge" 65 '{"result":"Failed","failedTests":1,"testFailures":['"$acces"']}' 65 65 oui
  scenario "relance qui ne joue rien : rouge" 65 '{"result":"Failed","failedTests":1,"testFailures":['"$acces"']}' 0 1 oui "$vide"
  scenario "résumé de la relance illisible : rouge" 65 '{"result":"Failed","failedTests":1,"testFailures":['"$acces"']}' 0 1 oui
  scenario "une assertion : pas de relance" 65 '{"result":"Failed","failedTests":2,"testFailures":['"$acces,$assertion"']}' 0 65 non
  scenario "résumé illisible : INCONNU" 65 "" 0 65 non
  rm -rf "${d:?}"
  [ "$rate" -eq 0 ] && echo "✅ tests-simulateur : autotest" && return 0
  return 1
}

if [ "${1:-}" = "--autotest" ]; then
  autotest
  exit $?
fi
passer "$@"
code=$?
[ -n "${GITHUB_STEP_SUMMARY:-}" ] || cat "$RESULTATS/resume.md" 2>/dev/null
exit "$code"
