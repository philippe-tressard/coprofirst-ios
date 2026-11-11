#!/bin/bash
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
#
# verifier-depot.sh — les garde-fous du dépôt qui ne demandent pas Xcode.
# Lancé par la CI, par le hook pre-commit et à la main ; sortie non nulle = refus.
#
#   1. aucun fichier versionné de plus de 500 lignes (standards/02 §6)
#   2. ni BOM ni CRLF (standards/10)
#   3. bit d'exécution sur les scripts, et sur eux seuls (standards/08 §3)
#   4. syntaxe de chaque script bash et Python (standards/05 §6)
#   5. LICENSE = permission App Store + texte de l'AGPL, assemblés par
#      `--ecrire-licence` : les deux textes vivent dans LICENSES/, LICENSE n'en est
#      que la réunion, et ce contrôle refuse qu'il en diverge.
#   6. aucune automatisation ne soumet à Apple : rien ne part en revue sans le
#      « oui » écrit de Philippe pour la version (skill publication-app-store).
#   7. aucune couleur écrite à la main dans l'app : elles se génèrent depuis
#      coprofirst dans la `Palette` (scripts/generer.py) ; seuls les fichiers de
#      chaque palette en portent, et une dispense qui ne couvre plus aucune couleur
#      échoue. Un fichier de `Fonctions/<Menu>/Genere/` porte l'en-tête
#      « GÉNÉRÉ » en 1re ligne — et aucune couleur (#34) ;
#   8. aucun moteur web pour le texte du site : ni WebKit, ni conversion HTML de
#      NSAttributedString — le HTML passe par TexteDuSite, seul (#22) ;
#   9. aucun chemin de .claude/worktrees/ suivi : les worktrees des sessions
#      parallèles sont des dépôts, pas des fichiers du projet ;
#  10. la table de parité avec le site (Parite/PARITE.md) classe chaque onglet,
#      et le registre des menus dit vrai (scripts/verifier-parite.py, #10) ;
#  11. un générateur ne lit coprofirst qu'à une version PUBLIÉE, et coprofirst-site
#      qu'à un commit épinglé (#51), par scripts/generateurs/_source.py seul : ni
#      clone, ni arbre de travail, ni branche (#34, #20) ; le logo, lui, se compare
#      et se recopie à l'étiquette du plancher (scripts/plancher.sh, #133) ;
#  12. chaque réponse de l'API simulée a la forme du schéma du serveur
#      (scripts/verifier-fixtures.py, bogue des badges du 05/11/2026) ;
#  13. les tests au simulateur : relance bornée et déclarée (#50), un passage qui ne
#      joue rien rendu INCONNU (#96), un seul passage à la fois sur le poste et
#      l'arrêt par le pid (#108) — autotests de scripts/bilan_tests_ui.py et
#      scripts/tests-simulateur.sh ; le simulateur choisi sans hasard — autotest de
#      scripts/destination_simulateur.py (#112) ;
#  14. les tickets de la concordance : un vert ferme, un rouge ou un INCONNU jamais —
#      autotest de scripts/tickets_concordance.py (#67).
#  15. la simulation ne part pas en production : `ServiceSimule`, ses jeux de
#      données et `-api-simulee` sous `#if DEBUG` seulement (scripts/verifier-simule.py,
#      autotest d'abord, #84) ;
#  16. ce que le serveur SERT ne se recalcule pas : aucune table ni aucun prédicat
#      retiré ne revient (scripts/verifier-regles-servies.py, #83) ;
#  17. dans les tests d'interface, une attente par prédicat passe par le point
#      d'attente commun (CoproFirstUITests/Attente.swift) et son plafond : aucune
#      n'est écrite sur place avec son propre délai (#123) ;
#  18. la confidentialité déclarée est celle du code : manifeste embarqué, fiche de
#      l'App Store et code concordent sur ce qui se mesure — API à raison requise,
#      envois, modules, droits, paquets (scripts/verifier-confidentialite.py, #19) ;
#  19. DEPENDANCES.md dit ce que Package.resolved épingle : chaque paquet embarqué de
#      la fiche y est listé embarqué, et chaque version écrite est l'épinglée
#      (scripts/verifier-dependances.py, #143).
#
# Il juge les fichiers que git connaît (index compris) : un fichier ignoré n'est
# pas livré, il n'a pas à passer.
set -uo pipefail
cd "$(dirname "$0")/.."

