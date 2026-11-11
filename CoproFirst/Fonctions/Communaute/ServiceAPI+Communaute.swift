// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import OpenAPIRuntime

/// La Communauté par le client GÉNÉRÉ. Idées et annonces n'ont pas de réponse typée
/// dans le contrat : elles se relisent en miroir (`Relecture`) — besoin noté pour
/// coprofirst#2460 (déclarer leurs `response_model`).
extension ServiceAPI: ServiceCommunaute {
    func moiCommunaute(_ installation: Installation) async throws -> MoiCommunaute {
        let (sortie, corps) = try await appeler {
            try await CorpsServi.garder { try await client(installation.adresse).getAuthMe() }
        }
        switch sortie {
        case .ok(let ok):
            let moi = try ok.body.json
            return MoiCommunaute(
                id: moi.id, statut: moi.statut.rawValue, roles: (moi.roles ?? []) + [moi.role.rawValue],
                motifRefus: moi.communauteMotifRefus.flatMap { $0.isEmpty ? nil : $0 },
                estModerateur: PersonneServie.lue(corps)?.estModerateur)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func sondagesCommunaute(_ installation: Installation) async throws -> [SondageResume] {
        let sortie = try await appeler { try await client(installation.adresse).getSondages() }
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
        let sortie = try await appeler { try await client(installation.adresse).getIdees() }
        switch sortie {
        case .ok(let ok): return try ok.body.json.map(Idee.init)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func proposerIdee(titre: String, description: String, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).postIdees(
                body: .json(.init(description: description, titre: titre)))
        }
        try await verifier(sortie.echec)
    }

    func voterIdee(_ id: Int, dans installation: Installation) async throws -> String? {
        let sortie = try await appeler {
            try await client(installation.adresse).postIdeesIdeeIdVoter(path: .init(ideeId: id))
        }
        switch sortie {
        case .created(let cree):
            return try? cree.body.json.message
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func annonces(_ installation: Installation) async throws -> [Annonce] {
        let sortie = try await appeler { try await client(installation.adresse).getAnnonces() }
        switch sortie {
        case .ok(let ok): return try ok.body.json.map(Annonce.init)
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
            try await client(installation.adresse).postAnnonces(body: .json(corps))
        }
        switch sortie {
        case .ok: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func changerStatutAnnonce(_ id: Int, statut: String, dans installation: Installation) async throws {
        guard let code = Components.Schemas.StatutAnnonce(rawValue: statut) else { throw ErreurService.inattendue(422) }
        let sortie = try await appeler {
            try await client(installation.adresse).patchAnnoncesAnnonceIdStatut(
                path: .init(annonceId: id), body: .json(.init(statut: code)))
        }
        switch sortie {
        case .ok: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func supprimerAnnonce(_ id: Int, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).deleteAnnoncesAnnonceId(path: .init(annonceId: id))
        }
        switch sortie {
        case .ok: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func repondreCommunaute(_ texte: String, a cible: CibleCommunaute, dans installation: Installation) async throws {
        let client = client(installation.adresse)
        let corps = Components.Schemas.ReponseCreate(contenu: texte)
        switch cible {
        case .idee(let id):
            let sortie = try await appeler {
                try await client.postIdeesCibleIdReponses(path: .init(cibleId: id), body: .json(corps))
            }
            try await verifier(sortie.echec)
        case .annonce(let id):
            let sortie = try await appeler {
                try await client.postAnnoncesCibleIdReponses(path: .init(cibleId: id), body: .json(corps))
            }
            try await verifier(sortie.echec)
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
                try await client.deleteIdeesCibleIdReponsesRepId(path: .init(cibleId: cibleId, repId: id))
            }
            try await verifier(sortie.echec)
        case .annonce(let cibleId):
            let sortie = try await appeler {
                try await client.deleteAnnoncesCibleIdReponsesRepId(
                    path: .init(cibleId: cibleId, repId: id))
            }
            try await verifier(sortie.echec)
        case .reponse:
            throw ErreurService.inattendue(400)
        }
    }

    func avisCommunaute(_ installation: Installation) async throws -> ListeAvis {
        let sortie = try await appeler { try await client(installation.adresse).getAvis() }
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
        let sortie = try await appeler { try await client(installation.adresse).postAvis(body: .json(corps)) }
        switch sortie {
        case .created: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func corrigerAvis(_ id: Int, _ saisie: SaisieAvis, dans installation: Installation) async throws {
        let corps = Components.Schemas.AvisUpdate(
            consentementPublication: saisie.consentementEnvoye, description: saisie.description, note: saisie.note,
            remarque: saisie.remarqueEnvoyee, titre: saisie.titre)
        let sortie = try await appeler {
            try await client(installation.adresse).patchAvisAvisId(path: .init(avisId: id), body: .json(corps))
        }
        switch sortie {
        case .ok: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func archiverAvis(_ id: Int, archive: Bool, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).patchAvisAvisIdArchivage(
                path: .init(avisId: id), body: .json(.init(archivee: archive)))
        }
        switch sortie {
        case .noContent: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    /// Une réussite (`nil`) ou un échec, dit en une phrase — celle du serveur s'il en donne une.
    private func verifier(_ echec: EchecDEcriture?) async throws {
        switch echec {
        case nil: return
        case .saisie: throw ErreurService.inattendue(422)
        case .refus(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }
}

/// L'échec d'une écriture : la saisie refusée (422), ou un refus et sa réponse.
private enum EchecDEcriture {
    case saisie
    case refus(Int, UndocumentedPayload)
}

// L'échec d'une écriture qui rend 201, d'une suppression qui rend 204 — `nil` sur
// une réussite. Une extension par sortie : chacune est un type généré.
extension Operations.PostIdees.Output {
    fileprivate var echec: EchecDEcriture? {
        switch self {
        case .created: nil
        case .unprocessableContent: .saisie
        case .undocumented(let statut, let reponse): .refus(statut, reponse)
        }
    }
}

extension Operations.PostIdeesCibleIdReponses.Output {
    fileprivate var echec: EchecDEcriture? {
        switch self {
        case .created: nil
        case .unprocessableContent: .saisie
        case .undocumented(let statut, let reponse): .refus(statut, reponse)
        }
    }
}

extension Operations.PostAnnoncesCibleIdReponses.Output {
    fileprivate var echec: EchecDEcriture? {
        switch self {
        case .created: nil
        case .unprocessableContent: .saisie
        case .undocumented(let statut, let reponse): .refus(statut, reponse)
        }
    }
}

extension Operations.DeleteIdeesCibleIdReponsesRepId.Output {
    fileprivate var echec: EchecDEcriture? {
        switch self {
        case .noContent: nil
        case .unprocessableContent: .saisie
        case .undocumented(let statut, let reponse): .refus(statut, reponse)
        }
    }
}

extension Operations.DeleteAnnoncesCibleIdReponsesRepId.Output {
    fileprivate var echec: EchecDEcriture? {
        switch self {
        case .noContent: nil
        case .unprocessableContent: .saisie
        case .undocumented(let statut, let reponse): .refus(statut, reponse)
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

// Le contrat 1.5.0 type les idées et les annonces (`IdeeRead`, `AnnonceRead`) : elles se
// lisent par leurs types générés — le client a déjà décodé leurs dates. Les relire par
// `Relecture` réencodait ces dates en nombre (bogue du 06/11/2026). L'API simulée passe
// par ces mêmes branchements (`FixturesCommunaute`).
extension Idee {
    init(_ lue: Components.Schemas.IdeeRead) {
        self.init(
            id: lue.id, titre: lue.titre, description: lue.description, auteurId: lue.auteurId, statut: lue.statut,
            creeLe: lue.creeLe, nbVotes: lue.nbVotes ?? 0, monVote: lue.monVote ?? false, archivee: lue.archivee,
            reponses: lue.reponses?.map(ReponseCommunaute.init))
    }
}

extension Annonce {
    init(_ lue: Components.Schemas.AnnonceRead) {
        self.init(
            id: lue.id, titre: lue.titre, description: lue.description, typeAnnonce: lue.typeAnnonce.rawValue,
            categorie: lue.categorie.rawValue, prix: lue.prix, negotiable: lue.negotiable, photos: lue.photos,
            statut: lue.statut.rawValue, auteurPrenom: lue.auteurPrenom, auteurNom: lue.auteurNom,
            auteurEmail: lue.auteurEmail, estAuteur: lue.estAuteur, peutSupprimer: lue.peutSupprimer ?? false,
            archivee: lue.archivee, creeLe: lue.creeLe,
            reponses: lue.reponses?.map(ReponseCommunaute.init))
    }
}
