// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import CoproFirst

// Le renouvellement de session sur un 401 (#81) : le jeton d'accès du serveur dure deux
// heures, celui de rafraîchissement bien plus. Sur un 401, l'app renouvelle UNE fois
// (POST /auth/refresh) et rejoue la requête UNE fois, comme le site ; un second 401 dit
// la session expirée. Le serveur fait tourner le jeton : deux requêtes refusées en même
// temps ne renouvellent qu'une fois.

/// Un serveur dont le jeton d'accès a expiré. GET /flux répond 401 tant que la session
/// n'est pas renouvelée ; POST /auth/refresh la renouvelle (ou la refuse). Chaque requête
/// prend sa validité AU DÉPART, et sa réponse n'arrive qu'après son délai : une requête
/// partie avec l'ancien jeton peut revenir refusée APRÈS le renouvellement.
private actor ServeurAJetonCourt {
    private(set) var renouvellements = 0
    private(set) var lecturesDuFil = 0
    private var valide = false
    private var delaisDuFil: [Duration]
    private let refreshAccepte: Bool
    private let refreshEfficace: Bool

    /// `refreshEfficace` faux : le serveur accepte le renouvellement, mais le jeton neuf
    /// est refusé à son tour (le second 401).
    init(delaisDuFil: [Duration] = [], refreshAccepte: Bool = true, refreshEfficace: Bool = true) {
        self.delaisDuFil = delaisDuFil
        self.refreshAccepte = refreshAccepte
        self.refreshEfficace = refreshEfficace
    }

    func repondre(_ operation: String) async -> (HTTPResponse.Status, String) {
        switch operation {
        case Operations.PostAuthRefresh.id:
            renouvellements += 1
            try? await Task.sleep(for: .milliseconds(50))
            guard refreshAccepte else { return (.unauthorized, #"{"detail": "Refresh token invalide"}"#) }
            if refreshEfficace { valide = true }
            return (.ok, "{}")
        case Operations.GetFlux.id:
            lecturesDuFil += 1
            let aDepart = valide
            let delai = delaisDuFil.isEmpty ? Duration.zero : delaisDuFil.removeFirst()
            try? await Task.sleep(for: delai)
            return aDepart ? (.ok, #"{"delai_recent_jours": 7, "items": []}"#) : Self.refus
        default:
            return Self.refus
        }
    }

    private static let refus = (HTTPResponse.Status.unauthorized, #"{"detail": "Not authenticated"}"#)
}

private struct TransportDuServeur: ClientTransport {
    let serveur: ServeurAJetonCourt

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws
        -> (HTTPResponse, HTTPBody?) {
        let (statut, corps) = await serveur.repondre(operationID)
        var reponse = HTTPResponse(status: statut)
        reponse.headerFields[.contentType] = "application/json"
        return (reponse, HTTPBody(corps))
    }
}

private let residence = Installation(
    adresse: URL(string: "https://jeton-court.exemple")!, nom: "Résidence", aUnLogo: false)

private func service(_ serveur: ServeurAJetonCourt) -> ServiceAPI {
    ServiceAPI(transport: { _ in TransportDuServeur(serveur: serveur) })
}

@Suite struct RenouvellementTests {
    @Test func unRefusDeSessionSeRenouvelleEtLaRequeteSeRejoue() async throws {
        let serveur = ServeurAJetonCourt()
        let fil = try await service(serveur).fil(residence)
        #expect(fil.isEmpty)
        #expect(await serveur.renouvellements == 1)
        #expect(await serveur.lecturesDuFil == 2, "la requête refusée, puis la même rejouée")
    }

    @Test func unSecondRefusDitLaSessionExpiree() async {
        let serveur = ServeurAJetonCourt(refreshEfficace: false)
        await #expect(throws: ErreurService.sessionExpiree) { try await service(serveur).fil(residence) }
        #expect(await serveur.renouvellements == 1, "un seul renouvellement")
        #expect(await serveur.lecturesDuFil == 2, "rejouée une fois, pas davantage")
    }

    @Test func unRenouvellementRefuseDitLaSessionExpiree() async {
        let serveur = ServeurAJetonCourt(refreshAccepte: false)
        await #expect(throws: ErreurService.sessionExpiree) { try await service(serveur).fil(residence) }
        #expect(await serveur.renouvellements == 1)
        #expect(await serveur.lecturesDuFil == 1, "rien à rejouer sans session neuve")
    }

    /// Trois lectures parties avec l'ancien jeton : deux reviennent refusées PENDANT le
    /// renouvellement (elles l'attendent), la troisième APRÈS (elle rejoue sans renouveler).
    @Test func desRequetesConcurrentesNeRenouvellentQuUneFois() async throws {
        let serveur = ServeurAJetonCourt(delaisDuFil: [.milliseconds(10), .milliseconds(10), .milliseconds(300)])
        let api = service(serveur)
        async let premiere = api.fil(residence)
        async let deuxieme = api.fil(residence)
        async let troisieme = api.fil(residence)
        _ = try await (premiere, deuxieme, troisieme)
        #expect(await serveur.renouvellements == 1, "le serveur fait tourner le jeton : un seul POST /auth/refresh")
        #expect(await serveur.lecturesDuFil == 6)
    }

    /// Un 401 à la connexion dit des identifiants refusés : rien à renouveler. Le mot de
    /// passe passe par la garde (#82), seule porte de `connecter` : la résidence est connue.
    @MainActor
    @Test func uneConnexionRefuseeNeRenouvellePas() async {
        let serveur = ServeurAJetonCourt()
        let garde = GardeHote(service: service(serveur), connues: { [residence] })
        await #expect(throws: ErreurService.identifiantsRefuses) {
            try await garde.connecter(residence, origine: .saisie, email: "a@exemple.fr", motDePasse: "x")
        }
        #expect(await serveur.renouvellements == 0)
    }
}
