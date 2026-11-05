// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Observation

/// L'état de « Comptes & accès » : la file chargée, et les quatre gestes du conseil.
/// Un geste réussi retire l'élément de la file, comme le site ; un refus garde la file
/// et rend la phrase du serveur.
@MainActor
@Observable
final class EtatComptesCS {
    enum Phase: Equatable {
        case chargement, pret
        case erreur(String)
    }

    private(set) var phase = Phase.chargement
    private(set) var comptes: [CompteEnAttente] = []
    private(set) var commandes: [CommandeEnAttente] = []
    /// L'élément dont un geste est en cours : ses boutons attendent.
    private(set) var enCours: Int?

    func charger(_ service: any ServiceComptesCS, _ installation: Installation) async {
        do {
            async let comptes = service.comptesEnAttente(installation)
            async let commandes = service.commandesEnAttente(installation)
            (self.comptes, self.commandes) = try await (comptes, commandes)
            phase = .pret
        } catch {
            if phase != .pret { phase = .erreur(ErreurService.phrase(error, sinon: TextesComptesCS.erreurChargement)) }
        }
    }

    /// Valider, puis — case « Nouvel Arrivant » cochée — lancer l'accueil. Rend ce
    /// qu'annonce le site (`validerCompte` de `#lib/comptes.ts`).
    func valider(
        _ compte: CompteEnAttente, accueil: AccueilArrivant?, _ service: any ServiceComptesCS,
        _ installation: Installation
    ) async throws -> String {
        enCours = compte.id
        defer { enCours = nil }
        try await service.traiterCompte(compte.id, valider: true, dans: installation)
        comptes.removeAll { $0.id == compte.id }
        guard let accueil else { return TextesComptesCS.compteActive }
        try await service.accueillir(compte.id, accueil, dans: installation)
        return TextesComptesCS.compteActive + " " + TextesComptesCS.accueilEnvoye
    }

    func rejeter(
        _ compte: CompteEnAttente, _ service: any ServiceComptesCS, _ installation: Installation
    ) async throws -> String {
        enCours = compte.id
        defer { enCours = nil }
        try await service.traiterCompte(compte.id, valider: false, dans: installation)
        comptes.removeAll { $0.id == compte.id }
        return TextesComptesCS.compteRejete
    }

    /// Accepter (`codes` : les codes des badges remis, éventuellement aucun) ou refuser.
    func traiter(
        _ commande: CommandeEnAttente, accepter codes: [String]?, _ service: any ServiceComptesCS,
        _ installation: Installation
    ) async throws -> String {
        enCours = commande.id
        defer { enCours = nil }
        try await service.traiterCommande(commande.id, accepter: codes, dans: installation)
        commandes.removeAll { $0.id == commande.id }
        return codes == nil ? TextesComptesCS.commandeRejetee : TextesComptesCS.commandeApprouvee
    }

    /// La saisie des codes, découpée comme le site (`accepterCommandeAcces`) : virgules,
    /// points-virgules ou espaces.
    nonisolated static func codes(_ saisie: String) -> [String] {
        saisie.split(whereSeparator: { $0 == "," || $0 == ";" || $0.isWhitespace }).map(String.init)
    }
}
