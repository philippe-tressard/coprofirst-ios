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

Le contrat dit qu'un `perimetre_cible` est une liste de chaînes ; le serveur y met des
CODES de l'arbre (`GET /perimetres`). Bogue du 08/11/2026 (#64) : l'API simulée y
mettait des libellés (« Copropriété »), et Badges affichait les codes bruts de la démo
(« bat:2 ») sans qu'aucun test le voie. Chaque `perimetre_cible` simulé doit donc citer
un `code` de l'arbre simulé (la réponse déclarée `PerimetreRead`).

Une route que le contrat ne TYPE pas (pas de `response_model` côté serveur, #16) n'a pas
de schéma à opposer : sa réponse se déclare par sa route,

    ReponseNonTypee(nom: "tableau", route: "GET /telemetry/dashboard", json: tableau),

et le juge vérifie que la route existe et qu'elle n'est toujours pas typée. Le jour où le
contrat la type, il échoue : la réponse se déclare alors par son schéma, et l'écran la lit
par son type généré, jamais plus par `Relecture`.

Une installation plus récente que le plancher sert, sur une route TYPÉE, des champs que
le contrat du plancher ne déclare pas encore (#89 : `gestes_roles`, contrat 1.18.0).
L'API simulée les sert, à la forme du serveur, s'ils sont déclarés :

    AuDessusDuPlancher(schema: "UtilisateurAdminRead", champs: ["gestes_roles"], contrat: "1.18.0")

et le juge les tolère dans ce schéma seulement. Il échoue le jour où le contrat les
déclare (les lire alors par le type généré, retirer la déclaration), et sur une
déclaration qu'aucune réponse simulée ne sert plus.

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
NON_TYPEE = re.compile(r'ReponseNonTypee\(nom: "(\w+)", route: "((?:GET|POST|PUT|PATCH|DELETE) /[^"]*)", json: (\w+)\)')
AU_DESSUS_DECLARE = re.compile(r'AuDessusDuPlancher\(\s*schema: "(\w+)",\s*champs: \[([^\]]*)\]')
ROUTE = "route:"
AU_DESSUS = "au-dessus:"
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
        self.chemins = contrat.get("paths", {})
        #: schéma → champs servis au-dessus du plancher, tolérés ; et ceux qu'on a vus.
        self.tolerés: dict[str, set[str]] = {}
        self.vus: set[tuple[str, str]] = set()
        if not self.schemas:
            raise Illisible("le contrat ne déclare aucun schéma")

    def ecarts(self, valeur, nom: str, chemin: str) -> list[str]:
        if nom.startswith(ROUTE):
            return self.non_typee(nom[len(ROUTE):], chemin)
        if nom not in self.schemas:
            return [f"{chemin} : schéma {nom} absent du contrat"]
        return self._noeud(valeur, self.schemas[nom], chemin, nom)

    def non_typee(self, route: str, chemin: str) -> list[str]:
        """La route existe, et le contrat ne type toujours pas sa réponse 200."""
        methode, adresse = route.split(" ", 1)
        operation = self.chemins.get(adresse, {}).get(methode.lower())
        if operation is None:
            return [f"{chemin} : {route} absente du contrat"]
        schema = (operation.get("responses", {}).get("200", {}).get("content", {})
                  .get("application/json", {}).get("schema", {}))
        if schema:
            return [f"{chemin} : {route} est typée par le contrat ({json.dumps(schema)[:60]}) — "
                    "déclarer la réponse par son schéma, la lire par son type généré"]
        return []

    def _noeud(self, valeur, schema: dict, chemin: str, nom: str = "") -> list[str]:
        if "$ref" in schema:
            return self.ecarts(valeur, schema["$ref"].rsplit("/", 1)[-1], chemin)
        for cle in ("anyOf", "oneOf"):
            if cle in schema:
                branches = [self._noeud(valeur, b, chemin) for b in schema[cle]]
                return [] if any(not b for b in branches) else min(branches, key=len)
        if "allOf" in schema:
            return [e for b in schema["allOf"] for e in self._noeud(valeur, b, chemin)]
        types = schema.get("type")
        types = [types] if isinstance(types, str) else (types or [])
        # Une énumération FACULTATIVE (`Optional[Literal[…]]` du serveur, écrite
        # `type: [string, "null"]` avec son `enum`) sert `null` : il n'est pas « hors de
        # l'énumération » (`gestes_roles`, contrat 1.18.0).
        if "enum" in schema and valeur not in schema["enum"] and not (valeur is None and "null" in types):
            return [f"{chemin} : « {valeur} » hors de {nom or 'l’énumération'}"]
        if types and not any(TYPES.get(t, lambda v: True)(valeur) for t in types):
            return [f"{chemin} : {json.dumps(valeur, ensure_ascii=False)[:40]} n'est pas {'|'.join(types)}"]
        if isinstance(valeur, list) and isinstance(schema.get("items"), dict):
            return [e for i, v in enumerate(valeur) for e in self._noeud(v, schema["items"], f"{chemin}[{i}]")]
        if isinstance(valeur, dict) and ("properties" in schema or "object" in types):
            return self._objet(valeur, schema, chemin, nom)
        return []

    def _objet(self, valeur: dict, schema: dict, chemin: str, nom: str = "") -> list[str]:
        proprietes = schema.get("properties", {})
        ecarts = []
        if schema.get("additionalProperties") in (None, False):
            hors = [c for c in sorted(valeur) if c not in proprietes]
            tolerés = self.tolerés.get(nom, set())
            self.vus |= {(nom, c) for c in hors if c in tolerés}
            ecarts += [f"{chemin}.{c} : non servi par le serveur" for c in hors if c not in tolerés]
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
        declarees |= {variable: (nom, ROUTE + route) for nom, route, variable in NON_TYPEE.findall(texte)}
        relatif = str(fichier.relative_to(racine))
        for schema, champs in AU_DESSUS_DECLARE.findall(texte):
            trouvees.append((relatif, "AuDessusDuPlancher", AU_DESSUS + schema, re.findall(r'"(\w+)"', champs)))
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
    declarations = [t for t in trouvees if t[2].startswith(AU_DESSUS)]
    trouvees = [t for t in trouvees if not t[2].startswith(AU_DESSUS)]
    juge.tolerés, juge.vus = {}, set()
    for _, _, schema, champs in declarations:
        juge.tolerés.setdefault(schema[len(AU_DESSUS):], set()).update(champs)
    for fichier, nom, schema, reponse in trouvees:
        if isinstance(reponse, (Illisible, NonDeclaree)):
            (illisibles if isinstance(reponse, Illisible) else ecarts).append(f"{fichier} : {nom} — {reponse}")
        elif isinstance(reponse, list) and not schema.startswith(ROUTE):
            for rang, element in enumerate(reponse):
                ecarts += [f"{fichier} : {e}" for e in juge.ecarts(element, schema, f"{nom}[{rang}]")]
        else:
            ecarts += [f"{fichier} : {e}" for e in juge.ecarts(reponse, schema, nom)]
    ecarts += ecarts_au_dessus(juge, declarations)
    codes, cites = set(), []
    for fichier, nom, schema, reponse in trouvees:
        if isinstance(reponse, (Illisible, NonDeclaree)):
            continue
        if schema == "PerimetreRead":
            codes |= {n.get("code") for n in (reponse if isinstance(reponse, list) else [reponse])}
        cites += [(fichier, nom, chemin, code) for chemin, code in perimetres_cites(reponse, nom)]
    if cites and not codes:
        illisibles.append("perimetre_cible : aucun arbre simulé (`PerimetreRead`) pour juger ses codes")
    ecarts += [
        f"{fichier} : {chemin} : « {code} » n'est pas un code de l'arbre simulé (PerimetreRead)"
        for fichier, nom, chemin, code in cites
        if codes and code not in codes
    ]
    return ecarts, illisibles


def ecarts_au_dessus(juge: Juge, declarations: list) -> list[str]:
    """Une déclaration `AuDessusDuPlancher` qui ne sert plus : son champ est au contrat,
    ou aucune réponse simulée ne le sert."""
    ecarts = []
    for fichier, nom, schema, champs in declarations:
        schema = schema[len(AU_DESSUS):]
        if schema not in juge.schemas:
            ecarts.append(f"{fichier} : {nom} — schéma {schema} absent du contrat")
            continue
        for champ in champs:
            if champ in juge.schemas[schema].get("properties", {}):
                ecarts.append(f"{fichier} : {nom} — {schema}.{champ} est au contrat : le lire par le type "
                              "généré, retirer la déclaration")
            elif (schema, champ) not in juge.vus:
                ecarts.append(f"{fichier} : {nom} — {schema}.{champ} : déclaré au-dessus du plancher, servi par "
                              "aucune réponse simulée — retirer la déclaration")
    return ecarts


def perimetres_cites(valeur, chemin: str):
    """(chemin, code) de chaque valeur d'un `perimetre_cible`, à tous les niveaux."""
    if isinstance(valeur, dict):
        for cle, sous in valeur.items():
            if cle == "perimetre_cible" and isinstance(sous, list):
                yield from ((f"{chemin}.{cle}[{i}]", code) for i, code in enumerate(sous))
            else:
                yield from perimetres_cites(sous, f"{chemin}.{cle}")
    elif isinstance(valeur, list):
        for i, sous in enumerate(valeur):
            yield from perimetres_cites(sous, f"{chemin}[{i}]")


def autotest() -> None:
    contrat = {"components": {"schemas": {
        "Statut": {"type": "string", "enum": ["actif", "perdu"]},
        "Porteur": {"type": "object", "required": ["id", "code"], "properties": {
            "id": {"type": "integer"}, "code": {"type": "string"},
            "statut": {"$ref": "#/components/schemas/Statut"},
            "lot": {"type": ["string", "null"]},
            "geste": {"type": ["string", "null"], "enum": ["ajouter", "retirer"]},
            "objets": {"type": "array", "items": {"$ref": "#/components/schemas/Objet"}}}},
        "Objet": {"type": "object", "properties": {"libelle": {"type": "string"}}},
    }}}
    juge = Juge(contrat)
    cas = [
        ({"id": 1, "code": "X", "statut": "actif", "lot": None, "objets": [{"libelle": "a"}]}, []),
        ({"id": 1, "code": "X", "type": "vigik"}, ["x.type : non servi par le serveur"]),
        ({"id": 1}, ["x.code : requis, absent"]),
        ({"id": 1, "code": "X", "statut": "volé"}, ["x.statut : « volé » hors de Statut"]),
        ({"id": 1, "code": "X", "geste": None}, []),
        ({"id": 1, "code": "X", "geste": "ajouter"}, []),
        ({"id": 1, "code": "X", "geste": "promouvoir"}, ["x.geste : « promouvoir » hors de l’énumération"]),
        ({"id": 1, "code": "X", "statut": None}, ["x.statut : « None » hors de Statut"]),
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
    routes = Juge({"components": {"schemas": {"X": {}}}, "paths": {
        "/libre": {"get": {"responses": {"200": {"content": {"application/json": {"schema": {}}}}}}},
        "/typee": {"get": {"responses": {"200": {"content": {"application/json": {
            "schema": {"$ref": "#/components/schemas/X"}}}}}}}}})
    for route, attendu in [("GET /libre", 0), ("GET /typee", 1), ("POST /libre", 1), ("GET /absente", 1)]:
        ecarts, _ = juger(routes, [("F", "r", ROUTE + route, [{"a": 1}, {"a": 2}])])
        if len(ecarts) != attendu:
            raise SystemExit(f"❌ autotest : réponse non typée {route} → {ecarts}")
    arbre = [("F", "arbre", "PerimetreRead", [{"code": "bat_a"}]),
             ("F", "parc", "Objet", [{"perimetre_cible": ["bat_a", "Copropriété"]}])]
    vide = Juge({"components": {"schemas": {"PerimetreRead": {}, "Objet": {}}}})
    ecarts, illisibles = juger(vide, arbre)
    if illisibles or ecarts != ["F : parc[0].perimetre_cible[1] : « Copropriété » n'est pas un code de l'arbre simulé (PerimetreRead)"]:
        raise SystemExit(f"❌ autotest : un libellé à la place d'un code doit être vu ({ecarts}, {illisibles})")
    _, illisibles = juger(vide, arbre[1:])
    if not illisibles:
        raise SystemExit("❌ autotest : sans arbre simulé, les codes cités sont INCONNU")
    plancher = Juge({"components": {"schemas": {"Compte": {"type": "object", "required": ["id"], "properties": {
        "id": {"type": "integer"}}}, "Typé": {"type": "object", "properties": {"neuf": {"type": "boolean"}}}}}})
    declare = ("F", "auDessus", AU_DESSUS + "Compte", ["neuf"])
    for trouvees, attendu in [
        ([declare, ("F", "c", "Compte", [{"id": 1, "neuf": True}])], []),
        ([declare, ("F", "c", "Compte", [{"id": 1, "autre": 1}])],
         ["F : c[0].autre : non servi par le serveur", "F : auDessus — Compte.neuf : déclaré au-dessus du plancher, "
          "servi par aucune réponse simulée — retirer la déclaration"]),
        ([(*declare[:2], AU_DESSUS + "Typé", ["neuf"]), ("F", "t", "Typé", [{"neuf": True}])],
         ["F : auDessus — Typé.neuf est au contrat : le lire par le type généré, retirer la déclaration"]),
        ([(*declare[:2], AU_DESSUS + "Absent", ["neuf"])], ["F : auDessus — schéma Absent absent du contrat"]),
    ]:
        ecarts, illisibles = juger(plancher, trouvees)
        if ecarts != attendu or illisibles:
            raise SystemExit(f"❌ autotest : champ au-dessus du plancher → {ecarts} {illisibles}, attendu {attendu}")
    print("✅ autotest : champ de trop, requis absent, énumération (facultative : null admis), type, imbriqué, "
          "réponse non déclarée, "
          "code de périmètre, route non typée, champ au-dessus du plancher")


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
