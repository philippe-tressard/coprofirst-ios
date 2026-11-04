// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Les onglets de « Ma résidence » (`pages.ts`, page `residence`).
///
/// ⚠️ PROVISOIRE : libellés et réservations recopiés de `pages.ts`, en attendant la
/// table GÉNÉRÉE des onglets du site (`Charte/OngletsDuSite.swift`, demandée à la
/// coordination le 04/11/2026). Elle remplace cette déclaration avant la fusion.
enum OngletResidence: String, CaseIterable, Identifiable, Sendable {
    case fiche, carnet, reglement

    var id: String { rawValue }

    var libelle: String {
        switch self {
        case .fiche: "Fiche"
        case .carnet: "Carnet d’entretien"
        case .reglement: "Règlement"
        }
    }

    /// `reserve: 'proprioOuCS'` du site : le carnet et le règlement.
    var reserveProprioOuCS: Bool { self != .fiche }

    /// Les onglets que ce profil ouvre — un onglet réservé ne s'affiche pas au rôle
    /// exclu (`BarreOnglets`). `accesReglement == false` : l'administration n'a pas
    /// ouvert l'assistant aux copropriétaires, l'onglet se masque aussi (le site
    /// le garde tant que la réponse n'est pas arrivée : `nil`).
    static func ouverts(_ profil: ProfilResidence?, accesReglement: Bool?) -> [OngletResidence] {
        allCases.filter { onglet in
            if onglet.reserveProprioOuCS, !DroitsResidence.proprioOuCS(profil) { return false }
            if onglet == .reglement, accesReglement == false { return false }
            return true
        }
    }
}

/// Les rôles que les écrans de la résidence lisent — ceux de `stores/auth.ts`.
enum DroitsResidence {
    /// `isProprioOuCS` : propriétaire, conseil syndical ou administrateur.
    static func proprioOuCS(_ profil: ProfilResidence?) -> Bool {
        aRole(profil, "propriétaire", "conseil_syndical", "admin")
    }

    /// `isCS` : conseil syndical ou administrateur.
    static func cs(_ profil: ProfilResidence?) -> Bool {
        aRole(profil, "conseil_syndical", "admin")
    }

    /// `isLocataire` : le STATUT, pas un rôle (`estLocataire`, `#lib/roles.ts`).
    static func locataire(_ profil: ProfilResidence?) -> Bool {
        profil?.statut == "locataire"
    }

    private static func aRole(_ profil: ProfilResidence?, _ roles: String...) -> Bool {
        guard let profil else { return false }
        return roles.contains { profil.roles.contains($0) }
    }
}

/// Les textes de la Fiche — écrits une fois, comme le site les écrit.
enum TextesResidence {
    static let titre = "Ma résidence"
    static let copropriete = "Copropriété"
    static let aucunePhoto = "Aucune photo"
    static let nonConfiguree = "Résidence non configurée"
    static let nonConfigureeDetail = "Les informations de la résidence ne sont pas encore disponibles."
    static let adresse = "Adresse"
    static let immatriculation = "N° immatriculation"
    static let lotsPrincipaux = "Lots d'habitation, commerces et bureaux"
    static let lotsTotal = "Lots au total"
    static let assurance = "🛡️ Assurance"
    static let syndic = "🏢 Syndic"
    static let composition = "Composition"
    static let regles = "📋 Règles & Recommandations"
    static let reglesVide = "Aucune règle ajoutée."
    static let plans = "🗺️ Plans"
    static let plansVide = "Aucun plan ajouté."
    static let reglement = "📖 Règlement de copropriété"
    static let reglementVide = "Aucun règlement ajouté."
    static let comptesRendus = "📋 Comptes-rendus d'AG"
    static let comptesRendusVide = "Aucun compte-rendu ajouté."
    static let diagnostics = "🔍 Diagnostics et Contrôles Réglementaires"
    static let diagnosticsVide = "Aucun diagnostic réglementaire disponible."
    static let synthese = "💡 Synthèse"
    static let annexes = "Annexes"

    /// « — échéance 12/03/2027 (reconduit tacitement) » (`echeance`, FicheResidence).
    static func echeance(_ date: Date?, reconduit: Bool) -> String {
        guard let date else { return "" }
        return " — échéance \(date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year()))"
            + (reconduit ? " (reconduit tacitement)" : "")
    }

    /// « — mandat jusqu'au … » ou « — mandat échu depuis le … » (`mandat`) : un
    /// mandat ne se reconduit pas, échu il appelle une AG.
    static func mandat(_ date: Date?, echu: Bool) -> String {
        guard let date else { return "" }
        let jour = date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year())
        return echu ? " — mandat échu depuis le \(jour)" : " — mandat jusqu'au \(jour)"
    }
}
