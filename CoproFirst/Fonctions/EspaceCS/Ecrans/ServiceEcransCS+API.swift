// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Les écrans du hall par le client GÉNÉRÉ (`EcranLu`, `Confirmation`, contrat 2.6.0 —
/// coprofirst#2770). Un code inconnu ou expiré rend la phrase du serveur (404).
extension ServiceAPI: ServiceEcransCS {
    func ecrans(dans installation: Installation) async throws -> [EcranDuHall] {
        let sortie = try await appeler { try await client(installation.adresse).getEcrans() }
        switch sortie {
        case .ok(let ok): return try ok.body.json.map(EcranDuHall.init)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func appairer(_ saisie: SaisieAppairage, dans installation: Installation) async throws -> EcranAppaire {
        let corps = Components.Schemas.Confirmation(
            codeCourt: saisie.lettres, nom: saisie.nomSaisi, perimetre: saisie.perimetres.codes.first ?? "")
        let sortie = try await appeler { try await client(installation.adresse).postEcrans(body: .json(corps)) }
        switch sortie {
        case .created(let cree):
            let lu = try cree.body.json
            return EcranAppaire(nom: lu.nom, perimetreLibelle: lu.perimetreLibelle)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func retirer(_ id: Int, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).deleteEcransEcranId(path: .init(ecranId: id))
        }
        switch sortie {
        case .noContent: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }
}
