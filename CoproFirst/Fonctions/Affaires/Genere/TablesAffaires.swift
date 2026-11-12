// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.89.0 (commit 10b85f3356d538254bfdca6f54270063c9008d4b), front/src/lib/tickets-categories.ts, kanban.ts, tickets.ts, styles/normes.css.
// swiftlint:disable line_length

import SwiftUI

/// Ce que le site écrit des affaires et que le contrat ne sert pas.
enum TablesAffaires {
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
    /// Des statuts que le filtre « Suivi » réunit sous une option (`GROUPES_SUIVI`).
    static let groupesDeSuivi: [GroupeDeSuivi] = [
        GroupeDeSuivi(code: "en_cours", libelle: "En cours", statuts: ["en_ag", "en_cours", "chez_prestataire"]),
    ]
    /// La catégorie d'une actualité (`CATEGORIE_ACTUALITE`).
    static let categorieActualite = "actualite"
}
// swiftlint:enable line_length
