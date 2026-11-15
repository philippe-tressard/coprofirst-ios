// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Un prestataire d'une affaire, tel que le serveur le sert (`TicketRead.prestataires`,
/// `PrestataireDeLAffaire`, #181) : l'affaire en porte plusieurs, dans l'ordre de saisie.
struct PrestataireAffaire: Identifiable, Hashable, Sendable {
    let id: Int?
    let nom: String

    /// Les prestataires servis d'une affaire.
    static func liste(_ ticket: Components.Schemas.TicketRead) -> [PrestataireAffaire] {
        (ticket.prestataires ?? []).map { PrestataireAffaire(id: $0.id, nom: $0.nom) }
    }
}

enum TextesPrestatairesAffaire {
    static let section = "Prestataires"
    static let ajouter = "Ajouter un prestataire"
    static let aucun = "Aucun prestataire pour l'instant."
    static let tousChoisis = "Tous les prestataires de la résidence sont déjà sur l'affaire."
    static let catalogueIllisible = "La liste des prestataires de la résidence n'a pas pu être lue."
    static let pied = "Le premier est celui que montre le Kanban."
    static func retirer(_ nom: String) -> String { "Retirer \(nom)" }
    static let monter = "Monter"
    static let descendre = "Descendre"
    /// « Intervenants : A, B · ↺ Mensuel » — ce que VoiceOver lit de la fiche.
    static func intervenant(_ phrase: String, nombre: Int) -> String {
        "\(nombre > 1 ? "Intervenants" : "Intervenant") : \(phrase)"
    }

    /// « Ascenseurs du Parc +1 » : le premier, et combien d'autres — la carte du Kanban
    /// (arbitrage Q6 de coprofirst#2704). `nil` sans prestataire.
    static func carte(_ noms: [String]) -> String? {
        guard let premier = noms.first else { return nil }
        return noms.count > 1 ? "\(premier) +\(noms.count - 1)" : premier
    }
}
