// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Le menu Affaires par le client GÉNÉRÉ — aucune route écrite à la main.
extension ServiceAPI: ServiceAffaires {
    func affaires(_ installation: Installation) async throws -> [Affaire] {
        let sortie = try await appeler { try await client(installation.adresse).listTicketsTicketsGet() }
        switch sortie {
        case .ok(let ok): return try ok.body.json.map(Affaire.init(ticket:))
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func rechercher(_ terme: String, dans installation: Installation) async throws -> [Int] {
        let sortie = try await appeler {
            try await client(installation.adresse).rechercherTicketsRechercheGet(query: .init(q: terme))
        }
        switch sortie {
        case .ok(let ok):
            // Une affaire peut répondre par plusieurs endroits : la première fait son rang.
            var vus = Set<Int>()
            return try ok.body.json.map(\.ticketId).filter { vus.insert($0).inserted }
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func offrirMeConcerne(_ installation: Installation) async -> Bool {
        // Une lecture qui échoue tait la pastille, sans gêner la liste (`offrirLaPastille`).
        guard
            case .ok(let ok) = try? await client(installation.adresse).mesPerimetresLotsMesPerimetresGet(),
            let mes = try? ok.body.json
        else { return false }
        return !mes.batiments.isEmpty || !mes.desservis.isEmpty
    }

    func perimetres(_ installation: Installation) async throws -> [PerimetreAffaire] {
        let sortie = try await appeler { try await client(installation.adresse).listerPerimetresPerimetresGet() }
        switch sortie {
        case .ok(let ok):
            return try ok.body.json.filter { $0.actif && $0.selectionnable }.map {
                PerimetreAffaire(
                    code: $0.code, libelle: $0.libelle, profondeur: $0.profondeur, global: $0.porteeGlobale,
                    racine: $0.parent == nil)
            }
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func creer(_ saisie: SaisieAffaire, dans installation: Installation) async throws -> Affaire {
        guard let categorie = Components.Schemas.CategorieTicket(rawValue: saisie.categorie) else {
            throw ErreurAffaires.categorieInconnue
        }
        let corps = Components.Schemas.TicketCreate(
            categorie: categorie, description: saisie.descriptionHTML,
            perimetreCible: saisie.perimetre.map { [$0] },
            titre: saisie.titre.trimmingCharacters(in: .whitespacesAndNewlines), urgente: saisie.urgente)
        let sortie = try await appeler {
            try await client(installation.adresse).createTicketTicketsPost(body: .json(corps))
        }
        switch sortie {
        case .created(let cree): return Affaire(ticket: try cree.body.json)
        case .unprocessableContent: throw ErreurAffaires.saisieRefusee
        case .undocumented(let statut, _): throw ErreurAffaires.depuis(statut)
        }
    }

    func candidatesALaFusion(_ affaire: Affaire, dans installation: Installation) async throws -> Int {
        let sortie = try await appeler {
            try await client(installation.adresse).candidatesALaFusionTicketsTicketIdFusionGet(
                path: .init(ticketId: affaire.id))
        }
        switch sortie {
        case .ok(let ok): return try ok.body.json.count
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurAffaires.depuis(statut)
        }
    }

    func deplacer(_ affaire: Affaire, vers statut: String, dans installation: Installation) async throws {
        guard let nouveau = Components.Schemas.StatutTicket(rawValue: statut) else {
            throw ErreurAffaires.saisieRefusee
        }
        let corps = Components.Schemas.TicketEvolutionCreate(notifier: false, nouveauStatut: nouveau, _type: "etat")
        let sortie = try await appeler {
            try await client(installation.adresse).addEvolutionTicketsTicketIdEvolutionsPost(
                path: .init(ticketId: affaire.id), body: .json(corps))
        }
        switch sortie {
        case .created: return
        case .unprocessableContent: throw ErreurAffaires.saisieRefusee
        case .undocumented(let statut, _): throw ErreurAffaires.depuis(statut)
        }
    }

    func archiver(_ affaire: Affaire, dans installation: Installation) async throws -> Affaire {
        let sortie = try await appeler {
            try await client(installation.adresse).updateTicketTicketsTicketIdPatch(
                path: .init(ticketId: affaire.id), body: .json(.init(archiveManuel: true)))
        }
        switch sortie {
        case .ok(let ok): return Affaire(ticket: try ok.body.json)
        case .unprocessableContent: throw ErreurAffaires.saisieRefusee
        case .undocumented(let statut, _): throw ErreurAffaires.depuis(statut)
        }
    }
}

extension Affaire {
    init(ticket: Components.Schemas.TicketRead) {
        self.init(
            id: ticket.id, numero: ticket.numero, titre: ticket.titre, apercu: ticket.description,
            creeLe: ticket.creeLe, misAJourLe: ticket.misAJourLe, statut: ticket.statut,
            categorie: ticket.categorie,
            // La règle du site : urgente = priorité haute (#lib/tickets.ts, ticketUrgent).
            urgente: ticket.priorite == "haute",
            meConcerne: ticket.meConcerne, archivee: ticket.archivee ?? false,
            suiviKanban: ticket.suiviKanban ?? false, natures: ticket.natures ?? [],
            prestataire: ticket.prestataireNom, perimetres: ticket.perimetreCible ?? [],
            lieu: nil, messages: nil)
    }
}

/// Ce qu'un geste du menu peut rencontrer, en une phrase.
enum ErreurAffaires: Error, Equatable, Sendable {
    /// 403 : la route refuse ce geste à ce compte.
    case refusee
    /// 422 : le serveur refuse la saisie (un champ manque ou n'est pas permis).
    case saisieRefusee
    case categorieInconnue
    /// Le service de la session ne réalise pas `ServiceAffaires` : un défaut de l'app,
    /// dit à l'écran — jamais une liste vide qui laisserait croire qu'il n'y a rien.
    case serviceAbsent
    case service(ErreurService)

    var phrase: String {
        switch self {
        case .refusee: "Ce geste est réservé au conseil syndical."
        case .saisieRefusee: "La résidence a refusé l'enregistrement. Vérifiez la saisie, puis réessayez."
        case .categorieInconnue: "Cette catégorie n'est pas connue de la résidence."
        case .serviceAbsent: "Les affaires ne sont pas disponibles dans cette version de l'app."
        case .service(let erreur): erreur.phrase
        }
    }

    static func depuis(_ statut: Int) -> ErreurAffaires {
        statut == 403 ? .refusee : .service(ErreurService.depuisLecture(statut))
    }

    static func depuis(_ erreur: any Error) -> ErreurAffaires {
        (erreur as? ErreurAffaires) ?? .service(ErreurService.depuis(erreur))
    }
}
