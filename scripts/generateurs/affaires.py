# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les tables du menu Affaires (#11).

Le contrat d'API ne sert que des CODES (`CategorieTicket`, `StatutTicket`) : les
libellés et l'ordre vivent dans le front du site :

- les NATURES d'une affaire (`NATURES`, `tickets-categories.ts`), avec leur teinte
  (`[data-nature=…]` de `normes.css`, rendue en classe `badge-*` de la `PastilleTeinte`,
  #78). Les CATÉGORIES, et celles que chaque compte peut poser, sont SERVIES depuis le
  contrat 1.14.0 (`GET /tickets/referentiels`, `permise`) : elles ne se génèrent plus (#105) ;
- la TEINTE de chaque colonne du Kanban (`KANBAN_COLS` de `kanban.ts`), un jeton
  `--kanban-*` de la `Palette` (#34) nommé ici par son chemin, et le mot d'une colonne
  vide (`MOT_COLONNE_VIDE`). Les colonnes elles-mêmes (ordre, libellés), la colonne de
  chaque statut et les statuts clos sont SERVIS depuis le contrat 1.14.0
  (`GET /tickets/referentiels`, `TicketRead.colonne_kanban`) : ils ne se génèrent plus
  (#83, `scripts/verifier-regles-servies.py`) ;
- les GROUPES de suivi des statuts (`tickets.ts`). L'ordre des statuts, leurs libellés et
  ceux qu'une Suite propose sont SERVIS (`statuts`, `proposable`) : ils ne se génèrent
  plus (#105).

→ `CoproFirst/Fonctions/Affaires/Genere/TablesAffaires.swift`.

Chaque table se lit dans `tables-clients.json` de la release (`ctx.table`, #356) :
`naturesAffaire`, `teinteNature`, `colonnesKanban`, `motColonneVide`, `groupesSuivi`,
`categorieActualite` — plus aucun fichier du site ne se lit ici.
"""

from __future__ import annotations

import re

from generateurs._commun import FONCTIONS, chaine, ecrire_table, propriete, sans_pictogramme

SOURCES: list[str] = []  # tables-clients.json de la release (#356), pas les sources du site

VAR_KANBAN = re.compile(r"^var\(--(kanban-[a-z0-9-]+)\)$")
#: La teinte forte d'une nature (`teinteNature`, publiée depuis `[data-nature=…]` de `normes.css`).
VAR_COULEUR = re.compile(r"^var\(--color-([a-z-]+)\)$")
#: La couleur d'état du site → la classe `badge-*` qui la porte (`PastilleTeinte.teintes`).
BADGE_PAR_COULEUR = {
    "info": "badge-blue",
    "violet": "badge-purple",
    "orange": "badge-orange",
    "success": "badge-green",
    "danger": "badge-red",
}
#: L'en-tête « Source : » des fichiers générés, inchangé par la lecture des tables publiées
#: (la concordance compare l'en-tête au-delà de la version, #356) : les fichiers du site d'où
#: le serveur tire ces tables.
PROVENANCE = "front/src/lib/tickets-categories.ts, kanban.ts, tickets.ts, styles/normes.css"


def _texte(nom: str, valeur) -> str:
    if not isinstance(valeur, str) or not valeur:
        raise SystemExit(f"❌ {nom} : forme inattendue ({valeur!r}) — l'app doit l'apprendre")
    return valeur


def _liste(nom: str, valeur) -> list[dict]:
    if not (isinstance(valeur, list) and valeur and all(isinstance(v, dict) for v in valeur)):
        raise SystemExit(f"❌ {nom} : forme inattendue ({valeur!r}) — l'app doit l'apprendre")
    return valeur


def badge_de_nature(code: str, teintes: dict) -> str:
    """La classe `badge-*` de la teinte que `teinteNature` donne à une nature."""
    teinte = teintes.get(code)
    m = VAR_COULEUR.match(str(teinte.get("--nature-fort", ""))) if isinstance(teinte, dict) else None
    couleur = m.group(1) if m else None
    if couleur not in BADGE_PAR_COULEUR:
        raise SystemExit(f"❌ teinteNature : la teinte de « {code} » ({teinte!r}) n'a pas de classe badge-* connue")
    return BADGE_PAR_COULEUR[couleur]


def natures(ctx) -> str:
    # Les catégories et ce que chaque compte peut poser sont SERVIS (`GET /tickets/referentiels`,
    # `permise`, #105) : plus lus ici.
    teintes = ctx.table("teinteNature")
    if not isinstance(teintes, dict):
        raise SystemExit(f"❌ teinteNature : forme inattendue ({teintes!r}) — l'app doit l'apprendre")
    natures = [
        f"        NatureAffaire(code: {chaine(n['val'])}, libelle: {chaine(n['libelle'])}, "
        f"abrege: {chaine(n['abrege'])}, emoji: {chaine(n['emoji'])}, icone: {chaine(n['icone'])}, "
        f"badge: {chaine(badge_de_nature(n['val'], teintes))}),\n"
        for n in _liste("naturesAffaire", ctx.table("naturesAffaire"))
    ]
    return (
        "    /// Les natures d'une affaire, dans l'ordre du filtre — `NATURES`.\n"
        "    static let natures: [NatureAffaire] = [\n" + "".join(natures) + "    ]\n"
    )


def kanban(ctx) -> str:
    lignes = []
    for c in _liste("colonnesKanban", ctx.table("colonnesKanban")):
        m = VAR_KANBAN.match(str(c.get("color")))
        if not m:
            raise SystemExit(f"❌ colonnesKanban : la teinte de {c.get('id')} n'est pas un jeton --kanban-* "
                             f"({c.get('color')})")
        lignes.append(f"        {chaine(c['id'])}: \\.{propriete(m.group(1))},\n")
    return (
        "    /// La teinte de chaque colonne du Kanban, par son code (`KANBAN_COLS`) — les colonnes\n"
        "    /// elles-mêmes sont SERVIES (`GET /tickets/referentiels`).\n"
        "    static let teintesKanban: [String: KeyPath<Palette, Color> & Sendable] = [\n"
        + "".join(lignes) + "    ]\n"
        "    /// Ce qu'une colonne vide affiche (`MOT_COLONNE_VIDE`).\n"
        f"    static let colonneVide = {chaine(_texte('motColonneVide', ctx.table('motColonneVide')))}\n"
    )


def statuts(ctx) -> str:
    # Les états du cycle, leurs libellés et ceux qu'une Suite propose sont SERVIS
    # (`statuts`, `proposable`, #105) : `STATUTS_TICKET` n'est plus lu ici.
    groupes = [
        f"        GroupeDeSuivi(code: {chaine(g['value'])}, libelle: {chaine(sans_pictogramme(g['label']))}, "
        f"statuts: [{', '.join(chaine(s) for s in g['statuts'])}]),\n"
        for g in _liste("groupesSuivi", ctx.table("groupesSuivi"))
    ]
    return (
        "    /// Des statuts que le filtre « Suivi » réunit sous une option (`GROUPES_SUIVI`).\n"
        "    static let groupesDeSuivi: [GroupeDeSuivi] = [\n" + "".join(groupes) + "    ]\n"
        "    /// La catégorie d'une actualité (`CATEGORIE_ACTUALITE`).\n"
        f"    static let categorieActualite = {chaine(_texte('categorieActualite', ctx.table('categorieActualite')))}\n"
    )


def generer(ctx) -> str:
    corps = natures(ctx) + kanban(ctx) + statuts(ctx)
    ecrire_table(ctx, FONCTIONS / "Affaires" / "Genere" / "TablesAffaires.swift", PROVENANCE, "TablesAffaires",
                 "Ce que le site écrit des affaires et que le contrat ne sert pas.", corps, swiftui=True)
    return "natures, teintes du Kanban et groupes de suivi des affaires"
