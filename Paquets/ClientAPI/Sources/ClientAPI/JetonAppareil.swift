// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import HTTPTypes
import OpenAPIRuntime

/// Le jeton d'un APPAREIL sans personne (le schéma `JetonAppareil` du contrat, coprofirst#2770) :
/// `Authorization: Bearer <jeton>` sur chaque requête du client qui le porte. Le générateur
/// ne pose pas l'authentification ; cet intercepteur est la seule écriture de l'en-tête.
///
/// UN client par jeton, et ce client ne sert QUE les routes de sa portée (l'écran de hall :
/// `GET /ecrans/moi/affiches` et leurs images) : le jeton ne part vers aucune autre route.
/// La montre (#226, portée « montre », coprofirst#2771) prendra le même.
public struct JetonAppareil: ClientMiddleware {
    private let jeton: String

    public init(_ jeton: String) { self.jeton = jeton }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var requete = request
        requete.headerFields[.authorization] = "Bearer \(jeton)"
        return try await next(requete, body, baseURL)
    }
}
