<!--
SPDX-FileCopyrightText: 2026 Philippe TRESSARD
SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
-->

# Provenance de `openapi.json`

Écrit par `scripts/generer-openapi.sh` — ne pas modifier à la main.

| | |
|---|---|
| Source | `philippe-tressard/coprofirst`, dossier `api/`, par `app.openapi()` |
| Commit | `4239610fcf1658b53c84664087f7e5d0650fe834` (`v3.61.0`) |
| Version du contrat | `1.2.0` (`API_VERSION` de `api/app/main.py`) |
| Préfixe servi | `/api` : les chemins du schéma s'entendent sous `https://<hôte>/api` |
| Normalisation | `anyOf: [X, null]` réécrit en `type: [X, "null"]` (`$ref` : nullabilité retirée) — le générateur supprimait ces champs |

Provisoire : coprofirst#2456 publiera le contrat ; ce fichier viendra alors de là.
