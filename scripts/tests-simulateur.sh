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
#     un runner jamais initialisé, AUCUN test joué (scripts/demarrage_runner.py, #50) :
#     c'est le passage entier qui se rejoue, sans rebuild — cette relance est alors la seule ;
#   - un passage sorti en 0 n'est vert que s'il a JOUÉ des tests : le compte se lit au
#     résumé de xcresult et se dit au résumé du run ; zéro test, ou un résumé qui ne
#     se lit pas, c'est INCONNU, sortie 2 (#96). Et CHAQUE filtre `-only-testing:` doit
#     avoir joué au moins un test, compté dans l'arbre du xcresult : deux filtres dont
#     l'un ne vise rien sortaient verts sur les tests de l'autre (#170) ;
#   - un fichier de test que le projet Xcode ne connaît pas (créé après
#     `generer-projet.sh`) arrête tout AVANT le build : INCONNU, avec la commande à
#     lancer. Le script ne régénère pas le projet lui-même : XcodeGen réécrit un projet
#     qu'Xcode peut tenir ouvert, et en CI la génération est une étape à part (#170) ;
#   - au poste, la machine ne s'endort pas pendant le passage (`caffeinate -i -s`), et le
#     résumé dit si elle s'est endormie quand même (`scripts/veille_poste.py`, #322) : le
#     20/11/2026, une passe a joué une heure sur un Mac en veille, 25 min par test et
#     « Timed out while synthesizing event » — un rouge sous veille est INCONNU ;
#   - le verrou COMMUN du poste d'abord (`verrou_poste.py`, #255), qui exclut aussi
#     Gradle et le rejeu de la CI des autres projets ; puis
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
# Appareil : un iPhone de série par défaut ; `APPAREIL=ipad` pour un iPad Pro 13 pouces
# (#220) ; `APPAREIL=tv` pour une Apple TV 4K et le schéma CoproFirstTV (#218) ;
# `APPAREIL=montre` pour une Apple Watch Series et le schéma CoproFirstWatch (#226) ;
# `DESTINATION` fixée l'emporte sur l'appareil.
#
# Système (#287) : au poste, le plus récent installé ; `OS_SIMULATEUR=ci` joue celui de la
# CI (`OS_SIMULATEUR_CI` d'outillage.env), `OS_SIMULATEUR=26.5` une version nommée. La CI
# joue toujours le sien. Le résumé nomme le système joué et celui de la CI : le 17/11/2026,
# #279 était vert sous 27.2 au poste et rouge sous 26.5 en CI.
#
# Arguments : passés au premier `xcodebuild test`, pour un passage partiel au poste
# (`bash scripts/tests-simulateur.sh -only-testing:CoproFirstUITests/ParcoursUITests`).
# `--autotest` rejoue tout cela avec un faux xcodebuild
# (scripts/autotest-tests-simulateur.sh) : relance permise, refusée, ratée, INCONNU,
# passage vide, filtre vide, fichier de test hors projet, veille du poste, deux passages en même temps, verrou orphelin,
# arrêt par le pid. Lancé
# par verifier-depot.sh (CI et pre-commit).
set -uo pipefail
cd "$(dirname "$0")/.."

XCODEBUILD=${XCODEBUILD:-xcodebuild}
XCRUN=${XCRUN:-xcrun}
MESURER=${MESURER:-1}
RESULTATS=${RESULTATS:-.build/Resultats}
CAFEINE=${CAFEINE:-caffeinate}
# La veille du poste (#322) : en CI, un runner ne s'endort pas et son journal
# d'alimentation n'est pas celui d'un poste.
if [ -z "${VEILLE_DU_POSTE:-}" ]; then
  VEILLE_DU_POSTE=oui
  [ "${GITHUB_ACTIONS:-}" != true ] || VEILLE_DU_POSTE=non
fi
PROJET=${PROJET:-CoproFirst.xcodeproj}
# Le schéma : celui de l'app ; avec APPAREIL=tv, celui de l'écran de hall (#218) ; avec
# APPAREIL=montre, celui de l'Apple Watch (#226).
case "${APPAREIL:-iphone}" in
  tv) SCHEMA=${SCHEMA:-CoproFirstTV} ;;
  montre) SCHEMA=${SCHEMA:-CoproFirstWatch} ;;
  *) SCHEMA=${SCHEMA:-CoproFirst} ;;
