#!/bin/bash
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
#
# generer-openapi.sh — produit Paquets/ClientAPI/Sources/ClientAPI/openapi.json
# depuis le code de l'API de coprofirst, en attendant que coprofirst publie son
# contrat (coprofirst#2456). Le jour où il est publié, ce script se remplace par
# un téléchargement du fichier publié, et le client ne lit plus que lui.
#
# Usage : bash scripts/generer-openapi.sh [chemin/vers/coprofirst/api]
#
# - Python : un venv À SOI (~/.cache/coprofirst-ios/venv-openapi), sur le Python
#   3.12 de Homebrew — celui de l'image de l'API —, jamais le Python du poste.
# - Aucune base : `app.openapi()` ne s'y connecte pas. DATABASE_URL désigne une
#   adresse injoignable, exprès : une base ouverte par un process tiers est
#   interdite (standards/06 §1).
# - Écrit aussi PROVENANCE-OPENAPI.md : commit et version du contrat d'origine.
set -euo pipefail

RACINE=$(cd "$(dirname "$0")/.." && pwd)
API=${1:-/Volumes/Data/Dev/5hostachy/api}
PYTHON=${PYTHON_OPENAPI:-/opt/homebrew/bin/python3.12}
VENV="$HOME/.cache/coprofirst-ios/venv-openapi"
CIBLE="$RACINE/Paquets/ClientAPI/Sources/ClientAPI/openapi.json"
PROVENANCE="$RACINE/Paquets/ClientAPI/PROVENANCE-OPENAPI.md"

[ -f "$API/app/main.py" ] || { echo "❌ API introuvable : $API/app/main.py" >&2; exit 1; }
[ -x "$PYTHON" ] || { echo "❌ Python introuvable : $PYTHON (brew install python@3.12)" >&2; exit 1; }

if [ ! -x "$VENV/bin/python" ]; then
  mkdir -p "$(dirname "$VENV")"
  "$PYTHON" -m venv "$VENV"
fi
"$VENV/bin/pip" install -q --disable-pip-version-check -r "$API/requirements.txt"

TRAVAIL=$(mktemp -d)
trap 'rm -rf "$TRAVAIL"' EXIT

# Lancé depuis un dossier vide, en mode isolé (-I) : rien du répertoire courant
# ne s'importe à la place d'un module de l'API.
(
  cd "$TRAVAIL"
  SECRET_KEY=$(openssl rand -hex 32) \
  ENABLE_API_DOCS=true \
  DATABASE_URL="postgresql+psycopg://aucun@127.0.0.1:1/aucune" \
  UPLOADS_DIR="$TRAVAIL/uploads" \
  CACHE_MANUEL_DIR="" \
  "$VENV/bin/python" -I - "$API" "$TRAVAIL/openapi.json" <<'PY'
import json
import sys

sys.path.insert(0, sys.argv[1])
from app.main import app  # noqa: E402

schema = app.openapi()
with open(sys.argv[2], "w", encoding="utf-8", newline="\n") as f:
    json.dump(schema, f, ensure_ascii=False, indent=2, sort_keys=True)
    f.write("\n")
print(f"{schema['openapi']} — {len(schema['paths'])} chemins, contrat {schema['info']['version']}")
PY
)

mv "$TRAVAIL/openapi.json" "$CIBLE"
DEPOT=$(git -C "$API" rev-parse --show-toplevel)
COMMIT=$(git -C "$DEPOT" rev-parse HEAD)
BRANCHE=$(git -C "$DEPOT" branch --show-current)
SALE=$(git -C "$DEPOT" status --porcelain -- api | head -1)
CONTRAT=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["info"]["version"])' "$CIBLE")

cat > "$PROVENANCE" <<EOF
<!--
SPDX-FileCopyrightText: 2026 Philippe TRESSARD
SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
-->

# Provenance de \`openapi.json\`

Écrit par \`scripts/generer-openapi.sh\` — ne pas modifier à la main.

| | |
|---|---|
| Source | \`philippe-tressard/coprofirst\`, dossier \`api/\`, par \`app.openapi()\` |
| Commit | \`$COMMIT\` (branche \`$BRANCHE\`)$([ -n "$SALE" ] && echo " — ⚠️ arbre de travail MODIFIÉ") |
| Version du contrat | \`$CONTRAT\` (\`API_VERSION\` de \`api/app/main.py\`) |
| Préfixe servi | \`/api\` : les chemins du schéma s'entendent sous \`https://<hôte>/api\` |

Provisoire : coprofirst#2456 publiera le contrat ; ce fichier viendra alors de là.
EOF
echo "✅ $CIBLE"
echo "   depuis $COMMIT ($BRANCHE)"
