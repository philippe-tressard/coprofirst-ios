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
set -uo pipefail
cd "$(dirname "$0")/.."
LISTE=$(xcrun simctl list devices available -j) \
  || { echo "❓ INCONNU : simctl ne liste pas les simulateurs" >&2; exit 2; }
UDID=$(python3 -I scripts/destination_simulateur.py <<< "$LISTE") || exit $?
echo "platform=iOS Simulator,id=$UDID"
