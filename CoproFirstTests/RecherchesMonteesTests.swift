// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// ⌘F va à la dernière recherche apparue (#223) : la feuille au-dessus de sa page, puis la
/// page de nouveau quand la feuille se referme.
@MainActor
struct RecherchesMonteesTests {
    @Test func laDerniereApparueSOuvreSeule() {
        let montees = RecherchesMontees()
        var ouvertes: [String] = []
        let page = UUID()
        let feuille = UUID()
        montees.monter(page) { ouvertes.append("page") }
        montees.monter(feuille) { ouvertes.append("feuille") }
        #expect(montees.ouvrirLaDerniere())
        #expect(ouvertes == ["feuille"], "la page derrière la feuille ne s'ouvre pas")
        montees.demonter(feuille)
        #expect(montees.ouvrirLaDerniere())
        #expect(ouvertes == ["feuille", "page"], "la feuille refermée, la page répond de nouveau")
    }

    @Test func revenirSurUnePageLaRemetEnTeteSansDoublon() {
        let montees = RecherchesMontees()
        var ouvertes: [String] = []
        let premiere = UUID()
        let seconde = UUID()
        montees.monter(premiere) { ouvertes.append("première") }
        montees.monter(seconde) { ouvertes.append("seconde") }
        montees.monter(premiere) { ouvertes.append("première") }
        montees.ouvrirLaDerniere()
        montees.demonter(premiere)
        montees.ouvrirLaDerniere()
        #expect(ouvertes == ["première", "seconde"])
        montees.demonter(seconde)
        #expect(!montees.ouvrirLaDerniere(), "aucune recherche à l'écran : ⌘F ne fait rien")
        #expect(ouvertes.count == 2)
    }
}
