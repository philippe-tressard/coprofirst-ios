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
#   Sans argument : $COPROFIRST_RACINE/api — le clone de coprofirst du poste
#   (défaut : /Volumes/Data/Dev/5hostachy).
#
# - Python : un venv À SOI (~/.cache/coprofirst-ios/venv-openapi), sur le Python
#   3.12 de Homebrew — celui de l'image de l'API —, jamais le Python du poste.
# - Aucune base : `app.openapi()` ne s'y connecte pas. DATABASE_URL désigne une
#   adresse injoignable, exprès : une base ouverte par un process tiers est
#   interdite (standards/06 §1).
# - Écrit aussi PROVENANCE-OPENAPI.md : commit et version du contrat d'origine.
set -euo pipefail

RACINE=$(cd "$(dirname "$0")/.." && pwd)
API=${1:-${COPROFIRST_RACINE:-/Volumes/Data/Dev/5hostachy}/api}
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


def nullable(noeud):
    """`anyOf: [X, {type: null}]` → X rendu nullable (forme OpenAPI 3.1 `type: [t, "null"]`).

    FastAPI écrit ainsi tout champ `Optional[...]`, et swift-openapi-generator 1.14
    ne lit pas cette forme : il SUPPRIME le champ en silence (« Schema "null" is
    not supported, skipping ») — `TicketRead` y perdait `me_concerne`,
    `perimetre_cible`, `auteur_nom`… Pour une référence (`$ref`), la nullabilité
    tombe : un champ facultatif absent ou `null` se décode en `nil` de toute façon.
    """
    if isinstance(noeud, list):
        return [nullable(n) for n in noeud]
    if not isinstance(noeud, dict):
        return noeud
    noeud = {cle: nullable(valeur) for cle, valeur in noeud.items()}
    branches = noeud.get("anyOf")
    if isinstance(branches, list) and {"type": "null"} in branches:
        autres = [b for b in branches if b != {"type": "null"}]
        if len(autres) == 1:
            seule = dict(autres[0])
            if isinstance(seule.get("type"), str):
                seule["type"] = [seule["type"], "null"]
            reste = {cle: valeur for cle, valeur in noeud.items() if cle != "anyOf"}
            return {**seule, **reste} if "$ref" not in seule else seule
    return noeud


def sans_cookies(schema):
    """Retire les paramètres `in: cookie` de chaque route (#26).

    Le serveur déclare ses cookies de session (`access_token`, `refresh_token`)
    comme paramètres de chaque route ; swift-openapi-generator ne sait pas les
    générer et le dit ~390 fois au build (« Cookie params is not supported »),
    noyant les avertissements qui comptent. L'app n'a pas à les passer : iOS
    (`URLSession` et son stockage de cookies) les envoie seul. Le contrat publié
    par le serveur n'est pas touché ; seule la copie de l'app l'est.
    """
    for chemin in schema.get("paths", {}).values():
        for cible in [chemin, *(o for o in chemin.values() if isinstance(o, dict))]:
            if "parameters" in cible:
                gardes = [p for p in cible["parameters"] if p.get("in") != "cookie"]
                if gardes:
                    cible["parameters"] = gardes
                else:
                    del cible["parameters"]
    return schema


schema = sans_cookies(nullable(schema))
with open(sys.argv[2], "w", encoding="utf-8", newline="\n") as f:
    json.dump(schema, f, ensure_ascii=False, indent=2, sort_keys=True)
    f.write("\n")
print(f"{schema['openapi']} — {len(schema['paths'])} chemins, contrat {schema['info']['version']}")
PY
)

mv "$TRAVAIL/openapi.json" "$CIBLE"
DEPOT=$(git -C "$API" rev-parse --show-toplevel)
COMMIT=$(git -C "$DEPOT" rev-parse HEAD)
# Une branche, sinon l'étiquette exacte (un clone d'une release est détaché).
BRANCHE=$(git -C "$DEPOT" branch --show-current)
[ -n "$BRANCHE" ] || BRANCHE=$(git -C "$DEPOT" describe --tags --exact-match 2>/dev/null || echo "détaché")
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
| Commit | \`$COMMIT\` (\`$BRANCHE\`)$([ -n "$SALE" ] && echo " — ⚠️ arbre de travail MODIFIÉ") |
| Version du contrat | \`$CONTRAT\` (\`API_VERSION\` de \`api/app/main.py\`) |
| Préfixe servi | \`/api\` : les chemins du schéma s'entendent sous \`https://<hôte>/api\` |
| Normalisation | \`anyOf: [X, null]\` réécrit en \`type: [X, "null"]\` (\`\$ref\` : nullabilité retirée) — le générateur supprimait ces champs ; paramètres \`in: cookie\` retirés — iOS envoie les cookies de session seul |

Provisoire : coprofirst#2456 publiera le contrat ; ce fichier viendra alors de là.
EOF
echo "✅ $CIBLE"
echo "   depuis $COMMIT ($BRANCHE)"
