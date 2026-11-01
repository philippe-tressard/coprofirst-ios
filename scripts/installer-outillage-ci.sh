#!/bin/bash
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
#
# installer-outillage-ci.sh — XcodeGen et SwiftLint pour la CI, aux versions
# d'outillage.env, empreinte SHA-256 vérifiée avant tout usage. Homebrew n'épingle
# pas une version : sur le runner, il installerait la dernière, et la CI jugerait
# avec un autre outil que le poste.
#
# Les empreintes sont celles que GitHub publie pour chaque fichier de la release
# (champ `digest` de l'API) ; une montée de version les change dans ce fichier.
set -euo pipefail
cd "$(dirname "$0")/.."
source outillage.env

XCODEGEN_SHA256=4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806
SWIFTLINT_SHA256=c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0

OUTILS=${OUTILS_CI:-$HOME/outils-ci}
mkdir -p "$OUTILS/bin"
TRAVAIL=$(mktemp -d)
trap 'rm -rf "$TRAVAIL"' EXIT

telecharger() { # url empreinte destination
  curl -fsSL --retry 3 -o "$3" "$1"
  echo "$2  $3" | shasum -a 256 -c - >/dev/null \
    || { echo "❌ empreinte inattendue : $1" >&2; exit 1; }
}

telecharger "https://github.com/yonaskolb/XcodeGen/releases/download/$XCODEGEN_VERSION/xcodegen.zip" \
  "$XCODEGEN_SHA256" "$TRAVAIL/xcodegen.zip"
unzip -q "$TRAVAIL/xcodegen.zip" -d "$OUTILS"

telecharger "https://github.com/realm/SwiftLint/releases/download/$SWIFTLINT_VERSION/portable_swiftlint.zip" \
  "$SWIFTLINT_SHA256" "$TRAVAIL/swiftlint.zip"
unzip -q "$TRAVAIL/swiftlint.zip" -d "$OUTILS/swiftlint"
ln -sf "$OUTILS/swiftlint/swiftlint" "$OUTILS/bin/swiftlint"
ln -sf "$OUTILS/xcodegen/bin/xcodegen" "$OUTILS/bin/xcodegen"

[ -n "${GITHUB_PATH:-}" ] && echo "$OUTILS/bin" >> "$GITHUB_PATH"
"$OUTILS/bin/xcodegen" --version
"$OUTILS/bin/swiftlint" version
