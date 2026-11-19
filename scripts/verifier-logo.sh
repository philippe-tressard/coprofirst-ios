#!/bin/bash
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
#
# verifier-logo.sh [ref] — la licence du logo et son dessin sont IDENTIQUES à ceux
# de coprofirst, lus sur GitHub à l'étiquette du PLANCHER par défaut
# (scripts/plancher.sh) : une version publiée, jamais une branche — `dev` y est
# supprimée à chaque mise en production, et la CI rougissait au hasard (#133).
# Une copie de licence est obligatoire, sa divergence ne l'est pas. L'icône est
# carrée, 1024 px, opaque. Sans réseau ou référence introuvable : INCONNU (sortie 2),
# jamais OK.
set -uo pipefail
cd "$(dirname "$0")/.."
REF=${1:-$(bash scripts/plancher.sh)} || exit 2
BRUT="https://raw.githubusercontent.com/philippe-tressard/coprofirst/$REF"
ICONE=CoproFirst/Ressources/Assets.xcassets/AppIcon.appiconset/icone-1024.png
ECHECS=0

comparer() { # chemin-local chemin-coprofirst
  local distant
  distant=$(mktemp)
  # Chaque tentative bornée à 20 s, nommée à l'expiration (#293) ; la borne de
  # controles-distants.sh coupe le reste.
  if ! curl -fsSL --retry 3 --max-time 20 -o "$distant" "$BRUT/$2"; then
    echo "❓ INCONNU : $2 illisible sur coprofirst@$REF (ou plus de 20 s par tentative)"
    rm -f "$distant"
    exit 2
  fi
  if cmp -s "$1" "$distant"; then
    echo "✅ $1 = coprofirst@$REF:$2"
  else
    echo "❌ $1 diverge de coprofirst@$REF:$2 — bash scripts/importer-logo.sh"
    ECHECS=$((ECHECS + 1))
  fi
  rm -f "$distant"
}

comparer LICENSES/LicenseRef-CoproFirst-Logo.txt LICENSES/LicenseRef-CoproFirst-Logo.txt
comparer CoproFirst/Ressources/Assets.xcassets/Logo.imageset/logo.svg front/static/favicon.svg

# L'en-tête PNG lu en Python, et non par `sips` (macOS seul) : le job « Dépôt » tourne sur
# Linux (#204). Largeur, hauteur, puis « sans alpha » : un type de couleur sans canal alpha
# (ni 4 ni 6) et aucun bloc tRNS. Un fichier qui n'est pas un PNG lisible : INCONNU.
dims=$(python3 -I - "$ICONE" <<'PY'
import struct, sys
d = open(sys.argv[1], "rb").read()
if d[:8] != b"\x89PNG\r\n\x1a\n" or d[12:16] != b"IHDR":
    sys.exit(2)
largeur, hauteur = struct.unpack(">II", d[16:24])
alpha, i = d[25] in (4, 6), 8
while i + 8 <= len(d):
    taille, nom = struct.unpack(">I4s", d[i:i + 8])
    alpha = alpha or nom == b"tRNS"
    i += 12 + taille
print(largeur, hauteur, "yes" if alpha else "no", end=" ")
PY
) || { echo "❓ INCONNU : $ICONE n'est pas un PNG lisible, icône non vérifiée"; exit 2; }
if [ "$dims" = "1024 1024 no " ]; then
  echo "✅ $ICONE : 1024×1024, opaque"
else
  echo "❌ $ICONE : $dims (attendu 1024 1024, sans alpha)"
  ECHECS=$((ECHECS + 1))
fi
[ "$ECHECS" -eq 0 ]
