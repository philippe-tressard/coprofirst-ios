// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Le service réel : le client GÉNÉRÉ depuis le contrat, une session HTTP par
/// installation. Les jetons voyagent en cookies (HttpOnly, posés par le serveur) ;
/// la session est éphémère — en mémoire —, et le jeton de rafraîchissement est
/// recopié au Trousseau pour la prochaine ouverture (coprofirst#2457).
final class ServiceAPI: ServiceCoproFirst {
    let sessions = SessionsParHote()

    func decouvrir(_ adresse: URL) async throws -> Installation {
        let sortie = try await appeler { try await client(adresse).getConfigConfigGet() }
        switch sortie {
        case .ok(let ok):
            let cles = try ok.body.json.additionalProperties
            guard let nom = cles["site_nom"], !nom.isEmpty else { throw ErreurService.pasCoproFirst }
            let prefixe = "page_config_"
            let surcharges = cles.reduce(into: [String: SurchargePage]()) { surcharges, cle in
                guard cle.key.hasPrefix(prefixe), let surcharge = SurchargePage(json: cle.value) else { return }
                surcharges[String(cle.key.dropFirst(prefixe.count))] = surcharge
            }
            return Installation(
                adresse: adresse, nom: nom, aUnLogo: !(cles["site_logo"] ?? "").isEmpty,
                codePalette: cles["site_palette"], ordrePages: OrdrePages.lire(cles["pages_order"]),
                surchargesPages: surcharges)
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

    func activerFaceID(_ installation: Installation) async -> Bool {
        guard let jeton = cookie("refresh_token", installation) else { return false }
        Trousseau.enregistrer(jeton, pour: installation.hote)
        return Trousseau.contient(pour: installation.hote)
    }

    func fil(_ installation: Installation) async throws -> [ElementDuFil] {
        let sortie = try await appeler { try await client(installation.adresse).getFluxFluxGet() }
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

    func client(_ adresse: URL) -> Client {
        ClientCoproFirst.client(installation: adresse, session: sessions.session(pour: adresse))
    }

    func appeler<T>(_ appel: () async throws -> T) async throws -> T {
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
final class SessionsParHote: @unchecked Sendable {
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

    /// Retire la session de cet hôte ; la prochaine requête en ouvre une neuve, vide.
    func retirer(_ adresse: URL) -> URLSession? {
        verrou.withLock { parHote.removeValue(forKey: adresse.host() ?? adresse.absoluteString) }
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
                lien: item.lien)
        )
    }
}
