# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les tables du menu Affaires (#11).

Le contrat d'API ne sert que des CODES (`CategorieTicket`, `StatutTicket`) : les
libellés et l'ordre sont ceux que le site publie (`tables-clients.json`) :

- les NATURES d'une affaire (`naturesAffaire`), avec leur teinte (`teinteNature` : le
  `--nature-fort` de chaque `[data-nature]`, rendu en classe `badge-*` de la
  `PastilleTeinte`, #78). Les CATÉGORIES, et celles que chaque compte peut poser, sont
  SERVIES (`GET /tickets/referentiels`, `permise`) : elles ne se génèrent plus dans l'app
  (#105) — `categoriesTicket` ne sert qu'à la réponse simulée (`saisie_affaire.py`) ;
- la TEINTE de chaque colonne du Kanban (`colonnesKanban`), un jeton `--kanban-*` de
  la `Palette` (#34) nommé ici par son chemin, et le mot d'une colonne vide
  (`motColonneVide`). Les colonnes elles-mêmes (ordre, libellés), la colonne de
  chaque statut et les statuts clos sont SERVIS (`GET /tickets/referentiels`,
  `TicketRead.colonne_kanban`) : ils ne se génèrent plus (#83,
  `scripts/verifier-regles-servies.py`) ;
- les GROUPES de suivi des statuts (`groupesSuivi`) et la catégorie d'une actualité
  (`categorieActualite`). L'ordre des statuts, leurs libellés et ceux qu'une Suite
  propose sont SERVIS (`statuts`, `proposable`) : ils ne se génèrent plus (#105).

→ `CoproFirst/Fonctions/Affaires/Genere/TablesAffaires.swift`.
"""

from __future__ import annotations

from generateurs._commun import FONCTIONS, chaine, ecrire_table, jeton_de, propriete, sans_pictogramme
from generateurs._tables import Facultatif, source

SOURCES: list[str] = []

#: La couleur d'état du site → la classe `badge-*` qui la porte (`PastilleTeinte.teintes`).
BADGE_PAR_COULEUR = {
    "info": "badge-blue",
    "violet": "badge-purple",
    "orange": "badge-orange",
    "success": "badge-green",
    "danger": "badge-red",
}
CATEGORIE = {"value": str, "label": str, "emoji": str, "description": str, "carnet": Facultatif(bool),
             "reserveCS": Facultatif(bool), "enTete": Facultatif(bool)}


def categories_du_site(ctx) -> list[dict]:
    """`categoriesTicket` — pour la seule réponse simulée des catégories servies
    (`saisie_affaire.py`) : l'app lit les catégories du serveur (#105)."""
    return ctx.table("categoriesTicket", [CATEGORIE])


def natures_d_affaire(ctx) -> list[dict]:
    """`naturesAffaire` — lue ici seulement : `pictogrammes.py` en tire les pictogrammes de
    la gouttière."""
    return ctx.table("naturesAffaire", [{"val": str, "libelle": str, "abrege": str, "emoji": str, "icone": str}])


def badge_de_nature(code: str, teintes: dict[str, dict]) -> str:
    """La classe `badge-*` de la teinte que le site donne à une nature (`--nature-fort`)."""
    if code not in teintes:
        raise SystemExit(f"❌ teinteNature : la nature « {code} » n'a pas de teinte")
    couleur = jeton_de(teintes[code]["--nature-fort"], f"teinteNature.{code}").removeprefix("color-")
    if couleur not in BADGE_PAR_COULEUR:
        raise SystemExit(f"❌ teinteNature : la teinte de « {code} » ({couleur}) n'a pas de classe badge-* connue")
    return BADGE_PAR_COULEUR[couleur]


def natures(ctx) -> str:
    teintes = ctx.table("teinteNature", {str: {"--nature-fort": str}})
    lignes = [
        f"        NatureAffaire(code: {chaine(n['val'])}, libelle: {chaine(n['libelle'])}, "
        f"abrege: {chaine(n['abrege'])}, emoji: {chaine(n['emoji'])}, icone: {chaine(n['icone'])}, "
        f"badge: {chaine(badge_de_nature(n['val'], teintes))}),\n"
        for n in natures_d_affaire(ctx)
    ]
    return (
        "    /// Les natures d'une affaire, dans l'ordre du filtre — `NATURES`.\n"
        "    static let natures: [NatureAffaire] = [\n" + "".join(lignes) + "    ]\n"
    )


def kanban(ctx) -> str:
    lignes = []
    for c in ctx.table("colonnesKanban", [{"id": str, "color": str}]):
        jeton = jeton_de(c["color"], f"colonnesKanban.{c['id']}")
        if not jeton.startswith("kanban-"):
            raise SystemExit(f"❌ colonnesKanban : la teinte de {c['id']} n'est pas un jeton --kanban-* ({c['color']})")
        lignes.append(f"        {chaine(c['id'])}: \\.{propriete(jeton)},\n")
    return (
        "    /// La teinte de chaque colonne du Kanban, par son code (`KANBAN_COLS`) — les colonnes\n"
        "    /// elles-mêmes sont SERVIES (`GET /tickets/referentiels`).\n"
        "    static let teintesKanban: [String: KeyPath<Palette, Color> & Sendable] = [\n"
        + "".join(lignes) + "    ]\n"
        "    /// Ce qu'une colonne vide affiche (`MOT_COLONNE_VIDE`).\n"
        f"    static let colonneVide = {chaine(ctx.table('motColonneVide', str))}\n"
    )


def statuts(ctx) -> str:
    # Les états du cycle, leurs libellés et ceux qu'une Suite propose sont SERVIS
    # (`statuts`, `proposable`, #105) : `statutsTicket` n'est pas lu ici.
    groupes = [
        f"        GroupeDeSuivi(code: {chaine(g['value'])}, libelle: {chaine(sans_pictogramme(g['label']))}, "
        f"statuts: [{', '.join(chaine(s) for s in g['statuts'])}]),\n"
        for g in ctx.table("groupesSuivi", [{"value": str, "label": str, "statuts": [str]}])
    ]
    return (
        "    /// Des statuts que le filtre « Suivi » réunit sous une option (`GROUPES_SUIVI`).\n"
        "    static let groupesDeSuivi: [GroupeDeSuivi] = [\n" + "".join(groupes) + "    ]\n"
        "    /// La catégorie d'une actualité (`CATEGORIE_ACTUALITE`).\n"
        f"    static let categorieActualite = {chaine(ctx.table('categorieActualite', str))}\n"
    )


def generer(ctx) -> str:
    corps = natures(ctx) + kanban(ctx) + statuts(ctx)
    ecrire_table(ctx, FONCTIONS / "Affaires" / "Genere" / "TablesAffaires.swift",
                 source("naturesAffaire", "teinteNature", "colonnesKanban", "motColonneVide", "groupesSuivi",
                        "categorieActualite"), "TablesAffaires",
                 "Ce que le site écrit des affaires et que le contrat ne sert pas.", corps, swiftui=True)
    return "natures, teintes du Kanban et groupes de suivi des affaires"
