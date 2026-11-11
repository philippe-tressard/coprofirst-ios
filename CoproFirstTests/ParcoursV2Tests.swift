// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import SwiftUI
import Testing

@testable import CoproFirst

private func page(_ id: String) -> PageDeNavigation {
    PageDeNavigation(id: id, route: "/\(id)", libelle: id, titre: id, icone: "circle")
}

@Test func laBarreSuitLOrdreRegleParLAdministration() {
    let pages = ["tableau-de-bord", "residence", "mes-demandes", "mon-lot", "faq"].map(page)
    let rangees = OrdrePages.ordonner(
        pages, ordre: ["faq", "inconnue", "residence", "faq"],
        surcharges: ["residence": SurchargePage(navLabel: "Chez nous")])
    #expect(rangees.map(\.id) == ["faq", "residence", "tableau-de-bord", "mes-demandes", "mon-lot"])
    #expect(rangees.first { $0.id == "residence" }?.libelle == "Chez nous")
    #expect(rangees.first { $0.id == "tableau-de-bord" }?.libelle == "Fil d'activité", "le tableau de bord")
}

@Test func sansReglageLOrdreEstCeluiDuSite() {
    let ids = OrdrePages.ordonner(PagesParDefaut.toutes, ordre: nil, surcharges: [:]).map(\.id)
    #expect(ids == PagesParDefaut.toutes.map(\.id))
    #expect(ids.first == OrdrePages.idFil)
}

@Test func pagesOrderSeLitEnJSONOuEnListe() {
    #expect(OrdrePages.lire(#"["faq","residence"]"#) == ["faq", "residence"])
    #expect(OrdrePages.lire("faq, residence") == ["faq", "residence"])
    #expect(OrdrePages.lire("") == nil)
    #expect(
        SurchargePage(json: #"{"navLabel":"Chez nous","titre":"T"}"#)
            == SurchargePage(navLabel: "Chez nous", titre: "T"))
    #expect(SurchargePage(json: #"{"navLabel":"","titre":"T"}"#)?.navLabel == nil, "un libellé vide ne compte pas")
    #expect(SurchargePage(json: "pas du JSON") == nil)
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
            publicationUrgente: urgente, statut: statut, meConcerne: false, cible: .resume(lien: nil))
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

/// « 1ᵉʳ » se rend collé (« 1 e r » à la capture du 02/11/2026) : un vrai exposant
/// « er », sans interlettrage — et le RENDU le prouve, pas seulement les attributs.
@MainActor
@Test func lePremierDuMoisSeRendColle() throws {
    let cal = Chronologie.calendrier
    let maintenant = try #require(cal.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 10)))
    let premier = try #require(cal.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 9)))
    let affiche = Chronologie.enteteAffiche(premier, maintenant: maintenant)
    #expect(String(affiche.characters) == "HIER · DIMANCHE 1er")
    let exposant = try #require(affiche.range(of: "er"))
    for run in affiche[exposant].runs {
        #expect((run.baselineOffset ?? 0) > 0, "« er » en exposant")
        #expect(run.tracking == 0)
    }

    // Le rendu : « …1er » ne dépasse « …1 » que de la largeur d'un « er » en petit
    // corps. Les lettres modificatives en ajoutaient bien davantage.
    func largeur(_ texte: AttributedString) -> CGFloat {
        let rendu = ImageRenderer(content: Text(texte).font(.caption.weight(.semibold)).fixedSize())
        return rendu.uiImage?.size.width ?? 0
    }
    var sansExposant = Chronologie.espacer("HIER · DIMANCHE 1")
    let chiffre = try #require(sansExposant.range(of: "1"))
    sansExposant[chiffre].tracking = 0
    var er = AttributedString("er")
    er.font = .caption2.weight(.semibold)
    let ecart = largeur(affiche) - largeur(sansExposant)
    let attendu = largeur(er)
    #expect(attendu > 0)
    #expect(ecart <= attendu + 0.5, "« er » collé au chiffre : écart \(ecart) pt pour \(attendu) pt")

    // Un autre jour n'a pas d'exposant : tout est espacé.
    let deux = Chronologie.enteteAffiche(maintenant, maintenant: maintenant)
    #expect(deux.runs.allSatisfy { $0.tracking == Chronologie.interlettrage })
}
