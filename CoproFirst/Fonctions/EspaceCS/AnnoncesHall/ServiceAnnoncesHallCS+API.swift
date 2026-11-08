// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Les Annonces Hall par le client GÉNÉRÉ : chaque réponse se lit par son type
/// (`AnnonceHallRead`, contrat 1.8.0 — coprofirst#2525).
extension ServiceAPI: ServiceAnnoncesHallCS {
    func annoncesHall(archivees: Bool, dans installation: Installation) async throws -> [AnnonceHall] {
        let sortie = try await appeler {
            try await client(installation.adresse).getAnnoncesHall(query: .init(archivees: archivees))
        }
        switch sortie {
        case .ok(let ok): return try ok.body.json.map(AnnonceHall.init)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func creerAnnonceHall(_ saisie: SaisieAnnonceHall, dans installation: Installation) async throws -> AnnonceHall {
        let corps = Components.Schemas.AnnonceHallCreate(
            envoyerAuteur: saisie.envoyerAuteur, envoyerCs: saisie.envoyerCS, envoyerSyndic: saisie.envoyerSyndic,
            formatDemande: saisie.format, images: [], message: HTMLDeSaisie.depuis(saisie.message),
            partagerWhatsapp: false, perimetreCible: saisie.perimetres.sorted(),
            titre: saisie.titre.trimmingCharacters(in: .whitespacesAndNewlines))
        let sortie = try await appeler { try await client(installation.adresse).postAnnoncesHall(body: .json(corps)) }
        switch sortie {
        case .created(let cree): return AnnonceHall(try cree.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func archiverAnnonceHall(_ id: Int, archivee: Bool, dans installation: Installation) async throws {
        // Archiver ou restaurer : le serveur note la décision humaine (`AnnonceHallArchive`).
        let corps = Components.Schemas.AnnonceHallArchive(archivee: archivee)
        let sortie = try await appeler {
            try await client(installation.adresse).patchAnnoncesHallAnnonceId(
                path: .init(annonceId: id), body: .json(corps))
        }
        switch sortie {
        case .ok: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func renvoyerAnnonceHall(_ id: Int, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).postAnnoncesHallAnnonceIdRenvoyerEmail(path: .init(annonceId: id))
        }
        switch sortie {
        case .noContent: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func supprimerAnnonceHall(_ id: Int, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).deleteAnnoncesHallAnnonceId(path: .init(annonceId: id))
        }
        switch sortie {
        case .noContent: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }
}
