#!/bin/bash
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
#
# env-report.sh — l'état VIVANT du projet au démarrage de session. L'étiquette, la
# banque de mémoire et les garde-fous, le hook global les affiche déjà depuis
# ~/.claude/projets.json : ils ne se recopient pas ici (skill nouveau-projet §2).
set -uo pipefail
ATTENDU="/Volumes/Data/Dev/CoproFirst-iOS"
COURANT=$(pwd)
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
if [ "$COURANT" != "$ATTENDU" ]; then
  echo "  ⚠️  RÉPERTOIRE INATTENDU (attendu $ATTENDU) — signale-le à l'utilisateur"
  echo "      AVANT d'agir : mémoires et étiquette partiront au mauvais endroit."
fi
echo "  → Reprends cette ligne en tête de ta 1ʳᵉ réponse."
echo "════════════════════════════════════════════════════════"
