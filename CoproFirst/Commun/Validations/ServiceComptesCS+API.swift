// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// « Comptes & accès » par le client GÉNÉRÉ : chaque réponse se lit par son type
/// (contrat 1.12.0, coprofirst#2522).
extension ServiceAPI: ServiceComptesCS {
    func comptesEnAttente(_ installation: Installation) async throws -> [CompteEnAttente] {
        let (sortie, corps) = try await appeler {
            try await CorpsServi.garder { try await client(installation.adresse).getAdminComptesEnAttente() }
        }
        switch sortie {
        case .ok(let ok): return CompteEnAttente.lus(try ok.body.json, corps: corps)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func commandesEnAttente(_ installation: Installation) async throws -> [CommandeEnAttente] {
        let sortie = try await appeler { try await client(installation.adresse).getAdminCommandesAcces() }
        switch sortie {
        case .ok(let ok): return try ok.body.json.map(CommandeEnAttente.init)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func traiterCompte(_ id: Int, valider: Bool, dans installation: Installation) async throws -> PhraseAvis? {
        let corps = Components.Schemas.CompteAction(action: valider ? "valider" : "refuser")
        let sortie = try await appeler {
            try await client(installation.adresse).postAdminComptesUserIdTraiter(
                path: .init(userId: id), body: .json(corps))
        }
        switch sortie {
        case .ok(let ok): return try ok.body.json.annonce.map(PhraseAvis.init)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func accueillir(_ id: Int, _ accueil: AccueilArrivant, dans installation: Installation) async throws {
        let corps = Components.Schemas.AccueilArrivantBody(
            ancienResident: accueil.ancienResident.nulSiVide, batiment: accueil.batiment.nulSiVide)
        let sortie = try await appeler {
            try await client(installation.adresse).postAdminUtilisateursUserIdAccueilArrivant(
                path: .init(userId: id), body: .json(corps))
        }
        switch sortie {
        case .ok: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func traiterCommande(_ id: Int, accepter codes: [String]?, dans installation: Installation) async throws {
        let corps = Components.Schemas.CommandeAction(
            action: codes == nil ? "refuser" : "accepter", codes: codes ?? [])
        let sortie = try await appeler {
            try await client(installation.adresse).postAdminCommandesAccesCmdIdTraiter(
                path: .init(cmdId: id), body: .json(corps))
        }
        switch sortie {
        case .ok: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }
}

extension CompteEnAttente {
    /// La file servie, puis les noms affichés relus au-dessus du plancher — le MÊME
    /// branchement pour le service réel et l'API simulée.
    static func lus(_ generes: [Components.Schemas.UserRead], corps: Data?) -> [CompteEnAttente] {
        let personnes = PersonneServie.parLigne(corps)
        return generes.map { user in
            CompteEnAttente(
                id: user.id, prenom: user.prenom, nom: user.nom, statut: user.statut.rawValue,
                batimentNom: user.batimentNom, prenomAide: user.prenomAide, nomAide: user.nomAide,
                creeLe: user.creeLe, nomServi: personnes[user.id]?.nomAffiche,
                nomAideServi: personnes[user.id]?.nomAideAffiche)
        }
    }
}