PERMISSION=LICENSES/LicenseRef-CoproFirst-AppStore.txt
AGPL=LICENSES/AGPL-3.0-or-later.txt

assembler_licence() {
  cat "$PERMISSION"
  printf '\n%s\n\n' "================================================================================"
  cat "$AGPL"
}

if [ "${1:-}" = "--ecrire-licence" ]; then
  assembler_licence > LICENSE
  echo "✅ LICENSE réassemblé depuis LICENSES/"
  exit 0
fi

ECHECS=0
echec() { echo "❌ $*"; ECHECS=$((ECHECS + 1)); }

FICHIERS=$(git ls-files --cached)
[ -n "$FICHIERS" ] || { echo "❓ INCONNU : git ne connaît aucun fichier (rien d'indexé ?)"; exit 2; }

# Les seuls fichiers dispensés de la limite de longueur — produits par un outil,
# jamais écrits à la main. Toute autre exception se discute, elle ne s'ajoute pas.
DISPENSES_LONGUEUR='^(LICENSE|LICENSES/.*|Paquets/ClientAPI/Sources/ClientAPI/openapi\.json|.*Package\.resolved)$'

while IFS= read -r f; do
  [ -f "$f" ] || continue
  # Un binaire n'a ni lignes ni fins de ligne.
  grep -Iq . "$f" 2>/dev/null || continue
  if ! [[ "$f" =~ $DISPENSES_LONGUEUR ]]; then
    n=$(wc -l < "$f" | tr -d ' ')
    [ "$n" -le 500 ] || echec "$f : $n lignes (> 500) — découper (standards/02 §6)"
  fi
  [ "$(head -c 3 "$f" | od -An -tx1 | tr -d " \n")" != "efbbbf" ] || echec "$f : BOM UTF-8"
  ! grep -q $'\r' "$f" || echec "$f : fins de ligne CRLF"
done <<< "$FICHIERS"

