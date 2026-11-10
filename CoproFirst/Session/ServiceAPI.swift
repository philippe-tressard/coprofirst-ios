// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import OpenAPIRuntime

/// Le service réel : le client GÉNÉRÉ depuis le contrat, une session HTTP par
/// installation. Les jetons voyagent en cookies (HttpOnly, posés par le serveur) ;
/// la session est éphémère — en mémoire —, et le jeton de rafraîchissement est
/// recopié au Trousseau pour la prochaine ouverture (coprofirst#2457).
final class ServiceAPI: ServiceCoproFirst {
    let sessions = SessionsParHote()
    /// LA porte du renouvellement de session, partagée par toutes les requêtes (#81).
    let renouvellement = Renouvellement()
    /// Le transport d'un test (un serveur simulé) ; `nil` : la session HTTP de chaque hôte.
    private let transport: (@Sendable (URL) -> any ClientTransport)?

    init(transport: (@Sendable (URL) -> any ClientTransport)? = nil) {
        self.transport = transport
    }

    func decouvrir(_ adresse: URL) async throws -> Installation {
        // L'entrée : ici, et ici seulement, une réponse illisible veut dire « pas CoproFirst ».
        let sortie: Operations.GetConfig.Output
        do {
            sortie = try await client(adresse).getConfig()
        } catch {
            throw ErreurService.depuisEntree(ClientCoproFirst.cause(error))
        }
        switch sortie {
        case .ok(let ok):
            let cles = try ok.body.json.additionalProperties
            guard let installation = Installation(adresse: adresse, config: cles) else {
                throw ErreurService.pasCoproFirst
            }
            return installation
        case .undocumented(let statut, _):
            throw ErreurService.depuis(statut: statut)
        }
    }

    func connecter(_ installation: Installation, email: String, motDePasse: String) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).postAuthLogin(
                body: .json(.init(email: email, password: motDePasse)))
        }
        switch sortie {
        case .ok:
            // La session vit en mémoire ; elle ne va au Trousseau que si l'utilisateur
            // accepte Face ID (activerFaceID).
            break
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
        // La porte du 401 (`Renouvellement`) : le jeton neuf y remplace l'ancien au Trousseau.
        guard try await appeler({ try await renouveler(installation.adresse) }) else {
            Trousseau.supprimer(pour: installation.hote)
            throw ErreurService.sessionExpiree
        }
    }

    func activerFaceID(_ installation: Installation) async -> Bool {
        guard let jeton = cookie("refresh_token", installation.adresse) else { return false }
        Trousseau.enregistrer(jeton, pour: installation.hote)
        return Trousseau.contient(pour: installation.hote)
    }

    func fil(_ installation: Installation) async throws -> [ElementDuFil] {
        let sortie = try await appeler { try await client(installation.adresse).getFlux() }
        switch sortie {
        case .ok(let ok):
            return try ok.body.json.items?.map(ElementDuFil.init(item:)) ?? []
        case .unprocessableContent:
            throw ErreurService.inattendue(422)
        case .undocumented(let statut, _):
            throw statut == 401 ? ErreurService.sessionExpiree : ErreurService.depuis(statut: statut)
        }
    }

    /// Aucune route ne sert les identifiants publics de la démo : pas d'entrée directe.
    func entrerEnDemo(_ code: String) async throws -> Installation? { nil }

    // MARK: - Session HTTP de chaque installation

    /// Le client généré de l'installation à cette adresse — un 401 s'y renouvelle (#81).
    func client(_ adresse: URL) -> Client {
        let renouveler = [renouvelerSurRefus(adresse)]
        if let transport {
            return ClientCoproFirst.client(
                installation: adresse, transport: transport(adresse), middlewares: renouveler)
        }
        return ClientCoproFirst.client(
            installation: adresse, session: sessions.session(pour: adresse), middlewares: renouveler)
    }

    func appeler<T>(_ appel: () async throws -> T) async throws -> T {
        do {
            return try await appel()
        } catch {
            if let refus = await Self.refusSousValidation(error) { throw refus }
            throw ErreurService.depuis(ClientCoproFirst.cause(error))
        }
    }

    func cookie(_ nom: String, _ adresse: URL) -> String? {
        sessions.cookies(adresse).first { $0.name == nom }?.value
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
final class SessionsParHote: @unchecked Sendable {
    private var parHote: [String: URLSession] = [:]
    private let verrou = NSLock()

    /// La clé d'un hôte : sa session HTTP, son renouvellement.
    static func cle(_ adresse: URL) -> String { adresse.host() ?? adresse.absoluteString }

    func session(pour adresse: URL) -> URLSession {
        verrou.withLock {
            let hote = Self.cle(adresse)
            if let existante = parHote[hote] { return existante }
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 15
            configuration.httpCookieAcceptPolicy = .onlyFromMainDocumentDomain
            let session = URLSession(configuration: configuration)
            parHote[hote] = session
            return session
        }
    }

    /// Retire la session de cet hôte ; la prochaine requête en ouvre une neuve, vide.
    func retirer(_ adresse: URL) -> URLSession? {
        verrou.withLock { parHote.removeValue(forKey: Self.cle(adresse)) }
    }

    func cookies(_ adresse: URL) -> [HTTPCookie] {
        session(pour: adresse).configuration.httpCookieStorage?.cookies(for: adresse) ?? []
    }
}

extension ElementDuFil {
    init(item: Components.Schemas.FluxItem) {
        let meta = item.meta?.additionalProperties.value ?? [:]
        // Un nombre JSON peut arriver entier ou flottant selon le décodeur.
        func entier(_ cle: String) -> Int? {
            (meta[cle] as? Int) ?? (meta[cle] as? Double).map { Int($0) }
        }
        self.init(
            id: "\(item._type):\(item.id ?? "\(item.date.timeIntervalSince1970)")",
            type: item._type,
            date: item.date,
            titre: item.titre,
            detail: item.detail,
            badges: item.badges ?? [],
            publicationUrgente: (meta["urgente"] as? Bool) ?? false,
            statut: meta["statut"] as? String,
            meConcerne: item.meConcerne ?? false,
            cible: .pour(
                type: item._type,
                meta: .init(
                    ticketId: entier("ticket_id"), sondageId: entier("sondage_id"), documentId: entier("document_id"),
                    fichierNom: meta["fichier_nom"] as? String),
                lien: item.lien),
            echeance: EcheanceDuFil(meta: item.meta?.additionalProperties),
            natures: MetaDuFil(meta: item.meta?.additionalProperties)?.affaire?.natures ?? []
        )
    }
}
