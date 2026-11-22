<!--
SPDX-FileCopyrightText: 2026 Philippe TRESSARD
SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
-->

# Provenance de `openapi.json`

GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.

| | |
|---|---|
| Source | philippe-tressard/coprofirst v3.121.2 (commit ac4f80f6ad5c8e861e61bd892c27d129025f80fa), pièce jointe `openapi.json` de la release |
| Commit | `ac4f80f6ad5c8e861e61bd892c27d129025f80fa` (`v3.121.2`) |
| Version du contrat | `2.10.0` (`info.version` du contrat publié, servie par chaque installation en `version_contrat` de `GET /config`) |
| Préfixe servi | `/api` : les chemins du schéma s'entendent sous `https://<hôte>/api` |
| Normalisation | `anyOf: [X, null]` réécrit en `type: [X, "null"]` (`$ref` : nullabilité retirée) — le générateur supprimait ces champs ; paramètres `in: cookie` retirés — iOS envoie les cookies de session seul |
| Au-dessus du plancher | aucune route |
