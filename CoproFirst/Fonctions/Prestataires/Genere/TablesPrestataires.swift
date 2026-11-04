// GÉNÉRÉ par scripts/generer-acces-prestataires.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// swiftlint:disable line_length
// Source : philippe-tressard/coprofirst v3.61.0 (commit 4239610fcf1658b53c84664087f7e5d0650fe834),
//   front/src/lib/pages.ts, prestataires.ts.

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
