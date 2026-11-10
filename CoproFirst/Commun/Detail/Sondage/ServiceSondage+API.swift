// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// La fiche d'un sondage par le client généré : chaque réponse lue par son type.
extension ServiceAPI: ServiceSondage {
    func sondage(_ id: Int, dans installation: Installation) async throws -> DetailSondage {
        let client = client(installation.adresse)
        async let fiche = appeler { try await client.getSondagesSondageId(path: .init(sondageId: id)) }
        async let compte = appeler { try await client.getAuthMe() }
        let lu: Components.Schemas.SondageDetail
        switch try await fiche {
        case .ok(let ok): lu = try ok.body.json
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
        // Le compte illisible n'empêche pas de lire la fiche : chaque commentaire offre
        // alors « Signaler », et le serveur juge.
        var moi: Int?
        if case .ok(let ok)? = try? await compte { moi = try? ok.body.json.id }
        return DetailSondage(lu, moi: moi)
    }

    func voter(_ vote: VoteSondage, au sondage: Int, dans installation: Installation) async throws {
        guard let option = vote.option else { throw ErreurService.inattendue(422) }
        let corps = Components.Schemas.VoteBody(
            commentaire: VoteSondage.nettoye(vote.commentaire), optionId: option,
            reponseLibre: VoteSondage.nettoye(vote.reponseLibre))
        let sortie = try await appeler {
            try await client(installation.adresse).postSondagesSondageIdVoter(
                path: .init(sondageId: sondage), body: .json(corps))
        }
        switch sortie {
        case .created: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func commenterSondage(_ texte: String, au sondage: Int, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).postSondagesSondageIdCommenter(
                path: .init(sondageId: sondage), body: .json(.init(contenu: texte)))
        }
        switch sortie {
        case .created: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func supprimerCommentaireSondage(_ id: Int, du sondage: Int, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).deleteSondagesSondageIdCommentairesCommentaireId(
                path: .init(sondageId: sondage, commentaireId: id))
        }
        switch sortie {
        case .noContent: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }
}
