// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Les écrans de détail : affaire, document, photo (le sondage : `Commun/Detail/Sondage/`) — par le client généré.
extension ServiceAPI {
    func affaire(_ id: Int, dans installation: Installation) async throws -> DetailAffaire {
        let client = client(installation.adresse)
        // Les deux lectures gardent leur corps servi : ce que le plancher ne type pas encore
        // s'y relit (`DetailAffaire.lue`, #125, #127).
        async let ticket = appeler {
            try await CorpsServi.garder { try await client.getTicketsTicketId(path: .init(ticketId: id)) }
        }
        async let evolutions = appeler {
            try await CorpsServi.garder { try await client.getTicketsTicketIdEvolutions(path: .init(ticketId: id)) }
        }
        async let messages = appeler { try await client.getTicketsTicketIdMessages(path: .init(ticketId: id)) }
        async let compte = appeler { try await client.getAuthMe() }

        let lu: Components.Schemas.TicketRead
        let (sortie, corps) = try await ticket
        switch sortie {
        case .ok(let ok): lu = try ok.body.json
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
        var lues: [Components.Schemas.TicketEvolutionRead] = []
        let (suites, corpsSuites) = try await evolutions
        if case .ok(let ok) = suites { lues = try ok.body.json }
        var detail = DetailAffaire.lue(lu, corps: corps, evolutions: lues, corpsEvolutions: corpsSuites)
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
        return try await lireFichier(adresse, session: installation.adresse)
    }

    /// Le logo de la résidence, à l'adresse que donne `Installation.adresseLogo(sombre:)`
    /// — une image servie par l'API, que le contrat déclare en JSON : la session de
    /// l'hôte la lit, comme une photo. Une route publique : rien à renouveler.
    func logo(_ adresse: URL) async throws -> Data {
        try await lireFichier(adresse, session: nil)
    }

    /// Un fichier de l'hôte (image, photo), lu par la session HTTP de son installation ;
    /// derrière la `session` de cette installation, un 401 s'y renouvelle (#81).
    private func lireFichier(_ adresse: URL, session installation: URL?) async throws -> Data {
        let lire = { [sessions] in try await sessions.session(pour: adresse).data(from: adresse) }
        let statutLu: ((Data, URLResponse)) -> Int = { ($0.1 as? HTTPURLResponse)?.statusCode ?? 0 }
        do {
            let (donnees, reponse) =
                if let installation {
                    try await rejouerSurRefus(installation, statut: statutLu, envoyer: lire)
                } else {
                    try await lire()
                }
            let statut = statutLu((donnees, reponse))
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
