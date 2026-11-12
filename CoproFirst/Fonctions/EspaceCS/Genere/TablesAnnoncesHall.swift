// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.88.1 (commit e13d52923f0429fd082c92e60893e2605a3d6d27), pièce jointe tables-clients.json de la release (formatsAffiche).

/// Ce que le site écrit des Annonces Hall de l'Espace CS et que le contrat ne sert pas.
enum TablesAnnoncesHall {
    /// Les formats qu'on peut demander pour une affiche (`AH_FORMATS`).
    static let formats: [(code: String, libelle: String)] = [
        ("auto", "Auto"),
        ("a4", "A4"),
        ("a5", "A5"),
        ("a6", "A6"),
        ("a7", "A7"),
    ]
}
