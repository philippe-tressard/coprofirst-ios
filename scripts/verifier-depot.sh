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
#      coprofirst (scripts/generer-charte.py) ;
#   8. aucun chemin de .claude/worktrees/ suivi : les worktrees des sessions
#      parallèles sont des dépôts, pas des fichiers du projet ;
#   9. la table de parité avec le site (Parite/PARITE.md) classe chaque onglet,
#      et le registre des menus dit vrai (scripts/verifier-parite.py, #10).
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

# Les couleurs se GÉNÈRENT depuis les sources de coprofirst (scripts/generer-charte.py) :
# aucune couleur écrite à la main dans le code Swift de l'app. Seuls le fichier
# généré et la fabrique qu'il appelle (Charte.swift) en portent.
COULEURS_MAIN='Color\(red:|UIColor\(red:|colorLiteral|RVBA\(0x|Color\.(red|blue|green|orange|yellow|purple|pink|black|white|gray)\b'
while IFS= read -r f; do
  [ -f "$f" ] || continue
  case "$f" in CoproFirst/Charte/Palette*.swift|CoproFirst/Charte/Charte.swift) continue ;; esac
  if grep -nE "$COULEURS_MAIN" "$f" >/dev/null; then
    echec "$f : couleur écrite à la main ($(grep -noE "$COULEURS_MAIN" "$f" | head -1)) — passer par Charte (généré)"
  fi
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

if ! cmp -s LICENSE <(assembler_licence); then
  echec "LICENSE diverge de LICENSES/ — bash scripts/verifier-depot.sh --ecrire-licence"
fi

if [ "$ECHECS" -gt 0 ]; then
  echo "── $ECHECS échec(s)"
  exit 1
fi
echo "✅ dépôt conforme : longueur, encodage, modes, syntaxe, LICENSE, aucune soumission automatisée, aucune couleur à la main, aucun worktree suivi ; ${PARITE#✅ } ($(wc -l <<< "$FICHIERS" | tr -d ' ') fichiers)"
