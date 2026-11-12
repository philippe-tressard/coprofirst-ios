// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.88.1 (commit e13d52923f0429fd082c92e60893e2605a3d6d27), pièce jointe tables-clients.json de la release (categoriesTicket, naturesAffaire, teinteNature, colonnesKanban, motColonneVide, statutsTicket, groupesSuivi, categorieActualite).
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
        NatureAffaire(code: "actualite", libelle: "Actualité", abrege: "ACTU.", emoji: "📰", icone: "newspaper", badge: "badge-blue"),
        NatureAffaire(code: "calendrier", libelle: "Calendrier", abrege: "CAL.", emoji: "📅", icone: "calendar-days", badge: "badge-purple"),
        NatureAffaire(code: "activite", libelle: "Affaire", abrege: "AFF.", emoji: "🛠️", icone: "wrench", badge: "badge-orange"),
    ]
    /// La teinte de chaque colonne du Kanban, par son code (`KANBAN_COLS`) — les colonnes
    /// elles-mêmes sont SERVIES (`GET /tickets/referentiels`).
    static let teintesKanban: [String: KeyPath<Palette, Color> & Sendable] = [
        "ag": \.kanbanAg,
        "cs": \.kanbanCs,
        "syndic": \.kanbanSyndic,
        "fournisseur": \.kanbanFournisseur,
        "termine": \.kanbanTermine,
        "annule": \.kanbanAnnule,
    ]
    /// Ce qu'une colonne vide affiche (`MOT_COLONNE_VIDE`).
    static let colonneVide = "Aucune affaire"
    /// Les statuts du cycle d'une affaire, dans l'ordre du site (`STATUTS_TICKET`).
    static let ordreDesStatuts: [String] = ["ouvert", "en_ag", "en_cours", "chez_prestataire", "résolu", "annulé"]
    /// Des statuts que le filtre « Suivi » réunit sous une option (`GROUPES_SUIVI`).
    static let groupesDeSuivi: [GroupeDeSuivi] = [
        GroupeDeSuivi(code: "en_cours", libelle: "En cours", statuts: ["en_ag", "en_cours", "chez_prestataire"]),
    ]
    /// La catégorie d'une actualité (`CATEGORIE_ACTUALITE`).
    static let categorieActualite = "actualite"
}
// swiftlint:enable line_length
