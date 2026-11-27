#!/bin/bash
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
#
# verifier-archive-montre.sh — l'archive de l'app iPhone EMBARQUE l'app Apple Watch (#324).
#
# L'app montre n'entre dans l'app iPhone qu'à l'archive (`ARCHIVE_AVEC_MONTRE=true`,
# project-archive.yml). Le 20/11/2026, ce chemin n'avait jamais été joué : le fichier
# inclus manquait, puis le build commun iPhone + montre échouait (« Multiple commands
# produce », le greffon OpenAPI lancé deux fois dans le même dossier). Ce contrôle refait
# l'archive, sans signature, et juge ce qu'elle contient :
#   1. le projet se génère avec la montre ;
#   2. l'archive Release se construit ;
#   3. elle contient Products/Applications/CoproFirst.app/Watch/CoproFirst.app ;
#   4. la montre EMBARQUÉE se dit dépendante de l'iPhone (verifier-montre-dependante.sh).
#   5. l'app iPhone et la montre embarquée ont chacune leur icône, compilée et nommée
#      (`Assets.car`, `CFBundleIconName`) : le 27/11/2026, App Store Connect a refusé la 1.2
#      (ITMS-90713, ITMS-90391), la montre n'ayant aucun catalogue d'images.
#
#   bash scripts/verifier-archive-montre.sh
#
# Sorties : 0 conforme ; 1 écart (génération, archive ou contenu) ; 2 INCONNU (outil absent).
# Au poste, l'archive passe sous le verrou commun (#255) et le projet est regénéré SANS la
# montre à la sortie, comme l'attendent les autres scripts.
set -uo pipefail
cd "$(dirname "$0")/.."

for outil in xcodegen xcodebuild; do
  command -v "$outil" >/dev/null || { echo "❓ INCONNU : $outil absent" >&2; exit 2; }
done

remettre_projet() { bash scripts/generer-projet.sh >/dev/null 2>&1 || echo "⚠️ projet non regénéré sans la montre : bash scripts/generer-projet.sh" >&2; }
[ -z "${CI:-}" ] && trap remettre_projet EXIT

mkdir -p .build
if ! ARCHIVE_AVEC_MONTRE=true bash scripts/generer-projet.sh > .build/archive-montre-projet.log 2>&1; then
  cat .build/archive-montre-projet.log >&2
  echo "❌ le projet ne se génère pas avec la montre embarquée (ARCHIVE_AVEC_MONTRE=true)" >&2
  exit 1
fi

# Ce qui se juge est l'assemblage (étapes du build, contenu de l'archive, Info.plist Release),
# pas l'optimisation : comme verifier-montre-dependante.sh, arm64 seul et sans -O, sinon le
# Release en -O dépassait le plafond du job (#292).
ARCHIVE=.build/ArchiveMontre/CoproFirst.xcarchive
rm -rf "$ARCHIVE"
COMMANDE=(xcodebuild archive -project CoproFirst.xcodeproj -scheme CoproFirst -configuration Release
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" -derivedDataPath .build/DerivedArchiveMontre
  -skipPackagePluginValidation -skipMacroValidation CODE_SIGNING_ALLOWED=NO
  ARCHS=arm64 SWIFT_OPTIMIZATION_LEVEL=-Onone SWIFT_COMPILATION_MODE=wholemodule)
VERROU=~/.claude/bin/verrou_poste.py
JOURNAL=.build/archive-montre.log
if [ -z "${CI:-}" ] && [ -f "$VERROU" ]; then
  python3 "$VERROU" prendre --libelle "archive iPhone + montre (#324)" -- "${COMMANDE[@]}" > "$JOURNAL" 2>&1
else
  "${COMMANDE[@]}" > "$JOURNAL" 2>&1
fi || {
  grep -E "error:" "$JOURNAL" | sort -u | head -10 >&2
  echo "❌ l'archive de l'app iPhone avec la montre ne se construit pas ($JOURNAL)" >&2
  exit 1
}

MONTRE="$ARCHIVE/Products/Applications/CoproFirst.app/Watch/CoproFirst.app"
if [ ! -d "$MONTRE" ]; then
  echo "❌ l'archive ne contient pas l'app montre ($MONTRE)" >&2
  exit 1
fi
echo "✅ archive iPhone avec la montre embarquée ($MONTRE)"
bash scripts/verifier-montre-dependante.sh "$MONTRE/Info.plist" || exit $?

for app in "$ARCHIVE/Products/Applications/CoproFirst.app" "$MONTRE"; do
  # watchOS la nomme à la racine ; iOS dans CFBundleIcons › CFBundlePrimaryIcon.
  icone=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' "$app/Info.plist" 2>/dev/null ||
    /usr/libexec/PlistBuddy -c 'Print :CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName' "$app/Info.plist" 2>/dev/null)
  if [ -z "$icone" ] || [ ! -f "$app/Assets.car" ]; then
    echo "❌ $app : sans icône compilée (CFBundleIconName « $icone », Assets.car $([ -f "$app/Assets.car" ] && echo présent || echo absent)) — App Store Connect refuse l'envoi (ITMS-90713)" >&2
    exit 1
  fi
done
echo "✅ icônes : l'app iPhone et la montre nomment chacune la leur (CFBundleIconName) dans leur Assets.car"