# `git ls-files --stage` : « <mode> <objet> <étape>\t<chemin> ».
while IFS=$'\t' read -r meta f; do
  mode=${meta%% *}
  if [[ "$f" == *.sh || "$f" == .githooks/* ]]; then
    [ "$mode" = "100755" ] || echec "$f : mode $mode, attendu 100755 (git update-index --chmod=+x)"
    bash -n "$f" 2>/dev/null || echec "$f : syntaxe bash invalide"
  elif [[ "$f" == *.py ]]; then
    # Un script Python lancé directement porte son shebang et son bit d'exécution.
    if head -1 "$f" | grep -q '^#!'; then
      [ "$mode" = "100755" ] || echec "$f : shebang sans bit d'exécution (git update-index --chmod=+x)"
    fi
    python3 -c 'import ast, sys; ast.parse(open(sys.argv[1], encoding="utf-8").read())' "$f" 2>/dev/null \
      || echec "$f : syntaxe Python invalide"
  elif [ "$mode" = "100755" ]; then
    echec "$f : exécutable sans être un script (git update-index --chmod=-x)"
  fi
done < <(git ls-files --stage)

# Les couleurs se GÉNÈRENT depuis les sources de coprofirst, dans la `Palette`
# (scripts/generer.py) : aucune couleur écrite à la main dans le code Swift de l'app.
COULEURS_MAIN='Color\(red:|UIColor\(red:|colorLiteral|RVBA\(0x|Color\.(red|blue|green|orange|yellow|purple|pink|black|white|gray)\b'
# Les seuls fichiers qui en portent : chaque palette générée (`Palette+<code>.swift`).
# Une dispense qui ne couvre plus de couleur échoue : une exception sans objet se retire.
DISPENSES_COULEUR='^CoproFirst/Charte/Palette\+[A-Z][a-z]+\.swift$'
# Un fichier qu'un générateur écrit dans le dossier d'un menu (`Fonctions/<Menu>/Genere/`)
# dit en 1re ligne qu'il est généré ; ses teintes, il les nomme dans la `Palette` (#34).
EN_TETE_GENERE='^// GÉNÉRÉ par scripts/generer\.py — NE PAS MODIFIER'
GENERE='^CoproFirst/Fonctions/[^/]+/Genere/[^/]+\.swift$'
# $1 : chemin dans le dépôt ; $2 : le fichier à lire. Rend le motif du refus, ou rien.
refus_couleur() {
  local couleur
  couleur=$(grep -noE "$COULEURS_MAIN" "$2" | head -1)
  if [[ "$1" =~ $DISPENSES_COULEUR ]]; then
    [ -n "$couleur" ] || echo "dispensé de la règle des couleurs sans en porter aucune — retirer la dispense"
    return
  fi
  if [[ "$1" =~ $GENERE ]] && ! head -1 "$2" | grep -qE "$EN_TETE_GENERE"; then
    echo "fichier de Genere/ sans l'en-tête « GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER » en 1re ligne"
  elif [ -n "$couleur" ]; then
    echo "couleur écrite à la main ($couleur) — un jeton de la Palette (générée)"
  fi
}
# Autotest, dans les deux sens : un contrôle qui ne refuse rien ne prouve rien.
autotest_couleurs() {
  local d ok=0
  d=$(mktemp -d) || return 1
  printf '// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.\nlet c = RVBA(0x01, 0x02, 0x03, 1)\n' > "$d/declare"
  printf '// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.\nlet t = \\.kanbanAg\n' > "$d/propre"
  printf '// Écrit à la main.\nlet c = RVBA(0x01, 0x02, 0x03, 1)\n' > "$d/nu"
  printf '// Écrit à la main.\nlet n = 1\n' > "$d/sans"
  [ -n "$(refus_couleur CoproFirst/Fonctions/M/Genere/T.swift "$d/declare")" ] || ok=1
  [ -z "$(refus_couleur CoproFirst/Fonctions/M/Genere/T.swift "$d/propre")" ] || ok=1
  [ -n "$(refus_couleur CoproFirst/Fonctions/M/Genere/T.swift "$d/sans")" ] || ok=1
  [ -n "$(refus_couleur CoproFirst/Fonctions/M/Vue.swift "$d/nu")" ] || ok=1
  [ -z "$(refus_couleur CoproFirst/Fonctions/M/Vue.swift "$d/sans")" ] || ok=1
  [ -z "$(refus_couleur CoproFirst/Charte/Palette+Seine.swift "$d/nu")" ] || ok=1
  [ -n "$(refus_couleur CoproFirst/Charte/Palette+Seine.swift "$d/sans")" ] || ok=1
  [ -n "$(refus_couleur CoproFirst/Charte/PaletteKanban.swift "$d/nu")" ] || ok=1
  rm -rf "${d:?}"
  return $ok
}
autotest_couleurs || echec "verifier-depot.sh : autotest des couleurs en échec"
while IFS= read -r f; do
  [ -f "$f" ] || continue
  motif=$(refus_couleur "$f" "$f")
  [ -z "$motif" ] || echec "$f : $motif"
done < <(grep -E '^CoproFirst/.*\.swift$' <<< "$FICHIERS")

# Une génération lit coprofirst à une version PUBLIÉE, et par `_source.py` seul (#34) :
# aucun autre script de génération n'ouvre un clone, une branche ou l'arbre de travail.
LECTURE_DIRECTE='COPROFIRST_RACINE|/Volumes/|subprocess|urllib|git (show|archive|-C)|rev-parse|\bHEAD\b|raw\.githubusercontent|refs/heads'
GENERATION='^scripts/(generer[^/]*|concordance[^/]*|generateurs/[^/]+)$'
SOURCE_UNIQUE='scripts/generateurs/_source.py'
# $1 : chemin dans le dépôt ; $2 : le fichier à lire. Rend le motif du refus, ou rien.
refus_lecture() {
  local trouve
  [[ "$1" =~ $GENERATION ]] || return
  if [ "$1" = "$SOURCE_UNIQUE" ]; then
    # La source elle-même : une version publiée, jamais une branche ni l'arbre d'un clone.
    trouve=$(grep -noE '\bHEAD\b|refs/heads|git |COPROFIRST_RACINE|/Volumes/' "$2" | head -1)
    [ -z "$trouve" ] || echo "la source lit autre chose qu'une version publiée ($trouve)"
    grep -q 'refs/tags/' "$2" || echo "la source ne lit plus l'archive d'une étiquette (refs/tags/)"
    return
  fi
  trouve=$(grep -noE "$LECTURE_DIRECTE" "$2" | head -1)
  [ -z "$trouve" ] || echo "lit coprofirst en direct ($trouve) — passer par ctx (generateurs/_source.py)"
}
autotest_lecture() {
  local d ok=0
  d=$(mktemp -d) || return 1
  printf 'x = subprocess.run(["git", "-C", f, "rev-parse", "HEAD"])\n' > "$d/tete"
  printf 'texte = ctx.lire("front/src/lib/pages.ts")\n' > "$d/propre"
  printf 'URL = "https://codeload.github.com/d/tar.gz/refs/tags/v1"\n' > "$d/source"
  printf 'URL = "https://codeload.github.com/d/tar.gz/refs/heads/main"\n' > "$d/branche"
  [ -n "$(refus_lecture scripts/generateurs/x.py "$d/tete")" ] || ok=1
  [ -n "$(refus_lecture scripts/generer.py "$d/tete")" ] || ok=1
  [ -z "$(refus_lecture scripts/generateurs/x.py "$d/propre")" ] || ok=1
  [ -z "$(refus_lecture scripts/verifier-logo.sh "$d/tete")" ] || ok=1
  [ -z "$(refus_lecture "$SOURCE_UNIQUE" "$d/source")" ] || ok=1
  [ -n "$(refus_lecture "$SOURCE_UNIQUE" "$d/branche")" ] || ok=1
  rm -rf "${d:?}"
  return $ok
}
autotest_lecture || echec "verifier-depot.sh : autotest de la lecture de coprofirst en échec"
grep -qx "$SOURCE_UNIQUE" <<< "$FICHIERS" || echec "$SOURCE_UNIQUE absent : la règle de provenance n'a plus de source"
while IFS= read -r f; do
  [ -f "$f" ] || continue
  motif=$(refus_lecture "$f" "$f")
  [ -z "$motif" ] || echec "$f : $motif"
done < <(grep -E "$GENERATION" <<< "$FICHIERS")

# Le logo se compare et se recopie à l'étiquette du plancher (scripts/plancher.sh),
# jamais à une branche : `dev` de coprofirst disparaît à chaque mise en production,
# et le job « Dépôt » rougissait au hasard (#133).
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
autotest_ref_logo || echec "verifier-depot.sh : autotest de la référence du logo en échec"
for f in scripts/verifier-logo.sh scripts/importer-logo.sh; do
  motif=$(refus_ref_logo "$f")
  [ -z "$motif" ] || echec "$f : $motif"
done
bash scripts/plancher.sh > /dev/null || echec "scripts/plancher.sh : plancher illisible (INCONNU)"

# Les réponses de l'API simulée contre le schéma du serveur : l'autotest d'abord, puis
# le juge. INCONNU (sortie 2) est un échec, jamais un succès.
python3 -I scripts/verifier-fixtures.py --autotest >/dev/null || echec "verifier-fixtures.py : autotest en échec"
FIXTURES=$(python3 -I scripts/verifier-fixtures.py) || { echo "$FIXTURES"; echec "API simulée hors du schéma du serveur"; }

# Ce que le serveur SERT ne se recalcule plus (#83) : une table ou un prédicat retiré
# qui revient échoue. L'autotest d'abord ; INCONNU (sortie 2) est un échec.
python3 -I scripts/verifier-regles-servies.py --autotest >/dev/null || echec "verifier-regles-servies.py : autotest en échec"
SERVIES=$(python3 -I scripts/verifier-regles-servies.py) || { echo "$SERVIES"; echec "une règle servie est recalculée dans l'app"; }

# Le texte riche du site passe par UNE porte, sans WebKit (#22) : WKWebView exécute
# et charge, NSAttributedString(.html) passe par WebKit et charge des ressources
# distantes. Ni l'un ni l'autre dans l'app.
MOTEUR_WEB='import WebKit|WKWebView|\.documentType|DocumentType\.html|NSAttributedString\(data:'
while IFS= read -r f; do
  [ -f "$f" ] || continue
  # Le code seul : un commentaire qui explique l'interdit a le droit de le nommer.
  trouve=$(grep -nE "$MOTEUR_WEB" "$f" | grep -vE '^[0-9]+:[[:space:]]*///?' | head -1)
  [ -z "$trouve" ] || echec "$f : moteur web pour du HTML (${trouve%%:*}) — passer par TexteDuSite"
done < <(grep -E '^CoproFirst/.*\.swift$' <<< "$FICHIERS")

# Les gestes qui envoient une version en revue chez Apple : soumission à l'App
# Store, distribution aux testeurs externes de TestFlight. Ils n'ont pas de place
# dans une automatisation — la soumission est manuelle, après validation du rendu.
GESTES_REVUE='submit_for_review|distribute_external|upload_to_app_store|deliver|submit-for-review|reviewSubmissions'
while IFS= read -r f; do
  [ -f "$f" ] || continue
  if grep -nEi "$GESTES_REVUE" "$f" >/dev/null; then
    echec "$f : geste de soumission à Apple automatisé ($(grep -oEi "$GESTES_REVUE" "$f" | head -1)) — interdit, skill publication-app-store"
  fi
done < <(grep -E '^(fastlane/|\.github/workflows/)' <<< "$FICHIERS")

# Un worktree de session ajouté par erreur arrive comme lien de sous-module ou
# comme fichiers : les deux se voient dans l'index.
if grep -qE '^\.claude/worktrees(/|$)' <<< "$FICHIERS"; then
  echec ".claude/worktrees/ est suivi — git rm -r --cached .claude/worktrees (exclu par .gitignore)"
fi

# La parité : son autotest d'abord (un contrôle qui ne refuse rien ne prouve rien),
# puis la table elle-même. INCONNU (sortie 2) est un échec, jamais un succès.
python3 -I scripts/verifier-parite.py --autotest >/dev/null || echec "verifier-parite.py : autotest en échec"
PARITE=$(python3 -I scripts/verifier-parite.py) || { echo "$PARITE"; echec "parité avec le site (Parite/PARITE.md)"; }

# Les tests au simulateur : une relance au plus, déclarée, sur une cause déclarée
# (#50). Les deux autotests prouvent que la décision refuse ce qu'elle doit refuser.
python3 -I scripts/bilan_tests_ui.py --autotest >/dev/null || echec "bilan_tests_ui.py : autotest en échec"
bash scripts/tests-simulateur.sh --autotest >/dev/null || echec "tests-simulateur.sh : autotest en échec"
# Le simulateur des tests : un iPhone de série du runtime standard, ou INCONNU (#112).
python3 -I scripts/destination_simulateur.py --autotest >/dev/null || echec "destination_simulateur.py : autotest en échec"

# Une attente par prédicat (le focus du clavier, un onglet retenu) passe par le point
# d'attente commun et son plafond (#123) : écrite sur place, chacune portait son délai,
# et 3 s ne tiennent pas sur un runner qui met 2 s par requête d'accessibilité.
ATTENTE_SUR_PLACE='expectation\(for:|waitForExpectations|XCTNSPredicateExpectation|XCTWaiter|[^.[:alnum:]]wait\(for:'
POINT_ATTENTE=CoproFirstUITests/Attente.swift
# $1 : chemin dans le dépôt ; $2 : le fichier à lire. Rend le motif du refus, ou rien.
refus_attente() {
  local trouve
  [ "$1" != "$POINT_ATTENTE" ] || return 0
  # Le code seul : un commentaire qui explique l'interdit a le droit de le nommer.
  trouve=$(grep -nE "$ATTENTE_SUR_PLACE" "$2" | grep -vE '^[0-9]+:[[:space:]]*///?' | head -1)
  [ -z "$trouve" ] || echo "attente par prédicat écrite sur place (ligne ${trouve%%:*}) — element.attendre(\"…\"), $POINT_ATTENTE"
}
autotest_attente() {
  local d ok=0
  d=$(mktemp -d) || return 1
  printf '        expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: champ)\n        waitForExpectations(timeout: 3)\n' > "$d/focus"
  printf '        wait(for: [visible], timeout: 3)\n' > "$d/visible"
  printf '        XCTAssertTrue(champ.attendre("hasKeyboardFocus == true"))\n        // jamais waitForExpectations(timeout: 3)\n' > "$d/commun"
  [ -n "$(refus_attente CoproFirstUITests/RetourUITests.swift "$d/focus")" ] || ok=1
  [ -n "$(refus_attente CoproFirstUITests/ConnexionUITests.swift "$d/visible")" ] || ok=1
  [ -z "$(refus_attente CoproFirstUITests/RetourUITests.swift "$d/commun")" ] || ok=1
  [ -z "$(refus_attente "$POINT_ATTENTE" "$d/focus")" ] || ok=1
  rm -rf "${d:?}"
  return $ok
}
autotest_attente || echec "verifier-depot.sh : autotest des attentes par prédicat en échec"
grep -qx "$POINT_ATTENTE" <<< "$FICHIERS" || echec "$POINT_ATTENTE absent : les attentes n'ont plus de point commun"
ATTENTES=0
while IFS= read -r f; do
  [ -f "$f" ] || continue
  motif=$(refus_attente "$f" "$f")
  [ -z "$motif" ] || echec "$f : $motif"
  [ "$f" = "$POINT_ATTENTE" ] || ! grep -q '\.attendre("' "$f" || ATTENTES=$((ATTENTES + 1))
done < <(grep -E '^CoproFirstUITests/.*\.swift$' <<< "$FICHIERS")
# Un point commun que personne n'emploie ne remplace rien.
[ "$ATTENTES" -gt 0 ] || echec "aucun test n'attend par $POINT_ATTENTE : le point commun n'est pas employé"

# Les tickets de la concordance quotidienne (#67) : rouge → vert et INCONNU → vert
# ferment, vert → vert ne touche à rien, un INCONNU ne ferme jamais.
python3 -I scripts/tickets_concordance.py --autotest >/dev/null || echec "tickets_concordance.py : autotest en échec"

# La simulation reste aux builds Debug (#84) : l'autotest prouve que le juge refuse
# un symbole hors de `#if DEBUG`, puis le juge lit l'app. INCONNU (2) est un échec.
python3 -I scripts/verifier-simule.py --autotest >/dev/null || echec "verifier-simule.py : autotest en échec"
SIMULE=$(python3 -I scripts/verifier-simule.py) || { echo "$SIMULE"; echec "simulation hors de #if DEBUG"; }

# Confidentialité déclarée = confidentialité réelle (#19) : l'autotest d'abord, puis le
# manifeste, la fiche et le code. Ce que le juge ne mesure pas, il le dit INCONNU à chaque
# passage — la ligne s'affiche, elle ne compte pas pour conforme.
python3 -I scripts/verifier-confidentialite.py --autotest >/dev/null || echec "verifier-confidentialite.py : autotest en échec"
CONFIDENTIALITE=$(python3 -I scripts/verifier-confidentialite.py) || { echo "$CONFIDENTIALITE"; echec "confidentialité déclarée ≠ code"; }
grep '^❓' <<< "$CONFIDENTIALITE" || true

# L'inventaire des dépendances tenu à Package.resolved (#143) : l'autotest d'abord.
python3 -I scripts/verifier-dependances.py --autotest >/dev/null || echec "verifier-dependances.py : autotest en échec"
DEPENDANCES=$(python3 -I scripts/verifier-dependances.py) || { echo "$DEPENDANCES"; echec "DEPENDANCES.md ≠ Package.resolved"; }

if ! cmp -s LICENSE <(assembler_licence); then
  echec "LICENSE diverge de LICENSES/ — bash scripts/verifier-depot.sh --ecrire-licence"
fi

if [ "$ECHECS" -gt 0 ]; then
  echo "── $ECHECS échec(s)"
  exit 1
fi
echo "✅ dépôt conforme : longueur, encodage, modes, syntaxe, LICENSE, aucune soumission automatisée, aucune couleur à la main, coprofirst lu à une version publiée, aucun moteur web, aucun worktree suivi, relance des tests bornée, passage vide refusé, un passage à la fois, simulateur choisi sans hasard, attentes par le point commun, tickets de la concordance, simulation sous #if DEBUG, règles servies lues ; ${PARITE#✅ } ; ${FIXTURES#✅ } ; $(grep '^✅' <<< "$CONFIDENTIALITE" | sed 's/^✅ //') ; ${DEPENDANCES#✅ } ($(wc -l <<< "$FICHIERS" | tr -d ' ') fichiers)"
