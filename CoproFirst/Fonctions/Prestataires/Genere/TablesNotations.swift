// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.102.0 (commit d3db6646db1053a82ad72fb0ce57f6d35216c77a), front/src/lib/notations.ts.

/// La notation d'un prestataire, telle que le site l'écrit.
enum TablesNotations {
    /// Les états d'un avis, dans l'ordre du site (`ETATS`).
    static let etats = ["mauvais", "neutre", "excellent"]
    /// Le libellé de chaque état (`LIBELLE_ETAT`).
    static let libelles: [String: String] = [
        "mauvais": "Mauvais",
        "neutre": "Neutre",
        "excellent": "Excellent",
    ]
    /// La classe de teinte de chaque état (`TEINTE_ETAT`).
    static let teintes: [String: String] = [
        "mauvais": "badge-red",
        "neutre": "badge-gray",
        "excellent": "badge-green",
    ]
    /// L'état d'une moyenne (`etatDeMoyenne`) : sous la borne, l'état — dans l'ordre.
    static let seuilsDeMoyenne: [(borne: Double, etat: String)] = [
        (2.5, "mauvais"),
        (4, "neutre"),
    ]
    /// Au-delà de la dernière borne.
    static let etatAuDela = "excellent"
}
