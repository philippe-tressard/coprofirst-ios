// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

final class AccueilUITests: XCTestCase {
    @MainActor
    func testLAppSOuvreSurLAccueil() throws {
        let app = XCUIApplication()
        app.launch()

        let titre = app.staticTexts["accueil.titre"]
        XCTAssertTrue(titre.waitForExistence(timeout: 10))
        XCTAssertEqual(titre.label, "CoproFirst")
    }
}
