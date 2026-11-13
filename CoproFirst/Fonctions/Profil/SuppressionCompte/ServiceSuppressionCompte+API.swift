// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// La demande de suppression par le client GÉNÉRÉ (coprofirst#2699, contrat 1.27.0).
extension ServiceAPI: ServiceSuppressionCompte {
    func etatSuppression(_ installation: Installation) async throws -> EtatSuppressionCompte {
        let sortie = try await appeler { try await client(installation.adresse).getAuthDemandeSuppression() }
        switch sortie {
        case .ok(let ok): return EtatSuppressionCompte(try ok.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func demanderSuppression(motDePasse: String, motif: String, dans installation: Installation) async throws
        -> DemandeSuppressionCompte {
        let corps = Components.Schemas.DemandeSuppressionCreate(motDePasse: motDePasse, motif: motif.nulSiVide)
        let sortie = try await appeler {
            try await client(installation.adresse).postAuthDemandeSuppression(body: .json(corps))
        }
        switch sortie {
        case .created(let cree): return DemandeSuppressionCompte(try cree.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        // 400 mot de passe faux, 409 déjà en cours : la phrase du serveur.
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func retirerDemandeSuppression(_ installation: Installation) async throws {
        let sortie = try await appeler { try await client(installation.adresse).deleteAuthDemandeSuppression() }
        switch sortie {
        case .noContent: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }
}
