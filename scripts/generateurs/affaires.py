# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les tables du menu Affaires (#11).

Le contrat d'API ne sert que des CODES (`CategorieTicket`, `StatutTicket`) : les
libellés et l'ordre vivent dans le front du site :

- les CATÉGORIES d'une affaire (`CATEGORIES_TICKET`, `tickets-categories.ts`) et
  ses NATURES (`NATURES`, même fichier) ;
- les COLONNES du Kanban et la colonne de chaque statut (`KANBAN_COLS`,
  `COLONNE_PAR_STATUT_TICKET`, `MOT_COLONNE_VIDE` de `kanban.ts`) ; la teinte d'une
  colonne est un jeton `--kanban-*` de la `Palette` (#34), nommé ici par son chemin ;
- l'ORDRE des statuts, leurs GROUPES de suivi et les statuts CLOS (`tickets.ts`).

→ `CoproFirst/Fonctions/Affaires/Genere/TablesAffaires.swift`.
"""

from __future__ import annotations

import re

import lecture_ts
from generateurs._commun import FONCTIONS, booleen, chaine, ecrire_table, propriete, sans_pictogramme

SOURCES = [
    "front/src/lib/tickets-categories.ts",
    "front/src/lib/kanban.ts",
    "front/src/lib/tickets.ts",
]

VAR_KANBAN = re.compile(r"^var\(--(kanban-[a-z0-9-]+)\)$")


def table_simple(texte: str, nom: str) -> dict[str, str]:
    """`export const NOM: Record<string, string> = { cle: 'valeur', … }`."""
    m = re.search(rf"\bconst {nom}\b[^=]*=\s*\{{(.*?)\}};", texte, re.S)
    if not m:
        raise SystemExit(f"❌ {nom} introuvable")
    corps = re.sub(r"//[^\n]*", "", m.group(1))
    return dict(re.findall(r"([\wéèàù]+):\s*'([^']*)'", corps))


def constante(texte: str, nom: str) -> str:
    m = re.search(rf"\bconst {nom}\s*=\s*'([^']*)'", texte)
    if not m:
        raise SystemExit(f"❌ {nom} introuvable")
    return m.group(1)


def categories(ctx) -> str:
    texte = ctx.lire(SOURCES[0])
    lignes = [
        f"        CategorieAffaire(code: {chaine(c['value'])}, libelle: {chaine(c['label'])}, "
        f"emoji: {chaine(c['emoji'])}, description: {chaine(c['description'])}, "
        f"carnet: {booleen(c.get('carnet'))}, reserveCS: {booleen(c.get('reserveCS'))}, "
        f"enTete: {booleen(c.get('enTete'))}),\n"
        for c in lecture_ts.table(texte, "CATEGORIES_TICKET")
    ]
    natures = [
        f"        NatureAffaire(code: {chaine(n['val'])}, libelle: {chaine(n['libelle'])}, "
        f"emoji: {chaine(n['emoji'])}),\n"
        for n in lecture_ts.table(texte, "NATURES")
    ]
    return (
        "    /// Les catégories, dans l'ordre du site (fréquence attendue) — `CATEGORIES_TICKET`.\n"
        "    static let categories: [CategorieAffaire] = [\n" + "".join(lignes) + "    ]\n"
        "    /// Les natures d'une affaire, dans l'ordre du filtre — `NATURES`.\n"
        "    static let natures: [NatureAffaire] = [\n" + "".join(natures) + "    ]\n"
    )


def kanban(ctx) -> str:
    texte = ctx.lire(SOURCES[1])
    lignes = []
    for c in lecture_ts.table(texte, "KANBAN_COLS"):
        m = VAR_KANBAN.match(str(c["color"]))
        if not m:
            raise SystemExit(f"❌ KANBAN_COLS : la teinte de {c['id']} n'est pas un jeton --kanban-* ({c['color']})")
        lignes.append(
            f"        ColonneKanban(id: {chaine(c['id'])}, libelle: {chaine(c['label'])}, "
            f"libelleCourt: {chaine(c['labelCourt'])}, teinte: \\.{propriete(m.group(1))}),\n"
        )
    par_statut = table_simple(texte, "COLONNE_PAR_STATUT_TICKET")
    return (
        "    /// Les colonnes du Kanban — ces colonnes SONT le workflow (`KANBAN_COLS`).\n"
        "    static let colonnesKanban: [ColonneKanban] = [\n" + "".join(lignes) + "    ]\n"
        "    /// Statut d'une affaire → sa colonne ; un statut absent sort l'affaire du tableau.\n"
        "    static let colonneParStatut: [String: String] = [\n"
        + "".join(f"        {chaine(s)}: {chaine(c)},\n" for s, c in par_statut.items())
        + "    ]\n"
        "    /// Ce qu'une colonne vide affiche (`MOT_COLONNE_VIDE`).\n"
        f"    static let colonneVide = {chaine(constante(texte, 'MOT_COLONNE_VIDE'))}\n"
    )


def statuts(ctx) -> str:
    texte = ctx.lire(SOURCES[2])
    ordre = [s["value"] for s in lecture_ts.table(texte, "STATUTS_TICKET")]
    clos = lecture_ts.table(texte, "STATUTS_TICKET_CLOS")
    groupes = [
        f"        GroupeDeSuivi(code: {chaine(g['value'])}, libelle: {chaine(sans_pictogramme(g['label']))}, "
        f"statuts: [{', '.join(chaine(s) for s in g['statuts'])}]),\n"
        for g in lecture_ts.table(texte, "GROUPES_SUIVI")
    ]
    return (
        "    /// Les statuts du cycle d'une affaire, dans l'ordre du site (`STATUTS_TICKET`).\n"
        f"    static let ordreDesStatuts: [String] = [{', '.join(chaine(s) for s in ordre)}]\n"
        "    /// Une affaire close ne demande plus de suivi (`STATUTS_TICKET_CLOS`).\n"
        f"    static let statutsClos: Set<String> = [{', '.join(chaine(s) for s in clos)}]\n"
        "    /// Des statuts que le filtre « Suivi » réunit sous une option (`GROUPES_SUIVI`).\n"
        "    static let groupesDeSuivi: [GroupeDeSuivi] = [\n" + "".join(groupes) + "    ]\n"
        "    /// La catégorie d'une actualité (`CATEGORIE_ACTUALITE`).\n"
        f"    static let categorieActualite = {chaine(constante(texte, 'CATEGORIE_ACTUALITE'))}\n"
    )


def generer(ctx) -> str:
    corps = categories(ctx) + kanban(ctx) + statuts(ctx)
    ecrire_table(ctx, FONCTIONS / "Affaires" / "Genere" / "TablesAffaires.swift",
                 "front/src/lib/tickets-categories.ts, kanban.ts, tickets.ts", "TablesAffaires",
                 "Ce que le site écrit des affaires et que le contrat ne sert pas.", corps, swiftui=True)
    return "catégories, natures, colonnes du Kanban et statuts des affaires"
