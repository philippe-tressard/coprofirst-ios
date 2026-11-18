// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.117.0 (commit d25fa8df3721cf67b5522648fd22d000b61ca237), front/src/lib/pages.ts#PAGES, front/src/lib/annuaire.ts#CIVILITES (tables-clients.json).
// swiftlint:disable line_length

/// Ce que le site écrit de l'Espace conseil syndical et que le contrat ne sert pas.
enum TablesEspaceCS {
    /// Le descriptif de chaque onglet de la page `espace-cs` (texte du site).
    static let descriptifs: [String: String] = [
        "validations": "Comptes en attente, demandes d'accès et validations à traiter.",
        "badges": "Tous les badges Vigik et télécommandes de la copropriété, avec leur porteur et leur lot. Vue de consultation : un badge s’enregistre par l’import du syndic, ou par son porteur.",
        "reporting": "Synthèses et indicateurs du conseil syndical, de l’état des affaires ouvertes aux échéances des contrats — à consulter ou à exporter.",
        "annonces-hall": "Créez une annonce à afficher dans le hall des bâtiments : PDF à la charte de la résidence, envoyé par mail aux membres du CS concernés, puis conservé dans l'historique.",
        "ecrans": "Les écrans qui affichent les annonces dans le hall : appairez-en un avec le code qu'il affiche, voyez quand il a lu les annonces pour la dernière fois, retirez-le s'il est perdu ou remplacé.",
        "annuaire": "Coordonnées des membres du CS et du syndic.",
        "courriels": "Ce que le site a fait de chaque message reçu à l'adresse des affaires — réponses du syndic, fils transférés par le conseil : ajouté à une affaire, refusé ou ignoré, et pourquoi. Un message refusé se corrige puis se transfère de nouveau.",
    ]
    /// L'adresse de chaque onglet sur le site, sous celle de la résidence.
    static let routes: [String: String] = [
        "validations": "/espace-cs",
        "badges": "/espace-cs/badges",
        "reporting": "/espace-cs/reporting",
        "annonces-hall": "/espace-cs/annonces-hall",
        "ecrans": "/espace-cs/ecrans",
        "annuaire": "/espace-cs/annuaire",
        "courriels": "/espace-cs/courriels",
    ]
    /// Les civilités d'une fiche de l'annuaire, dans l'ordre du site (`CIVILITES`).
    static let civilites: [String] = ["Mme", "Mlle", "Mr"]
}
// swiftlint:enable line_length
