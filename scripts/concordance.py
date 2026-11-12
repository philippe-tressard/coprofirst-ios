#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""La CONCORDANCE avec coprofirst (#20 ; standards/09 §8, règle 2 : ce qu'un client
dérive du serveur se surveille chaque jour). Deux verdicts, jamais confondus :

1. `--plancher` (défaut) — l'ÉCART AU PLANCHER : tout ce que l'app tire de coprofirst
   (contrat, charte, palettes, pages et onglets, natures du fil, rôles, tables des
   menus) est régénéré depuis le plancher (`generateurs/_plancher.py`) dans un dossier
   jetable et comparé au dépôt, à l'octet ; les réponses de l'API simulée sont jugées
   contre le contrat du plancher. Un écart est ROUGE (sortie 1) : un fichier retouché
   à la main, un générateur modifié sans régénérer, un champ que le serveur ne sert pas
   — ou une installation connue qui SERT un contrat sous celui du plancher (#83) : le
   plancher se MESURE (`version_contrat` de GET /config de `_plancher.INSTALLATIONS`),
   il ne se croit pas sur parole ; l'app n'ouvrirait plus cette installation.
2. `--montee` — une NOUVELLE VERSION publiée au-dessus du plancher : une information,
   jamais un rouge (sortie 3). Le rapport dit ce que monter le plancher exigerait :
   champs devenus requis, propriétés et routes retirées, fichiers générés qui
   changeraient, réponses simulées que le nouveau contrat refuserait — et le plancher
   MESURÉ : jusqu'à quelle release il peut monter, d'après le plus ancien contrat servi.
   Sortie 0 si la dernière version EST le plancher.

Une version, une archive ou une table illisible : INCONNU (sortie 2), jamais vert.

Usage : python3 scripts/concordance.py [--plancher | --montee | --autotest]
                                       [--rapport FICHIER.md] [--simuler-ecart]
"""

from __future__ import annotations

import argparse
import difflib
import importlib.util
import json
import pathlib
import re
import sys
import tempfile

RACINE = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RACINE / "scripts"))

import generer  # noqa: E402
from generateurs import _plancher, _tables  # noqa: E402
from generateurs._commun import PROVENANCE, SIGNATURE  # noqa: E402
from generateurs._source import SourceIllisible, Version, contrat_servi, derniere_version, versions_publiees  # noqa: E402
from generateurs.contrat import CONTRAT  # noqa: E402

LIGNES_DE_DIFF = 40
# Où vivent les fichiers générés ; un dossier caché ou de build n'est pas le dépôt.
DOSSIERS_GENERES = ("CoproFirst", "Paquets/ClientAPI", "Parite")
COMMIT_NOMME = re.compile(r"`[0-9a-f]{40}` \(`v\d+\.\d+\.\d+`\)")
REGENERER = "python3 scripts/generer.py"


def _juge():
    """`scripts/verifier-fixtures.py` (nom à tiret) chargé comme module : un seul juge."""
    spec = importlib.util.spec_from_file_location("verifier_fixtures", RACINE / "scripts" / "verifier-fixtures.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def sans_provenance(texte: str) -> str:
    """Le texte sans ce qui nomme la version lue (en-tête, table de PROVENANCE-OPENAPI.md)."""
    return COMMIT_NOMME.sub("<commit>", PROVENANCE.sub("<provenance>", texte))


def candidats(racine: pathlib.Path) -> list[str]:
    return sorted(
        str(f.relative_to(racine)) for d in DOSSIERS_GENERES if (racine / d).is_dir() for f in (racine / d).rglob("*")
        if f.is_file() and not any(p.startswith(".") for p in f.relative_to(racine).parts))


def generes_du_depot(racine: pathlib.Path) -> list[str]:
    """Chaque fichier du dépôt qui se dit GÉNÉRÉ (signature dans ses premières lignes)."""
    trouves = []
    for relatif in candidats(racine):
        try:
            tete = (racine / relatif).read_text(encoding="utf-8").splitlines()[:12]
        except (OSError, UnicodeDecodeError):
            continue
        if any(SIGNATURE in ligne for ligne in tete):
            trouves.append(relatif)
    return trouves


def comparer(depot: pathlib.Path, genere: pathlib.Path, ecrits: list[str], declares: list[str],
             *, a_l_octet: bool = True) -> list[str]:
    """Les écarts entre le dépôt et une génération : divergent, absent, orphelin.

    `a_l_octet=False` : la ligne qui nomme la version lue ne compte pas."""
    ecarts = []
    for relatif in sorted(set(ecrits)):
        attendu, present = genere / relatif, depot / relatif
        if not present.exists():
            ecarts.append(f"`{relatif}` : absent")
            continue
        avant, apres = present.read_text(encoding="utf-8"), attendu.read_text(encoding="utf-8")
        if not a_l_octet:
            avant, apres = sans_provenance(avant), sans_provenance(apres)
        if avant != apres:
            diff = list(difflib.unified_diff(avant.splitlines(), apres.splitlines(), "avant", "généré",
                                             lineterm="", n=0))
            extrait = "\n".join(f"  {ligne}" for ligne in diff[:LIGNES_DE_DIFF])
            extrait += "\n  …" if len(diff) > LIGNES_DE_DIFF else ""
            ecarts.append(f"`{relatif}` : diverge\n  ```diff\n{extrait}\n  ```")
    ecarts += [f"`{r}` : se dit GÉNÉRÉ, mais plus aucun générateur ne l'écrit"
               for r in sorted(set(declares) - set(ecrits))]
    return ecarts


def exigences(ancien: dict, nouveau: dict) -> list[str]:
    """Ce que le nouveau contrat exige qu'un client de l'ancien ne fournit ou n'attend pas."""
    avant, apres = ancien.get("components", {}).get("schemas", {}), nouveau.get("components", {}).get("schemas", {})
    lignes = [f"route retirée : `{c}`" for c in sorted(set(ancien.get("paths", {})) - set(nouveau.get("paths", {})))]
    lignes += [f"schéma retiré : `{s}`" for s in sorted(set(avant) - set(apres))]
    for nom in sorted(set(avant) & set(apres)):
        a, b = avant[nom], apres[nom]
        requis = sorted(set(b.get("required", [])) - set(a.get("required", [])))
        if requis:
            lignes.append(f"`{nom}` : champ(s) devenu(s) requis — {', '.join(f'`{c}`' for c in requis)}")
        retires = sorted(set(a.get("properties", {})) - set(b.get("properties", {})))
        if retires:
            lignes.append(f"`{nom}` : propriété(s) retirée(s) — {', '.join(f'`{c}`' for c in retires)}")
        valeurs = sorted(set(a.get("enum", [])) - set(b.get("enum", [])), key=str)
        if valeurs:
            lignes.append(f"`{nom}` : valeur(s) retirée(s) de l'énumération — {', '.join(map(str, valeurs))}")
    return lignes


def nombres(contrat: str) -> tuple[int, ...]:
    """« 1.9.0 » < « 1.15.0 » : une version se compare par ses nombres, jamais en chaîne."""
    return tuple(int(n) for n in contrat.split("."))


def mesurer() -> dict[str, str]:
    """Le contrat que sert chaque installation connue ; une seule illisible : INCONNU."""
    if not _plancher.INSTALLATIONS:
        raise SourceIllisible("aucune installation connue à mesurer (_plancher.INSTALLATIONS)")
    return {hote: contrat_servi(hote) for hote in _plancher.INSTALLATIONS}


def sous_le_plancher(servis: dict[str, str], plancher_contrat: str) -> list[str]:
    """Les installations qui servent un contrat plus ancien que le plancher : des écarts."""
    return [f"installation `{hote}` : sert le contrat {servi}, sous le plancher ({plancher_contrat}) — "
            "l'app ne s'y ouvre plus (« cette résidence doit être mise à jour ») : redescendre le plancher"
            for hote, servi in sorted(servis.items()) if nombres(servi) < nombres(plancher_contrat)]


def mesure_lue(servis: dict[str, str]) -> str:
    return ", ".join(f"`{hote}` {servi}" for hote, servi in sorted(servis.items()))


def cible(contrats: list[tuple[str, str]], minimum: str) -> str | None:
    """La release la plus récente dont le contrat ne dépasse pas `minimum`.

    `contrats` : (étiquette, contrat), de la plus récente à la plus ancienne."""
    return next((etiquette for etiquette, contrat in contrats if nombres(contrat) <= nombres(minimum)), None)


def plancher_mesure(servis: dict[str, str], plancher_contrat: str) -> list[str]:
    """Ce que la mesure dit d'une montée : attendre, ou jusqu'à quelle release monter."""
    minimum = min(servis.values(), key=nombres)
    lignes = [f"installations connues : {mesure_lue(servis)} ; contrat du plancher : {plancher_contrat}"]
    if nombres(minimum) <= nombres(plancher_contrat):
        retiennent = [h for h, v in sorted(servis.items()) if v == minimum]
        return lignes + [f"le plancher mesuré est {minimum} : la montée attend {', '.join(f'`{h}`' for h in retiennent)}"]
    contrats = []
    for etiquette in versions_publiees():
        contrats.append((etiquette, Version(etiquette).contrat()))
        if nombres(contrats[-1][1]) <= nombres(minimum):
            break
    vers = cible(contrats, minimum)
    if vers is None:
        raise SourceIllisible(f"aucune des cent dernières releases ne porte un contrat ≤ {minimum}")
    return lignes + [f"toutes servent au moins {minimum} : le plancher peut monter à **{vers}** "
                     f"(la release la plus récente au contrat ≤ {minimum})"]


def generer_dans(etiquette: str, sortie: pathlib.Path, simuler: bool = False) -> list[str]:
    ctx, _ = generer.executer(etiquette, sortie)
    ecrits = [str(p) for p in ctx.ecrits]
    if simuler:
        with open(sortie / ecrits[0], "a", encoding="utf-8") as f:
            f.write("// écart simulé par concordance.py --simuler-ecart\n")
    return ecrits


def juger_fixtures(contrat: pathlib.Path) -> list[str]:
    juge = _juge()
    hors_schema, illisibles = juge.juger(juge.Juge(json.loads(contrat.read_text(encoding="utf-8"))),
                                         juge.fixtures(RACINE))
    if illisibles:
        raise SourceIllisible("réponse simulée illisible : " + " ; ".join(illisibles))
    return hors_schema


def contrat_de(dossier: pathlib.Path) -> str:
    return json.loads((dossier / CONTRAT).read_text(encoding="utf-8"))["info"]["version"]


def plancher(simuler: bool) -> tuple[int, str]:
    titre = f"Écart au plancher ({_plancher.VERSION})"
    servis = mesurer()
    with tempfile.TemporaryDirectory(prefix="concordance-") as dossier:
        sortie = pathlib.Path(dossier)
        ecrits = generer_dans(_plancher.VERSION, sortie, simuler)
        ecarts = comparer(RACINE, sortie, ecrits, generes_du_depot(RACINE))
        ecarts += [f"API simulée : {e}" for e in juger_fixtures(sortie / CONTRAT)]
        ecarts += sous_le_plancher(servis, contrat_de(sortie))
    mesure = f"Contrat servi par les installations connues : {mesure_lue(servis)}.\n"
    if not ecarts:
        return 0, (f"## {titre} : aucun\n\nLe dépôt est ce que le plancher génère ; l'API simulée a sa forme.\n"
                   + mesure)
    corps = f"## {titre} : ❌ {len(ecarts)}\n\n" + "".join(f"- {e}\n" for e in ecarts) + "\n" + mesure
    return 1, corps + f"\nRégénérer : `{REGENERER}`, relire le diff, puis `xcodebuild test`.\n"


def montee() -> tuple[int, str]:
    derniere = derniere_version()
    if derniere == _plancher.VERSION:
        return 0, f"## Montée : la dernière version publiée est le plancher ({derniere})\n"
    with tempfile.TemporaryDirectory(prefix="montee-") as dossier:
        bas, haut = pathlib.Path(dossier, "plancher"), pathlib.Path(dossier, "derniere")
        generer_dans(_plancher.VERSION, bas)
        changeraient = comparer(bas, haut, generer_dans(derniere, haut), [], a_l_octet=False)
        contrat = exigences(json.loads((bas / CONTRAT).read_text(encoding="utf-8")),
                            json.loads((haut / CONTRAT).read_text(encoding="utf-8")))
        refusees = juger_fixtures(haut / CONTRAT)
        mesure = plancher_mesure(mesurer(), contrat_de(bas))
    corps = (f"## Montée possible : {derniere} est publiée, le plancher est {_plancher.VERSION}\n\n"
             f"Une information, pas un écart. Le plancher ({_plancher.RAISON}) ne monte que sur "
             "décision, quand toutes les installations connues ont dépassé la nouvelle version : "
             "`scripts/generateurs/_plancher.py`, puis `python3 scripts/generer.py`.\n\n")
    sections = [("Plancher mesuré (#83)", mesure), ("Ce que le contrat exigerait", contrat),
                ("Réponses simulées que le nouveau contrat refuserait", refusees),
                ("Fichiers générés qui changeraient", changeraient)]
    for titre, lignes in sections:
        corps += f"### {titre}\n\n" + ("".join(f"- {ligne}\n" for ligne in lignes) or "- aucun\n") + "\n"
    return 3, corps


def executer(mode: str, simuler: bool) -> tuple[int, str]:
    try:
        return plancher(simuler) if mode == "plancher" else montee()
    except SourceIllisible as erreur:
        motif = str(erreur)
    except SystemExit as erreur:
        # Un générateur qui ne retrouve pas sa table : la source a changé de forme.
        motif = f"un générateur échoue — {erreur}"
    return 2, f"## Concordance ({mode}) : ❓ INCONNU\n\n{motif}\n\nRien n'a pu être comparé : ce n'est pas un vert.\n"


def _autotest_comparer(dossier: pathlib.Path) -> None:
    depot, genere = dossier / "depot", dossier / "genere"
    entete = f"// {SIGNATURE}\n// Source : philippe-tressard/coprofirst v1.2.3 (commit {'a' * 40}), x.\n"
    for racine in (depot, genere):
        (racine / "CoproFirst").mkdir(parents=True)
        (racine / "CoproFirst" / "T.swift").write_text(entete + "let a = 1\n", encoding="utf-8")
    declares, ecrits = generes_du_depot(depot), ["CoproFirst/T.swift"]
    if declares != ecrits or comparer(depot, genere, ecrits, declares):
        raise SystemExit("❌ autotest : le cas zéro doit passer")
    (genere / "CoproFirst" / "T.swift").write_text(entete.replace("v1.2.3", "v1.2.4") + "let a = 1\n", "utf-8")
    if len(comparer(depot, genere, ecrits, declares)) != 1 or comparer(depot, genere, ecrits, declares,
                                                                       a_l_octet=False):
        raise SystemExit("❌ autotest : une autre version sans changement est un écart à l'octet seulement")
    (genere / "CoproFirst" / "T.swift").write_text(entete + "let a = 2\n", encoding="utf-8")
    ecarts = comparer(depot, genere, ecrits, declares)
    if len(ecarts) != 1 or "CoproFirst/T.swift" not in ecarts[0] or "+let a = 2" not in ecarts[0]:
        raise SystemExit(f"❌ autotest : un écart posé exprès doit être vu ({ecarts})")
    (depot / "CoproFirst" / "Vieux.swift").write_text(entete, encoding="utf-8")
    orphelins = comparer(depot, depot, ecrits, generes_du_depot(depot))
    if len(orphelins) != 1 or "plus aucun générateur" not in orphelins[0]:
        raise SystemExit(f"❌ autotest : un fichier généré orphelin doit être vu ({orphelins})")


def autotest() -> None:
    """Hors réseau : un cas zéro passe, un écart posé exprès est vu, chaque forme d'écart."""
    with tempfile.TemporaryDirectory() as dossier:
        _autotest_comparer(pathlib.Path(dossier))
    ancien = {"paths": {"/a": {}, "/b": {}}, "components": {"schemas": {
        "T": {"required": ["id"], "properties": {"id": {}, "vieux": {}}}, "E": {"enum": ["x", "y"]}, "R": {}}}}
    nouveau = {"paths": {"/a": {}}, "components": {"schemas": {
        "T": {"required": ["id", "neuf"], "properties": {"id": {}, "neuf": {}}}, "E": {"enum": ["x"]}}}}
    attendu = ["route retirée : `/b`", "schéma retiré : `R`", "`E` : valeur(s) retirée(s) de l'énumération — y",
               "`T` : champ(s) devenu(s) requis — `neuf`", "`T` : propriété(s) retirée(s) — `vieux`"]
    if exigences(ancien, nouveau) != attendu or exigences(ancien, ancien):
        raise SystemExit(f"❌ autotest : exigences d'une montée ({exigences(ancien, nouveau)})")
    _autotest_mesure()
    _tables.autotest()
    print("✅ autotest : cas zéro, version seule, écart posé exprès, orphelin, exigences d'une montée, "
          "plancher mesuré, tables du site (absente, vide, forme fausse, source du front)")


def _autotest_mesure() -> None:
    """Le plancher MESURÉ (#83) : une installation sous le plancher est vue, par ses nombres."""
    if sous_le_plancher({"a.fr": "1.14.0", "b.fr": "1.18.0"}, "1.14.0"):
        raise SystemExit("❌ autotest : au plancher et au-dessus, aucun écart")
    fautif = sous_le_plancher({"a.fr": "1.12.0", "b.fr": "1.18.0"}, "1.14.0")
    if len(fautif) != 1 or "`a.fr`" not in fautif[0]:
        raise SystemExit(f"❌ autotest : une installation sous le plancher doit être vue ({fautif})")
    if len(sous_le_plancher({"a.fr": "1.9.0"}, "1.15.0")) != 1:
        raise SystemExit("❌ autotest : 1.9.0 < 1.15.0 — une version se compare par ses nombres")
    contrats = [("v4", "1.18.0"), ("v3", "1.15.0"), ("v2", "1.14.0"), ("v1", "1.14.0")]
    if cible(contrats, "1.14.0") != "v2" or cible(contrats, "1.16.0") != "v3" or cible(contrats, "1.0.0"):
        raise SystemExit("❌ autotest : la cible d'une montée est la release la plus récente au contrat ≤ mesuré")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    choix = parser.add_mutually_exclusive_group()
    choix.add_argument("--plancher", action="store_true", help="écart au plancher (défaut)")
    choix.add_argument("--montee", action="store_true", help="une version publiée au-dessus du plancher")
    choix.add_argument("--autotest", action="store_true")
    parser.add_argument("--rapport", type=pathlib.Path, help="écrit le rapport (Markdown) dans ce fichier")
    parser.add_argument("--simuler-ecart", action="store_true", help="pose un écart exprès : doit rendre rouge")
    arguments = parser.parse_args()
    if arguments.autotest:
        autotest()
        return 0
    code, texte = executer("montee" if arguments.montee else "plancher", arguments.simuler_ecart)
    if arguments.rapport:
        arguments.rapport.write_text(texte[:60000], encoding="utf-8")
    print(texte)
    print({0: "✅ rien à signaler", 1: "❌ écart au plancher", 2: "❓ INCONNU", 3: "ℹ️ montée possible"}[code])
    return code


if __name__ == "__main__":
    sys.exit(main())
