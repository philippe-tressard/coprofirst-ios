#!/bin/bash
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
#
# generer-projet.sh — CoproFirst.xcodeproj depuis project.yml (XcodeGen), puis les
# versions des paquets figées.
#
# Le projet généré n'est pas versionné, donc son Package.resolved non plus : sans
# la copie ci-dessous, chaque génération résoudrait les dépendances TRANSITIVES
# (swift-http-types, swift-collections…) à leur dernière version. La seule liste
# figée est Paquets/ClientAPI/Package.resolved — l'app n'a pas d'autre paquet.
set -euo pipefail
cd "$(dirname "$0")/.."

source outillage.env
VERSION=$(xcodegen --version | awk '{print $2}')
if [ "$VERSION" != "$XCODEGEN_VERSION" ]; then
  echo "❌ XcodeGen $VERSION, attendu $XCODEGEN_VERSION (outillage.env)" >&2
  exit 1
fi

# Sans ses préréglages, XcodeGen ne fait qu'avertir — et produit un projet dont les
# cibles de test n'ont pas de nom. L'avertissement est donc un refus.
SORTIE=$(xcodegen generate 2>&1)
if grep -q 'settings found' <<< "$SORTIE"; then
  echo "$SORTIE" >&2
  echo "❌ XcodeGen n'a pas trouvé ses préréglages (SettingPresets) : installation incomplète ou appel par un lien" >&2
  exit 1
fi
SWIFTPM=CoproFirst.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
mkdir -p "$SWIFTPM"
cp Paquets/ClientAPI/Package.resolved "$SWIFTPM/Package.resolved"
echo "✅ CoproFirst.xcodeproj généré (XcodeGen $VERSION), versions figées"
