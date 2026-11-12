// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.89.0 (commit 10b85f3356d538254bfdca6f54270063c9008d4b), front/src/lib/annonces-hall.ts#AH_FORMATS (tables-clients.json).

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
