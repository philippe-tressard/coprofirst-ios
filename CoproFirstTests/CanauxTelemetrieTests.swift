// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import CoproFirst

// « Accès : site ou application » (coprofirst#2726, contrat 1.31.0) : la répartition se LIT
// dans la réponse — libellés, parts, utilisateurs —, jamais ne se recalcule.

/// Un serveur qui sert `corps` à toute requête.
private struct TransportFixeTelemetrie: ClientTransport {
    let corps: String
    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws
        -> (HTTPResponse, HTTPBody?) {
        var reponse = HTTPResponse(status: .ok)
        reponse.headerFields[.contentType] = "application/json"
        return (reponse, HTTPBody(corps))
    }
}

struct CanauxTelemetrieTests {
    @Test func laRepartitionServieSeLitParLeServiceReel() async throws {
        let service = ServiceAPI(transport: { _ in TransportFixeTelemetrie(corps: FixturesTelemetrie.jour) })
        let tableau = try await service.tableauTelemetrie(
            ServiceSimule.residence, portee: .jour, sansGestionnaire: false)
        #expect(tableau.canaux.map(\.libelle) == ["Site web", "App iPhone"], "les libellés servis, dans l'ordre servi")
        #expect(tableau.canaux.map(\.part) == [75, 25], "la part servie, pas recalculée")
        #expect(tableau.canaux.map(\.visiteurs) == [19, 8])
        #expect(tableau.topPages.first?.canaux.map(\.vues) == [36, 22])
        #expect(tableau.plusieursCanauxParPage)
    }

    @Test func uneInstallationAnterieureNeMontreNiBlocNiColonne() async throws {
        // La réponse d'une installation au contrat 1.30.0 : sans `canaux`, nulle part.
        var json = try #require(
            try JSONSerialization.jsonObject(with: Data(FixturesTelemetrie.jour.utf8)) as? [String: Any])
        json["canaux"] = nil
        json["top_pages"] = (json["top_pages"] as? [[String: Any]])?.map { page in page.filter { $0.key != "canaux" } }
        let corps = try #require(String(data: JSONSerialization.data(withJSONObject: json), encoding: .utf8))
        let service = ServiceAPI(transport: { _ in TransportFixeTelemetrie(corps: corps) })
        let tableau = try await service.tableauTelemetrie(
            ServiceSimule.residence, portee: .jour, sansGestionnaire: false)
        #expect(tableau.canaux.isEmpty)
        #expect(tableau.topPages.allSatisfy { $0.canaux.isEmpty })
        #expect(!tableau.plusieursCanauxParPage)
        #expect(tableau.kpi.vues == 146, "le reste du tableau, lu comme avant")
    }

    @Test func unSeulCanalLeDitEtNeMontrePasLaColonne() throws {
        let total = try FixturesTelemetrie.tableau(.total)
        #expect(total.canaux.map(\.canal) == ["site"])
        #expect(!total.plusieursCanauxParPage, "« Site web » sur chaque ligne ne dirait rien")
        let pied = try #require(TextesTelemetrie.piedAcces(total.canaux))
        #expect(pied.hasPrefix("Toutes les vues de la période viennent de : Site web."))
    }

    @Test func sansUtilisateursServisLaColonneSEfface() throws {
        let annee = try FixturesTelemetrie.tableau(.annee)
        #expect(annee.canaux.allSatisfy { $0.visiteurs == nil }, "Année : au-delà des 30 jours d'évènements")
        #expect(TextesTelemetrie.piedAcces(annee.canaux) == nil)
        let jour = try FixturesTelemetrie.tableau(.jour)
        #expect(TextesTelemetrie.piedAcces(jour.canaux) == TextesTelemetrie.utilisateursParAcces)
        #expect(TextesTelemetrie.vuesEtPart(jour.canaux[1]) == "37 vues · 25 %")
    }

    @Test func lAccesDUnePageSeLitCommeAuSite() throws {
        let jour = try FixturesTelemetrie.tableau(.jour)
        #expect(TextesTelemetrie.accesDe(jour.topPages[0]) == "Site web\u{00A0}36 · App iPhone\u{00A0}22")
        #expect(TextesTelemetrie.accesDe(jour.topPages[3]) == "Site web\u{00A0}12", "seuls les canaux qui ont des vues")
    }
}
