// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import OpenAPIRuntime

/// « Mes lots & accès » par le client GÉNÉRÉ — toutes les réponses sont typées depuis
/// le contrat 1.5.0 (coprofirst v3.66.0, #2507) : plus aucune relecture à la main.
extension ServiceAPI: ServiceAcces {
    func mesLots(_ installation: Installation) async throws -> [LotDuCompte] {
        let sortie = try await appeler { try await client(installation.adresse).getLotsMesLots() }
        switch sortie {
        case .ok(let ok): return try ok.body.json.map(LotDuCompte.init)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func monBail(_ installation: Installation) async throws -> BailDuLocataire? {
        do {
            let (sortie, corps) = try await CorpsServi.garder {
                try await client(installation.adresse).getBailleurMonBail()
            }
            switch sortie {
            case .ok(let ok): return BailDuLocataire(try ok.body.json, corps: corps)
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
        // Le corps servi est gardé : le nom affiché du locataire est au-dessus du plancher.
        if tous {
            let (sortie, corps) = try await appeler {
                try await CorpsServi.garder { try await client.getBailleurTousLesBaux() }
            }
            switch sortie {
            case .ok(let ok): return Bail.lus(try ok.body.json, corps: corps)
            case .unprocessableContent: throw ErreurService.inattendue(422)
            case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
            }
        }
        let (sortie, corps) = try await appeler {
            try await CorpsServi.garder { try await client.getBailleurMesBaux() }
        }
        switch sortie {
        case .ok(let ok): return Bail.lus(try ok.body.json, corps: corps)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func mesAcces(_ type: TypeAcces, dans installation: Installation) async throws -> [AccesDetenu] {
        let client = client(installation.adresse)
        switch type {
        case .vigik:
            switch try await appeler({ try await client.getAccesMesVigiks() }) {
            // Le type d'un accès est celui de la ROUTE appelée : `AccesPorteur` ne le porte pas.
            case .ok(let ok): return try ok.body.json.map { AccesDetenu($0, type: .vigik) }
            case .unprocessableContent: throw ErreurService.inattendue(422)
            case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
            }
        case .telecommande:
            switch try await appeler({ try await client.getAccesMesTelecommandes() }) {
            case .ok(let ok): return try ok.body.json.map { AccesDetenu($0, type: .telecommande) }
            case .unprocessableContent: throw ErreurService.inattendue(422)
            case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
            }
        }
    }

    func accesRecus(_ installation: Installation) async throws -> [AccesDetenu] {
        let sortie = try await appeler {
            try await client(installation.adresse).getBailleurMesAccesRecus()
        }
        switch sortie {
        case .ok(let ok): return try ok.body.json.map(AccesDetenu.init)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func demander(_ demande: DemandeAcces, dans installation: Installation) async throws {
        guard let lot = demande.lotId else { throw ErreurService.refus(.init(phrase: TextesAcces.choisirUnLot)) }
        let motif = demande.motif.trimmingCharacters(in: .whitespacesAndNewlines)
        let corps = Components.Schemas.CommandeAccesCreate(
            lotId: lot, motif: motif.isEmpty ? nil : motif, quantite: demande.quantite, _type: demande.type.rawValue)
        let sortie = try await appeler {
            try await client(installation.adresse).postAccesCommandes(body: .json(corps))
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
            try await client(installation.adresse).postAccesDeclarerBadge(body: .json(corps))
        }
        switch sortie {
        case .created(let cree):
            return try cree.body.json.importResolu
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func signalerPerdu(_ acces: AccesDetenu, dans installation: Installation) async throws {
        let client = client(installation.adresse)
        let statut: Int?
        if acces.type == TypeAcces.telecommande.rawValue {
            let sortie = try await appeler {
                try await client.patchAccesTelecommandesTcIdPerdu(
                    path: .init(tcId: acces.id), body: .json(.init()))
            }
            switch sortie {
            case .ok: statut = nil
            case .unprocessableContent: statut = 422
            case .undocumented(let code, let reponse): throw await Self.refus(code, reponse)
            }
        } else {
            let sortie = try await appeler {
                try await client.patchAccesVigiksVigikIdPerdu(
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
            try await client(installation.adresse).postBailleurBauxBailIdRecupererAcces(
                path: .init(bailId: bail))
        }
        switch sortie {
        case .ok: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }
}

extension Bail {
    /// Les baux servis, puis le nom affiché du locataire relu au-dessus du plancher — le
    /// MÊME branchement pour le service réel et l'API simulée.
    static func lus(_ generes: [Components.Schemas.BailOut], corps: Data?) -> [Bail] {
        let personnes = PersonneServie.parLigne(corps)
        return generes.map {
            var bail = Bail($0)
            bail.locataireNomServi = personnes[$0.id]?.locataireNomAffiche
            return bail
        }
    }

    private init(_ bail: Components.Schemas.BailOut) {
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

extension LotDuCompte {
    init(_ lu: Components.Schemas.LotRead) {
        self.init(
            id: lu.id, numero: lu.numero, type: lu._type, typeAppartement: lu.typeAppartement, etage: lu.etage,
            superficie: lu.superficie, batimentNom: lu.batimentNom, typeLien: lu.typeLien,
            numeroUsage: lu.numeroUsage,
            perimetres: (lu.perimetres ?? []).map { PerimetreDuLot(libelle: $0.libelle, relation: $0.relation) },
            alertes: (lu.alertes ?? []).map { ConstatDuLot(code: $0.code, gravite: $0.gravite, message: $0.message) },
            libelleTypeComplet: lu.libelleTypeComplet, etageLibelle: lu.etageLibelle)
    }
}

extension AccesDetenu {
    /// Un accès DÉTENU (`/acces/mes-vigiks`, `/acces/mes-telecommandes`) : son type est
    /// celui de la route qui l'a servi.
    init(_ acces: Components.Schemas.AccesPorteur, type: TypeAcces) {
        self.init(
            id: acces.id, code: acces.code, statut: acces.statut.rawValue, type: type.rawValue,
            chezLocataire: acces.chezLocataire, bailId: acces.bailId)
    }

    /// Un accès CONFIÉ par un bailleur (`AccesOut`, qui porte son type).
    init(_ acces: Components.Schemas.AccesOut) {
        self.init(
            id: acces.id, code: acces.code, statut: acces.statut.rawValue, type: acces._type,
            chezLocataire: acces.chezLocataire, bailId: acces.bailId)
    }
}

extension BailDuLocataire {
    /// Le bail servi, et le nom affiché du bailleur relu au-dessus du plancher.
    init(_ bail: Components.Schemas.BailLocataireOut, corps: Data?) {
        self.init(
            id: bail.id, statut: bail.statut.rawValue, lotBatimentNom: bail.lotBatimentNom,
            lotNumero: bail.lotNumero, lotType: bail.lotType, lotTypeAppartement: bail.lotTypeAppartement,
            lotEtage: bail.lotEtage, lotSuperficie: bail.lotSuperficie, dateEntree: bail.dateEntree,
            dateSortiePrevue: bail.dateSortiePrevue, bailleurPrenom: bail.bailleurPrenom,
            bailleurNom: bail.bailleurNom, bailleurEmail: bail.bailleurEmail,
            bailleurTelephone: bail.bailleurTelephone, bailleurNomServi: PersonneServie.lue(corps)?.bailleurNomAffiche)
    }
}
