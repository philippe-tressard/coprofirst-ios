#!/bin/bash
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
#
# verrou-simulateur.sh — un seul passage au simulateur à la fois sur le poste (#108).
# À SOURCER (scripts/tests-simulateur.sh) : `prendre_verrou` attend son tour,
# `rendre_verrou` le rend. Le verrou est un répertoire, `simulateur.verrou`, dans le
# répertoire git COMMUN — celui que partagent tous les worktrees des sessions —, avec
# sa fiche : `pid` (le processus à arrêter pour arrêter le passage), `qui`, `depuis`.
#
#   - pris par `mkdir`, qui réussit pour un seul ; les autres attendent en disant qui
#     le tient et depuis quand ;
#   - jamais retiré tant que le processus de sa fiche vit ; orphelin (processus mort),
#     il se reprend, à un seul à la fois ;
#   - tenu par un ancêtre du passage (un lanceur qui l'a pris pour lui), il ne
#     s'attend pas et ne se rend pas à sa place ;
#   - en CI, pas de verrou : un runner, un passage.
#
# Éprouvé par `scripts/tests-simulateur.sh --autotest` : deux passages en même temps,
# verrou orphelin, verrou sans fiche, arrêt par le pid, CI, ancêtre.

# Vide en CI (aucun verrou), sinon dans le répertoire git commun.
if [ "${GITHUB_ACTIONS:-}" = true ]; then
  VERROU=""
else
  VERROU=${VERROU:-$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)/simulateur.verrou}
fi
VERROU_PAS=${VERROU_PAS:-5}
VERROU_TENU=0

# Le verrou est orphelin : le processus de sa fiche est mort, ou il n'a pas de fiche
# depuis plus d'une minute (son preneur est mort entre `mkdir` et la fiche). Jamais
# orphelin tant que son processus vit.
verrou_orphelin() {
  local p
  p=$(cat "$VERROU/pid" 2>/dev/null)
  if [ -n "$p" ]; then
    ! kill -0 "$p" 2>/dev/null
    return
  fi
  [ -n "$(find "$VERROU" -maxdepth 0 -mmin +1 2>/dev/null)" ]
}

# Le verrou est tenu par ce passage ou par un de ses ancêtres (un lanceur qui l'a
# pris pour lui) : il n'y a pas à l'attendre, ni à le rendre à sa place.
tenu_pour_moi() {
  local p=$$
  while [ -n "$p" ] && [ "$p" -gt 1 ]; do
    [ "$p" = "$1" ] && return 0
    p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
  done
  return 1
}

prendre_verrou() {
  [ -n "$VERROU" ] || return 0
  local debut=$SECONDS dit=-300 p
  until mkdir "$VERROU" 2>/dev/null; do
    # Un verrou qui ne peut pas se poser (hors d'un dépôt git, répertoire disparu ou
    # fermé à l'écriture) ne s'attend pas : personne ne le rendrait.
    if [ ! -d "$VERROU" ] && { [ "$VERROU" = /simulateur.verrou ] || [ ! -w "$(dirname "$VERROU")" ]; }; then
      echo "❓ INCONNU : le verrou du simulateur ne se pose pas ($VERROU) — aucun test joué." >&2
      return 2
    fi
    p=$(cat "$VERROU/pid" 2>/dev/null)
    if [ -n "$p" ] && tenu_pour_moi "$p"; then
      echo "🔒 simulateur déjà pris pour ce passage par $(cat "$VERROU/qui" 2>/dev/null || echo '?') (pid $p)" >&2
      return 0
    fi
    # La reprise se fait à un seul à la fois, et l'orphelin se rejuge dedans : deux
    # attentes qui voient le même mort ne retirent pas le verrou repris par l'autre.
    if verrou_orphelin && mkdir "$VERROU.reprise" 2>/dev/null; then
      if verrou_orphelin; then
        echo "🔓 verrou orphelin repris (pid ${p:-sans fiche}, mort)" >&2
        rm -rf "$VERROU"
      fi
      rmdir "$VERROU.reprise"
      continue
    fi
    # Une reprise restée en plan (son auteur est mort dedans) ne bloque pas les suivantes.
    find "$VERROU.reprise" -maxdepth 0 -mmin +1 -exec rmdir {} \; 2>/dev/null
    if [ $((SECONDS - dit)) -ge 300 ]; then
      echo "⏳ simulateur pris par $(cat "$VERROU/qui" 2>/dev/null || echo '?') (pid ${p:-?})" \
        "depuis $(cat "$VERROU/depuis" 2>/dev/null || echo '?') — j'attends mon tour" >&2
      dit=$SECONDS
    fi
    sleep "$VERROU_PAS"
  done
  echo $$ > "$VERROU/pid"
  echo "${VERROU_QUI:-$(basename "$PWD") ($(git branch --show-current 2>/dev/null))}" > "$VERROU/qui"
  date -u +%FT%TZ > "$VERROU/depuis"
  VERROU_TENU=1
  echo "🔒 simulateur pris par $(cat "$VERROU/qui") (pid $$, après $((SECONDS - debut)) s d'attente)" >&2
}

# Rendu par celui qui le tient, et par lui seul.
rendre_verrou() {
  if [ "$VERROU_TENU" = 1 ] && [ "$(cat "$VERROU/pid" 2>/dev/null)" = "$$" ]; then
    rm -rf "$VERROU"
  fi
}
