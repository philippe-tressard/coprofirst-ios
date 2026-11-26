// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.126.5 (commit 62852e89915e6bfaf695125a8cca5affa72abdcf), front/src/lib/pages.ts#PAGES et front/src/lib/flux.ts#TITRE_FIL (tables-clients.json).

/// Les pages de navigation du site, dans l'ordre par défaut ; `pages_order` le remplace.
enum PagesParDefaut {
    static let toutes: [PageDeNavigation] = [
        PageDeNavigation(id: "tableau-de-bord", route: "/tableau-de-bord", libelle: "Accueil", titre: "Tableau de bord", icone: "layout-dashboard", acces: "tous"),
        PageDeNavigation(id: "residence", route: "/residence", libelle: "Résidence", titre: "Ma résidence", icone: "building-2", acces: "tous"),
        PageDeNavigation(id: "mes-demandes", route: "/tickets", libelle: "Affaires", titre: "Mes affaires", icone: "message-square-text", acces: "tous"),
        PageDeNavigation(id: "mon-lot", route: "/mon-lot", libelle: "Mes lots & accès", titre: "Mes lots & accès", icone: "key-round", acces: "tous"),
        PageDeNavigation(id: "annuaire", route: "/annuaire", libelle: "Annuaire", titre: "Annuaire", icone: "users", acces: "tous"),
        PageDeNavigation(id: "prestataires", route: "/prestataires", libelle: "Prestataires", titre: "Prestataires", icone: "hard-hat", acces: "cs"),
        PageDeNavigation(id: "communaute", route: "/sondages", libelle: "Communauté", titre: "Communauté", icone: "users-round", acces: "resident"),
        PageDeNavigation(id: "faq", route: "/faq", libelle: "FAQ", titre: "FAQ", icone: "help-circle", acces: "tous"),
        PageDeNavigation(id: "espace-cs", route: "/espace-cs", libelle: "Espace CS", titre: "Espace Conseil Syndical (CS)", icone: "shield-half", acces: "cs"),
        PageDeNavigation(id: "admin", route: "/admin", libelle: "Admin", titre: "Paramétrage", icone: "sliders-horizontal", acces: "admin"),
        PageDeNavigation(id: "delegations", route: "/delegations", libelle: "Délégations", titre: "Délégations aidant", icone: "heart-handshake", acces: "cs-ou-aidant"),
    ]
    /// Le titre de la section du tableau de bord que le fil de l'app reprend (`.titre-fil`).
    static let titreDuFil = "Fil d'activité"
}
