// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import OpenAPIRuntime

/// « Mes lots & accès » par le client GÉNÉRÉ.
///
/// ⚠️ Trois réponses ne sont pas typées dans le contrat (`/lots/mes-lots`,
/// `/acces/mes-vigiks`, `/acces/mes-telecommandes` : pas de `response_model`) : elles
/// sont relues telles quelles, comme `sondage` le fait déjà, en attendant que
/// coprofirst les type (coprofirst#2507). La route, elle, reste celle du client.
extension ServiceAPI: ServiceAcces {
    func mesLots(_ installation: Installation) async throws -> [LotDuCompte] {
        let sortie = try await appeler { try await client(installation.adresse).mesLotsLotsMesLotsGet() }
        switch sortie {
        case .ok(let ok): return try Self.relire(try ok.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func monBail(_ installation: Installation) async throws -> BailDuLocataire? {
        do {
            let sortie = try await client(installation.adresse).monBailBailleurMonBailGet()
            switch sortie {
            case .ok(let ok): return BailDuLocataire(try ok.body.json)
            case .unprocessableContent: throw ErreurService.inattendue(422)
            case .undocumented(let statut, _):
                if statut == 404 { return nil }
                throw ErreurService.depuisLecture(statut)
            }
        } catch let erreur as ClientError where erreur.response?.status == .ok {
            // « Pas de bail » est un 200 qui porte `null` (#1459) : le décodage typé
            // le refuse, ce n'est pas une erreur.
            if ClientCoproFirst.cause(erreur) is DecodingError { return nil }
            throw ErreurService.depuis(ClientCoproFirst.cause(erreur))
        } catch let erreur as ErreurService {
            throw erreur
        } catch {
            throw ErreurService.depuis(ClientCoproFirst.cause(error))
        }
    }

    func baux(_ installation: Installation, tous: Bool) async throws -> [Bail] {
        let client = client(installation.adresse)
        if tous {
            switch try await appeler({ try await client.tousLesBauxBailleurTousLesBauxGet() }) {
            case .ok(let ok): return try ok.body.json.map(Bail.init)
            case .unprocessableContent: throw ErreurService.inattendue(422)
            case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
            }
        }
        switch try await appeler({ try await client.mesBauxBailleurMesBauxGet() }) {
        case .ok(let ok): return try ok.body.json.map(Bail.init)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func mesAcces(_ type: TypeAcces, dans installation: Installation) async throws -> [AccesDetenu] {
        let client = client(installation.adresse)
        switch type {
        case .vigik:
            switch try await appeler({ try await client.mesVigiksAccesMesVigiksGet() }) {
            case .ok(let ok): return try Self.relire(try ok.body.json)
            case .unprocessableContent: throw ErreurService.inattendue(422)
            case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
            }
        case .telecommande:
            switch try await appeler({ try await client.mesTelecommandesAccesMesTelecommandesGet() }) {
            case .ok(let ok): return try Self.relire(try ok.body.json)
            case .unprocessableContent: throw ErreurService.inattendue(422)
            case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
            }
        }
    }

    func accesRecus(_ installation: Installation) async throws -> [AccesDetenu] {
        let sortie = try await appeler {
            try await client(installation.adresse).mesAccesRecusBailleurMesAccesRecusGet()
        }
        switch sortie {
        case .ok(let ok): return try ok.body.json.map(AccesDetenu.init)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func demander(_ demande: DemandeAcces, dans installation: Installation) async throws {
        guard let lot = demande.lotId else { throw RefusDuServeur(phrase: TextesAcces.choisirUnLot) }
        let motif = demande.motif.trimmingCharacters(in: .whitespacesAndNewlines)
        let corps = Components.Schemas.CommandeAccesCreate(
            lotId: lot, motif: motif.isEmpty ? nil : motif, quantite: demande.quantite, _type: demande.type.rawValue)
        let sortie = try await appeler {
            try await client(installation.adresse).creerCommandeAccesCommandesPost(body: .json(corps))
        }
        switch sortie {
        case .created: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func declarer(_ type: TypeAcces, code: String, dans installation: Installation) async throws -> Bool {
        let corps = Components.Schemas.DeclarerBadgeBody(code: code, _type: type.rawValue)
        let sortie = try await appeler {
            try await client(installation.adresse).declarerBadgeAccesDeclarerBadgePost(body: .json(corps))
        }
        switch sortie {
        case .created(let cree):
            // Réponse non typée : `{type, id, code, import_resolu}`.
            let lu: Declaration? = try? Self.relire(try cree.body.json)
            return lu?.importResolu ?? false
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func signalerPerdu(_ acces: AccesDetenu, dans installation: Installation) async throws {
        let client = client(installation.adresse)
        let statut: Int?
        if acces.type == TypeAcces.telecommande.rawValue {
            let sortie = try await appeler {
                try await client.signalerTcPerduAccesTelecommandesTcIdPerduPatch(
                    path: .init(tcId: acces.id), body: .json(.init()))
            }
            switch sortie {
            case .ok: statut = nil
            case .unprocessableContent: statut = 422
            case .undocumented(let code, let reponse): throw await Self.refus(code, reponse)
            }
        } else {
            let sortie = try await appeler {
                try await client.signalerVigikPerduAccesVigiksVigikIdPerduPatch(
                    path: .init(vigikId: acces.id), body: .json(.init()))
            }
            switch sortie {
            case .ok: statut = nil
            case .unprocessableContent: statut = 422
            case .undocumented(let code, let reponse): throw await Self.refus(code, reponse)
            }
        }
        if let statut { throw ErreurService.inattendue(statut) }
    }

    func recupererAcces(bail: Int, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).recupererAccesBailleurBauxBailIdRecupererAccesPost(
                path: .init(bailId: bail))
        }
        switch sortie {
        case .ok: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    // MARK: - Relectures

    private struct Declaration: Decodable {
        let importResolu: Bool?
    }

    /// Une réponse non typée, relue dans le modèle de l'écran (clés en `snake_case`).
    static func relire<T: Decodable>(_ brut: OpenAPIValueContainer) throws -> T {
        let decodeur = JSONDecoder()
        decodeur.keyDecodingStrategy = .convertFromSnakeCase
        return try decodeur.decode(T.self, from: JSONEncoder().encode(brut))
    }

    /// Un refus du serveur, avec SA phrase (`detail`) quand il en donne une.
    static func refus(_ statut: Int, _ reponse: UndocumentedPayload) async -> any Error {
        if statut == 401 { return ErreurService.sessionExpiree }
        struct Detail: Decodable { let detail: String }
        if let corps = reponse.body, let donnees = try? await Data(collecting: corps, upTo: 64 * 1024),
            let lu = try? JSONDecoder().decode(Detail.self, from: donnees), !lu.detail.isEmpty
        {
            return RefusDuServeur(phrase: lu.detail)
        }
        return ErreurService.depuisLecture(statut)
    }
}

extension Bail {
    init(_ bail: Components.Schemas.BailOut) {
        self.init(
            id: bail.id, lotId: bail.lotId, statut: bail.statut.rawValue, locataireId: bail.locataireId,
            locatairePrenom: bail.locatairePrenom, locataireNom: bail.locataireNom,
            locataireEmail: bail.locataireEmail, locataireTelephone: bail.locataireTelephone,
            dateEntree: bail.dateEntree, dateSortiePrevue: bail.dateSortiePrevue,
            dateSortieReelle: bail.dateSortieReelle, notes: bail.notes,
            objets: (bail.objets ?? []).map(ObjetRemis.init))
    }
}

extension ObjetRemis {
    init(_ objet: Components.Schemas.ObjetOut) {
        self.init(
            id: objet.id, type: objet._type.rawValue, libelle: objet.libelle, quantite: objet.quantite,
            reference: objet.reference, statut: objet.statut.rawValue, remisLe: objet.remisLe,
            renduLe: objet.renduLe)
    }
}

extension AccesDetenu {
    init(_ acces: Components.Schemas.AccesOut) {
        self.init(
            id: acces.id, code: acces.code, statut: acces.statut.rawValue, type: acces._type,
            chezLocataire: acces.chezLocataire, bailId: acces.bailId)
    }
}

extension BailDuLocataire {
    init(_ bail: Components.Schemas.BailLocataireOut) {
        self.init(
            id: bail.id, statut: bail.statut.rawValue, lotBatimentNom: bail.lotBatimentNom,
            lotNumero: bail.lotNumero, lotType: bail.lotType, lotTypeAppartement: bail.lotTypeAppartement,
            lotEtage: bail.lotEtage, lotSuperficie: bail.lotSuperficie, dateEntree: bail.dateEntree,
            dateSortiePrevue: bail.dateSortiePrevue, bailleurPrenom: bail.bailleurPrenom,
            bailleurNom: bail.bailleurNom, bailleurEmail: bail.bailleurEmail,
            bailleurTelephone: bail.bailleurTelephone)
    }
}
