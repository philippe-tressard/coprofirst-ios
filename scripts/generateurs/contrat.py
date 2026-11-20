# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Le CONTRAT d'API : `openapi.json`, la pièce jointe de la release de coprofirst
(coprofirst#2456), normalisée pour swift-openapi-generator
→ `Paquets/ClientAPI/Sources/ClientAPI/openapi.json` et `PROVENANCE-OPENAPI.md` ;
et la version de ce contrat → `CoproFirst/Session/ContratDuPlancher.swift`
(`VersionContrat.plancher`) : sous elle, la découverte dit que la résidence doit être
mise à jour (#83).

La version se lit dans ce que la release PUBLIE : `info.version` d'`openapi.json`, la
version que chaque installation sert en `version_contrat` (GET /config) — jamais dans les
sources de l'API (#237 ; `api/app/contrat/reference.json` la tenait, coprofirst la
recopie dans le contrat publié). Hors de X.Y.Z, la génération s'arrête (#86).

Le client se génère depuis ce fichier à chaque build ; aucune route ne s'écrit à la
main. Seule la copie de l'app est normalisée, jamais le contrat publié.

Une route servie AU-DESSUS du plancher (#286) se déclare dans `AU_DESSUS_DU_PLANCHER` :
elle se prend telle que la publie la release qui l'introduit, avec les schémas qu'elle
nomme, et s'AJOUTE au contrat du plancher — rien de ce qu'il porte ne change. L'app ne
l'appelle que derrière sa PORTE, générée ici dans `ContratDuPlancher.swift` à la version
du contrat de cette release : `installation.sert(.moderation)`.
"""

from __future__ import annotations

import json
import pathlib
import re

from generateurs import _plancher
from generateurs._source import Version

SOURCES: list[str] = []  # tout vient du contrat publié (#237)
PIECES_JOINTES = ["openapi.json"]

CLIENT = pathlib.Path("Paquets/ClientAPI")
CONTRAT = CLIENT / "Sources" / "ClientAPI" / "openapi.json"
PLANCHER_SWIFT = pathlib.Path("CoproFirst/Session/ContratDuPlancher.swift")
VERSION = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")

#: Les routes servies au-dessus du plancher, par PORTE : la release qui les publie, ce
#: qu'elles ouvrent, et leurs chemins. Le jour où le plancher les sert, la génération
#: échoue : la déclaration se retire, et la porte avec elle (comme `AuDessusDuPlancher`
#: pour un champ, #89).
AU_DESSUS_DU_PLANCHER = {
    "moderation": (
        "v3.118.0",
        "masquer ce que publie un résident, signaler une affaire, une suite ou la réponse de "
        "l'assistant (coprofirst#2861, #286)",
        ("/masquages", "/masquages/{auteur_id}"),
    ),
}


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


def schemas_nommes(noeud, schemas: dict, vus: set[str] | None = None) -> set[str]:
    """Les schémas que `noeud` nomme (`#/components/schemas/X`), et ceux qu'ils nomment."""
    vus = set() if vus is None else vus
    if isinstance(noeud, dict):
        ref = noeud.get("$ref")
        if isinstance(ref, str) and ref.startswith("#/components/schemas/"):
            nom = ref.rsplit("/", 1)[-1]
            if nom not in vus:
                vus.add(nom)
                schemas_nommes(schemas.get(nom), schemas, vus)
        for valeur in noeud.values():
            schemas_nommes(valeur, schemas, vus)
    elif isinstance(noeud, list):
        for valeur in noeud:
            schemas_nommes(valeur, schemas, vus)
    return vus


def ajouter_routes(base: dict, publie: dict, chemins, origine: str) -> list[str]:
    """Ajoute à `base` les `chemins` du contrat `publie` et les schémas qu'ils nomment.

    Ajout SEULEMENT : un chemin que `base` sert déjà, absent de `publie`, ou un schéma
    homonyme d'une autre forme arrête la génération — le client du plancher ne change
    jamais en silence. Rend les schémas ajoutés."""
    schemas = publie.get("components", {}).get("schemas", {})
    cibles = base.setdefault("components", {}).setdefault("schemas", {})
    ajoutes = []
    for chemin in chemins:
        if chemin in base.get("paths", {}):
            raise SystemExit(f"❌ {chemin} : le plancher le sert déjà — retirer sa déclaration "
                             "(AU_DESSUS_DU_PLANCHER) et sa porte")
        if chemin not in publie.get("paths", {}):
            raise SystemExit(f"❌ {chemin} : absent du contrat de {origine}")
        base["paths"][chemin] = publie["paths"][chemin]
        for nom in sorted(schemas_nommes(publie["paths"][chemin], schemas)):
            if nom not in schemas:
                raise SystemExit(f"❌ {chemin} nomme le schéma {nom}, absent du contrat de {origine}")
            if nom in cibles:
                if cibles[nom] != schemas[nom]:
                    raise SystemExit(f"❌ schéma {nom} : sa forme diffère entre le plancher et {origine}")
                continue
            cibles[nom] = schemas[nom]
            ajoutes.append(nom)
    return ajoutes


def autotest() -> None:
    """Un chemin déjà servi, absent ou un schéma qui change de forme sont refusés ; le reste s'ajoute."""
    publie = {"paths": {"/b": {"get": {"r": {"$ref": "#/components/schemas/B"}}}},
              "components": {"schemas": {"B": {"properties": {"c": {"$ref": "#/components/schemas/C"}}},
                                         "C": {"type": "string"}}}}
    base = {"paths": {"/a": {}}, "components": {"schemas": {"C": {"type": "string"}}}}
    if ajouter_routes(base, publie, ["/b"], "t") != ["B"] or "/b" not in base["paths"]:
        raise SystemExit("❌ autotest contrat : une route au-dessus du plancher ne s'ajoute pas")
    for cas, chemins in ((base, ["/b"]), ({"paths": {}}, ["/z"]),
                         ({"paths": {}, "components": {"schemas": {"C": {"type": "integer"}}}}, ["/b"])):
        try:
            ajouter_routes(json.loads(json.dumps(cas)), publie, chemins, "t")
        except SystemExit:
            continue
        raise SystemExit(f"❌ autotest contrat : {chemins} aurait dû être refusé")


# Le fichier que le script ÉCRIT : une chaîne, pas la déclaration de ce module.
# REUSE-IgnoreStart
def provenance(ctx, contrat: str, ajouts: list[str]) -> str:
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
| Version du contrat | `{contrat}` (`info.version` du contrat publié, servie par chaque installation en `version_contrat` de `GET /config`) |
| Préfixe servi | `/api` : les chemins du schéma s'entendent sous `https://<hôte>/api` |
| Normalisation | `anyOf: [X, null]` réécrit en `type: [X, "null"]` (`$ref` : nullabilité retirée) — le générateur supprimait ces champs ; paramètres `in: cookie` retirés — iOS envoie les cookies de session seul |
| Au-dessus du plancher | {"<br>".join(ajouts) or "aucune route"} |
"""
# REUSE-IgnoreEnd


def version_swift(version: str) -> str:
    return "VersionContrat({}, {}, {})".format(*VERSION.match(version).groups())


def plancher_swift(ctx, version: str, portes: dict[str, tuple[str, str, str]]) -> str:
    corps = ctx.entete("openapi.json de la release (info.version)")
    corps += "\n/// Le contrat du PLANCHER : celui sur lequel l'app se génère (`scripts/generateurs/_plancher.py`).\n"
    corps += "extension VersionContrat {\n"
    corps += "    /// Une installation qui sert un contrat plus ancien ne se décode plus : la découverte\n"
    corps += "    /// le dit (« cette résidence doit être mise à jour »), au lieu d'une erreur muette.\n"
    corps += f"    static let plancher = {version_swift(version)}\n"
    for porte, (contrat, etiquette, ouvre) in sorted(portes.items()):
        corps += "\n"
        corps += f"    /// Au-dessus du plancher : {ouvre} — servi depuis {etiquette} (contrat {contrat}).\n"
        corps += f"    static let {porte} = {version_swift(contrat)}\n"
    corps += "}\n"
    return corps


def version_du_contrat(ctx, schema: dict) -> str:
    """`info.version` du contrat publié : la version que les installations servent."""
    try:
        publiee = schema["info"]["version"]
    except (KeyError, TypeError) as erreur:
        raise SystemExit(f"❌ version du contrat de {ctx.version.etiquette} illisible : {erreur}") from erreur
    if not isinstance(publiee, str) or not VERSION.match(publiee):
        raise SystemExit(f"❌ openapi.json de {ctx.version.etiquette} : version « {publiee} » hors de X.Y.Z")
    return publiee


def generer(ctx) -> str:
    try:
        schema = json.loads(ctx.version.piece_jointe("openapi.json"))
    except ValueError as erreur:
        raise SystemExit(f"❌ openapi.json de {ctx.version.etiquette} illisible : {erreur}") from erreur
    version = version_du_contrat(ctx, schema)
    portes, ajouts = {}, []
    for porte, (etiquette, ouvre, chemins) in AU_DESSUS_DU_PLANCHER.items():
        publiee = Version(etiquette)
        publie = json.loads(publiee.piece_jointe("openapi.json"))
        contrat = publiee.contrat()
        portes[porte] = (contrat, etiquette, ouvre)
        if all(c in schema.get("paths", {}) for c in chemins) and ctx.version.etiquette != _plancher.VERSION:
            continue  # une version plus récente que le plancher les sert déjà (concordance --montee)
        nommes = ajouter_routes(schema, publie, chemins, etiquette)
        ajouts.append(f"`{'`, `'.join(chemins)}` et {', '.join(f'`{n}`' for n in nommes) or 'aucun schéma'}, "
                      f"de {etiquette} (contrat {contrat}) — porte `VersionContrat.{porte}`")
    schema = sans_cookies(nullable(schema))
    ctx.ecrire(CONTRAT, json.dumps(schema, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    ctx.ecrire(CLIENT / "PROVENANCE-OPENAPI.md", provenance(ctx, version, ajouts))
    ctx.ecrire(PLANCHER_SWIFT, plancher_swift(ctx, version, portes))
    return f"contrat {version}, {len(schema.get('paths', {}))} chemins, {len(ajouts)} porte(s) au-dessus"
