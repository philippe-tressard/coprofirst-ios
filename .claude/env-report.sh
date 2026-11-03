#!/bin/bash
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
#
# env-report.sh — l'état VIVANT du projet au démarrage de session. L'étiquette, la
# banque de mémoire et les garde-fous, le hook global les affiche déjà depuis
# ~/.claude/projets.json : ils ne se recopient pas ici (skill nouveau-projet §2).
set -uo pipefail
# Le répertoire attendu se lit au registre des projets — jamais écrit ici : il dit la
# disposition du disque du poste, et un dépôt public n'a pas à la publier.
ATTENDU=$(python3 -c 'import json, os, sys
d = json.load(open(os.path.expanduser("~/.claude/projets.json")))
for p in (d.get("projets", d) if isinstance(d, dict) else d):
    if p.get("nom") == "CoproFirst-iOS":
        print(p.get("repertoire", {}).get("macos", ""))' 2>/dev/null)
COURANT=$(pwd)
# Un worktree de session (.claude/worktrees/…) appartient au projet.
case "$COURANT" in "$ATTENDU"/.claude/worktrees/*) COURANT=$ATTENDU ;; esac
echo "═══════════════ ENVIRONNEMENT DE TRAVAIL ═══════════════"
echo "  Répertoire    : $COURANT"
echo "  Dépôt/branche : $(git config --get remote.origin.url 2>/dev/null || echo 'aucun dépôt distant') [$(git branch --show-current 2>/dev/null)]"
[ "$(git config --get core.hooksPath 2>/dev/null)" = ".githooks" ] \
  && echo "  Hook pre-commit : armé" \
  || echo "  Hook pre-commit : 🔴 NON ARMÉ — git config core.hooksPath .githooks"
source outillage.env 2>/dev/null
for outil in xcodegen swiftlint swift-format; do
  command -v "$outil" >/dev/null || echo "  Outillage     : 🔴 $outil absent (brew install $outil)"
done
if xcrun simctl list runtimes 2>/dev/null | grep -q '^iOS'; then
  echo "  Simulateur    : $(xcrun simctl list runtimes | grep '^iOS' | tail -1 | cut -d' ' -f1-2)"
else
  echo "  Simulateur    : 🔴 aucun runtime iOS — xcodebuild -downloadPlatform iOS"
fi
echo "  Contrat d'API : $(sed -n 's/^| Commit | `\([0-9a-f]\{9\}\).*/coprofirst@\1/p' Paquets/ClientAPI/PROVENANCE-OPENAPI.md 2>/dev/null)"
if [ -z "$ATTENDU" ]; then
  echo "  Répertoire attendu : ❓ INCONNU (registre ~/.claude/projets.json illisible)"
elif [ "$COURANT" != "$ATTENDU" ]; then
  echo "  ⚠️  RÉPERTOIRE INATTENDU (attendu $ATTENDU) — signale-le à l'utilisateur"
  echo "      AVANT d'agir : mémoires et étiquette partiront au mauvais endroit."
fi
echo "  → Reprends cette ligne en tête de ta 1ʳᵉ réponse."
echo "════════════════════════════════════════════════════════"
