// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.89.0 (commit 10b85f3356d538254bfdca6f54270063c9008d4b), front/src/lib/pages.ts#PAGES, front/src/lib/prestataires.ts#TYPES_PRESTATAIRE, front/src/lib/prestataires.ts#FILTRES_CONTRAT (tables-clients.json).
// swiftlint:disable line_length

/// Ce que le site écrit de « Prestataires » et que le contrat ne sert pas.
enum TablesPrestataires {
    /// Le descriptif de chaque onglet de la page `prestataires` (texte du site, parfois HTML).
    static let descriptifs: [String: String] = [
        "prestataires": "Intervenants et contrats d'entretien de la résidence.",
        "contrats": "Contrats d'entretien en cours, leur échéance et leurs documents.",
        "consommations": "Suivi des relevés de compteurs et abonnements de la résidence.",
    ]
    /// Les catégories de prestataires, dans l'ordre du site (`TYPES_PRESTATAIRE`).
    static let types: [TypePrestataire] = [
        TypePrestataire(code: "maintenance_depannage", libelle: "🔧 Maintenance & dépannage", description: "Entretien, réparations"),
        TypePrestataire(code: "travaux", libelle: "🏗️ Travaux", description: "Interventions importantes"),
        TypePrestataire(code: "reglementaire", libelle: "📋 Réglementaire", description: "Contrôles obligatoires"),
        TypePrestataire(code: "etudes_expertise", libelle: "📐 Études & expertise", description: "Diagnostics, maîtrise d’œuvre"),
        TypePrestataire(code: "gestion", libelle: "🏢 Gestion", description: "Syndic, gestion locative"),
    ]
    /// Le filtre « Contrat » (`FILTRES_CONTRAT`).
    static let filtresContrat: [(code: String, libelle: String)] = [
        ("sous_contrat", "📄 Sous contrat"),
        ("sans_contrat", "Sans contrat"),
    ]
}
// swiftlint:enable line_length
