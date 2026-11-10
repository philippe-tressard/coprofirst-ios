// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import Testing

@testable import CoproFirst

/// La nature d'une carte du fil (#78) — lue dans `meta.affaire.natures` de GET /flux par le
/// chemin du service réel (le JSON décodé comme le client généré, puis `ElementDuFil(item:)`).

private func carte(_ type: String, meta: String?) throws -> ElementDuFil {
    let json = #"""
        {"type": "\#(type)", "id": "38", "date": "2026-11-09T09:00:00", "titre": "Ravalement",
         "detail": null, "badges": [], "lien": "/tickets", "meta": \#(meta ?? "null")}
        """#
    return ElementDuFil(item: try Relecture.generee(Components.Schemas.FluxItem.self, json: json))
}

private func natures(_ codes: String) -> String { #"{"ticket_id": 38, "affaire": {"natures": [\#(codes)]}}"# }

@Test func uneAffaireDateeMontreLaNatureCalendrierEnPastilleAvecLaTeinteDuSite() throws {
    let element = try carte("ticket_mis_a_jour", meta: natures(#""calendrier""#))
    let pastille = try #require(element.natureEnPastille)
    // Le libellé et la teinte de la table du site, jamais un mot de l'app.
    #expect(pastille.libelle == "Calendrier")
    #expect(pastille.badge == "badge-purple")
}

@Test func uneActualiteDateeSeClasseActualiteCarLActualitePrime() throws {
    let element = try carte("ticket_ouvert", meta: natures(#""calendrier", "actualite""#))
    #expect(element.natureDeLAffaire?.libelle == "Actualité")
    #expect(element.natureEnPastille?.badge == "badge-blue")
}

@Test func laNatureQueLaRubriqueDitDejaNeSEcritPasDeuxFois() throws {
    // « Affaire » / « Affaire mise à jour » / « Affaire résolue » disent déjà « Affaire ».
    for type in ["ticket_ouvert", "ticket_mis_a_jour", "ticket_resolu"] {
        #expect(try carte(type, meta: natures(#""activite""#)).natureEnPastille == nil, "\(type)")
    }
    // La rubrique « Actualité » dit déjà « Actualité ».
    #expect(try carte("publication", meta: natures(#""actualite", "calendrier""#)).natureEnPastille == nil)
}

@Test func uneRubriqueSansNatureNeMontreAucunePastille() throws {
    #expect(try carte("document", meta: nil).natureEnPastille == nil)
    #expect(try carte("annonce", meta: #"{"annonce_id": 3}"#).natureEnPastille == nil)
    #expect(try carte("sondage_ouvert", meta: #"{"sondage_id": 3}"#).natureEnPastille == nil)
    #expect(try carte("ticket_ouvert", meta: natures("")).natureEnPastille == nil)
}

@Test func uneNatureInconnueRetombeSurLaNatureParDefautDuSite() throws {
    // `natureDe` : `?? NATURES[2]` — « Affaire », que la rubrique ticket dit déjà.
    let element = try carte("ticket_ouvert", meta: natures(#""autre""#))
    #expect(element.natureDeLAffaire?.code == "activite")
}
