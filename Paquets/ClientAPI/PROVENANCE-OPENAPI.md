<!--
SPDX-FileCopyrightText: 2026 Philippe TRESSARD
SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
-->

# Provenance de `openapi.json`

GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.

| | |
|---|---|
| Source | philippe-tressard/coprofirst v3.126.10 (commit 803696b615c922d3c0b93f69e2c81c6fa44c3e4c), pièce jointe `openapi.json` de la release |
| Commit | `803696b615c922d3c0b93f69e2c81c6fa44c3e4c` (`v3.126.10`) |
| Version du contrat | `2.14.0` (`info.version` du contrat publié, servie par chaque installation en `version_contrat` de `GET /config`) |
| Préfixe servi | `/api` : les chemins du schéma s'entendent sous `https://<hôte>/api` |
| Normalisation | `anyOf: [X, null]` réécrit en `type: [X, "null"]` (`$ref` : nullabilité retirée) — le générateur supprimait ces champs ; paramètres `in: cookie` retirés — iOS envoie les cookies de session seul |
| Au-dessus du plancher | `/tickets/{ticket_id}/agenda` et `AgendaServi`, `LiensAgenda`, de v3.128.0 (contrat 2.15.0) — porte `VersionContrat.agenda` |
