// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// Les textes des composants tiers sont DANS l'app construite (#168) : un avis ou une
/// licence qui n'y est plus — fichier déplacé, phase de ressources perdue — ne fait
/// échouer aucun build, et l'écran « À propos » se viderait sans rien dire.
struct ComposantsTiersTests {
    @Test func chaqueComposantMontreTousSesTextes() {
        for composant in ComposantsTiers.tous {
            let lus = composant.lus()
            #expect(lus.count == composant.textes.count, "\(composant.nom) : un texte manque dans l'app")
            #expect(lus.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }, "\(composant.nom)")
        }
    }

    @Test func lesPaquetsSousApacheMontrentLaLicenceEntiere() throws {
        let paquets = ComposantsTiers.tous.filter { $0.licences == ComposantsTiers.apache }
        #expect(paquets.count == 4)
        for paquet in paquets {
            let licence = try #require(paquet.lus().last)
            #expect(licence.contains("Apache License") && licence.contains("Version 2.0"))
            #expect(licence.contains("END OF TERMS AND CONDITIONS"))
        }
    }

    @Test func unAvisNommeSonProjet() throws {
        let runtime = try #require(ComposantsTiers.tous.first { $0.nom == "swift-openapi-runtime" })
        #expect(runtime.lus().first?.contains("The SwiftOpenAPIGenerator Project") == true)
    }
}
