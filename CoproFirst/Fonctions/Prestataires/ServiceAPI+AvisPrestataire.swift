// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Les gestes des avis par le client GÉNÉRÉ (#207) : choisir l'affaire, noter, corriger,
/// retirer. Un refus du serveur garde SA phrase (`Self.refus`).
extension ServiceAPI {
    func affairesANoter(de prestataire: Int, dans installation: Installation) async throws -> [AffaireANoter] {
        let sortie = try await appeler {
            try await client(installation.adresse).getPrestatairesAffairesANoter(
                query: .init(prestataireId: prestataire))
        }
        switch sortie {
        case .ok(let ok): return try ok.body.json.map(AffaireANoter.init)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func noter(_ envoi: EnvoiAvis, dans installation: Installation) async throws {
        let corps = Components.Schemas.NotationCreate(
            commentaire: envoi.commentaire, confirmerAjout: envoi.confirmerAjout, contratId: envoi.contratId,
            etat: .init(rawValue: envoi.etat), prestataireId: envoi.prestataireId, ticketId: envoi.affaire)
        let sortie = try await appeler {
            try await client(installation.adresse).postPrestatairesNotations(body: .json(corps))
        }
        switch sortie {
        case .created: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func corriger(_ avis: Int, _ envoi: EnvoiAvis, dans installation: Installation) async throws {
        let corps = Components.Schemas.NotationUpdate(
            commentaire: envoi.commentaire, confirmerAjout: envoi.confirmerAjout, etat: .init(rawValue: envoi.etat),
            ticketId: envoi.affaire)
        // Le type généré tait un champ `nil` ; le serveur ne lit que les champs ENVOYÉS
        // (`model_fields_set`) : un commentaire vidé ou un avis ramené « sans affaire »
        // part donc en `null` explicite, comme le site.
        let nuls: [String: Int?] = Dictionary(
            uniqueKeysWithValues: [("commentaire", envoi.commentaire == nil), ("ticket_id", envoi.affaire == nil)]
                .filter(\.1).map { ($0.0, Int?.none) })
        let sortie = try await CorpsEnvoye.completer(avec: nuls) {
            try await appeler {
                try await client(installation.adresse).patchPrestatairesNotationsNId(
                    path: .init(nId: avis), body: .json(corps))
            }
        }
        switch sortie {
        case .ok: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func retirer(_ avis: Int, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).deletePrestatairesNotationsNId(path: .init(nId: avis))
        }
        switch sortie {
        case .noContent: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }
}
