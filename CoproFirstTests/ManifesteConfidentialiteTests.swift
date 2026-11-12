// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// Le manifeste de confidentialité est DANS l'app construite (#19) : Apple le lit à la
/// racine du paquet de l'app. S'il n'y est plus — dossier déplacé, phase de ressources
/// perdue —, aucun build n'échoue : c'est ce test qui le dit.
///
/// Son accord avec le code et avec la fiche de l'App Store se juge dans le dépôt
/// (`scripts/verifier-confidentialite.py`) ; ici, ce que seule l'app construite montre.
struct ManifesteConfidentialiteTests {
    private func manifeste() throws -> [String: Any] {
        let adresse = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let lu = try PropertyListSerialization.propertyList(from: Data(contentsOf: adresse), format: nil)
        return try #require(lu as? [String: Any])
    }

    @Test func leManifesteEstEmbarqueALaRacineDeLApp() throws {
        let adresse = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        #expect(adresse.deletingLastPathComponent().standardizedFileURL == Bundle.main.bundleURL.standardizedFileURL)
    }

    @Test func lAppNeTracePas() throws {
        let manifeste = try manifeste()
        #expect(manifeste["NSPrivacyTracking"] as? Bool == false)
        #expect((manifeste["NSPrivacyTrackingDomains"] as? [String]) == [])
        let donnees = try #require(manifeste["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
        #expect(!donnees.isEmpty)
        for donnee in donnees {
            #expect(donnee["NSPrivacyCollectedDataTypeTracking"] as? Bool == false)
        }
    }

    /// Les réglages (`UserDefaults`) sont la seule API à raison requise que l'app appelle.
    @Test func lesReglagesSontDeclares() throws {
        let acces = try #require(try manifeste()["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        #expect(acces.map { $0["NSPrivacyAccessedAPIType"] as? String } == ["NSPrivacyAccessedAPICategoryUserDefaults"])
        #expect(acces.first?["NSPrivacyAccessedAPITypeReasons"] as? [String] == ["CA92.1"])
    }
}
