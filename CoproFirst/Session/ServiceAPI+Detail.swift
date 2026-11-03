// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Les écrans de détail : affaire, sondage, document, photo — par le client généré.
extension ServiceAPI {
    func affaire(_ id: Int, dans installation: Installation) async throws -> DetailAffaire {
        let client = client(installation.adresse)
        async let ticket = appeler { try await client.getTicketTicketsTicketIdGet(path: .init(ticketId: id)) }
        async let evolutions = appeler {
            try await client.getEvolutionsTicketsTicketIdEvolutionsGet(path: .init(ticketId: id))
        }
        async let moi = appeler { try await client.meAuthMeGet() }

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
        var peutRepondre = false
        if case .ok(let ok) = try await moi, let utilisateur = try? ok.body.json {
            let roles = (utilisateur.roles ?? []) + [utilisateur.role.rawValue]
            peutRepondre = DroitsAffaire.peutRepondre(
                moi: utilisateur.id, roles: roles, auteur: lu.auteurId, saisiPour: lu.saisiPourUserId)
        }
        return DetailAffaire(ticket: lu, suites: suites, peutRepondre: peutRepondre)
    }

    func repondre(_ texte: String, a affaire: Int, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).addEvolutionTicketsTicketIdEvolutionsPost(
                path: .init(ticketId: affaire), body: .json(.init(contenu: texte, _type: "commentaire")))
        }
        switch sortie {
        case .created: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func sondage(_ id: Int, dans installation: Installation) async throws -> DetailSondage {
        let sortie = try await appeler {
            try await client(installation.adresse).getSondageSondagesSondageIdGet(path: .init(sondageId: id))
        }
        switch sortie {
        case .ok(let ok):
            // La réponse n'est pas typée dans le contrat : relue telle quelle.
            let brut = try JSONEncoder().encode(try ok.body.json)
            return try JSONDecoder().decode(DetailSondage.self, from: brut)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func voter(_ option: Int, au sondage: Int, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).voterSondagesSondageIdVoterPost(
                path: .init(sondageId: sondage), body: .json(.init(optionId: option)))
        }
        switch sortie {
        case .created: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    /// Le contrat déclare du JSON, la route sert le FICHIER (`FileResponse`) : le client
    /// généré refuse ce type, et l'erreur porte la réponse. Le corps se lit là, sur un
    /// 200 seulement (besoin noté pour coprofirst#2460 : déclarer le type servi).
    func document(_ id: Int, nom: String?, dans installation: Installation) async throws -> URL {
        let donnees: Data
        do {
            let sortie = try await client(installation.adresse)
                .downloadDocumentDocumentsDocIdTéléchargerGet(path: .init(docId: id))
            switch sortie {
            case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
            default: throw ErreurService.inattendue(200)
            }
        } catch {
            guard let fichier = try await ClientCoproFirst.fichierServi(error) else {
                throw ErreurService.depuis(ClientCoproFirst.cause(error))
            }
            donnees = fichier
        }
        let dossier = FileManager.default.temporaryDirectory.appending(path: "documents", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        let fichier = dossier.appending(path: Fichiers.nomSur(nom, defaut: "document-\(id)"))
        try donnees.write(to: fichier, options: [.atomic, .completeFileProtection])
        return fichier
    }

    /// Une photo de `/uploads/` n'est pas une route de l'API : un fichier derrière la
    /// session (forward_auth). La session HTTP de l'installation la lit, cookies compris.
    func photo(_ chemin: String, dans installation: Installation) async throws -> Data {
        guard let adresse = URL(string: chemin, relativeTo: installation.adresse)?.absoluteURL,
            adresse.host() == installation.adresse.host()
        else { throw ErreurService.inattendue(400) }
        do {
            let (donnees, reponse) = try await sessions.session(pour: installation.adresse).data(from: adresse)
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

/// Un nom de fichier sûr pour le disque : sans chemin, sans caractère de contrôle.
enum Fichiers {
    static func nomSur(_ nom: String?, defaut: String) -> String {
        let propre = (nom ?? "")
            .components(separatedBy: CharacterSet(charactersIn: "/\\:").union(.controlCharacters))
            .joined(separator: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: ". ").union(.whitespaces))
        return propre.isEmpty ? defaut : propre
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
    init(ticket: Components.Schemas.TicketRead, suites: [SuiteAffaire], peutRepondre: Bool) {
        self.init(
            id: ticket.id, numero: ticket.numero, titre: ticket.titre, description: ticket.description,
            categorie: ticket.categorie, statut: ticket.statut,
            // La règle du site : urgente = priorité haute (#lib/tickets.ts, ticketUrgent).
            urgente: ticket.priorite == "haute", creeLe: ticket.creeLe,
            auteur: ticket.saisiPourAffichage ?? ticket.auteurNom, lieu: nil,
            photos: (ticket.photosUrls ?? []) + (ticket.fichiersUrls ?? []).filter(Fichiers.estImage),
            suites: suites, peutRepondre: peutRepondre)
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

extension Fichiers {
    static func estImage(_ chemin: String) -> Bool {
        ["jpg", "jpeg", "png", "heic", "webp", "gif"].contains((chemin as NSString).pathExtension.lowercased())
    }
}
