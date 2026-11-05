// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.66.0 (commit 14fec7b6ba683cd74161d874e48a47f2d007ff5f), front/src/lib/pages.ts (PAGES).

/// Les pages de navigation du site, dans l'ordre par défaut ; `pages_order` le remplace.
enum PagesParDefaut {
    static let toutes: [PageDeNavigation] = [
        PageDeNavigation(id: "tableau-de-bord", route: "/tableau-de-bord", libelle: "Accueil", titre: "Tableau de bord", icone: "layout-dashboard"),
        PageDeNavigation(id: "residence", route: "/residence", libelle: "Résidence", titre: "Ma résidence", icone: "building-2"),
        PageDeNavigation(id: "mes-demandes", route: "/tickets", libelle: "Affaires", titre: "Mes affaires", icone: "message-square-text"),
        PageDeNavigation(id: "mon-lot", route: "/mon-lot", libelle: "Mes lots & accès", titre: "Mes lots & accès", icone: "key-round"),
        PageDeNavigation(id: "annuaire", route: "/annuaire", libelle: "Annuaire", titre: "Annuaire", icone: "users"),
        PageDeNavigation(id: "prestataires", route: "/prestataires", libelle: "Prestataires", titre: "Prestataires", icone: "hard-hat"),
        PageDeNavigation(id: "communaute", route: "/sondages", libelle: "Communauté", titre: "Communauté", icone: "users-round"),
        PageDeNavigation(id: "faq", route: "/faq", libelle: "FAQ", titre: "FAQ", icone: "help-circle"),
    ]
}
