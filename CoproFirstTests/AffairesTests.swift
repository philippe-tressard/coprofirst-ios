// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

@Test func lesFiltresRetiennentCeQuIlsDisent() {
    let affaires = ServiceSimule.affaires
    #expect(affaires.retenues(par: .toutes, recherche: "").count == affaires.count)
    #expect(affaires.retenues(par: .urgentes, recherche: "").allSatisfy { $0.urgente })
    #expect(affaires.retenues(par: .resolues, recherche: "").allSatisfy { $0.resolue })
    #expect(affaires.retenues(par: .enCours, recherche: "").allSatisfy { !$0.resolue })
    #expect(affaires.retenues(par: .meConcernent, recherche: "").allSatisfy { $0.meConcerne })
}

@Test func laRechercheIgnoreCasseEtAccents() {
    let trouvees = ServiceSimule.affaires.retenues(par: .toutes, recherche: "ECLAIRAGE")
    #expect(trouvees.map(\.numero) == ["A-0035"])
    #expect(ServiceSimule.affaires.retenues(par: .toutes, recherche: "A-0041").count == 1)
}

@MainActor
@Test func uneResidenceConnueNApparaitQuUneFois() throws {
    let suite = "tests.\(UUID().uuidString)"
    let reglages = try #require(UserDefaults(suiteName: suite))
    defer { reglages.removePersistentDomain(forName: suite) }
    let connues = InstallationsConnues(reglages: reglages)
    let residence = ServiceSimule.residence
    connues.retenir(residence)
    connues.retenir(Installation(adresse: URL(string: "https://autre.exemple.fr")!, nom: "Autre", aUnLogo: false))
    connues.retenir(residence)
    #expect(connues.liste.map(\.nom) == [residence.nom, "Autre"])
    #expect(InstallationsConnues(reglages: reglages).liste.count == 2, "relue au lancement suivant")
}
