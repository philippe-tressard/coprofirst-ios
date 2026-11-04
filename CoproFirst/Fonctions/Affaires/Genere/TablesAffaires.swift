// GÉNÉRÉ par scripts/generer-affaires.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// swiftlint:disable line_length
// Source : philippe-tressard/coprofirst v3.61.0 (commit 4239610fcf1658b53c84664087f7e5d0650fe834),
//   front/src/lib/tickets-categories.ts, kanban.ts, tickets.ts, pages.ts ;
//   front/src/styles/socle.css et palette-sombre.css.

import SwiftUI

/// Ce que le site écrit des affaires et que le contrat ne sert pas.
enum TablesAffaires {
    /// Les catégories, dans l'ordre du site (fréquence attendue) — `CATEGORIES_TICKET`.
    static let categories: [CategorieAffaire] = [
        CategorieAffaire(code: "panne", libelle: "Panne", emoji: "🛠️", description: "Ascenseur, chauffage, éclairage, fuite, porte — à réparer", carnet: true, reserveCS: false, enTete: false),
        CategorieAffaire(code: "nuisance", libelle: "Nuisance & propreté", emoji: "📢", description: "Bruit, odeurs, stationnement…", carnet: false, reserveCS: false, enTete: false),
        CategorieAffaire(code: "acces_accueil", libelle: "Accès & accueil", emoji: "🔑", description: "Interphone, boîte aux lettres, emménagement", carnet: false, reserveCS: false, enTete: false),
        CategorieAffaire(code: "espaces_verts", libelle: "Espaces verts", emoji: "🌳", description: "Élagage, haies, arrosage, allées…", carnet: true, reserveCS: false, enTete: false),
        CategorieAffaire(code: "sinistre", libelle: "Sinistre", emoji: "💧", description: "Dégât constaté : eau, incendie, vandalisme…", carnet: true, reserveCS: false, enTete: false),
        CategorieAffaire(code: "etude_travaux", libelle: "Étude & travaux", emoji: "🏗️", description: "Diagnostic, sondage, devis, chantier suivi par le conseil", carnet: true, reserveCS: true, enTete: false),
        CategorieAffaire(code: "entretien", libelle: "Entretien", emoji: "🧰", description: "Visite ou maintenance d’un prestataire, récurrente ou non", carnet: true, reserveCS: true, enTete: false),
        CategorieAffaire(code: "question", libelle: "Question", emoji: "❓", description: "Information, procédure…", carnet: false, reserveCS: false, enTete: false),
        CategorieAffaire(code: "bug", libelle: "Bug", emoji: "🐛", description: "Pb technique sur le site", carnet: false, reserveCS: false, enTete: false),
        CategorieAffaire(code: "actualite", libelle: "Actualité", emoji: "📰", description: "Information — suivi optionnel", carnet: false, reserveCS: true, enTete: true),
    ]
    /// Les natures d'une affaire, dans l'ordre du filtre — `NATURES`.
    static let natures: [NatureAffaire] = [
        NatureAffaire(code: "actualite", libelle: "Actualité", emoji: "📰"),
        NatureAffaire(code: "calendrier", libelle: "Calendrier", emoji: "📅"),
        NatureAffaire(code: "activite", libelle: "Affaire", emoji: "🛠️"),
    ]
    /// Les colonnes du Kanban — ces colonnes SONT le workflow (`KANBAN_COLS`).
    static let colonnesKanban: [ColonneKanban] = [
        ColonneKanban(id: "ag", libelle: "AG", libelleCourt: "AG",
                      teinte: Color(clair: RVBA(0x72, 0x40, 0xDA, 1), sombre: RVBA(0xA4, 0x7F, 0xF8, 1))),
        ColonneKanban(id: "cs", libelle: "CS (en cours)", libelleCourt: "CS",
                      teinte: Color(clair: RVBA(0x15, 0x5C, 0xCE, 1), sombre: RVBA(0x58, 0x94, 0xF6, 1))),
        ColonneKanban(id: "syndic", libelle: "Syndic (en cours)", libelleCourt: "Syndic",
                      teinte: Color(clair: RVBA(0x7F, 0x5D, 0x05, 1), sombre: RVBA(0xF5, 0x9E, 0x0B, 1))),
        ColonneKanban(id: "fournisseur", libelle: "Prestataire (en cours)", libelleCourt: "Prestataire",
                      teinte: Color(clair: RVBA(0xA5, 0x46, 0x02, 1), sombre: RVBA(0xF9, 0x73, 0x16, 1))),
        ColonneKanban(id: "termine", libelle: "Terminé", libelleCourt: "Terminé",
                      teinte: Color(clair: RVBA(0x02, 0x72, 0x2F, 1), sombre: RVBA(0x22, 0xC5, 0x5E, 1))),
        ColonneKanban(id: "annule", libelle: "Annulé", libelleCourt: "Annulé",
                      teinte: Color(clair: RVBA(0x5E, 0x64, 0x6F, 1), sombre: RVBA(0x9C, 0xA3, 0xAF, 1))),
    ]
    /// Statut d'une affaire → sa colonne ; un statut absent sort l'affaire du tableau.
    static let colonneParStatut: [String: String] = [
        "ouvert": "cs",
        "en_ag": "ag",
        "en_cours": "syndic",
        "chez_prestataire": "fournisseur",
        "résolu": "termine",
        "annulé": "annule",
    ]
    /// Ce qu'une colonne vide affiche (`MOT_COLONNE_VIDE`).
    static let colonneVide = "Aucune affaire"
    /// Les statuts du cycle d'une affaire, dans l'ordre du site (`STATUTS_TICKET`).
    static let ordreDesStatuts: [String] = ["ouvert", "en_ag", "en_cours", "chez_prestataire", "résolu", "annulé"]
    /// Une affaire close ne demande plus de suivi (`STATUTS_TICKET_CLOS`).
    static let statutsClos: Set<String> = ["résolu", "annulé", "fermé"]
    /// Des statuts que le filtre « Suivi » réunit sous une option (`GROUPES_SUIVI`).
    static let groupesDeSuivi: [GroupeDeSuivi] = [
        GroupeDeSuivi(code: "en_cours", libelle: "En cours", statuts: ["en_ag", "en_cours", "chez_prestataire"]),
    ]
    /// La catégorie d'une actualité (`CATEGORIE_ACTUALITE`).
    static let categorieActualite = "actualite"
    /// Les onglets de la page `mes-demandes`, et la réserve de chacun (`pages.ts`).
    static let onglets: [OngletAffaires] = [
        OngletAffaires(id: "liste", libelle: "Liste", reserve: nil),
        OngletAffaires(id: "kanban", libelle: "Kanban", reserve: "nonLocataire"),
        OngletAffaires(id: "archives", libelle: "Archives", reserve: nil),
    ]
}
// swiftlint:enable line_length
