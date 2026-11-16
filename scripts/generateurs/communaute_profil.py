# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les tables de la Communauté et du Profil (#14).

Le contrat d'API ne sert que des CODES : libellés, teintes et seuils vivent dans le
code de coprofirst. Quand une règle vit des deux côtés, la source est le SERVEUR —
c'est lui qui juge. Tout se lit dans les pièces de la release : ce que le front publie
dans `tables-clients.json` (#128), les constantes du serveur dans `constantes-clients.json`
(depuis v3.102.0, #237) — jamais dans les sources :

- idées : `statutsIdee` (`STATUTS_IDEE`, publiée) ;
- annonces : `typesAnnonce`, `categoriesAnnonce`, `trisAnnonce`, `statutsAnnonce` et la
  teinte de chaque statut (`teinteStatutAnnonce`), publiées ;
- avis : les bornes et les seuils de la note (`noteMin`, `noteMax`, `noteRemarque`,
  `notePubliable`, constantes du serveur) ;
- thème : `optionsTheme`, `cookieTheme`, `themeParDefaut`, publiées ;
- préférences de notification : les défauts (`defautsPreferences`, constante du serveur) et
  les deux canaux (`canauxNotifications`, publiée) ;
- profils demandables (`statutsDemandables`, publiée) ;
- longueur minimale d'un mot de passe (`longueurMinMotDePasse`, constante du serveur).

→ `CoproFirst/Fonctions/Communaute/Genere/TablesCommunaute.swift` et
`CoproFirst/Fonctions/Profil/Genere/TablesProfil.swift`.
"""

from __future__ import annotations

from generateurs._commun import FONCTIONS, chaine, ecrire_table

#: Rien ne se lit dans les sources : tables et constantes viennent de la release (#237).
SOURCES: list[str] = []
NOTES = ("noteMin", "noteMax", "noteRemarque", "notePubliable")


def entier(ctx, nom: str) -> int:
    valeur = ctx.constante(nom)
    if not isinstance(valeur, int) or isinstance(valeur, bool):
        raise SystemExit(f"❌ constantes-clients.json : {nom} n'est pas un entier ({valeur!r})")
    return valeur


def defauts_preferences(ctx) -> dict[str, bool]:
    """`DEFAUTS` du serveur, clé par clé, tel que publié."""
    defauts = ctx.constante("defautsPreferences")
    if not isinstance(defauts, dict) or not defauts or not all(isinstance(v, bool) for v in defauts.values()):
        raise SystemExit(f"❌ constantes-clients.json : defautsPreferences illisible ({defauts!r})")
    return defauts


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


def libelles(table: list, cle: str = "val") -> str:
    return "".join(f"        ({chaine(e[cle])}, {chaine(e['label'])}),\n" for e in table)


def communaute(ctx) -> str:
    teintes = ctx.table("teinteStatutAnnonce")
    statuts_annonce = ctx.table("statutsAnnonce")
    manquantes = [s["val"] for s in statuts_annonce if s["val"] not in teintes]
    if manquantes:
        raise SystemExit(f"❌ teinteStatutAnnonce ne teinte pas : {manquantes}")
    return (
        "    /// Les états d'une idée, dans l'ordre du cycle de vie (`STATUTS_IDEE`).\n"
        "    static let statutsIdee: [EntreeStatut] = [\n"
        + "".join(statut(s["value"], s["label"], s["badge"]) for s in ctx.table("statutsIdee"))
        + "    ]\n"
        "    /// Les types d'annonce (`TYPES_ANNONCE`).\n"
        "    static let typesAnnonce: [(code: String, libelle: String)] = [\n"
        + libelles(ctx.table("typesAnnonce"))
        + "    ]\n"
        "    /// Les catégories d'annonce (`CATEGORIES_ANNONCE`).\n"
        "    static let categoriesAnnonce: [(code: String, libelle: String)] = [\n"
        + libelles(ctx.table("categoriesAnnonce"))
        + "    ]\n"
        "    /// Les tris des annonces (`TRIS_ANNONCE`).\n"
        "    static let trisAnnonce: [(code: String, libelle: String)] = [\n"
        + libelles(ctx.table("trisAnnonce"))
        + "    ]\n"
        "    /// Les états d'une annonce et leur teinte (`STATUTS_ANNONCE`, `TEINTE_STATUT_ANNONCE`).\n"
        "    static let statutsAnnonce: [EntreeStatut] = [\n"
        + "".join(statut(s["val"], s["label"], teintes[s["val"]]) for s in statuts_annonce)
        + "    ]\n"
        "    /// La note d'un avis et ses seuils — la règle du SERVEUR (`utils/avis.py`) :\n"
        "    /// sous `noteRemarque`, ce qui a manqué ; à partir de `notePubliable`, l'accord de diffusion.\n"
        + "".join(f"    static let {nom} = {entier(ctx, nom)}\n" for nom in NOTES)
    )


def profil(ctx) -> str:
    defauts = defauts_preferences(ctx)
    canaux = ctx.table("canauxNotifications")  # clés déjà résolues par le site
    for canal in canaux:
        for cle in ("mon", "autres"):
            if canal[cle] not in defauts:
                raise SystemExit(f"❌ CANAUX_NOTIFS : {canal[cle]} n'a pas de défaut côté serveur")
    longueur = entier(ctx, "longueurMinMotDePasse")
    return (
        "    /// Le thème : une préférence de l'APPAREIL (le cookie du site), ses choix (`OPTIONS_THEME`).\n"
        f"    static let cleTheme = {chaine(ctx.table('cookieTheme'))}\n"
        f"    static let themeParDefaut = {chaine(ctx.table('themeParDefaut'))}\n"
        "    static let optionsTheme: [OptionTheme] = [\n"
        + "".join(
            element("OptionTheme", code=o["val"], libelle=o["label"], detail=o["desc"])
            for o in ctx.table("optionsTheme"))
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
        + "".join(f"        {chaine(s)},\n" for s in ctx.table("statutsDemandables"))
        + "    ]\n"
        "    /// La longueur minimale d'un nouveau mot de passe (`LONGUEUR_MIN_MOT_DE_PASSE`, serveur).\n"
        f"    static let longueurMinimaleMotDePasse = {longueur}\n"
    )


def generer(ctx) -> str:
    ecrire_table(ctx, FONCTIONS / "Communaute" / "Genere" / "TablesCommunaute.swift",
                 ctx.provenance_tables("statutsIdee", "typesAnnonce", "categoriesAnnonce", "trisAnnonce", "statutsAnnonce",
                        "teinteStatutAnnonce") + " ; " + ctx.provenance_constantes(*NOTES), "TablesCommunaute",
                 "Ce que le site écrit de la Communauté et que le contrat ne sert pas.", communaute(ctx))
    ecrire_table(ctx, FONCTIONS / "Profil" / "Genere" / "TablesProfil.swift",
                 ctx.provenance_tables("cookieTheme", "themeParDefaut", "optionsTheme", "canauxNotifications", "statutsDemandables")
                 + " ; " + ctx.provenance_constantes("defautsPreferences", "longueurMinMotDePasse"),
                 "TablesProfil",
                 "Ce que le site écrit du Profil et que le contrat ne sert pas.", profil(ctx))
    return "idées, annonces, avis, thème, préférences et profils"
