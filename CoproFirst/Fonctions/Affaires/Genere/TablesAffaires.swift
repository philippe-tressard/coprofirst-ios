// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.73.0 (commit de78b44da68b31e8e256ff1ef80e4507ac49d24b), front/src/lib/tickets-categories.ts, kanban.ts, tickets.ts, styles/normes.css.
// swiftlint:disable line_length

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
        NatureAffaire(code: "actualite", libelle: "Actualité", abrege: "ACTU.", emoji: "📰", badge: "badge-blue"),
        NatureAffaire(code: "calendrier", libelle: "Calendrier", abrege: "CAL.", emoji: "📅", badge: "badge-purple"),
        NatureAffaire(code: "activite", libelle: "Affaire", abrege: "AFF.", emoji: "🛠️", badge: "badge-orange"),
    ]
    /// Les colonnes du Kanban — ces colonnes SONT le workflow (`KANBAN_COLS`).
    static let colonnesKanban: [ColonneKanban] = [
        ColonneKanban(id: "ag", libelle: "AG", libelleCourt: "AG", teinte: \.kanbanAg),
        ColonneKanban(id: "cs", libelle: "CS (en cours)", libelleCourt: "CS", teinte: \.kanbanCs),
        ColonneKanban(id: "syndic", libelle: "Syndic (en cours)", libelleCourt: "Syndic", teinte: \.kanbanSyndic),
        ColonneKanban(id: "fournisseur", libelle: "Prestataire (en cours)", libelleCourt: "Prestataire", teinte: \.kanbanFournisseur),
        ColonneKanban(id: "termine", libelle: "Terminé", libelleCourt: "Terminé", teinte: \.kanbanTermine),
        ColonneKanban(id: "annule", libelle: "Annulé", libelleCourt: "Annulé", teinte: \.kanbanAnnule),
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
}
// swiftlint:enable line_length
