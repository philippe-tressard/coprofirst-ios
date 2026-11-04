// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// La Communauté par le client GÉNÉRÉ. Idées et annonces n'ont pas de réponse typée
/// dans le contrat : elles se relisent en miroir (`Relecture`) — besoin noté pour
/// coprofirst#2460 (déclarer leurs `response_model`).
extension ServiceAPI: ServiceCommunaute {
    func moiCommunaute(_ installation: Installation) async throws -> MoiCommunaute {
        let sortie = try await appeler { try await client(installation.adresse).meAuthMeGet() }
        switch sortie {
        case .ok(let ok):
            let moi = try ok.body.json
            return MoiCommunaute(
                id: moi.id, statut: moi.statut.rawValue, roles: (moi.roles ?? []) + [moi.role.rawValue],
                motifRefus: moi.communauteMotifRefus.flatMap { $0.isEmpty ? nil : $0 })
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func sondagesCommunaute(_ installation: Installation) async throws -> [SondageResume] {
        let sortie = try await appeler { try await client(installation.adresse).listSondagesSondagesGet() }
        switch sortie {
        case .ok(let ok):
            return try ok.body.json.map {
                SondageResume(
                    id: $0.id, question: $0.question, description: $0.description, clotureLe: $0.clotureLe,
                    cloture: $0.cloture ?? false, nbVotants: $0.nbVotants ?? 0, archivee: $0.archivee ?? false,
                    creeLe: $0.creeLe)
            }
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func idees(_ installation: Installation) async throws -> [Idee] {
        let sortie = try await appeler { try await client(installation.adresse).listIdeesIdeesGet() }
        switch sortie {
        case .ok(let ok): return try Relecture.lire([Idee].self, depuis: try ok.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func proposerIdee(titre: String, description: String, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).createIdeeIdeesPost(
                body: .json(.init(description: description, titre: titre)))
        }
        try verifier(sortie.statutCree)
    }

    func voterIdee(_ id: Int, dans installation: Installation) async throws -> String? {
        let sortie = try await appeler {
            try await client(installation.adresse).voterIdeesIdeeIdVoterPost(path: .init(ideeId: id))
        }
        switch sortie {
        case .created(let cree):
            struct Phrase: Decodable { let message: String? }
            return (try? Relecture.lire(Phrase.self, depuis: try cree.body.json))?.message
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func annonces(_ installation: Installation) async throws -> [Annonce] {
        let sortie = try await appeler { try await client(installation.adresse).listAnnoncesAnnoncesGet() }
        switch sortie {
        case .ok(let ok): return try Relecture.lire([Annonce].self, depuis: try ok.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func deposerAnnonce(_ saisie: SaisieAnnonce, dans installation: Installation) async throws {
        let vente = saisie.type == "vente"
        let corps = Components.Schemas.AnnonceCreate(
            categorie: .init(rawValue: saisie.categorie), contactVisible: saisie.coordonneesVisibles,
            description: saisie.description, negotiable: vente ? saisie.negociable : false,
            prix: vente ? saisie.prix : nil, titre: saisie.titre, typeAnnonce: .init(rawValue: saisie.type))
        let sortie = try await appeler {
            try await client(installation.adresse).createAnnonceAnnoncesPost(body: .json(corps))
        }
        switch sortie {
        case .ok: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func changerStatutAnnonce(_ id: Int, statut: String, dans installation: Installation) async throws {
        guard let code = Components.Schemas.StatutAnnonce(rawValue: statut) else { throw ErreurService.inattendue(422) }
        let sortie = try await appeler {
            try await client(installation.adresse).updateStatutAnnoncesAnnonceIdStatutPatch(
                path: .init(annonceId: id), body: .json(.init(statut: code)))
        }
        switch sortie {
        case .ok: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func supprimerAnnonce(_ id: Int, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).deleteAnnonceAnnoncesAnnonceIdDelete(path: .init(annonceId: id))
        }
        switch sortie {
        case .ok: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func repondreCommunaute(_ texte: String, a cible: CibleCommunaute, dans installation: Installation) async throws {
        let client = client(installation.adresse)
        let corps = Components.Schemas.ReponseCreate(contenu: texte)
        switch cible {
        case .idee(let id):
            let sortie = try await appeler {
                try await client.createReponseIdeesCibleIdReponsesPost(path: .init(cibleId: id), body: .json(corps))
            }
            try verifier(sortie.statutCree)
        case .annonce(let id):
            let sortie = try await appeler {
                try await client.createReponseAnnoncesCibleIdReponsesPost(path: .init(cibleId: id), body: .json(corps))
            }
            try verifier(sortie.statutCree)
        case .reponse:
            throw ErreurService.inattendue(400)
        }
    }

    func supprimerReponseCommunaute(_ id: Int, de cible: CibleCommunaute, dans installation: Installation)
        async throws {
        let client = client(installation.adresse)
        switch cible {
        case .idee(let cibleId):
            let sortie = try await appeler {
                try await client.deleteReponseIdeesCibleIdReponsesRepIdDelete(path: .init(cibleId: cibleId, repId: id))
            }
            try verifier(sortie.statutSupprime)
        case .annonce(let cibleId):
            let sortie = try await appeler {
                try await client.deleteReponseAnnoncesCibleIdReponsesRepIdDelete(
                    path: .init(cibleId: cibleId, repId: id))
            }
            try verifier(sortie.statutSupprime)
        case .reponse:
            throw ErreurService.inattendue(400)
        }
    }

    func signalerAuConseil(_ cible: CibleCommunaute, motif: String, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).creerSignalementSignalementsPost(
                body: .json(.init(cibleId: cible.id, cibleType: cible.typeSignalement, motif: motif)))
        }
        try verifier(sortie.statutCree)
    }

    func avisCommunaute(_ installation: Installation) async throws -> ListeAvis {
        let sortie = try await appeler { try await client(installation.adresse).listerAvisGet() }
        switch sortie {
        case .ok(let ok):
            let liste = try ok.body.json
            return ListeAvis(
                avis: liste.avis.map(AvisResident.init(lu:)), gestionnaire: liste.gestionnaire,
                monAvisId: liste.monAvisId)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func deposerAvis(_ saisie: SaisieAvis, dans installation: Installation) async throws {
        let corps = Components.Schemas.AvisCreate(
            consentementPublication: saisie.consentementEnvoye, description: saisie.description, note: saisie.note,
            remarque: saisie.remarqueEnvoyee, titre: saisie.titre)
        let sortie = try await appeler { try await client(installation.adresse).deposerAvisPost(body: .json(corps)) }
        switch sortie {
        case .created: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func corrigerAvis(_ id: Int, _ saisie: SaisieAvis, dans installation: Installation) async throws {
        let corps = Components.Schemas.AvisUpdate(
            consentementPublication: saisie.consentementEnvoye, description: saisie.description, note: saisie.note,
            remarque: saisie.remarqueEnvoyee, titre: saisie.titre)
        let sortie = try await appeler {
            try await client(installation.adresse).corrigerAvisAvisIdPatch(path: .init(avisId: id), body: .json(corps))
        }
        switch sortie {
        case .ok: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func archiverAvis(_ id: Int, archive: Bool, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).archiverAvisAvisIdArchivagePatch(
                path: .init(avisId: id), body: .json(.init(archivee: archive)))
        }
        switch sortie {
        case .noContent: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    /// Un statut de réussite (`nil`) ou d'échec, dit en une phrase.
    private func verifier(_ statut: Int?) throws {
        if let statut { throw statut == 422 ? ErreurService.inattendue(422) : ErreurService.depuisLecture(statut) }
    }
}

// Le statut d'échec d'une écriture qui rend 201, d'une suppression qui rend 204 —
// `nil` sur une réussite. Une extension par sortie : chacune est un type généré.
extension Operations.CreateIdeeIdeesPost.Output {
    fileprivate var statutCree: Int? {
        switch self {
        case .created: nil
        case .unprocessableContent: 422
        case .undocumented(let statut, _): statut
        }
    }
}

extension Operations.CreateReponseIdeesCibleIdReponsesPost.Output {
    fileprivate var statutCree: Int? {
        switch self {
        case .created: nil
        case .unprocessableContent: 422
        case .undocumented(let statut, _): statut
        }
    }
}

extension Operations.CreateReponseAnnoncesCibleIdReponsesPost.Output {
    fileprivate var statutCree: Int? {
        switch self {
        case .created: nil
        case .unprocessableContent: 422
        case .undocumented(let statut, _): statut
        }
    }
}

extension Operations.CreerSignalementSignalementsPost.Output {
    fileprivate var statutCree: Int? {
        switch self {
        case .created: nil
        case .unprocessableContent: 422
        case .undocumented(let statut, _): statut
        }
    }
}

extension Operations.DeleteReponseIdeesCibleIdReponsesRepIdDelete.Output {
    fileprivate var statutSupprime: Int? {
        switch self {
        case .noContent: nil
        case .unprocessableContent: 422
        case .undocumented(let statut, _): statut
        }
    }
}

extension Operations.DeleteReponseAnnoncesCibleIdReponsesRepIdDelete.Output {
    fileprivate var statutSupprime: Int? {
        switch self {
        case .noContent: nil
        case .unprocessableContent: 422
        case .undocumented(let statut, _): statut
        }
    }
}

extension AvisResident {
    init(lu avis: Components.Schemas.AvisRead) {
        self.init(
            id: avis.id, note: avis.note, titre: avis.titre, description: avis.description,
            auteurNom: avis.auteurNom, auteurRole: avis.auteurRole, estAuteur: avis.estAuteur ?? false,
            reponse: avis.reponse, reponseLe: avis.reponseLe, remarque: avis.remarque,
            consentement: avis.consentementPublication, archivee: avis.archivee ?? false,
            restaurable: avis.restaurable ?? false, luDeTous: avis.luDeTous ?? true,
            retenu: avis.publicationValidee ?? false, creeLe: avis.creeLe)
    }
}
