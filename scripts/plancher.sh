#!/bin/bash
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
#
# plancher.sh — imprime l'étiquette du plancher (`VERSION` de
# scripts/generateurs/_plancher.py) : la version PUBLIÉE de coprofirst à laquelle un
# script shell lit ce qu'il compare ou recopie. Une étiquette ne disparaît pas ; une
# branche, si (`dev` de coprofirst est supprimée à chaque mise en production, #133).
# Illisible ou mal formée : INCONNU (sortie 2), jamais une valeur par défaut.
set -uo pipefail
cd "$(dirname "$0")/.."
VERSION=$(python3 -I -c '
import sys
sys.path.insert(0, "scripts/generateurs")
import _plancher
print(_plancher.VERSION)
' 2>/dev/null) || VERSION=""
if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❓ INCONNU : plancher illisible (scripts/generateurs/_plancher.py)" >&2
  exit 2
fi
echo "$VERSION"
