// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

private func page(_ id: String) -> PageDeNavigation {
    PageDeNavigation(id: id, route: "/\(id)", libelle: id, titre: id, icone: "circle")
}

@Test func laBarreSuitLOrdreRegleParLAdministration() {
    let pages = ["tableau-de-bord", "residence", "mes-demandes", "mon-lot", "faq"].map(page)
    let rangees = OrdrePages.ordonner(
        pages, ordre: ["faq", "inconnue", "residence", "faq"], libelles: ["residence": "Chez nous"])
    #expect(rangees.map(\.id) == ["faq", "residence", "tableau-de-bord", "mes-demandes", "mon-lot"])
    #expect(rangees.first { $0.id == "residence" }?.libelle == "Chez nous")
    #expect(rangees.first { $0.id == "tableau-de-bord" }?.libelle == "Fil", "le tableau de bord devient le fil")
}

@Test func sansReglageLOrdreEstCeluiDuSite() {
    let ids = OrdrePages.ordonner(PagesParDefaut.toutes, ordre: nil, libelles: [:]).map(\.id)
    #expect(ids == PagesParDefaut.toutes.map(\.id))
    #expect(ids.first == OrdrePages.idFil)
}

@Test func pagesOrderSeLitEnJSONOuEnListe() {
    #expect(OrdrePages.lire(#"["faq","residence"]"#) == ["faq", "residence"])
    #expect(OrdrePages.lire("faq, residence") == ["faq", "residence"])
    #expect(OrdrePages.lire("") == nil)
    #expect(OrdrePages.libelle(surcharge: #"{"navLabel":"Chez nous","titre":"T"}"#) == "Chez nous")
    #expect(OrdrePages.libelle(surcharge: "pas du JSON") == nil)
}

@Test func lesEnTetesDeJourDisentAujourdhuiHierPuisLaDate() throws {
    let cal = Chronologie.calendrier
    let maintenant = try #require(cal.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 10)))
    let hier = try #require(cal.date(byAdding: .day, value: -1, to: maintenant))
    let avant = try #require(cal.date(byAdding: .day, value: -2, to: maintenant))
    let anneeDerniere = try #require(cal.date(from: DateComponents(year: 2025, month: 12, day: 24)))
    #expect(Chronologie.entete(maintenant, maintenant: maintenant) == "AUJOURD'HUI · LUNDI 2")
    #expect(Chronologie.entete(hier, maintenant: maintenant) == "HIER · DIMANCHE 1ᵉʳ")
    #expect(Chronologie.entete(avant, maintenant: maintenant) == "SAMEDI 31 OCTOBRE")
    #expect(Chronologie.entete(anneeDerniere, maintenant: maintenant) == "MERCREDI 24 DÉCEMBRE 2025")
}

@Test func leFilSeRangeJourParJourLePlusRecentEnTete() {
    let jours = Chronologie.parJour(ServiceSimule.fil)
    #expect(jours.map(\.jour) == jours.map(\.jour).sorted(by: >))
    for jour in jours {
        #expect(jour.elements.map(\.date) == jour.elements.map(\.date).sorted(by: >))
    }
    #expect(jours.flatMap(\.elements).count == ServiceSimule.fil.count)
}

@Test func lUrgenceSuitLaRegleDuSite() {
    func element(_ type: String, badges: [String] = [], urgente: Bool = false, statut: String? = nil) -> ElementDuFil {
        ElementDuFil(
            id: "x", type: type, date: .now, titre: "T", detail: nil, badges: badges,
            publicationUrgente: urgente, statut: statut, meConcerne: false)
    }
    #expect(element("ticket_ouvert", badges: ["urgent"]).urgent)
    #expect(!element("ticket_ouvert").urgent)
    #expect(!element("ticket_resolu", badges: ["urgent"]).urgent)
    #expect(element("publication", urgente: true).urgent)
    #expect(!element("publication", urgente: true, statut: "resolu").urgent)
    #expect(element("type_inconnu").nature.libelle == NatureDuFil.inconnue.libelle)
}

@Test func chaquePaletteServieExisteEtUnCodeInconnuGardeLaCharte() {
    for code in ["seine", "bordeaux", "bouteille", "cuivre", "roi", "prune"] {
        #expect(Palette.parCode[code]?.code == code)
    }
    #expect(Palette.pour(code: "inexistante").code == "seine")
    #expect(Palette.pour(code: nil).code == "seine")
}
