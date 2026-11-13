// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Un prestataire d'une affaire, tel que le serveur le sert (`TicketRead.prestataires`,
/// contrat 1.28.0, #181) : l'affaire en porte plusieurs, dans l'ordre de saisie.
struct PrestataireAffaire: Identifiable, Hashable, Sendable, Decodable {
    /// `nil` d'une installation antérieure qui ne sert que le nom (`prestataire_nom`).
    let id: Int?
    let nom: String
}

/// Ce que `TicketRead` sert au-dessus du plancher sur les prestataires (contrat 1.28.0) —
/// relu dans le corps servi (`Relecture.auDessusDuPlancher`), tous champs facultatifs.
struct PrestatairesServis: Identifiable, Decodable, Sendable {
    let id: Int
    /// La liste servie ; absente d'une installation antérieure.
    let prestataires: [PrestataireAffaire]?
    /// Ajouter, retirer un prestataire (`peut_changer_prestataires`) ; absent : non.
    let peutChangerPrestataires: Bool?

    /// Les prestataires de l'affaire : la liste servie ; d'une installation antérieure,
    /// le seul qu'elle sert (`prestataire_id`, `prestataire_nom`), comme avant.
    static func liste(
        _ servis: PrestatairesServis?, ticket: Components.Schemas.TicketRead
    ) -> [PrestataireAffaire] {
        if let liste = servis?.prestataires { return liste }
        guard let nom = ticket.prestataireNom?.nulSiVide else { return [] }
        return [PrestataireAffaire(id: ticket.prestataireId, nom: nom)]
    }
}

/// Ce que « Modifier l'affaire » ajoute au corps du PATCH quand la liste a changé
/// (`prestataire_ids`, contrat 1.28.0) : la liste ENTIÈRE, qui remplace l'ancienne.
struct ChampsPrestataires: Encodable, Sendable {
    let prestataireIds: [Int]
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
