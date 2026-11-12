// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import ClientAPI

/// Un transport qui n’atteint aucun réseau : il note la requête et rend une réponse fixe
/// (partagé par les tests du paquet).
final class TransportEnregistreur: ClientTransport, @unchecked Sendable {
    private(set) var requetes: [(HTTPRequest, URL)] = []
    let statut: HTTPResponse.Status
    let corps: String

    init(statut: HTTPResponse.Status, corps: String) {
        self.statut = statut
        self.corps = corps
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        requetes.append((request, baseURL))
        var reponse = HTTPResponse(status: statut)
        reponse.headerFields[.contentType] = "application/json"
        return (reponse, HTTPBody(corps))
    }
}

@Test func lAdresseDeLAPISeTrouveSousLePrefixeApi() {
    let installation = URL(string: "https://demo.coprofirst.fr")!
    #expect(
        ClientCoproFirst.adresseAPI(installation: installation).absoluteString
            == "https://demo.coprofirst.fr/api/"
    )
}

@Test func leClientGenereAppelleLaSondeDeSante() async throws {
    let transport = TransportEnregistreur(statut: .ok, corps: #"{"status":"ok"}"#)
    let client = ClientCoproFirst.client(
        installation: URL(string: "https://demo.coprofirst.fr")!,
        transport: transport
    )

    let reponse = try await client.getHealth()

    _ = try reponse.ok
    let (requete, base) = try #require(transport.requetes.first)
    #expect(requete.method == .get)
    #expect(requete.path == "/health")
    #expect(base.absoluteString == "https://demo.coprofirst.fr/api/")
}

@Test(arguments: [
    "2026-11-02T09:30:00Z",
    "2026-11-02T09:30:00.123456Z",
    "2026-11-02T09:30:00+00:00",
    "2026-11-02T09:30:00",
    "2026-11-02T09:30:00.5",
])
func lesDatesDeLAPISeLisent(texte: String) throws {
    let date = try TranscodeurDates().decode(texte)
    let attendu = try Date("2026-11-02T09:30:00Z", strategy: .iso8601)
    #expect(abs(date.timeIntervalSince(attendu)) < 1)
}

/// Les champs facultatifs du contrat (`Optional[...]` de FastAPI) existent bien côté
/// Swift : sans la normalisation de `generateurs/contrat.py`, le générateur les supprimait
/// en silence — ce test ne compilerait plus.
@Test func lesChampsFacultatifsSontGeneres() throws {
    let json = #"""
        {"id": 1, "numero": "A-1", "titre": "T", "description": "D", "categorie": "c",
         "statut": "ouvert", "priorite": "haute", "cree_le": "2026-11-02T09:30:00Z",
         "urgente": true, "categorie_libelle": "C", "statut_libelle": "Ouvert", "close": false,
         "colonne_kanban": null, "nouveau": false, "nom_proprietaire": "Alix Exemple",
         "me_concerne": true, "perimetre_cible": null, "auteur_nom": null,
         "frequence_libelle": "", "suivi_actualite_libelle": ""}
        """#
    let decodeur = JSONDecoder()
    decodeur.dateDecodingStrategy = .iso8601
    let ticket = try decodeur.decode(Components.Schemas.TicketRead.self, from: Data(json.utf8))
    #expect(ticket.meConcerne == true)
    #expect(ticket.perimetreCible == nil)
    #expect(ticket.auteurNom == nil)
}

/// Le libellé du logement (`libelle_logement`, contrat ≥ 1.2.0, coprofirst#2500) : servi
/// tel quel, `null` quand il n'y a rien à dire, absent d'un serveur plus ancien.
@Test(
    arguments: [
        (#", "libelle_logement": "Bât. A, T3, 2ème""#, "Bât. A, T3, 2ème"),
        (#", "libelle_logement": null"#, nil),
        ("", nil),
    ] as [(String, String?)])
func leLibelleDuLogementSeLit(champ: String, attendu: String?) throws {
    let json = #"""
        {"id": 7, "nom": "Durand", "prenom": "Alix", "email": "alix@exemple.fr",
         "statut": "locataire", "role": "résident", "actif": true, "onboarding_complete": true,
         "onboarding_etape": 0, "preferences_notifications": "{}", "cree_le": "2026-11-02T09:30:00Z",
         "nom_affiche": "Alix DURAND", "nom_aide_affiche": "Alix D."
        """# + champ + "}"
    let decodeur = JSONDecoder()
    decodeur.dateDecodingStrategy = .iso8601
    let moi = try decodeur.decode(Components.Schemas.UserRead.self, from: Data(json.utf8))
    #expect(moi.libelleLogement == attendu)
}

/// Le contrat de l'app ne déclare aucun paramètre `in: cookie` (#26) : la
/// normalisation de `generateurs/contrat.py` les retire — iOS envoie les cookies de session
/// seul, et swift-openapi-generator en faisait ~390 avertissements par build.
@Test func leContratNeDeclareAucunParametreCookie() throws {
    let contrat = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "Sources/ClientAPI/openapi.json")
    let racine = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: contrat)) as? [String: Any])
    let chemins = try #require(racine["paths"] as? [String: [String: Any]])
    var cookies: [String] = []
    for (chemin, element) in chemins {
        let cibles = [element] + element.values.compactMap { $0 as? [String: Any] }
        for cible in cibles {
            for parametre in cible["parameters"] as? [[String: Any]] ?? []
            where parametre["in"] as? String == "cookie" {
                cookies.append("\(chemin) \(parametre["name"] ?? "?")")
            }
        }
    }
    #expect(chemins.count > 100, "le contrat se lit")
    #expect(cookies.isEmpty, "paramètres cookie : \(cookies.prefix(3))")
}
