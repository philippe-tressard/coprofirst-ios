# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les tables de la Communauté et du Profil (#14).

Le contrat d'API ne sert que des CODES : libellés, teintes et seuils vivent dans
coprofirst. Ce que le site AFFICHE se lit dans les tables qu'il publie
(`tables-clients.json`) ; quand une règle vit des deux côtés, la source est le
SERVEUR — c'est lui qui juge :

- idées : `statutsIdee` ;
- annonces : `typesAnnonce`, `categoriesAnnonce`, `trisAnnonce`, `statutsAnnonce` et la
  teinte de chaque statut (`teinteStatutAnnonce`) ;
- avis : les bornes et les seuils de la note (`api/app/utils/avis.py`, serveur) ;
- thème : `optionsTheme`, `cookieTheme`, `themeParDefaut` ;
- préférences de notification : les défauts (`DEFAUTS`, `api/app/utils/preferences_mail.py`,
  serveur) et les deux canaux (`canauxNotifications`) ;
- profils demandables (`statutsDemandables`) ;
- longueur minimale d'un mot de passe (`verifier_robustesse`, `api/app/utils/mots_de_passe.py`).

→ `CoproFirst/Fonctions/Communaute/Genere/TablesCommunaute.swift` et
`CoproFirst/Fonctions/Profil/Genere/TablesProfil.swift`.
"""

from __future__ import annotations

import re

from generateurs._commun import FONCTIONS, OPTION, chaine, couples, ecrire_table
from generateurs._tables import source

# Les fichiers Python de l'API : le site ne les publie pas en table (#128).
SOURCES = [
    "api/app/utils/avis.py",
    "api/app/utils/preferences_mail.py",
    "api/app/utils/mots_de_passe.py",
]
API = "api/app/utils/"


def entier(texte: str, motif: str, source_lue: str) -> int:
    m = re.search(motif, texte)
    if not m:
        raise SystemExit(f"❌ {source_lue} : « {motif} » introuvable — la source a changé")
    return int(m.group(1))


def defauts_preferences(texte: str) -> dict[str, bool]:
    """`DEFAUTS` du serveur, ses clés résolues par les constantes du module."""
    constantes = dict(re.findall(r'^([A-Z_]+)\s*=\s*"([a-z_]+)"', texte, re.M))
    corps = re.search(r"^DEFAUTS[^=]*=\s*\{(.*?)\}", texte, re.S | re.M)
    if not corps:
        raise SystemExit("❌ DEFAUTS introuvable dans preferences_mail.py")
    paires = re.findall(r"([A-Z_]+):\s*(True|False)", corps.group(1))
    if not paires:
        raise SystemExit("❌ DEFAUTS vide ou illisible")
    return {constantes[nom]: valeur == "True" for nom, valeur in paires}


def element(type_: str, **champs) -> str:
    """Un élément de tableau Swift ; au-delà de 120 colonnes, un argument par ligne."""
    arguments = [f"{nom}: {chaine(valeur)}" for nom, valeur in champs.items()]
    ligne = f"        {type_}({', '.join(arguments)}),\n"
    if len(ligne) <= 121:
        return ligne
    return f"        {type_}(\n" + "".join(f"            {a},\n" for a in arguments[:-1]) + (
        f"            {arguments[-1]}),\n")


def statut(code: str, libelle: str, pastille: str) -> str:
    return element("EntreeStatut", code=code, libelle=libelle, pastille=pastille)


def options(ctx, table: str) -> list[tuple[str, str]]:
    return [(e["val"], e["label"]) for e in ctx.table(table, [OPTION])]


def communaute(ctx) -> str:
    avis = ctx.lire(API + "avis.py")
    teintes = ctx.table("teinteStatutAnnonce", {str: str})
    statuts_annonce = ctx.table("statutsAnnonce", [OPTION])
    manquantes = [s["val"] for s in statuts_annonce if s["val"] not in teintes]
    if manquantes:
        raise SystemExit(f"❌ teinteStatutAnnonce ne teinte pas : {manquantes}")
    return (
        "    /// Les états d'une idée, dans l'ordre du cycle de vie (`STATUTS_IDEE`).\n"
        "    static let statutsIdee: [EntreeStatut] = [\n"
        + "".join(statut(s["value"], s["label"], s["badge"])
                  for s in ctx.table("statutsIdee", [{"value": str, "label": str, "badge": str}]))
        + "    ]\n"
        + couples("typesAnnonce", "Les types d'annonce (`TYPES_ANNONCE`).", options(ctx, "typesAnnonce"))
        + couples("categoriesAnnonce", "Les catégories d'annonce (`CATEGORIES_ANNONCE`).",
                  options(ctx, "categoriesAnnonce"))
        + couples("trisAnnonce", "Les tris des annonces (`TRIS_ANNONCE`).", options(ctx, "trisAnnonce"))
        + "    /// Les états d'une annonce et leur teinte (`STATUTS_ANNONCE`, `TEINTE_STATUT_ANNONCE`).\n"
        "    static let statutsAnnonce: [EntreeStatut] = [\n"
        + "".join(statut(s["val"], s["label"], teintes[s["val"]]) for s in statuts_annonce)
        + "    ]\n"
        "    /// La note d'un avis et ses seuils — la règle du SERVEUR (`utils/avis.py`) :\n"
        "    /// sous `noteRemarque`, ce qui a manqué ; à partir de `notePubliable`, l'accord de diffusion.\n"
        f"    static let noteMin = {entier(avis, r'(?m)^NOTE_MIN\s*=\s*(\d+)', 'avis.py')}\n"
        f"    static let noteMax = {entier(avis, r'(?m)^NOTE_MAX\s*=\s*(\d+)', 'avis.py')}\n"
        f"    static let noteRemarque = {entier(avis, r'(?m)^NOTE_REMARQUE\s*=\s*(\d+)', 'avis.py')}\n"
        f"    static let notePubliable = {entier(avis, r'(?m)^NOTE_PUBLIABLE\s*=\s*(\d+)', 'avis.py')}\n"
    )


def profil(ctx) -> str:
    defauts = defauts_preferences(ctx.lire(API + "preferences_mail.py"))
    canaux = ctx.table("canauxNotifications", [{"titre": str, "mon": str, "autres": str}])
    for canal in canaux:
        for cle in ("mon", "autres"):
            if canal[cle] not in defauts:
                raise SystemExit(f"❌ canauxNotifications : {canal[cle]} n'a pas de défaut côté serveur")
    longueur = entier(ctx.lire(API + "mots_de_passe.py"), r"len\(password\)\s*<\s*(\d+)", "mots_de_passe.py")
    return (
        "    /// Le thème : une préférence de l'APPAREIL (le cookie du site), ses choix (`OPTIONS_THEME`).\n"
        f"    static let cleTheme = {chaine(ctx.table('cookieTheme', str))}\n"
        f"    static let themeParDefaut = {chaine(ctx.table('themeParDefaut', str))}\n"
        "    static let optionsTheme: [OptionTheme] = [\n"
        + "".join(
            element("OptionTheme", code=o["val"], libelle=o["label"], detail=o["desc"])
            for o in ctx.table("optionsTheme", [{**OPTION, "desc": str}]))
        + "    ]\n"
        "    /// Les défauts d'une préférence jamais réglée — ceux du SERVEUR (`DEFAUTS`).\n"
        "    static let defautsPreferences: [String: Bool] = [\n"
        + "".join(f"        {chaine(cle)}: {'true' if v else 'false'},\n" for cle, v in defauts.items())
        + "    ]\n"
        "    /// Les deux canaux et leurs deux cases (`CANAUX_NOTIFS`).\n"
        "    static let canauxNotifications: [CanalNotifications] = [\n"
        + "".join(element("CanalNotifications", titre=c["titre"], mon=c["mon"], autres=c["autres"]) for c in canaux)
        + "    ]\n"
        "    /// Les profils qu'on peut demander depuis son profil (`STATUTS_DEMANDABLES`).\n"
        "    static let statutsDemandables: [String] = [\n"
        + "".join(f"        {chaine(s)},\n" for s in ctx.table("statutsDemandables", [str]))
        + "    ]\n"
        "    /// La longueur minimale d'un nouveau mot de passe (`verifier_robustesse`, serveur).\n"
        f"    static let longueurMinimaleMotDePasse = {longueur}\n"
    )


def generer(ctx) -> str:
    ecrire_table(ctx, FONCTIONS / "Communaute" / "Genere" / "TablesCommunaute.swift",
                 source("statutsIdee", "typesAnnonce", "categoriesAnnonce", "trisAnnonce", "statutsAnnonce",
                        "teinteStatutAnnonce") + " ; api/app/utils/avis.py", "TablesCommunaute",
                 "Ce que le site écrit de la Communauté et que le contrat ne sert pas.", communaute(ctx))
    ecrire_table(ctx, FONCTIONS / "Profil" / "Genere" / "TablesProfil.swift",
                 source("cookieTheme", "themeParDefaut", "optionsTheme", "canauxNotifications", "statutsDemandables")
                 + " ; api/app/utils/preferences_mail.py et mots_de_passe.py", "TablesProfil",
                 "Ce que le site écrit du Profil et que le contrat ne sert pas.", profil(ctx))
    return "idées, annonces, avis, thème, préférences et profils"
