// GÉNÉRÉ par scripts/generer-delegations-cs.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.61.0 (commit 4239610fcf1658b53c84664087f7e5d0650fe834),
//   front/src/lib/entretien-periodique.ts, reporting.ts, components/reporting/
//   (TableauAffaires, VueSuiviAffaires, BarresCroisees) ; front/src/styles/socle.css et
//   palette-sombre.css.

import SwiftUI

// swiftlint:disable line_length
/// Ce que le site écrit du Reporting de l'Espace CS et que le contrat ne sert pas.
enum TablesReporting {
    /// La pastille de l'âge d'une affaire, selon son ancienneté servie (`TEINTE_AGE`).
    static let teintesAge: [String: String] = [
        "ancienne": "badge-red",
        "moyenne": "badge-orange",
        "recente": "badge-gray",
    ]
    /// Les modes du Suivi des affaires, dans l'ordre du site (`MODES`).
    static let modes: [(code: String, libelle: String)] = [
        ("suivi", "Suivi affaires"),
        ("entretien", "Suivi entretiens périodiques"),
        ("relance", "Relancer le syndic"),
    ]
    /// L'état d'une visite d'entretien, calculé au serveur (`ETATS_VISITE`).
    static let etatsVisite: [String: LibelleTeinte] = [
        "realisee": LibelleTeinte("Réalisée", "badge-green"),
        "non_realisee": LibelleTeinte("Non réalisée", "badge-red"),
        "a_venir": LibelleTeinte("À venir", "badge-blue"),
        "a_planifier": LibelleTeinte("À planifier", "badge-orange"),
        "annulee": LibelleTeinte("Annulée", "badge-gray"),
    ]
    /// Ce que le signal « a évolué » dit d'une affaire, selon le motif servi (`MOTIFS_EVOLUTION`).
    static let motifsEvolution: [String: String] = [
        "nouvelle": "Nouvelle affaire, jamais résumée",
        "commentaire": "Nouvelle suite depuis le dernier résumé",
        "etat": "Changement d’état depuis le dernier résumé",
        "reponse": "Nouveau message depuis le dernier résumé",
        "relance": "Relance envoyée depuis le dernier résumé",
    ]
    /// Un motif inconnu ou absent (`motifEvolution`).
    static let motifEvolutionParDefaut = "Du nouveau depuis le dernier résumé"
    /// La couleur de chaque tranche d'une répartition, selon la teinte que le serveur
    /// lui choisit (`BarresCroisees.svelte`) : une couleur, un aplat ; deux, des hachures.
    static let tranches: [String: [CouleurDeTranche]] = [
        "s1": [.fixe(Color(clair: RVBA(0x2A, 0x78, 0xD6, 1), sombre: RVBA(0x54, 0x94, 0xE3, 1)))],
        "s2": [.fixe(Color(clair: RVBA(0xE3, 0x61, 0x2C, 1), sombre: RVBA(0xDC, 0x6F, 0x3C, 1)))],
        "s3": [.fixe(Color(clair: RVBA(0x09, 0x9C, 0x6B, 1), sombre: RVBA(0x04, 0xAC, 0x7A, 1)))],
        "s4": [.fixe(Color(clair: RVBA(0xB9, 0x7D, 0x04, 1), sombre: RVBA(0xBB, 0x89, 0x08, 1)))],
        "s5": [.fixe(Color(clair: RVBA(0xD1, 0x66, 0x8F, 1), sombre: RVBA(0xCE, 0x6F, 0x95, 1)))],
        "s6": [.fixe(Color(clair: RVBA(0x00, 0x83, 0x00, 1), sombre: RVBA(0x39, 0xAD, 0x3A, 1)))],
        "s7": [.fixe(Color(clair: RVBA(0x4A, 0x3A, 0xA7, 1), sombre: RVBA(0x8E, 0x82, 0xE6, 1)))],
        "s8": [.fixe(Color(clair: RVBA(0xE3, 0x49, 0x48, 1), sombre: RVBA(0xE7, 0x60, 0x5F, 1)))],
        "autre": [.palette(\.textMuted)],
        "p1": [.fixe(Color(clair: RVBA(0x2D, 0x2D, 0x2B, 1), sombre: RVBA(0xD3, 0xD1, 0xC7, 1)))],
        "p2": [.fixe(Color(clair: RVBA(0x58, 0x57, 0x51, 1), sombre: RVBA(0xB4, 0xB2, 0xA9, 1)))],
        "p3": [.fixe(Color(clair: RVBA(0x70, 0x6E, 0x66, 1), sombre: RVBA(0x8F, 0x8D, 0x85, 1)))],
        "p4": [.fixe(Color(clair: RVBA(0x8B, 0x89, 0x80, 1), sombre: RVBA(0x75, 0x73, 0x6C, 1)))],
        "plusieurs": [.fixe(Color(clair: RVBA(0x58, 0x57, 0x51, 1), sombre: RVBA(0xB4, 0xB2, 0xA9, 1))), .palette(\.neutreFond)],
    ]
}
// swiftlint:enable line_length
