#!/bin/bash
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
#
# produits-tests.sh — un build pour les six lots d'interface (#408). À SOURCER
# (scripts/tests-simulateur.sh), qui les appelle de `jouer_passage`, après l'écriture des
# empreintes (#328) et le contrôle « hors projet » : le build de tête et les lots jugent
# donc les mêmes sources, par le même chemin.
#
#   - `CONSTRUIRE_SEUL=oui` : `build-for-testing` pour la destination que les lots résolvent
#     (même appareil, même système), puis la version de Xcode écrite à côté des produits.
#     Ni simulateur démarré ni test joué. Le job « Build des tests d'interface » de la CI en
#     fait une archive tar (l'artefact perd sinon les bits d'exécution).
#   - `SANS_BUILD=oui` : les produits reçus se jouent par leur `.xctestrun`, en
#     `test-without-building` (le premier passage comme les relances) — jamais `test`, jamais
#     un build de repli. Produits absents, mêlés (plus d'un `.xctestrun`) ou faits par un autre
#     Xcode : INCONNU, sortie 2. L'empreinte du binaire reçu se juge ensuite comme celle d'un
#     binaire construit ici (« Binaire joué », #328) : des produits d'un autre commit rendent
#     INCONNU.
#
# Ces fonctions emploient `lancer`, `$XCODEBUILD`, `$RESULTATS` et `$RESUME` du script qui
# les source.

PRODUITS=${PRODUITS:-.build/DerivedData/Build/Products}

# La version de Xcode, en une ligne (« Xcode 26.6 Build version 17F… »).
version_xcode() {
  "$XCODEBUILD" -version 2>/dev/null | tr '\n' ' ' | sed 's/ *$//'
}

# $@ : les arguments communs du passage (projet, schéma, destination, DerivedData).
construire_produits() {
  local version
  version=$(version_xcode)
  [ -n "$version" ] || { echo "❓ INCONNU : version de Xcode illisible (xcodebuild -version)" >&2; return 2; }
  lancer "$RESULTATS/build.log" build-for-testing "$@" || {
    echo "❌ build-for-testing en échec : $RESULTATS/build.log" >&2
    echo "Build des tests : en échec." >> "$RESUME"
    return 1
  }
  mkdir -p "$PRODUITS" && echo "$version" > "$PRODUITS/version-xcode.txt" || return 2
  echo "Build des tests : produits pour $DESTINATION, $version — aucun test joué ici (#408)." >> "$RESUME"
}

# Les produits reçus : `XCTESTRUN` posé, sortie 0 ; sinon INCONNU, sortie 2.
produits_recus() {
  local trouves=() f recue ici motif=""
  for f in "$PRODUITS"/*.xctestrun; do [ ! -e "$f" ] || trouves+=("$f"); done
  recue=$(cat "$PRODUITS/version-xcode.txt" 2>/dev/null)
  ici=$(version_xcode)
  if [ "${#trouves[@]}" -ne 1 ]; then
    motif="${#trouves[@]} .xctestrun dans $PRODUITS, un seul attendu — produits absents ou mêlés"
  elif [ -z "$recue" ] || [ "$recue" != "$ici" ]; then
    motif="produits faits par « ${recue:-Xcode inconnu} », joués par « ${ici:-Xcode illisible} »"
  fi
  if [ -n "$motif" ]; then
    echo "❓ INCONNU : $motif. Aucun test joué : relancer l'exécution entière (#408)." >&2
    echo "Produits reçus : INCONNU — $motif ; aucun test joué." >> "$RESUME"
    return 2
  fi
  XCTESTRUN=${trouves[0]}
  echo "Produits reçus : $(basename "$XCTESTRUN"), $recue — sans build ici (#408)." >> "$RESUME"
}
