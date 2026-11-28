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
        installation: URL(string: "https://demo.test")!, transport: TransportFixe(corps: corps, statut: statut))
}

/// Un serveur qui sert un corps par chemin (sous `/api`, sans requête) ; 404 ailleurs.
struct TransportParRoute: ClientTransport {
    let corps: [String: String]

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws
        -> (HTTPResponse, HTTPBody?) {
        let chemin = (request.path ?? "").split(separator: "?").first.map(String.init) ?? ""
        let route = chemin.hasPrefix("/api") ? String(chemin.dropFirst(4)) : chemin
        guard let servi = corps[route] else { return (HTTPResponse(status: .notFound), nil) }
        var reponse = HTTPResponse(status: .ok)
        reponse.headerFields[.contentType] = "application/json"
        return (reponse, HTTPBody(servi))
    }
}

/// Une affaire de `TicketRead` au plancher, avec `extra` tel que servi.
func ticketServi(_ id: Int, _ extra: String = "") -> String {
    #"""
    {"id": \#(id), "numero": "TK-\#(id)", "titre": "Essai", "description": "", "categorie": "panne",
     "statut": "ouvert", "priorite": "normale", "cree_le": "2026-11-02T09:00:00", "urgente": false,
     "categorie_libelle": "Panne", "statut_libelle": "Ouvert", "close": false, "colonne_kanban": null,
     "nouveau": false, "nom_proprietaire": "Camille Essai", "perimetre_libelle": "Bât. 2 › Toit",
     "suivi_actualite_libelle": "", "frequence_libelle": ""
    """# + extra + "}"
}
