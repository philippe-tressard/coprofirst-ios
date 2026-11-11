// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import Testing

@testable import CoproFirst

/// La vignette d'échéance d'une affaire datée du fil (#75) — lue dans `meta.affaire` de
/// GET /flux par le chemin du service réel : le JSON décodé comme le client généré
/// (`FluxItem`), puis `ElementDuFil(item:)`.

private func lu(_ affaire: String?) throws -> ElementDuFil {
    let meta = affaire.map { #"{"ticket_id": 38, "affaire": \#($0)}"# } ?? #"{"ticket_id": 38}"#
    let json = #"""
        {"type": "ticket_mis_a_jour", "id": "38", "date": "2026-11-09T09:00:00", "titre": "Ravalement",
         "detail": null, "badges": [], "lien": "/tickets", "meta": \#(meta)}
        """#
    return ElementDuFil(item: try Relecture.generee(Components.Schemas.FluxItem.self, json: json))
}

/// Le 10 novembre 2026, le jour où le serveur a compté ces délais.
private let maintenant = FormatsDuSite.lire("2026-11-10T12:00:00Z") ?? .now

@Test func uneAffaireAVenirSurPlusieursJoursMontreSonDelaiPuisSesDeuxDates() throws {
    let echeance = try #require(
        try lu(
            #"""
            {"numero": "A-0038", "debut": "2026-11-17T08:00:00", "fin": "2026-11-19T16:00:00",
             "echeance": {"etat": "a_venir", "jours": 7, "libelle": "J-7", "plusieurs_jours": true}}
            """#
        ).echeance)
    // Le libellé tel que servi : l'app ne compte pas les jours.
    #expect(echeance.libelle == "J-7")
    #expect(!echeance.passee)
    #expect(echeance.dates(maintenant: maintenant) == "mar. 17 nov. →\u{00A0}19 nov.")
    #expect(echeance.enClair == "J-7, prévu du 17 novembre 2026 au 19 novembre 2026")
}

@Test func uneAffaireDUnJourNeMontreQueSonDebutMemeAvecUneFin() throws {
    let echeance = try #require(
        try lu(
            #"""
            {"debut": "2026-11-10T08:00:00", "fin": "2026-11-10T11:00:00",
             "echeance": {"etat": "jour_j", "jours": 0, "libelle": "Jour J", "plusieurs_jours": false}}
            """#
        ).echeance)
    #expect(echeance.libelle == "Jour J")
    #expect(echeance.fin == nil)
    #expect(echeance.dates(maintenant: maintenant) == "mar. 10 nov.")
    #expect(echeance.enClair == "Jour J, prévu le 10 novembre 2026")
}

@Test func uneAffairePasseePerdLaTeinteEtUneAffaireCloseNaPlusDeDelai() throws {
    let passee = try #require(
        try lu(
            #"""
            {"debut": "2026-11-07T08:00:00", "fin": null,
             "echeance": {"etat": "passee", "jours": -3, "libelle": "Passé", "plusieurs_jours": false}}
            """#
        ).echeance)
    #expect(passee.passee && passee.libelle == "Passé")

    let close = try #require(
        try lu(
            #"""
            {"debut": "2026-11-01T09:00:00Z", "fin": null,
             "echeance": {"etat": "close", "jours": -9, "libelle": null, "plusieurs_jours": false}}
            """#
        ).echeance)
    #expect(close.libelle == nil, "la date seule dit quand c'était prévu")
    #expect(!close.passee)
    #expect(close.dates(maintenant: maintenant) == "dim. 1 nov.")
    #expect(close.enClair == "prévu le 1 novembre 2026")
}

/// 🔴 Une installation antérieure à coprofirst v3.79.0 — la démo sert encore le contrat
/// 1.14.0 — n'envoie ni `fin` ni `echeance` : aucune vignette, la carte reste telle
/// qu'avant. De même pour une affaire sans date (`echeance: null`) et une carte sans affaire.
@Test func sansEcheanceServieLaCarteResteCommeAvant() throws {
    #expect(try lu(#"{"numero": "A-0038", "debut": "2026-11-17T08:00:00", "statut": "en_cours"}"#).echeance == nil)
    #expect(try lu(#"{"numero": "A-0041", "debut": null, "fin": null, "echeance": null}"#).echeance == nil)
    #expect(try lu(nil).echeance == nil)
    // Une échéance sans début n'a rien à dater : rien, comme sur le site.
    let sansDebut = #"{"debut": null, "echeance": {"etat": "a_venir", "jours": 2, "libelle": "J-2"}}"#
    #expect(try lu(sansDebut).echeance == nil)
    // Le reste de la carte est lu comme avant.
    #expect(try lu(nil).cible == .affaire(id: 38))
}

@Test func leFilSimuleMontreChaqueCasDeLaVignette() {
    let affaires = Apercu.fil.filter { if case .affaire = $0.cible { true } else { false } }
    let libelles = affaires.compactMap(\.echeance).map { $0.libelle ?? "close" }
    #expect(Set(libelles).isSuperset(of: ["Jour J", "Passé", "close"]))
    #expect(libelles.contains { $0.hasPrefix("J-") }, "une affaire à venir")
    #expect(affaires.contains { $0.echeance?.fin != nil }, "une affaire sur plusieurs jours")
    #expect(affaires.contains { $0.echeance == nil }, "une affaire sans date")
    #expect(affaires.contains { $0.echeance?.passee == true })
}
