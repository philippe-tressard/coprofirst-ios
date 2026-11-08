<!--
SPDX-FileCopyrightText: 2026 Philippe TRESSARD
SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
-->

# Provenance de `openapi.json`

GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.

| | |
|---|---|
| Source | philippe-tressard/coprofirst v3.73.0 (commit de78b44da68b31e8e256ff1ef80e4507ac49d24b), pièce jointe `openapi.json` de la release |
| Commit | `de78b44da68b31e8e256ff1ef80e4507ac49d24b` (`v3.73.0`) |
| Version du contrat | `1.12.0` (`API_VERSION` de `api/app/main.py`) |
| Préfixe servi | `/api` : les chemins du schéma s'entendent sous `https://<hôte>/api` |
| Normalisation | `anyOf: [X, null]` réécrit en `type: [X, "null"]` (`$ref` : nullabilité retirée) — le générateur supprimait ces champs ; paramètres `in: cookie` retirés — iOS envoie les cookies de session seul |
