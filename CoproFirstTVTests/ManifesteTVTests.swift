// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

/// Le manifeste de l'écran de hall est DANS l'app Apple TV construite (#218, lot 5), à la
/// racine du paquet, où Apple le lit — comme `ManifesteConfidentialiteTests` pour l'iPhone.
/// Son accord avec le code se juge dans le dépôt (`scripts/verifier-confidentialite.py`) ;
/// ici, ce que seule l'app construite montre.
struct ManifesteTVTests {
    @Test func leManifesteEstEmbarqueALaRacineEtNeDeclareRien() throws {
        let adresse = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        #expect(adresse.deletingLastPathComponent().standardizedFileURL == Bundle.main.bundleURL.standardizedFileURL)
        let lu = try PropertyListSerialization.propertyList(from: Data(contentsOf: adresse), format: nil)
        let manifeste = try #require(lu as? [String: Any])
        #expect(manifeste["NSPrivacyTracking"] as? Bool == false)
        #expect((manifeste["NSPrivacyTrackingDomains"] as? [String]) == [])
        #expect((manifeste["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true, "l'écran ne collecte rien")
        #expect((manifeste["NSPrivacyAccessedAPITypes"] as? [Any])?.isEmpty == true)
    }
}
