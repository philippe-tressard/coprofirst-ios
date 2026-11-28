// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import EventKit
import Foundation
import SwiftUI
import Testing

@testable import CoproFirst

// « Ajouter à mon agenda » (#435, coprofirst#3164, contrat 2.15.0) : l'entrée ne s'offre que
// si l'affaire la SERT (`agenda_propose`, au-dessus du plancher) et que la résidence a la
// route (porte `VersionContrat.agenda`) ; le rendez-vous est celui que le serveur compose.

private func service(_ corps: [String: String]) -> ServiceAPI {
    ServiceAPI(transport: { _ in TransportParRoute(corps: corps) })
}

private func residence(contrat: String?) -> Installation {
    Installation(
        adresse: URL(string: "https://agenda.test")!, nom: "Résidence", aUnLogo: false, versionContrat: contrat)
}

/// Le rendez-vous tel que `GET /tickets/9/agenda` le sert (coprofirst v3.128.0).
private func agendaServi(description: String = "Le ramoneur passe.") -> String {
    #"""
    {"uid": "affaire-9@agenda.test", "titre": "Ramonage", "debut": "2026-12-03T07:00:00Z",
     "fin": "2026-12-03T11:00:00Z", "lieu": "1 rue de l'Exemple — Bât. B", "description": "\#(description)",
     "lien": "https://agenda.test/tickets/9",
     "liens": {"google": "https://google.agenda.test/x", "outlook": "https://outlook.agenda.test/x",
               "microsoft365": "https://microsoft365.agenda.test/x", "yahoo": "https://yahoo.agenda.test/x"}}
    """#
}

/// Le détail de l'affaire 9, servi avec `extra` (le champ au-dessus du plancher, ou rien).
private func detail(_ extra: String) async throws -> DetailAffaire {
    try await service([
        "/tickets/9": ticketServi(9, extra), "/tickets/9/evolutions": "[]", "/tickets/9/messages": "[]",
    ]).affaire(9, dans: residence(contrat: "2.15.0"))
}

@Suite struct AgendaProposeTests {
    @Test func uneInstallationAnterieureNeLeSertPas() async throws {
        #expect(try await detail("").agendaPropose == false, "champ absent : aucune entrée, comme avant")
    }

    @Test func leServeurLeRefuse() async throws {
        #expect(try await detail(#", "agenda_propose": false"#).agendaPropose == false)
        #expect(try await detail(#", "agenda_propose": "oui""#).agendaPropose == false, "illisible : fermé")
    }

    @Test func leServeurLeProposeEtLeServiceReelLeLit() async throws {
        #expect(try await detail(#", "agenda_propose": true"#).agendaPropose)
    }

    @Test func laRelectureNeVautQuePourSonAffaire() {
        #expect(ChampsAgenda.propose(.init(id: 8, agendaPropose: true), pour: 9) == false)
        #expect(ChampsAgenda.propose(nil, pour: 9) == false)
    }

    @Test func laPorteDuContratFermeLEntree() throws {
        var affaire = try #require(try FixturesDetailAffaire.lue(44))
        #expect(affaire.agendaPropose, "l'affaire datée à venir de l'API simulée")
        #expect(MenuPartage<EmptyView>.agendaOffert(affaire, residence(contrat: "2.15.0")))
        #expect(MenuPartage<EmptyView>.agendaOffert(affaire, residence(contrat: "2.14.0")) == false, "sous la porte")
        #expect(MenuPartage<EmptyView>.agendaOffert(affaire, residence(contrat: nil)) == false, "contrat non servi")
        affaire.agendaPropose = false
        #expect(MenuPartage<EmptyView>.agendaOffert(affaire, residence(contrat: "2.15.0")) == false)
    }

    @Test func lesAffairesSimuleesDisentCeQueLeServeurSert() throws {
        #expect(try FixturesDetailAffaire.lue(31)?.agendaPropose == false, "close : servi faux")
        #expect(try FixturesDetailAffaire.lue(41)?.agendaPropose == false, "sans date : non servi")
    }
}

@Suite struct RendezVousServiTests {
    @Test func leRendezVousSeLitTelQueServi() async throws {
        let lu = try await service(["/tickets/9/agenda": agendaServi()])
            .rendezVous(de: 9, dans: residence(contrat: "2.15.0"))
        #expect(lu.titre == "Ramonage" && lu.lieu == "1 rue de l'Exemple — Bât. B")
        #expect(lu.debut == Date(timeIntervalSince1970: 1_796_281_200), "UTC : 07:00Z, 08:00 à Paris")
        #expect(lu.fin.timeIntervalSince(lu.debut) == 4 * 3600)
        #expect(lu.lien == URL(string: "https://agenda.test/tickets/9"))
        #expect(lu.enLigne[.google] == URL(string: "https://google.agenda.test/x"))
        #expect(lu.enLigne.count == 4)
    }

    @Test func sansRendezVousLeServeurRepond404() async throws {
        await #expect(throws: (any Error).self) {
            try await service([:]).rendezVous(de: 9, dans: residence(contrat: "2.15.0"))
        }
    }

    @Test func lesAgendasEnLignePortentLesLibellesDuSite() {
        #expect(AgendaEnLigne.allCases.map(\.libelle)
            == ["Google Agenda", "Outlook.com", "Outlook — Microsoft 365", "Yahoo Agenda"])
    }

    @Test func lEvenementPrendCeQueLeServeurACompose() throws {
        let lu = RendezVousAffaire(try Relecture.generee(Components.Schemas.AgendaServi.self, json: agendaServi()))
        let evenement = lu.evenement(dans: EKEventStore())
        #expect(evenement.title == "Ramonage")
        #expect(evenement.startDate == lu.debut && evenement.endDate == lu.fin)
        #expect(evenement.location == "1 rue de l'Exemple — Bât. B")
        #expect(evenement.notes == "Le ramoneur passe.\n\nhttps://agenda.test/tickets/9", "comme le .ics du serveur")
        #expect(evenement.url == URL(string: "https://agenda.test/tickets/9"))
    }

    @Test func uneAffaireReserveeAuConseilNeDonneQueTitreDatesEtLien() throws {
        let servi = try Relecture.generee(Components.Schemas.AgendaServi.self, json: agendaServi(description: ""))
        let evenement = RendezVousAffaire(servi).evenement(dans: EKEventStore())
        #expect(evenement.notes == "https://agenda.test/tickets/9", "la description tue par le serveur : le lien seul")
        #expect(evenement.url != nil)
    }

    @Test func lApiSimuleeSuitLaPorte() async throws {
        let simule = ServiceSimule()
        await #expect(throws: (any Error).self) {
            try await simule.rendezVous(de: 44, dans: residence(contrat: "2.14.0"))
        }
        let lu = try await simule.rendezVous(de: 44, dans: residence(contrat: "2.15.0"))
        #expect(lu.titre == "Ramonage des conduits de cheminée")
        await #expect(throws: (any Error).self) {
            try await simule.rendezVous(de: 41, dans: residence(contrat: "2.15.0"))
        }
    }
}
