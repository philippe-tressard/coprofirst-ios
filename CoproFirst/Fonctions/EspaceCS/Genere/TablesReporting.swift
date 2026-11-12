// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.89.0 (commit 10b85f3356d538254bfdca6f54270063c9008d4b), front/src/lib/reporting.ts#TEINTE_AGE, front/src/lib/reporting.ts#MODES_SUIVI, front/src/lib/entretien-periodique.ts#ETATS_VISITE, front/src/lib/reporting.ts#MOTIFS_EVOLUTION, front/src/lib/reporting.ts#MOTIF_EVOLUTION_PAR_DEFAUT, front/src/lib/components/reporting/BarresCroisees.svelte@[data-teinte='*'] (tables-clients.json).

import SwiftUI

/// Ce que le site écrit du Reporting de l'Espace CS et que le contrat ne sert pas.
enum TablesReporting {
    /// La pastille de l'âge d'une affaire, selon son ancienneté servie (`TEINTE_AGE`).
    static let teintesAge: [String: String] = [
        "ancienne": "badge-red",
        "moyenne": "badge-orange",
        "recente": "badge-gray",
    ]
    /// Les modes du Suivi des affaires, dans l'ordre du site (`MODES_SUIVI`).
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
        "s1": [.palette(\.serie1)],
        "s2": [.palette(\.serie2)],
        "s3": [.palette(\.serie3)],
        "s4": [.palette(\.serie4)],
        "s5": [.palette(\.serie5)],
        "s6": [.palette(\.serie6)],
        "s7": [.palette(\.serie7)],
        "s8": [.palette(\.serie8)],
        "autre": [.palette(\.textMuted)],
        "p1": [.palette(\.palier1)],
        "p2": [.palette(\.palier2)],
        "p3": [.palette(\.palier3)],
        "p4": [.palette(\.palier4)],
        "plusieurs": [.palette(\.palier2), .palette(\.neutreFond)],
    ]
}
