// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Les écrans de détail : affaire, document, photo (le sondage : `Commun/Detail/Sondage/`) — par le client généré.
extension ServiceAPI {
    func affaire(_ id: Int, dans installation: Installation) async throws -> DetailAffaire {
        let client = client(installation.adresse)
        async let ticket = appeler { try await client.getTicketsTicketId(path: .init(ticketId: id)) }
        async let evolutions = appeler {
            try await client.getTicketsTicketIdEvolutions(path: .init(ticketId: id))
        }
        async let messages = appeler { try await client.getTicketsTicketIdMessages(path: .init(ticketId: id)) }
        async let compte = appeler { try await client.getAuthMe() }

        let lu: Components.Schemas.TicketRead
        switch try await ticket {
        case .ok(let ok): lu = try ok.body.json
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
        var suites: [SuiteAffaire] = []
        if case .ok(let ok) = try await evolutions {
            suites = try ok.body.json.map(SuiteAffaire.init(evolution:)).sorted { $0.date < $1.date }
        }
        var detail = DetailAffaire(ticket: lu, suites: suites)
        // Pas de messages sur une actualité : elle informe, on n'y répond pas (`+page.svelte`).
        guard !detail.estActualite else { return detail }
        // Le compte illisible n'empêche pas de lire le fil : aucune bulle n'est alors « à moi ».
        var moi: Int?
        if case .ok(let ok)? = try? await compte { moi = try? ok.body.json.id }
        switch try await messages {
        case .ok(let ok): detail.messages = try ok.body.json.map { MessageAffaire($0, moi: moi) }
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
        return detail
    }

    /// POST /tickets/{id}/messages — la réponse du site (`sendMessage`) : un message du
    /// fil, que le serveur double lui-même d'une suite « reponse » dans l'Historique.
    func repondre(_ texte: String, a affaire: Int, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).postTicketsTicketIdMessages(
                path: .init(ticketId: affaire), body: .json(Self.corpsReponse(texte)))
        }
        switch sortie {
        case .created: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    /// Le corps de « Répondre » : le texte saisi, écrit comme l'éditeur du site ; un
    /// message public (`interne` : défaut du serveur), sans pièce jointe.
    static func corpsReponse(_ texte: String) -> Components.Schemas.MessageCreate {
        .init(contenu: TexteDuSite.html(saisi: texte))
    }

    /// POST /tickets/{id}/evolutions — LA porte des suites d'une affaire : la réponse,
    /// la Suite du bandeau, le glissement au Kanban. `siInvalide` : ce qu'un 422 dit.
    func ajouterEvolution(
        _ corps: Components.Schemas.TicketEvolutionCreate, a affaire: Int, dans installation: Installation,
        siInvalide: any Error = ErreurService.inattendue(422)
    ) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).postTicketsTicketIdEvolutions(
                path: .init(ticketId: affaire), body: .json(corps))
        }
        switch sortie {
        case .created: return
        case .unprocessableContent: throw siInvalide
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    /// PATCH /tickets/{id} — LA porte des réglages d'une affaire : options, archivage.
    @discardableResult
    func modifierAffaire(
        _ affaire: Int, _ corps: Components.Schemas.TicketUpdate, dans installation: Installation,
        siInvalide: any Error = ErreurService.inattendue(422)
    ) async throws -> Components.Schemas.TicketRead {
        let sortie = try await appeler {
            try await client(installation.adresse).patchTicketsTicketId(
                path: .init(ticketId: affaire), body: .json(corps))
        }
        switch sortie {
        case .ok(let ok): return try ok.body.json
        case .unprocessableContent: throw siInvalide
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    /// Le fichier se lit par le geste commun (`ServiceAPI.fichierServi`, Commun/Session/).
    func document(_ id: Int, nom: String?, dans installation: Installation) async throws -> URL {
        let client = client(installation.adresse)
        return try await Self.fichierServi(nom: nom, defaut: "document-\(id)") {
            let sortie = try await client.getDocumentsDocIdTélécharger(path: .init(docId: id))
            if case .undocumented(let statut, _) = sortie { throw ErreurService.depuisLecture(statut) }
        }
    }

    /// Une photo de `/uploads/` n'est pas une route de l'API : un fichier derrière la
    /// session (forward_auth). La session HTTP de l'installation la lit, cookies compris.
    func photo(_ chemin: String, dans installation: Installation) async throws -> Data {
        guard let adresse = URL(string: chemin, relativeTo: installation.adresse)?.absoluteURL,
            adresse.host() == installation.adresse.host()
        else { throw ErreurService.inattendue(400) }
        return try await lireFichier(adresse)
    }

    /// Le logo de la résidence, à l'adresse que donne `Installation.adresseLogo(sombre:)`
    /// — une image servie par l'API, que le contrat déclare en JSON : la session de
    /// l'hôte la lit, comme une photo.
    func logo(_ adresse: URL) async throws -> Data {
        try await lireFichier(adresse)
    }

    /// Un fichier de l'hôte (image, photo), lu par la session HTTP de son installation.
    private func lireFichier(_ adresse: URL) async throws -> Data {
        do {
            let (donnees, reponse) = try await sessions.session(pour: adresse).data(from: adresse)
            let statut = (reponse as? HTTPURLResponse)?.statusCode ?? 0
            guard statut == 200 else { throw ErreurService.depuisLecture(statut) }
            return donnees
        } catch let erreur as ErreurService {
            throw erreur
        } catch {
            throw ErreurService.depuis(error)
        }
    }
}

extension ErreurService {
    /// Un statut d'une route de LECTURE : 401 dit une session expirée, pas des
    /// identifiants refusés ; 403 et 404, un élément qu'on ne peut pas ouvrir.
    static func depuisLecture(_ statut: Int) -> ErreurService {
        switch statut {
        case 401: .sessionExpiree
        case 403, 404: .introuvable
        default: depuis(statut: statut)
        }
    }
}

extension DetailAffaire {
    init(ticket: Components.Schemas.TicketRead, suites: [SuiteAffaire]) {
        self.init(
            id: ticket.id, numero: ticket.numero, titre: ticket.titre, description: ticket.description,
            categorie: ticket.categorie, statut: ticket.statut,
            // Urgente au sens du SERVEUR (`TicketRead.urgente`, contrat 1.8.0) : l'app ne la
            // déduit pas de la priorité.
            urgente: ticket.urgente, creeLe: ticket.creeLe,
            auteur: ticket.saisiPourAffichage ?? ticket.auteurNom, lieu: nil,
            photos: (ticket.photosUrls ?? []) + (ticket.fichiersUrls ?? []).filter(Fichiers.estImage),
            suites: suites,
            droits: DroitsServisAffaire(
                repondre: ticket.peutRepondre ?? false, changerEtat: ticket.peutChangerEtat ?? false,
                modifier: ticket.peutModifier ?? false, archiver: ticket.peutArchiver ?? false),
            epingle: ticket.epingle ?? false, archivee: ticket.archivee ?? false,
            fusionnee: ticket.fusionnee ?? false)
    }
}

extension SuiteAffaire {
    init(evolution: Components.Schemas.TicketEvolutionRead) {
        self.init(
            id: evolution.id, type: evolution._type, date: evolution.creeLe, auteur: evolution.auteurNom,
            contenu: evolution.contenu, ancienStatut: evolution.ancienStatut ?? evolution.statutAvant,
            nouveauStatut: evolution.nouveauStatut,
            photos: (evolution.fichiersUrls ?? []).filter(Fichiers.estImage))
    }
}
