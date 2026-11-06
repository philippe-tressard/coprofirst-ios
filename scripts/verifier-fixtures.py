#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les données de l'API SIMULÉE jugées contre le schéma du SERVEUR (#20, #13).

Bogue du 05/11/2026 : l'API simulée servait un champ `type` que `/acces/mes-vigiks`
n'a jamais servi ; les tests étaient verts, l'iPhone affichait une erreur. Une réponse
simulée s'écrit donc en JSON, à la forme exacte de sa route, dans un fichier
`Fixtures*.swift` qui la déclare avec son schéma :

    static let mesVigiks = #\"\"\" [ {...} ] \"\"\"#
    Reponse(nom: "mesVigiks", schema: "AccesPorteur", json: mesVigiks),

Ce juge lit chaque réponse et la confronte à `components/schemas` du contrat, à tous
les niveaux : un champ que le serveur ne sert pas, un champ requis absent, une valeur
hors de son énumération, un type faux font échouer. Une réponse JSON qu'aucune
`Reponse(…)` ne déclare échoue aussi : elle échapperait au juge.

Usage :
  python3 scripts/verifier-fixtures.py [--contrat openapi.json]
      Défaut : le contrat du dépôt. La concordance (#20) passe celui de la dernière
      version publiée de coprofirst.
  python3 scripts/verifier-fixtures.py --autotest

Sortie : 0 conforme, 1 écart, 2 INCONNU (contrat ou fixture illisible, aucune fixture).
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys
import tempfile

RACINE = pathlib.Path(__file__).resolve().parents[1]
CONTRAT = RACINE / "Paquets" / "ClientAPI" / "Sources" / "ClientAPI" / "openapi.json"
JSON_BRUT = re.compile(r'static let (\w+) = #"""\n(.*?)\n\s*"""#', re.S)
DECLAREE = re.compile(r'Reponse\(nom: "(\w+)", schema: "(\w+)", json: (\w+)\)')
TYPES = {
    "string": lambda v: isinstance(v, str),
    "integer": lambda v: isinstance(v, int) and not isinstance(v, bool),
    "number": lambda v: isinstance(v, (int, float)) and not isinstance(v, bool),
    "boolean": lambda v: isinstance(v, bool),
    "array": lambda v: isinstance(v, list),
    "object": lambda v: isinstance(v, dict),
    "null": lambda v: v is None,
}


class Illisible(Exception):
    pass


class NonDeclaree(Exception):
    """Une réponse JSON sans `Reponse(…)` : elle échapperait au juge — un écart."""


class Juge:
    def __init__(self, contrat: dict) -> None:
        self.schemas = contrat.get("components", {}).get("schemas", {})
        if not self.schemas:
            raise Illisible("le contrat ne déclare aucun schéma")

    def ecarts(self, valeur, nom: str, chemin: str) -> list[str]:
        if nom not in self.schemas:
            return [f"{chemin} : schéma {nom} absent du contrat"]
        return self._noeud(valeur, self.schemas[nom], chemin, nom)

    def _noeud(self, valeur, schema: dict, chemin: str, nom: str = "") -> list[str]:
        if "$ref" in schema:
            return self.ecarts(valeur, schema["$ref"].rsplit("/", 1)[-1], chemin)
        for cle in ("anyOf", "oneOf"):
            if cle in schema:
                branches = [self._noeud(valeur, b, chemin) for b in schema[cle]]
                return [] if any(not b for b in branches) else min(branches, key=len)
        if "allOf" in schema:
            return [e for b in schema["allOf"] for e in self._noeud(valeur, b, chemin)]
        if "enum" in schema and valeur not in schema["enum"]:
            return [f"{chemin} : « {valeur} » hors de {nom or 'l’énumération'}"]
        types = schema.get("type")
        types = [types] if isinstance(types, str) else (types or [])
        if types and not any(TYPES.get(t, lambda v: True)(valeur) for t in types):
            return [f"{chemin} : {json.dumps(valeur, ensure_ascii=False)[:40]} n'est pas {'|'.join(types)}"]
        if isinstance(valeur, list) and isinstance(schema.get("items"), dict):
            return [e for i, v in enumerate(valeur) for e in self._noeud(v, schema["items"], f"{chemin}[{i}]")]
        if isinstance(valeur, dict) and ("properties" in schema or "object" in types):
            return self._objet(valeur, schema, chemin)
        return []

    def _objet(self, valeur: dict, schema: dict, chemin: str) -> list[str]:
        proprietes = schema.get("properties", {})
        ecarts = []
        if schema.get("additionalProperties") in (None, False):
            ecarts += [f"{chemin}.{c} : non servi par le serveur" for c in sorted(valeur) if c not in proprietes]
        ecarts += [f"{chemin}.{c} : requis, absent" for c in sorted(schema.get("required", [])) if c not in valeur]
        for cle in sorted(valeur):
            if cle in proprietes:
                ecarts += self._noeud(valeur[cle], proprietes[cle], f"{chemin}.{cle}")
        return ecarts


def fixtures(racine: pathlib.Path) -> list[tuple[str, str, str, object]]:
    """(fichier, nom, schéma, réponse lue) de chaque réponse simulée déclarée."""
    trouvees = []
    for fichier in sorted((racine / "CoproFirst").rglob("Fixtures*.swift")):
        texte = fichier.read_text(encoding="utf-8")
        brutes = dict(JSON_BRUT.findall(texte))
        declarees = {variable: (nom, schema) for nom, schema, variable in DECLAREE.findall(texte)}
        relatif = str(fichier.relative_to(racine))
        for variable in sorted(set(brutes) - set(declarees)):
            trouvees.append((relatif, variable, "", NonDeclaree("aucune Reponse(…) ne la déclare avec son schéma")))
        for variable, (nom, schema) in sorted(declarees.items()):
            if variable not in brutes:
                trouvees.append((relatif, nom, schema, Illisible(f"aucun JSON « static let {variable} »")))
                continue
            try:
                trouvees.append((relatif, nom, schema, json.loads(brutes[variable])))
            except json.JSONDecodeError as erreur:
                trouvees.append((relatif, nom, schema, Illisible(f"JSON illisible ({erreur})")))
    return trouvees


def juger(juge: Juge, trouvees: list) -> tuple[list[str], list[str]]:
    """(écarts, illisibles) de toutes les réponses simulées."""
    ecarts, illisibles = [], []
    for fichier, nom, schema, reponse in trouvees:
        if isinstance(reponse, (Illisible, NonDeclaree)):
            (illisibles if isinstance(reponse, Illisible) else ecarts).append(f"{fichier} : {nom} — {reponse}")
        elif isinstance(reponse, list):
            for rang, element in enumerate(reponse):
                ecarts += [f"{fichier} : {e}" for e in juge.ecarts(element, schema, f"{nom}[{rang}]")]
        else:
            ecarts += [f"{fichier} : {e}" for e in juge.ecarts(reponse, schema, nom)]
    return ecarts, illisibles


def autotest() -> None:
    contrat = {"components": {"schemas": {
        "Statut": {"type": "string", "enum": ["actif", "perdu"]},
        "Porteur": {"type": "object", "required": ["id", "code"], "properties": {
            "id": {"type": "integer"}, "code": {"type": "string"},
            "statut": {"$ref": "#/components/schemas/Statut"},
            "lot": {"type": ["string", "null"]},
            "objets": {"type": "array", "items": {"$ref": "#/components/schemas/Objet"}}}},
        "Objet": {"type": "object", "properties": {"libelle": {"type": "string"}}},
    }}}
    juge = Juge(contrat)
    cas = [
        ({"id": 1, "code": "X", "statut": "actif", "lot": None, "objets": [{"libelle": "a"}]}, []),
        ({"id": 1, "code": "X", "type": "vigik"}, ["x.type : non servi par le serveur"]),
        ({"id": 1}, ["x.code : requis, absent"]),
        ({"id": 1, "code": "X", "statut": "volé"}, ["x.statut : « volé » hors de Statut"]),
        ({"id": "1", "code": "X"}, ['x.id : "1" n\'est pas integer']),
        ({"id": 1, "code": "X", "objets": [{"libelle": "a", "type": "cle"}]}, ["x.objets[0].type : non servi par le serveur"]),
    ]
    for valeur, attendu in cas:
        obtenu = juge.ecarts(valeur, "Porteur", "x")
        if obtenu != attendu:
            raise SystemExit(f"❌ autotest : {valeur} → {obtenu}, attendu {attendu}")
    texte = 'static let a = #"""\n[{"id": 1, "code": "X"}]\n"""#\nstatic let b = #"""\n{}\n"""#\n' \
            'Reponse(nom: "a", schema: "Porteur", json: a),\n'
    with tempfile.TemporaryDirectory() as dossier:
        fichier = pathlib.Path(dossier) / "CoproFirst" / "FixturesX.swift"
        fichier.parent.mkdir()
        fichier.write_text(texte, encoding="utf-8")
        ecarts, illisibles = juger(juge, fixtures(pathlib.Path(dossier)))
    if illisibles or len(ecarts) != 1 or "b — aucune Reponse" not in ecarts[0]:
        raise SystemExit(f"❌ autotest : une réponse non déclarée doit être vue ({ecarts}, {illisibles})")
    print("✅ autotest : champ de trop, requis absent, énumération, type, imbriqué, réponse non déclarée")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--contrat", type=pathlib.Path, default=CONTRAT)
    parser.add_argument("--autotest", action="store_true")
    arguments = parser.parse_args()
    if arguments.autotest:
        autotest()
        return 0
    try:
        juge = Juge(json.loads(arguments.contrat.read_text(encoding="utf-8")))
    except (OSError, ValueError, Illisible) as erreur:
        print(f"❓ INCONNU : contrat {arguments.contrat} illisible ({erreur})")
        return 2
    trouvees = fixtures(RACINE)
    if not trouvees:
        print("❓ INCONNU : aucune réponse simulée trouvée (CoproFirst/**/Fixtures*.swift)")
        return 2
    ecarts, illisibles = juger(juge, trouvees)
    for ligne in illisibles:
        print(f"❓ {ligne}")
    for ligne in ecarts:
        print(f"❌ {ligne}")
    if illisibles:
        return 2
    if ecarts:
        return 1
    print(f"✅ {len(trouvees)} réponses simulées conformes au contrat ({arguments.contrat.name})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
