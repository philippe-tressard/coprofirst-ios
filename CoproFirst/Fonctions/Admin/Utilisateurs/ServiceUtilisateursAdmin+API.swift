// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// « Utilisateurs » par le client GÉNÉRÉ : chaque réponse se lit par son type.
extension ServiceAPI: ServiceUtilisateursAdmin {
    func utilisateurs(_ installation: Installation) async throws -> [UtilisateurAdmin] {
        let sortie = try await appeler { try await client(installation.adresse).getAdminUtilisateurs() }
        switch sortie {
        case .ok(let ok): return try ok.body.json.map(UtilisateurAdmin.init)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func bannirCommunaute(_ id: Int, interdit: Bool, dans installation: Installation) async throws -> BanCommunaute {
        let sortie = try await appeler {
            try await client(installation.adresse).patchAdminUtilisateursUserIdBanCommunaute(
                path: .init(userId: id), body: .json(.init(interdit: interdit)))
        }
        switch sortie {
        case .ok(let ok): return BanCommunaute(try ok.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func relancerRapprochement(_ id: Int, dans installation: Installation) async throws -> PhraseAvis {
        let sortie = try await appeler {
            try await client(installation.adresse).postAdminUtilisateursUserIdAutoMatch(path: .init(userId: id))
        }
        switch sortie {
        case .ok(let ok): return PhraseAvis(try ok.body.json.annonce)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func supprimerUtilisateur(_ id: Int, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).deleteAdminUtilisateursUserId(path: .init(userId: id))
        }
        switch sortie {
        case .noContent: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }
}
