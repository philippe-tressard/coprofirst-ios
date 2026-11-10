<!--
SPDX-FileCopyrightText: 2026 Philippe TRESSARD
SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
-->

# Provenance de `openapi.json`

GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.

| | |
|---|---|
| Source | philippe-tressard/coprofirst v3.76.0 (commit 92633e233a414f3d20d189055d71ea62a0b36b41), pièce jointe `openapi.json` de la release |
| Commit | `92633e233a414f3d20d189055d71ea62a0b36b41` (`v3.76.0`) |
| Version du contrat | `1.14.0` (`version` de `api/app/contrat/reference.json`, servie par chaque installation en `version_contrat` de `GET /config`) |
| Préfixe servi | `/api` : les chemins du schéma s'entendent sous `https://<hôte>/api` |
| Normalisation | `anyOf: [X, null]` réécrit en `type: [X, "null"]` (`$ref` : nullabilité retirée) — le générateur supprimait ces champs ; paramètres `in: cookie` retirés — iOS envoie les cookies de session seul |
