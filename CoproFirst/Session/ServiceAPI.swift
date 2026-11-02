// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Le service réel : le client GÉNÉRÉ depuis le contrat, une session HTTP par
/// installation. Les jetons voyagent en cookies (HttpOnly, posés par le serveur) ;
/// la session est éphémère — en mémoire —, et le jeton de rafraîchissement est
/// recopié au Trousseau pour la prochaine ouverture (coprofirst#2457).
final class ServiceAPI: ServiceCoproFirst {
    private let sessions = SessionsParHote()

    func decouvrir(_ adresse: URL) async throws -> Installation {
        let sortie = try await appeler { try await client(adresse).getConfigConfigGet() }
        switch sortie {
        case .ok(let ok):
            let cles = try ok.body.json.additionalProperties
            guard let nom = cles["site_nom"], !nom.isEmpty else { throw ErreurService.pasCoproFirst }
            return Installation(adresse: adresse, nom: nom, aUnLogo: !(cles["site_logo"] ?? "").isEmpty)
        case .undocumented(let statut, _):
            throw ErreurService.depuis(statut: statut)
        }
    }

    func connecter(_ installation: Installation, email: String, motDePasse: String) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).loginAuthLoginPost(
                body: .json(.init(email: email, password: motDePasse)))
        }
        switch sortie {
        case .ok:
            if let jeton = cookie("refresh_token", installation) {
                Trousseau.enregistrer(jeton, pour: installation.hote)
            }
        case .unprocessableContent:
            throw ErreurService.identifiantsRefuses
        case .undocumented(let statut, _):
            throw ErreurService.depuis(statut: statut)
        }
    }

    func aUneSessionGardee(_ installation: Installation) -> Bool {
        Trousseau.contient(pour: installation.hote)
    }

    func reprendre(_ installation: Installation) async throws {
        guard
            let jeton = Trousseau.lire(
                pour: installation.hote, raison: "Ouvrir votre espace à \(installation.nom)")
        else { throw ErreurService.sessionExpiree }
        poserCookie("refresh_token", valeur: jeton, installation)
        let sortie = try await appeler { try await client(installation.adresse).refreshAuthRefreshPost() }
        switch sortie {
        case .ok:
            // Le serveur fait tourner le jeton : la nouvelle valeur remplace l'ancienne.
            if let neuf = cookie("refresh_token", installation) {
                Trousseau.enregistrer(neuf, pour: installation.hote)
            }
        case .undocumented, .unprocessableContent:
            Trousseau.supprimer(pour: installation.hote)
            throw ErreurService.sessionExpiree
        }
    }

    func affaires(_ installation: Installation) async throws -> [Affaire] {
        let sortie = try await appeler { try await client(installation.adresse).listTicketsTicketsGet() }
        switch sortie {
        case .ok(let ok):
            return try ok.body.json.map(Affaire.init(ticket:))
        case .unprocessableContent:
            throw ErreurService.inattendue(422)
        case .undocumented(let statut, _):
            throw statut == 401 ? ErreurService.sessionExpiree : ErreurService.depuis(statut: statut)
        }
    }

    /// Les droits ne sont pas encore servis par le contrat : rien n'est offert.
    func peutArchiver(_ installation: Installation) -> Bool { false }

    func archiver(_ affaire: Affaire, dans installation: Installation) async throws {
        throw ErreurService.inattendue(403)
    }

    // MARK: - Session HTTP de chaque installation

    private func client(_ adresse: URL) -> Client {
        ClientCoproFirst.client(installation: adresse, session: sessions.session(pour: adresse))
    }

    private func appeler<T>(_ appel: () async throws -> T) async throws -> T {
        do {
            return try await appel()
        } catch {
            throw ErreurService.depuis(ClientCoproFirst.cause(error))
        }
    }

    private func cookie(_ nom: String, _ installation: Installation) -> String? {
        sessions.cookies(installation.adresse).first { $0.name == nom }?.value
    }

    private func poserCookie(_ nom: String, valeur: String, _ installation: Installation) {
        guard
            let cookie = HTTPCookie(properties: [
                .name: nom, .value: valeur, .domain: installation.hote, .path: "/", .secure: "TRUE",
            ])
        else { return }
        sessions.session(pour: installation.adresse).configuration.httpCookieStorage?.setCookie(cookie)
    }
}

/// Une URLSession éphémère par hôte : cookies en mémoire, jamais partagés.
private final class SessionsParHote: @unchecked Sendable {
    private var parHote: [String: URLSession] = [:]
    private let verrou = NSLock()

    func session(pour adresse: URL) -> URLSession {
        verrou.withLock {
            let hote = adresse.host() ?? adresse.absoluteString
            if let existante = parHote[hote] { return existante }
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 15
            configuration.httpCookieAcceptPolicy = .onlyFromMainDocumentDomain
            let session = URLSession(configuration: configuration)
            parHote[hote] = session
            return session
        }
    }

    func cookies(_ adresse: URL) -> [HTTPCookie] {
        session(pour: adresse).configuration.httpCookieStorage?.cookies(for: adresse) ?? []
    }
}

extension Affaire {
    init(ticket: Components.Schemas.TicketRead) {
        self.init(
            id: ticket.id,
            numero: ticket.numero,
            titre: ticket.titre,
            apercu: ticket.description,
            creeLe: ticket.creeLe,
            statut: ticket.statut,
            // La règle du site : urgente = priorité haute (#lib/tickets.ts, ticketUrgent).
            urgente: ticket.priorite == "haute",
            meConcerne: ticket.meConcerne ?? false,
            lieu: nil,
            messages: nil
        )
    }
}
