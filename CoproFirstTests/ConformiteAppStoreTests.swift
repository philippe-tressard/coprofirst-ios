// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// Ce que la revue d'Apple lit dans l'app CONSTRUITE, et qu'aucun build ne contredit : le
/// plist de l'app, pas `project.yml`. Constaté le 12/11/2026 sur l'archive Release : l'app
/// sortait iPhone ET iPad (« 1,2 » posé par XcodeGen sur la cible) et sa version « 1.0 »
/// était écrite en dur, sans rapport avec `MARKETING_VERSION`.
struct ConformiteAppStoreTests {
    private var info: [String: Any] { Bundle.main.infoDictionary ?? [:] }

    /// iPhone seul (CLAUDE.md) : une app iPad exige ses captures et le multitâche, donc
    /// toutes les orientations — que cette app n'a pas.
    @Test func lAppEstUneAppIPhone() {
        #expect(info["UIDeviceFamily"] as? [Int] == [1])
        #expect(info["UISupportedInterfaceOrientations"] as? [String] == ["UIInterfaceOrientationPortrait"])
        #expect(info["UISupportedInterfaceOrientations~ipad"] == nil)
    }

    @Test func laVersionEstUneVersionPubliable() throws {
        let version = try #require(info["CFBundleShortVersionString"] as? String)
        // Une variable de build non résolue (« $(MARKETING_VERSION) ») ne passerait pas la revue.
        #expect(version.wholeMatch(of: /\d+(\.\d+){1,2}/) != nil, "version « \(version) »")
        let build = try #require(info["CFBundleVersion"] as? String)
        #expect(build.wholeMatch(of: /\d+(\.\d+){0,2}/) != nil, "build « \(build) »")
    }

    @Test func lIdentifiantEstFige() {
        #expect(Bundle.main.bundleIdentifier == "fr.coprofirst.app")
    }

    /// Chaque autorisation demandée a son texte, et rien d'autre n'est demandé : une clé
    /// `NS…UsageDescription` de plus sans usage fait refuser la revue (5.1.1).
    @Test func lesAutorisationsSontCellesDeLApp() {
        let demandees = Set(info.keys.filter { $0.hasPrefix("NS") && $0.hasSuffix("UsageDescription") })
        #expect(demandees == ["NSCameraUsageDescription", "NSFaceIDUsageDescription"])
        for cle in demandees {
            #expect(!((info[cle] as? String) ?? "").isEmpty, "\(cle)")
        }
    }

    @Test func lAppNeDeclareAucuneExceptionDeTransport() {
        #expect(info["NSAppTransportSecurity"] == nil)
        #expect(info["ITSAppUsesNonExemptEncryption"] as? Bool == false)
    }
}