esac
SOURCES_TESTS=${SOURCES_TESTS:-CoproFirstTests CoproFirstUITests}
OS_CI=$(sed -n 's/^OS_SIMULATEUR_CI=//p' outillage.env 2>/dev/null)
# En CI, le système déclaré, jamais celui que l'image du runner met en tête (#287).
[ "${GITHUB_ACTIONS:-}" != true ] || OS_SIMULATEUR=${OS_SIMULATEUR:-ci}
A_ETEINDRE=""
DEBUT_JOURNAL=""
# Le verrou du poste : prendre_verrou, rendre_verrou.
source scripts/verrou-simulateur.sh
# Un build pour six lots (#408) : construire_produits, produits_recus.
source scripts/produits-tests.sh

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

# Les apps du projet installées sur ce simulateur (identifiants `fr.coprofirst.app…`). Sortie 2
# si la liste ne se lit pas : une liste vide ne prouverait rien.
nos_apps() {
  local liste
  liste=$("$XCRUN" simctl listapps "$1" 2>/dev/null) && grep -q 'CFBundleIdentifier' <<< "$liste" || return 2
  # Aucune des nôtres : grep sort en 1, ce qui n'est pas une erreur (pipefail).
  { grep -oE 'CFBundleIdentifier = "?fr\.coprofirst\.app[A-Za-z0-9.-]*' <<< "$liste" || true; } \
    | sed -E 's/.*= "?//' | sort -u
}

# Ni l'app ni le runner d'un passage d'avant : désinstallés, ils s'installent EN ENTIER (#328).
# Installés par-dessus, le simulateur les met à jour par un patch différentiel (« Delta patch
# update … from 1 (1.0) to 1 (1.0) ») : au poste, le 23/11/2026, le binaire du passage d'avant
# a joué 3 fois sur 7 ainsi, 0 sur 4 désinstallés. INCONNU (2) s'il en reste un.
desinstaller() {
  local udid=${DESTINATION##*id=} ids id
  if ! ids=$(nos_apps "$udid"); then
    echo "❌ simulateur $udid : ses apps ne se lisent pas (simctl listapps) — INCONNU, aucun test joué." >&2
    return 2
  fi
  for id in $ids; do "$XCRUN" simctl uninstall "$udid" "$id" > /dev/null 2>&1; done
  if ! ids=$(nos_apps "$udid") || [ -n "$ids" ]; then
    echo "❌ simulateur $udid : encore installé(s) après simctl uninstall : ${ids:-liste illisible} — INCONNU, aucun test joué." >&2
    return 2
  fi
  echo "Installation : complète, rien d'un passage d'avant (#328)."
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

# La ligne « Système » du résumé : le système de l'appareil joué, et celui de la CI (#287).
systeme_joue() {
  "$XCRUN" simctl list devices -j 2>/dev/null \
    | python3 -I scripts/destination_simulateur.py --systeme "${DESTINATION##*id=}" "$OS_CI"
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

# Le binaire JOUÉ est-il celui du source ? Un vert n'en prouve rien sinon : le 22/11/2026, un
# passage a joué l'app de test du passage précédent (#328). INCONNU (2) s'il ne se prouve pas.
binaire_joue() {
  local motif code
  motif=$(python3 -I scripts/empreinte_tests.py verifier "$1")
  code=$?
  echo "Binaire joué : $motif" >> "$RESUME"
  [ "$code" -eq 0 ] || echo "::error title=Binaire joué (#328)::$motif" >&2
  [ "$code" -eq 0 ] || return "$code"
  app_jouee "$1"
}

# L'APP jouée est-elle celle du source ? En Debug, elle dit son empreinte au journal du
# simulateur à chaque lancement (#328) : sans elle, un correctif ou un mutant de l'app se
# jugeait sur l'app d'avant. iPhone et iPad seuls : l'Apple TV et la montre ont la leur.
app_jouee() {
  case "${APPAREIL:-iphone}" in iphone | ipad) ;; *) return 0 ;; esac
  local motif code
  "$XCRUN" simctl spawn "${DESTINATION##*id=}" log show --start "$DEBUT_JOURNAL" --style compact \
    --predicate 'process == "CoproFirst" AND eventMessage BEGINSWITH "Empreinte de l'"'"'app jouée"' \
    > "$RESULTATS/empreinte-app.log" 2>&1
  motif=$(python3 -I scripts/empreinte_tests.py verifier-app "$RESULTATS/empreinte-app.log" "$1")
  code=$?
  echo "App jouée : $motif" >> "$RESUME"
  [ "$code" -eq 0 ] || echo "::error title=App jouée (#328)::$motif" >&2
  return "$code"
}

# Le poste éveillé pendant le passage, et sa veille dite au résumé quand même (#322).
passer() {
  local RESUME=${GITHUB_STEP_SUMMARY:-$RESULTATS/resume.md} debut eveil="" code motif v
  debut=$(date +%s)
  if [ "$VEILLE_DU_POSTE" = oui ]; then
    if command -v "$CAFEINE" > /dev/null; then "$CAFEINE" -i -s -w $$ & eveil=$!; fi
  fi
  # Pas d'arrêt ici : `-w $$` le termine avec le script, et `sortir` arrête ses descendants.
  jouer_passage "$@"
  code=$?
  [ "$VEILLE_DU_POSTE" = oui ] || return "$code"
  [ -n "$eveil" ] || echo "Veille du poste : rien ne l'empêche — $CAFEINE absent." >> "$RESUME"
  motif=$(python3 -I scripts/veille_poste.py "$debut" "$(date +%s)")
  v=$?
  case "$v:$code" in
    0:*) echo "Veille du poste : aucune pendant le passage." ;;
    1:0) echo "**Veille du poste (#322)** : $motif — le passage est vert malgré elle." ;;
    1:*) echo "::warning title=Veille du poste (#322)::$motif — ce rouge est INCONNU." >&2
      echo "**Veille du poste (#322)** : $motif — ce rouge est INCONNU, pas un défaut du test : à rejouer, le poste éveillé." ;;
    *) echo "Veille du poste : INCONNU — $motif." ;;
  esac >> "$RESUME"
  return "$code"
}

