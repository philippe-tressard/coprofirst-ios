// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Les notifications push (#17), contre l'API et le centre de notifications simulés :
/// l'offre d'activer dans la cloche, jamais au lancement ; une notification touchée
/// ouvre la cloche de sa résidence. Captures : `LancementCaptures`.
final class PushUITests: XCTestCase {

    /// Un élément par son identifiant, quel que soit son type (skill `swiftui-patterns`).
    private func el(_ app: XCUIApplication, _ identifiant: String) -> XCUIElement {
        app.descendants(matching: .any)[identifiant].firstMatch
    }

    /// La feuille des notifications est ouverte : son bouton « OK » paraît.
    private func feuilleOuverte(_ app: XCUIApplication) -> Bool {
        el(app, "notifications.ok").apparait()
    }

    @MainActor
    func testAucuneDemandeAuLancementLOffreAttendDansLaCloche() throws {
        let app = LancementCaptures.lancer(arguments: ["-push", "non-demandee"])
        let cloche = el(app, "cloche")
        XCTAssertTrue(cloche.apparait())
        XCTAssertFalse(el(app, "push.offre").exists, "rien ne se propose hors de la cloche")
        cloche.tap()
        XCTAssertTrue(el(app, "push.offre").apparait(), "l'offre en tête de la cloche")
        LancementCaptures.capturer("17a-offre-push")
        el(app, "push.activer").tap()
        XCTAssertTrue(
            el(app, "push.offre").disparait(), "accordée : l'offre se retire")
        XCTAssertTrue(el(app, "notifications.modifier").exists, "la liste reste")
    }

    @MainActor
    func testPlusTardRetireLOffre() throws {
        let app = LancementCaptures.lancer(arguments: ["-push", "non-demandee"])
        el(app, "cloche").tap()
        XCTAssertTrue(el(app, "push.plusTard").apparait())
        el(app, "push.plusTard").tap()
        XCTAssertTrue(el(app, "push.offre").disparait())
    }

    @MainActor
    func testUnRefusDIOSNeSeRedemandePas() throws {
        let app = LancementCaptures.lancer(arguments: ["-push", "refusee"])
        el(app, "cloche").tap()
        XCTAssertTrue(el(app, "notifications.modifier").apparait(), "la liste chargée")
        XCTAssertFalse(el(app, "push.offre").exists)
    }

    @MainActor
    func testUneNotificationToucheeOuvreLaCloche() throws {
        let app = LancementCaptures.lancer(arguments: ["-push-touchee"])
        XCTAssertTrue(feuilleOuverte(app), "la cloche de la résidence, lue par l'API")
        LancementCaptures.capturer("17b-notification-touchee")
    }

    /// À froid, la session gardée : Face ID rouvre la résidence, puis sa cloche.
    @MainActor
    func testUneNotificationToucheeAFroidPasseParFaceIDPuisOuvreLaCloche() throws {
        let app = LancementCaptures.lancer(ecran: "retour", arguments: ["-push-touchee"])
        XCTAssertTrue(feuilleOuverte(app), "après Face ID, la cloche")
    }
}
