<!--
SPDX-FileCopyrightText: 2026 Philippe TRESSARD
SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
-->

# Provenance de `openapi.json`

GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.

| | |
|---|---|
| Source | philippe-tressard/coprofirst v3.101.0 (commit e6e8ecdbbd269ccb2b25081a0c12828176047a5c), pièce jointe `openapi.json` de la release |
| Commit | `e6e8ecdbbd269ccb2b25081a0c12828176047a5c` (`v3.101.0`) |
| Version du contrat | `2.0.0` (`version` de `api/app/contrat/reference.json`, servie par chaque installation en `version_contrat` de `GET /config`) |
| Préfixe servi | `/api` : les chemins du schéma s'entendent sous `https://<hôte>/api` |
| Normalisation | `anyOf: [X, null]` réécrit en `type: [X, "null"]` (`$ref` : nullabilité retirée) — le générateur supprimait ces champs ; paramètres `in: cookie` retirés — iOS envoie les cookies de session seul |
