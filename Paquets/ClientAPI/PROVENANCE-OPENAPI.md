<!--
SPDX-FileCopyrightText: 2026 Philippe TRESSARD
SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
-->

# Provenance de `openapi.json`

Écrit par `scripts/generer-openapi.sh` — ne pas modifier à la main.

| | |
|---|---|
| Source | `philippe-tressard/coprofirst`, dossier `api/`, par `app.openapi()` |
| Commit | `14fec7b6ba683cd74161d874e48a47f2d007ff5f` (`v3.66.0`) |
| Version du contrat | `1.5.0` (`API_VERSION` de `api/app/main.py`) |
| Préfixe servi | `/api` : les chemins du schéma s'entendent sous `https://<hôte>/api` |
| Normalisation | `anyOf: [X, null]` réécrit en `type: [X, "null"]` (`$ref` : nullabilité retirée) — le générateur supprimait ces champs ; paramètres `in: cookie` retirés — iOS envoie les cookies de session seul |

Provisoire : coprofirst#2456 publiera le contrat ; ce fichier viendra alors de là.
