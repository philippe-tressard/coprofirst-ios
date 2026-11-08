// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import HTTPTypes
import OpenAPIRuntime

/// Un transport qui sert un corps JSON fixe, quelle que soit la route : la réponse du
/// serveur traverse le client GÉNÉRÉ (son transcodeur de dates compris) puis le
/// branchement du service, sans réseau (#61, #62).
struct TransportFixe: ClientTransport {
    let corps: String
    var statut = HTTPResponse.Status.ok

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws
        -> (HTTPResponse, HTTPBody?) {
        var reponse = HTTPResponse(status: statut)
        reponse.headerFields[.contentType] = "application/json"
        return (reponse, HTTPBody(corps))
    }
}

/// Le client généré, branché sur un serveur qui sert `corps` avec `statut`.
func client(servant corps: String, statut: HTTPResponse.Status = .ok) -> Client {
    ClientCoproFirst.client(
        installation: URL(string: "https://demo.exemple")!, transport: TransportFixe(corps: corps, statut: statut))
}
