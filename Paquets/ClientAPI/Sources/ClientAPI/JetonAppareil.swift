// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import HTTPTypes
import OpenAPIRuntime

/// Le jeton d'un APPAREIL sans personne (le schéma `JetonAppareil` du contrat, coprofirst#2770) :
/// `Authorization: Bearer <jeton>` sur chaque requête du client qui le porte. Le générateur
/// ne pose pas l'authentification ; cet intercepteur est la seule écriture de l'en-tête
/// (`scripts/verifier-jetons.py` refuse toute autre, #342). Le jeton y reste masqué
/// (`JetonMasque`) : l'intercepteur se décrit et se vide sans lui.
///
/// UN client par jeton, et ce client ne sert QUE les routes de sa portée — l'écran de hall
/// (`GET /ecrans/moi/affiches` et leurs images), la montre (`GET /notifications`, portée
/// « montre », coprofirst#2771) : le jeton ne part vers aucune autre route.
public struct JetonAppareil: ClientMiddleware {
    private let jeton: JetonMasque

    public init(_ jeton: JetonMasque) { self.jeton = jeton }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var requete = request
        requete.headerFields[.authorization] = "Bearer \(jeton.enClair)"
        return try await next(requete, body, baseURL)
    }
}
