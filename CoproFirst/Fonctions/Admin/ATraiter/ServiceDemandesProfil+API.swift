// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// « Demandes de profil » par le client GÉNÉRÉ : la liste et le traitement se lisent par
/// leurs types (`DemandeProfilEnAttente`, `DemandeProfilTraitee`, contrat 1.16.0, #87).
extension ServiceAPI: ServiceDemandesProfil {
    func demandesProfil(_ installation: Installation) async throws -> [DemandeProfil] {
        let sortie = try await appeler { try await client(installation.adresse).getAdminDemandesProfil() }
        switch sortie {
        case .ok(let ok): return try ok.body.json.map(DemandeProfil.init)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func traiterDemandeProfil(
        _ id: Int, approuver: Bool, motif: String?, dans installation: Installation
    ) async throws -> PhraseAvis {
        let corps = Components.Schemas.DemandeProfilAction(
            action: approuver ? "approuver" : "rejeter", motifRefus: approuver ? nil : motif?.nulSiVide)
        let sortie = try await appeler {
            try await client(installation.adresse).postAdminDemandesProfilDemandeIdTraiter(
                path: .init(demandeId: id), body: .json(corps))
        }
        switch sortie {
        case .ok(let ok): return PhraseAvis(try ok.body.json.annonce)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }
}