jouer_passage() {
  local RESUME=${GITHUB_STEP_SUMMARY:-$RESULTATS/resume.md} motif
  rm -rf "$RESULTATS" && mkdir -p "$RESULTATS" || return 2
  if [ -z "${DESTINATION:-}" ]; then
    # APPAREIL=ipad : un iPad Pro 13 pouces de série (#220) ; tv : une Apple TV (#218) ;
    # montre : une Apple Watch Series (#226). OS_SIMULATEUR : le système (#287).
    local choix=() systeme=${OS_SIMULATEUR:-}
    case "${APPAREIL:-iphone}" in
      iphone) ;;
      ipad | tv | montre) choix=("--$APPAREIL") ;;
      *) echo "❓ INCONNU : APPAREIL=$APPAREIL (iphone, ipad, tv ou montre)" >&2; return 2 ;;
    esac
    [ "$systeme" != ci ] || systeme=$OS_CI
    if [ "${OS_SIMULATEUR:-}" = ci ] && [ -z "$systeme" ]; then
      echo "❓ INCONNU : OS_SIMULATEUR=ci, et outillage.env ne déclare pas OS_SIMULATEUR_CI" >&2
      return 2
    fi
    [ -z "$systeme" ] || choix+=(--os "$systeme")
    DESTINATION=$(bash scripts/destination-simulateur.sh ${choix[@]+"${choix[@]}"}) || return 1
  fi
  echo "## Tests au simulateur" >> "$RESUME"
  motif=$(systeme_joue)
  echo "$motif"
  echo "$motif" >> "$RESUME"
  # L'empreinte des sources, compilée dans le paquet de tests : le binaire joué la redira (#328).
  python3 -I scripts/empreinte_tests.py ecrire > /dev/null || return 2
  if ! motif=$(hors_projet); then
    echo "❌ $motif" >&2
    echo "Projet : $motif" >> "$RESUME"
    return 2
  fi
  echo "Destination : $DESTINATION"
  local communs=(
    -project "$PROJET" -scheme "$SCHEMA" -destination "$DESTINATION"
    -derivedDataPath .build/DerivedData -skipPackagePluginValidation
    -onlyUsePackageVersionsFromResolvedFile CODE_SIGNING_ALLOWED=NO
  )
  # Un build pour six lots (#408, scripts/produits-tests.sh) : le build de tête s'arrête là ;
  # un lot joue les produits reçus, par leur .xctestrun, jamais un build de repli.
  local premier=test
  [ -z "${CONSTRUIRE_SEUL:-}" ] || { construire_produits "${communs[@]}"; return $?; }
  if [ -n "${SANS_BUILD:-}" ]; then
    produits_recus || return 2
    communs=(-xctestrun "$XCTESTRUN" -destination "$DESTINATION")
    premier=test-without-building
  fi
  demarrer_simulateur || return 1
  desinstaller | tee -a "$RESUME"
  [ "${PIPESTATUS[0]}" -eq 0 ] || return 2
  # Le journal du simulateur, lu depuis ce point : l'app y dira son empreinte (#328).
  DEBUT_JOURNAL=$(date '+%Y-%m-%d %H:%M:%S')
  local debut=$SECONDS code seuls decision
  lancer "$RESULTATS/tests.log" "$premier" "${communs[@]}" "$@" -resultBundlePath "$RESULTATS/tests.xcresult"
  code=$?
  # Le runner n'a pas démarré, aucun test joué (#50, « AX loaded notification ») : le
  # passage se rejoue UNE fois, sans rebuild, déclaré — et c'est la seule relance permise.
  local relance_faite=""
  if [ "$code" -ne 0 ] && motif=$(python3 -I scripts/demarrage_runner.py "$RESULTATS/tests.log"); then
    echo "::warning title=Relance déclarée (#50)::$motif — le passage rejoué une fois, sans rebuild."
    echo "**Relance déclarée (#50)** : $motif — le passage rejoué une fois, sans rebuild." >> "$RESUME"
    mv "$RESULTATS/tests.log" "$RESULTATS/demarrage.log" && rm -rf "$RESULTATS/tests.xcresult"
    lancer "$RESULTATS/tests.log" test-without-building "${communs[@]}" "$@" -resultBundlePath "$RESULTATS/tests.xcresult"
    code=$?
    relance_faite=oui
  fi
  python3 -I scripts/bilan_tests_ui.py lenteurs "$RESULTATS/tests.log" "$RESUME"
  # Un ROUGE ne prouve pas plus qu'un vert : sur un binaire périmé, il juge un autre code, et
  # sa relance (sans rebuild) rejouerait le même (#328 : au poste, le 23/11, un mutant rouge a
  # joué le binaire du passage d'avant). INCONNU, sans relance.
  if [ "$code" -ne 0 ] && ! binaire_joue "$RESULTATS/tests.log"; then return 2; fi
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
    verifier_filtres "$@" >> "$RESUME" || return $?
    binaire_joue "$RESULTATS/tests.log"
    return $?
  fi

  mesurer $((SECONDS - debut)) >> "$RESUME"
  if [ -n "$relance_faite" ]; then
    echo "Relance : aucune de plus — la seule permise a servi au démarrage du runner." >> "$RESUME"
    return "$code"
  fi
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
    binaire_joue "$RESULTATS/tests.log" && binaire_joue "$RESULTATS/relance.log"
    return $?
  fi
  echo "Relance : non prouvée — ${motif:-INCONNU, résumé de la relance illisible}. Le run échoue." >> "$RESUME"
  return 1
}

