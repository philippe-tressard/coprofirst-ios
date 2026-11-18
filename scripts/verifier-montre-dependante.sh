#!/bin/bash
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
#
# verifier-montre-dependante.sh — l'app Apple Watch LIVRÉE est dépendante de l'iPhone (#226).
#
# `project.yml` la déclare dépendante (`WKRunsIndependentlyOfCompanionApp: false`, comme la
# montre Wear OS, `standalone=false`) ; une étape de build la déclare indépendante en Debug
# SEULEMENT, pour le simulateur sans iPhone jumelé. Cet écart Debug/Release se garde ici, sur
# ce qui est CONSTRUIT : l'app est construite en Release, et son Info.plist doit porter la clé
# à `false` — absente, `true` ou illisible, le contrôle échoue.
#
#   bash scripts/verifier-montre-dependante.sh              construit en Release, puis lit
#   bash scripts/verifier-montre-dependante.sh <Info.plist> lit un Info.plist déjà construit
#   bash scripts/verifier-montre-dependante.sh --autotest   un Release sabordé doit rougir
#
# Sorties : 0 dépendante ; 1 indépendante (ou clé absente) ; 2 INCONNU (build ou lecture).
set -uo pipefail
cd "$(dirname "$0")/.."

CLE=WKRunsIndependentlyOfCompanionApp

# La clé, lue par plistlib et non par PlistBuddy : l'autotest tourne aussi dans le job « Dépôt »,
# sous Linux, où PlistBuddy n'existe pas (#226). Imprime true, false, une autre valeur, ou rien
# si la clé manque ; sort en 1 si le fichier n'est pas une liste de propriétés lisible.
lire_cle() {
  python3 -I -c '
import plistlib, sys
try:
    with open(sys.argv[1], "rb") as f:
        valeur = plistlib.load(f).get(sys.argv[2])
except Exception:
    sys.exit(1)
if valeur is not None:
    print(str(valeur).lower() if isinstance(valeur, bool) else valeur)
' "$1" "$CLE"
}

juger() {
  local plist=$1 valeur
  [ -f "$plist" ] || { echo "❓ INCONNU : aucun Info.plist construit ($plist)" >&2; return 2; }
  if ! valeur=$(lire_cle "$plist") || [ -z "$valeur" ]; then
    echo "❌ $CLE absente de l'Info.plist construit : l'app montre doit s'y dire dépendante ($plist)" >&2
    return 1
  fi
  if [ "$valeur" != false ]; then
    echo "❌ l'app montre construite en Release se dit indépendante ($CLE = $valeur) : elle doit rester dépendante de l'iPhone (#226)" >&2
    return 1
  fi
  echo "✅ app montre Release dépendante de l'iPhone ($CLE = false)"
}

# Un Info.plist d'essai : la clé à la valeur donnée (un booléen), ou absente.
ecrire_plist() {
  python3 -I -c '
import plistlib, sys
contenu = {"CFBundleIdentifier": "fr.coprofirst.app.watchkitapp"}
if sys.argv[2] != "absente":
    contenu[sys.argv[3]] = sys.argv[2] == "true"
with open(sys.argv[1], "wb") as f:
    plistlib.dump(contenu, f)
' "$1" "$2" "$CLE"
}

autotest() {
  local dossier rate=0 sortie
  dossier=$(mktemp -d)
  trap 'rm -rf "$dossier"' RETURN
  for cas in "false:0" "true:1" "absente:1" "corrompue:1" "illisible:2"; do
    local valeur=${cas%%:*} attendu=${cas##*:}
    local plist="$dossier/Info-$valeur.plist"
    case "$valeur" in
      illisible) plist="$dossier/inexistant.plist" ;;
      corrompue) printf 'pas une liste de propriétés' > "$plist" ;;
      *) ecrire_plist "$plist" "$valeur" ;;
    esac
    juger "$plist" >/dev/null 2>&1
    sortie=$?
    if [ "$sortie" != "$attendu" ]; then
      echo "❌ autotest, clé $valeur : sortie $sortie, attendu $attendu" >&2
      rate=1
    fi
  done
  [ "$rate" = 0 ] && echo "✅ verifier-montre-dependante : autotest"
  return $rate
}

case "${1:-}" in
  --autotest) autotest; exit $? ;;
  "") ;;
  *) juger "$1"; exit $? ;;
esac

# Construire l'app montre en Release, au simulateur (aucune signature) : sous le verrou commun
# du poste quand il existe, comme tout xcodebuild lancé à la main ; en CI, directement.
DERIVEES=.build/DerivedMontreRelease
COMMANDE=(xcodebuild build -project CoproFirst.xcodeproj -scheme CoproFirstWatch -configuration Release
  -destination 'generic/platform=watchOS Simulator' -derivedDataPath "$DERIVEES"
  -skipPackagePluginValidation -skipMacroValidation CODE_SIGNING_ALLOWED=NO)
VERROU=~/.claude/bin/verrou_poste.py
mkdir -p .build
if [ -z "${CI:-}" ] && [ -f "$VERROU" ]; then
  python3 "$VERROU" prendre --libelle "app montre en Release (#226)" -- "${COMMANDE[@]}" > .build/montre-release.log 2>&1
else
  "${COMMANDE[@]}" > .build/montre-release.log 2>&1
fi || { echo "❓ INCONNU : l'app montre ne se construit pas en Release (.build/montre-release.log)" >&2; exit 2; }
juger "$DERIVEES/Build/Products/Release-watchsimulator/CoproFirst.app/Info.plist"
