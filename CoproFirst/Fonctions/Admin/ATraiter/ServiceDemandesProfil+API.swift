// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// « Demandes de profil » par le client GÉNÉRÉ. La liste n'est pas typée par le contrat
/// (pas de `response_model`) : elle se relit par `Relecture`, le seul usage admis.
extension ServiceAPI: ServiceDemandesProfil {
    func demandesProfil(_ installation: Installation) async throws -> [DemandeProfil] {
        let sortie = try await appeler { try await client(installation.adresse).getAdminDemandesProfil() }
        switch sortie {
        case .ok(let ok): return try Relecture.lire([DemandeProfil].self, depuis: try ok.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func traiterDemandeProfil(
        _ id: Int, approuver: Bool, motif: String?, dans installation: Installation
    ) async throws {
        let corps = Components.Schemas.DemandeProfilAction(
            action: approuver ? "approuver" : "rejeter", motifRefus: approuver ? nil : motif?.nulSiVide)
        let sortie = try await appeler {
            try await client(installation.adresse).postAdminDemandesProfilDemandeIdTraiter(
                path: .init(demandeId: id), body: .json(corps))
        }
        switch sortie {
        case .ok: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }
}
