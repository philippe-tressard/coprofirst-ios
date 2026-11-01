#!/bin/bash
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
#
# destination-simulateur.sh — imprime la destination xcodebuild du premier iPhone
# disponible (`platform=iOS Simulator,id=<udid>`). Les noms d'appareils changent
# d'une image de runner à l'autre : on ne les écrit pas en dur.
# Aucun iPhone → sortie non nulle : un test qui ne peut pas tourner n'est pas vert.
set -euo pipefail
UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
appareils = json.load(sys.stdin)["devices"]
for runtime in sorted(appareils, reverse=True):
    if ".iOS-" not in runtime:
        continue
    for a in appareils[runtime]:
        if a["name"].startswith("iPhone"):
            print(a["udid"])
            sys.exit(0)
sys.exit(1)
') || { echo "❌ aucun simulateur iPhone disponible (xcodebuild -downloadPlatform iOS)" >&2; exit 1; }
echo "platform=iOS Simulator,id=$UDID"
