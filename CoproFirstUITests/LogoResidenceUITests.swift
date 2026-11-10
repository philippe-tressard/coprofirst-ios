// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Le logo de la résidence là où il s'affiche — pastille, feuille de la résidence,
/// connexion — sur l'API simulée, au contrat 1.15.0 (variante sombre demandée au thème
/// sombre) et 1.14.0 (le logo seul) (#70). Le choix de la variante est jugé par les tests
/// unitaires (`LogoResidenceTests`) ; ceux-ci parcourent les écrans et en laissent les
/// captures (`TEST_RUNNER_CAPTURES`, `TEST_RUNNER_THEME`).
final class LogoResidenceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLeLogoAuContrat1_15_0() throws {
        try parcourir(contrat: "1.15.0")
    }

    @MainActor
    func testLeLogoAuContrat1_14_0() throws {
        try parcourir(contrat: "1.14.0")
    }

    @MainActor
    private func parcourir(contrat: String) throws {
        var app = LancementCaptures.lancer(ecran: "fil", arguments: ["-logo-residence", contrat])
        let pastille = app.descendants(matching: .any).matching(identifier: "pastille.residence").firstMatch
        XCTAssertTrue(pastille.waitForExistence(timeout: 5))
        capturer("logo-\(contrat)-pastille")

        pastille.tap()
        let sortir = app.descendants(matching: .any).matching(identifier: "residence.deconnecter").firstMatch
        XCTAssertTrue(sortir.waitForExistence(timeout: 5), "la feuille de la résidence s'ouvre")
        capturer("logo-\(contrat)-feuille")
        app.terminate()

        app = LancementCaptures.lancer(ecran: "connexion", arguments: ["-logo-residence", contrat])
        let champ = app.descendants(matching: .any).matching(identifier: "connexion.residence").firstMatch
        XCTAssertTrue(champ.waitForExistence(timeout: 5))
        capturer("logo-\(contrat)-connexion")
    }

    /// Une capture, une fois le dessin simulé arrivé (150 ms) et son fondu fini — la
    /// pause ne se fait que si des captures sont demandées.
    @MainActor
    private func capturer(_ nom: String) {
        guard ProcessInfo.processInfo.environment["CAPTURES"] != nil else { return }
        Thread.sleep(forTimeInterval: 1)
        LancementCaptures.capturer(nom)
    }
}
