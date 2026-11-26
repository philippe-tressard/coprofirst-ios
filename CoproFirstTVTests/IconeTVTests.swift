// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// L'icône et l'étagère sont DANS l'app Apple TV construite (#320) : sans elles, la soumission
/// est refusée, et rien ne casse le build. `actool` les inscrit dans l'Info.plist depuis le
/// catalogue (`ASSETCATALOG_COMPILER_APPICON_NAME`) ; leurs dimensions se jugent dans le dépôt
/// (`scripts/images_logo.py`). L'« À propos » de l'écran de hall dit où lire le code.
struct IconeTVTests {
    @Test func lIconeEtLEtagereSontInscritesDansLApp() throws {
        let info = try #require(Bundle.main.infoDictionary)
        let icones = try #require(info["CFBundleIcons"] as? [String: Any])
        #expect(icones["CFBundlePrimaryIcon"] as? String == "App Icon")
        let etagere = try #require(info["TVTopShelfImage"] as? [String: String])
        #expect(etagere["TVTopShelfPrimaryImage"] == "Top Shelf Image")
        #expect(etagere["TVTopShelfPrimaryImageWide"] == "Top Shelf Image Wide")
        #expect(Bundle.main.url(forResource: "Assets", withExtension: "car") != nil)
    }

    @Test func lAProposDitLAdresseDuCodeEtLaLicence() {
        #expect(SourceDeLApp.depot == "https://github.com/philippe-tressard/coprofirst-ios")
        #expect(SourceDeLApp.licence.contains("GNU Affero General Public License"))
        #expect(EcranDeHall.versionApp(SourceDeLApp.version()).contains("version "))
    }
}
