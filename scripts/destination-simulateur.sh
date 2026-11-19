#!/bin/bash
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
#
# destination-simulateur.sh — imprime la destination xcodebuild du simulateur des
# tests (`platform=iOS Simulator,id=<udid>`), et dit lequel sur la sortie d'erreur.
# Le choix — un iPhone de série du runtime iOS standard le plus récent, le même d'un
# passage à l'autre — et son autotest vivent dans scripts/destination_simulateur.py.
# Un choix impossible, ou une liste qui ne se lit pas : INCONNU (sortie 2), jamais un
# appareil au hasard — un test qui ne peut pas tourner n'est pas vert (#112).
# `--ipad` : un iPad Pro 13 pouces de série à la place de l'iPhone (#220) ; `--tv` : une
# Apple TV 4K de série, pour l'écran de hall (#218), sous `platform=tvOS Simulator`.
# `--os X.Y`, après l'appareil : ce système et lui seul (#287) — tests-simulateur.sh le passe
# avec `OS_SIMULATEUR`.
set -uo pipefail
cd "$(dirname "$0")/.."
LISTE=$(xcrun simctl list devices available -j) \
  || { echo "❓ INCONNU : simctl ne liste pas les simulateurs" >&2; exit 2; }
UDID=$(python3 -I scripts/destination_simulateur.py "$@" <<< "$LISTE") || exit $?
PLATEFORME=iOS
[ "${1:-}" = --tv ] && PLATEFORME=tvOS
[ "${1:-}" = --montre ] && PLATEFORME=watchOS
echo "platform=$PLATEFORME Simulator,id=$UDID"