if [ "${1:-}" = "--autotest" ]; then
  source scripts/autotest-tests-simulateur.sh
  autotest
  exit $?
fi
# Le verrou COMMUN du poste d'abord (`~/.claude/bin/verrou_poste.py`, claude-config#552,
# #255) : xcodebuild, Gradle et l'émulateur d'Android, le rejeu de la CI de 5Hostachy
# s'excluent tous. Le 16/11/2026, un xcodebuild iPad et Gradle tournaient ensemble (charge
# à 39 sur 12 cœurs, 4,2 Go de swap) : le verrou du simulateur, plus bas, n'exclut que
# les passages iOS entre eux. Le script se relance sous le verrou commun, qui DEVIENT ce
# passage (même pid : la fiche du verrou iOS et l'arrêt par le pid restent justes). Déjà
# tenu (`VERROU_POSTE_TENU`), en CI ou sans le verrou commun : il continue, et l'absence
# se dit. `VERROU_POSTE` remplace son chemin (l'autotest).
VERROU_COMMUN=${VERROU_POSTE:-$HOME/.claude/bin/verrou_poste.py}
if [ -z "${VERROU_POSTE_TENU:-}" ] && [ "${GITHUB_ACTIONS:-}" != true ]; then
  if [ -f "$VERROU_COMMUN" ]; then
    export VERROU_POSTE_TENU=1
    exec python3 "$VERROU_COMMUN" prendre --libelle "xcodebuild test (CoproFirst-iOS)" --depot "$PWD" \
      -- "$BASH" "$PWD/scripts/tests-simulateur.sh" "$@"
  fi
  echo "ℹ️  sans verrou commun du poste ($VERROU_COMMUN absent) : ce passage n'exclut que les passages iOS" >&2
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
