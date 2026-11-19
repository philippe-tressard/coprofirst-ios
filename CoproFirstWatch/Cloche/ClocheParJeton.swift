// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import HTTPTypes
import OpenAPIRuntime

/// Le jeton n'ouvre plus rien (retiré, échu, mot de passe changé) : la montre attend l'iPhone.
struct JetonRefuse: Error {}

/// La cloche lue par la montre : `GET /notifications`, par le client GÉNÉRÉ, avec le jeton de
/// montre en porteur — la seule route que ce jeton ouvre (coprofirst#2771 : `lecteur_de_la_cloche`
/// lit `Authorization: Bearer` ; le contrat 2.6.0 et suivants la protègent par le schéma
/// `JetonAppareil`, que le client généré ne pose pas lui-même). Une session éphémère, sans
/// cookie : un cookie présent l'emporterait côté serveur. Le jeton ne part que vers l'adresse
/// de la liaison.
enum ClocheParJeton {
    static func alertes(_ liaison: LiaisonGardee, transport: (any ClientTransport)? = nil) async throws
        -> [NotificationRecue]
    {
        let porteur = [JetonPorteur(jeton: liaison.jeton)]
        let client =
            if let transport {
                ClientCoproFirst.client(installation: liaison.adresse, transport: transport, middlewares: porteur)
            } else {
                ClientCoproFirst.client(
                    installation: liaison.adresse, session: URLSession(configuration: .ephemeral),
                    middlewares: porteur)
            }
        switch try await client.getNotifications() {
        case .ok(let ok): return try ok.body.json.map(NotificationRecue.init(lue:))
        case .undocumented(401, _): throw JetonRefuse()
        case .undocumented(let statut, _): throw URLError(.badServerResponse, userInfo: ["statut": statut])
        case .unprocessableContent: throw URLError(.badServerResponse)
        }
    }
}

/// Pose `Authorization: Bearer <jeton>` sur chaque requête de CE client — jamais une
/// configuration commune à l'app.
struct JetonPorteur: ClientMiddleware, CustomStringConvertible {
    let jeton: String

    var description: String { "JetonPorteur(jeton masqué)" }

    func intercept(
        _ requete: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var requete = requete
        requete.headerFields[.authorization] = "Bearer \(jeton)"
        return try await next(requete, body, baseURL)
    }
}
