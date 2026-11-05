# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Le CONTRAT d'API : `openapi.json`, la pièce jointe de la release de coprofirst
(coprofirst#2456), normalisée pour swift-openapi-generator
→ `Paquets/ClientAPI/Sources/ClientAPI/openapi.json` et `PROVENANCE-OPENAPI.md`.

Le client se génère depuis ce fichier à chaque build ; aucune route ne s'écrit à la
main. Seule la copie de l'app est normalisée, jamais le contrat publié.
"""

from __future__ import annotations

import json
import pathlib

SOURCES: list[str] = []
PIECES_JOINTES = ["openapi.json"]

CLIENT = pathlib.Path("Paquets/ClientAPI")
CONTRAT = CLIENT / "Sources" / "ClientAPI" / "openapi.json"


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


def sans_cookies(schema: dict) -> dict:
    """Retire les paramètres `in: cookie` de chaque route (#26).

    Le serveur déclare ses cookies de session (`access_token`, `refresh_token`)
    comme paramètres de chaque route ; swift-openapi-generator ne sait pas les
    générer et le dit ~390 fois au build (« Cookie params is not supported »),
    noyant les avertissements qui comptent. L'app n'a pas à les passer : iOS
    (`URLSession` et son stockage de cookies) les envoie seul.
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


# Le fichier que le script ÉCRIT : une chaîne, pas la déclaration de ce module.
# REUSE-IgnoreStart
def provenance(ctx, contrat: str) -> str:
    return f"""<!--
SPDX-FileCopyrightText: 2026 Philippe TRESSARD
SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
-->

# Provenance de `openapi.json`

GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.

| | |
|---|---|
| Source | {ctx.provenance}, pièce jointe `openapi.json` de la release |
| Commit | `{ctx.commit}` (`{ctx.version.etiquette}`) |
| Version du contrat | `{contrat}` (`API_VERSION` de `api/app/main.py`) |
| Préfixe servi | `/api` : les chemins du schéma s'entendent sous `https://<hôte>/api` |
| Normalisation | `anyOf: [X, null]` réécrit en `type: [X, "null"]` (`$ref` : nullabilité retirée) — le générateur supprimait ces champs ; paramètres `in: cookie` retirés — iOS envoie les cookies de session seul |
"""
# REUSE-IgnoreEnd


def generer(ctx) -> str:
    try:
        schema = json.loads(ctx.version.piece_jointe("openapi.json"))
        version = schema["info"]["version"]
    except (ValueError, KeyError, TypeError) as erreur:
        raise SystemExit(f"❌ openapi.json de {ctx.version.etiquette} illisible : {erreur}") from erreur
    schema = sans_cookies(nullable(schema))
    ctx.ecrire(CONTRAT, json.dumps(schema, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    ctx.ecrire(CLIENT / "PROVENANCE-OPENAPI.md", provenance(ctx, version))
    return f"contrat {version}, {len(schema.get('paths', {}))} chemins"
