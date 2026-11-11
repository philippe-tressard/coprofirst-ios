#!/bin/bash
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
#
# autotest-tests-simulateur.sh — l'autotest de scripts/tests-simulateur.sh, qui le
# SOURCE pour `--autotest` (il emploie ses fonctions) : un faux xcodebuild, qui sert
# aussi de faux xcrun, et deux familles de cas.
#
#   - la décision d'un passage, rejouée dans ce processus (`scenario`) : relance
#     permise, refusée, ratée, INCONNU (#50) ; simulateur démarré avant le build
#     (#48) ; passage qui ne joue rien (#96) ;
#   - de vrais passages, chacun dans son processus (`passage`) : deux en même temps,
#     verrou orphelin ou sans fiche, arrêt par le pid, CI, lanceur, extinction du
#     simulateur (#108).
#
# Un contrôle qui ne refuse rien ne prouve rien : chaque cas a été vu rouge en
# retirant la ligne qu'il éprouve.

autotest() {
  local d rate=0
  d=$(mktemp -d) || return 2
  # Le dossier ne survit pas à l'autotest, même interrompu.
  trap "rm -rf '$d'" EXIT
  cat > "$d/faux" <<'FAUX'
#!/bin/bash
echo "$*" >> "$FAUX_DOSSIER/appels"
case "$1" in
  test)
    cat "$FAUX_DOSSIER/journal"
    # Un passage qui dure : retenu tant que le fichier existe, son pid dit pour l'arrêt.
    echo $$ > "$FAUX_DOSSIER/pid-test"
    while [ -f "$FAUX_DOSSIER/retenir" ]; do sleep 0.1; done
    exit "$(cat "$FAUX_DOSSIER/sortie-test")" ;;
  test-without-building) exit "$(cat "$FAUX_DOSSIER/sortie-relance")" ;;
  simctl)
    case "$2" in
      list) [ ! -f "$FAUX_DOSSIER/deja-demarre" ] || echo "    iPhone (X) (Booted)" ;;
      bootstatus) [ ! -f "$FAUX_DOSSIER/demarrage-rate" ] || exit 1 ;;
    esac
    exit 0 ;;
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
  # Le résumé réel d'un passage qui n'a rien joué (11/11/2026, deux filtres en un argument).
  local rien='{"result":"unknown","failedTests":0,"passedTests":0,"skippedTests":0,"totalTestCount":0,"testFailures":[]}'
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
  scenario "vert d'emblée" 0 "$vert" 0 0 non
  grep -q '^Tests joués : 1 passé' "$d/resume.md" \
    || { echo "❌ le compte des tests joués ne se dit pas au résumé"; rate=$((rate + 1)); }
  # Sortie 0 ne suffit pas : un passage qui n'a rien joué n'est pas vert (#96).
  scenario "passage qui ne joue rien : INCONNU" 0 "$rien" 0 2 non
  grep -q '^Tests joués : INCONNU : aucun test joué' "$d/resume.md" \
    || { echo "❌ le passage vide ne se dit pas au résumé"; rate=$((rate + 1)); }
  scenario "passage vert au résumé illisible : INCONNU" 0 "" 0 2 non
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
  # Le simulateur se démarre AVANT le build et les tests (#48) ; non confirmé, rien ne joue.
  # Avant de le démarrer, son état se lit : un passage n'éteint que ce qu'il a démarré.
  scenario "vert d'emblée, démarrage d'abord" 0 "$vert" 0 0 non
  if [ "$(sed -n 1p "$d/appels")" != "simctl list devices booted" ] \
      || [ "$(sed -n 2p "$d/appels")" != "simctl bootstatus X -b" ] || ! sed -n 3p "$d/appels" | grep -q '^test '; then
    echo "❌ le simulateur n'est pas démarré avant le build et les tests"; rate=$((rate + 1))
  fi
  touch "$d/demarrage-rate"
  scenario "démarrage non confirmé : INCONNU" 0 "" 0 1 non
  if grep -q '^test' "$d/appels"; then
    echo "❌ des tests joués sur un simulateur au démarrage non confirmé"; rate=$((rate + 1))
  fi
  rm -f "$d/demarrage-rate"

  # ── Le verrou, l'arrêt et l'extinction : de vrais passages, chacun dans son processus ──
  # $1 nom (sa sortie va dans $d/$1.txt), puis des variables d'environnement en plus.
  # `exec` : le pid du lancement en arrière-plan est celui du script.
  passage() {
    local nom=$1
    shift
    exec env FAUX_DOSSIER="$d" XCODEBUILD="$d/faux" XCRUN="$d/faux" MESURER=0 \
      DESTINATION='platform=iOS Simulator,id=X' RESULTATS="$d/r-$nom" GITHUB_STEP_SUMMARY="$d/resume-$nom.md" \
      GITHUB_ACTIONS= VERROU="$d/verrou" VERROU_PAS=0.1 VERROU_QUI="$nom" "$@" \
      "$BASH" scripts/tests-simulateur.sh > "$d/$nom.txt" 2>&1
  }
  # Attendre qu'une commande réussisse, 10 s au plus.
  jusqua() {
    local n=0
    until "$@" 2>/dev/null; do
      n=$((n + 1))
      [ "$n" -lt 100 ] || return 1
      sleep 0.1
    done
  }
  # La sortie du passage $1, attendue 10 s au plus : au-delà il est arrêté, sortie 124 —
  # un verrou qui ne se rend plus ne fige pas l'autotest.
  fin() {
    if ! jusqua eval "! kill -0 $1"; then
      kill "$1"
      rm -f "$d/retenir"
      jusqua eval "! kill -0 $1" || kill -9 "$1"
      wait "$1" 2> /dev/null
      return 124
    fi
    wait "$1"
  }
  joues() { local n; n=$(grep -c '^test ' "$d/appels" 2>/dev/null); echo "${n:-0}"; }
  attendu() { [ "$2" = "$3" ] || { echo "❌ $1 : $2 (attendu $3)"; rate=$((rate + 1)); }; }
  local a b sa sb intrus
  echo "$vert" > "$d/resume.json"
  echo 0 > "$d/sortie-test"

  # Deux passages en même temps : le second attend, dit qui tient le verrou, puis joue (#108).
  rm -f "$d/appels"; touch "$d/retenir"
  passage A & a=$!
  jusqua grep -q '^test ' "$d/appels" || { echo "❌ le premier passage ne joue pas"; rate=$((rate + 1)); }
  attendu "le pid de la fiche du verrou" "$(cat "$d/verrou/pid" 2>/dev/null)" "$a"
  passage B & b=$!
  jusqua grep -q '⏳ simulateur pris par A (pid '"$a"') depuis 20' "$d/B.txt" \
    || { echo "❌ le second passage ne dit pas qui tient le verrou, ni depuis quand"; rate=$((rate + 1)); }
  sleep 0.5
  attendu "passages joués pendant que le premier tient le verrou" "$(joues)" 1
  rm -f "$d/retenir"
  fin "$a"; sa=$?
  fin "$b"; sb=$?
  attendu "sorties des deux passages" "$sa $sb" "0 0"
  attendu "passages joués, l'un après l'autre" "$(joues)" 2
  attendu "extinctions du simulateur démarré" "$(grep -c '^simctl shutdown X$' "$d/appels")" 2
  [ ! -e "$d/verrou" ] || { echo "❌ le verrou n'est pas rendu"; rate=$((rate + 1)); }

  # Un verrou sans fiche, tout frais : son preneur écrit sa fiche — il ne se reprend pas.
  # Sa fiche dit ensuite un processus mort : orphelin, il se reprend.
  rm -f "$d/appels"; mkdir "$d/verrou"
  passage C & a=$!
  jusqua grep -q '⏳' "$d/C.txt"; sleep 0.5
  attendu "passage joué sous un verrou frais sans fiche" "$(joues)" 0
  echo 99999999 > "$d/verrou/pid"
  fin "$a"
  attendu "sortie après la reprise d'un verrou orphelin" "$?" 0
  grep -q '🔓 verrou orphelin repris' "$d/C.txt" \
    || { echo "❌ la reprise du verrou orphelin ne se dit pas"; rate=$((rate + 1)); }
  attendu "passage joué après la reprise" "$(joues)" 1
  [ ! -e "$d/verrou" ] || { echo "❌ le verrou repris n'est pas rendu"; rate=$((rate + 1)); }

  # Un verrou sans fiche depuis plus d'une minute : son preneur est mort avant de l'écrire.
  mkdir "$d/verrou"; touch -t 202001010000 "$d/verrou"
  passage D & a=$!
  fin "$a"
  attendu "sortie après la reprise d'un vieux verrou sans fiche" "$?" 0

  # L'arrêt par le pid de la fiche : xcodebuild ne survit pas, simulateur éteint, verrou rendu.
  rm -f "$d/appels" "$d/pid-test"; touch "$d/retenir"
  passage E & a=$!
  jusqua grep -q '^test ' "$d/appels" && jusqua test -s "$d/pid-test"
  kill "$(cat "$d/verrou/pid")"
  fin "$a"
  attendu "sortie d'un passage arrêté par son pid" "$?" 143
  jusqua eval '! kill -0 "$(cat "$d/pid-test")"' \
    || { echo "❌ xcodebuild survit au passage arrêté"; rate=$((rate + 1)); }
  attendu "extinction du simulateur à l'arrêt" "$(grep -c '^simctl shutdown X$' "$d/appels")" 1
  [ ! -e "$d/verrou" ] || { echo "❌ le verrou n'est pas rendu à l'arrêt"; rate=$((rate + 1)); }
  rm -f "$d/retenir"

  # Le verrou d'un autre, vivant : en CI il ne coûte rien (pas de verrou), et il n'est pas touché.
  sleep 30 & intrus=$!
  rm -f "$d/appels"; mkdir "$d/verrou"; echo "$intrus" > "$d/verrou/pid"
  passage F GITHUB_ACTIONS=true & a=$!
  fin "$a"
  attendu "sortie en CI malgré le verrou d'un autre" "$?" 0
  attendu "fiche du verrou d'un autre après un passage de CI" "$(cat "$d/verrou/pid" 2>/dev/null)" "$intrus"
  { kill "$intrus"; wait "$intrus"; } 2>/dev/null

  # Le verrou tenu par un ancêtre (un lanceur l'a pris pour ce passage) : ni attendu, ni rendu.
  # Et un simulateur déjà démarré avant le passage ne s'éteint pas.
  rm -f "$d/appels"; echo $$ > "$d/verrou/pid"; touch "$d/deja-demarre"
  passage G & a=$!
  fin "$a"
  attendu "sortie sous le verrou d'un ancêtre" "$?" 0
  attendu "fiche du verrou d'un ancêtre après le passage" "$(cat "$d/verrou/pid" 2>/dev/null)" "$$"
  attendu "extinctions d'un simulateur déjà démarré" "$(grep -c '^simctl shutdown' "$d/appels")" 0

  # Un verrou qui ne peut pas se poser (son répertoire n'existe pas) : INCONNU, sans attendre.
  rm -rf "$d/verrou" "$d/appels"
  passage H VERROU="$d/absent/verrou" & a=$!
  fin "$a"
  attendu "sortie quand le verrou ne peut pas se poser" "$?" 2
  attendu "passage joué sans verrou possible" "$(joues)" 0
  rm -rf "${d:?}"
  [ "$rate" -eq 0 ] && echo "✅ tests-simulateur : autotest" && return 0
  return 1
}
