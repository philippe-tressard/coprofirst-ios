// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Les écrans de détail : affaire, document, photo (le sondage : `Commun/Detail/Sondage/`) — par le client généré.
extension ServiceAPI {
    func affaire(_ id: Int, dans installation: Installation) async throws -> DetailAffaire {
        let client = client(installation.adresse)
        // Le corps se garde : `agenda_propose` (contrat 2.15.0) est servi au-dessus du plancher (#435).
        async let ticketServi = appeler {
            try await CorpsServi.garder { try await client.getTicketsTicketId(path: .init(ticketId: id)) }
        }
        async let evolutions = appeler { try await client.getTicketsTicketIdEvolutions(path: .init(ticketId: id)) }
        async let messages = appeler { try await client.getTicketsTicketIdMessages(path: .init(ticketId: id)) }
        async let servis = referentiels(installation)
        async let comptesRendus = comptesRendus(id, client: client)

        let lu: Components.Schemas.TicketRead
        let (ticket, corps) = try await ticketServi
        switch ticket {
        case .ok(let ok): lu = try ok.body.json
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
        var lues: [Components.Schemas.TicketEvolutionRead] = []
        if case .ok(let ok) = try await evolutions { lues = try ok.body.json }
        var detail = DetailAffaire.lue(
            lu, evolutions: lues, agenda: Relecture.auDessusDuPlancher(ChampsAgenda.self, corps: corps))
        // Des référentiels illisibles n'empêchent pas de lire l'affaire : rien de ce qu'ils
        // ouvrent n'est alors offert (états d'une Suite, catégories), et un état que l'objet
        // ne met pas en clair se montre par son code.
        detail.referentiels = (try? await servis) ?? .vides
        // Le fil de l'affaire (#178) : ses comptes rendus, puis sa synthèse si elle est close.
        detail.comptesRendus = await comptesRendus
        if detail.close { detail.synthese = await synthese(id, client: client) }
        // Pas de messages sur une actualité : elle informe, on n'y répond pas (`+page.svelte`).
        guard !detail.estActualite else { return detail }
        switch try await messages {
        case .ok(let ok): detail.messages = MessageAffaire.lus(try ok.body.json)
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

    /// Un fichier de `/uploads/` (photo, pièce jointe) n'est pas une route de l'API : il est
    /// derrière la session (forward_auth). La session HTTP de l'installation la lit, cookies compris.
    func fichierProtege(_ chemin: String, dans installation: Installation) async throws -> Data {
        guard let adresse = URL(string: chemin, relativeTo: installation.adresse)?.absoluteURL,
            adresse.host() == installation.adresse.host()
        else { throw ErreurService.inattendue(400) }
        return try await lireFichier(adresse, session: installation.adresse)
    }

    /// Le logo de la résidence que dit `Installation.logo(sombre:)` : GET /config/logo.png par
    /// le client généré (#345), la variante en paramètre. Le contrat déclare du JSON, le
    /// serveur sert l'image : ses octets se lisent par `octetsServis`. Une route publique.
    func logo(_ demande: LogoDemande) async throws -> Data {
        let client = clientPublic(demande.installation)
        return try await Self.octetsServis {
            switch try await client.getConfigLogoPng(query: .init(variante: demande.sombre ? .sombre : nil)) {
            case .ok: break
            case .unprocessableContent: throw ErreurService.inattendue(422)
            case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
            }
        }
    }

    /// Un fichier de l'hôte (photo, pièce jointe), lu par la session HTTP de son installation ;
    /// un 401 s'y renouvelle (#81).
    private func lireFichier(_ adresse: URL, session installation: URL) async throws -> Data {
        let lire = { [sessions] in try await sessions.session(pour: adresse).data(from: adresse) }
        let statutLu: ((Data, URLResponse)) -> Int = { ($0.1 as? HTTPURLResponse)?.statusCode ?? 0 }
        do {
            let (donnees, reponse) = try await rejouerSurRefus(installation, statut: statutLu, envoyer: lire)
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
