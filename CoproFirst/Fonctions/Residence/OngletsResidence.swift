// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Les onglets que l'écran de « Ma résidence » sait rendre. Leurs libellés, leur ordre
/// et leurs réserves ne s'écrivent pas ici : ils viennent de la table GÉNÉRÉE des
/// onglets du site (`OngletsDuSite`, #30), lue par `OngletsResidence.ouverts`.
enum OngletResidence: String, Sendable {
    case fiche, carnet, reglement
}

enum OngletsResidence {
    /// L'identifiant de la page dans `pages.ts`.
    static let page = "residence"

    /// Les onglets que ce compte ouvre (`OngletsDuSite.ouverts`, la règle du site),
    /// plus le masquage qui dépend des DONNÉES : l'administration n'a pas ouvert
    /// l'assistant aux copropriétaires (`accesReglement == false`). Tant qu'elle n'a pas
    /// répondu (`nil`), l'onglet reste, comme sur le site.
    static func ouverts(_ droits: DroitsOnglet, accesReglement: Bool?) -> [OngletDuSite] {
        OngletsDuSite.ouverts(page: page, droits: droits).filter { onglet in
            guard let rendu = OngletResidence(rawValue: onglet.id) else { return false }
            return rendu != .reglement || accesReglement != false
        }
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
        return " — échéance \(FormatsDuSite.dateCourte(date))"
            + (reconduit ? " (reconduit tacitement)" : "")
    }

    /// « — mandat jusqu'au … » ou « — mandat échu depuis le … » (`mandat`) : un
    /// mandat ne se reconduit pas, échu il appelle une AG.
    static func mandat(_ date: Date?, echu: Bool) -> String {
        guard let date else { return "" }
        let jour = FormatsDuSite.dateCourte(date)
        return echu ? " — mandat échu depuis le \(jour)" : " — mandat jusqu'au \(jour)"
    }
}
