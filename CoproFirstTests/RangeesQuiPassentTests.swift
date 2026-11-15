// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import CoreGraphics
import SwiftUI
import Testing

@testable import CoproFirst

/// Un élément qui mesure `ideale` sans contrainte, et qui passe à la ligne quand on lui
/// propose moins : sa hauteur grandit d'autant de lignes qu'il en faut.
private func element(_ ideale: CGSize) -> (ProposedViewSize) -> CGSize {
    { proposition in
        guard let largeur = proposition.width, largeur < ideale.width else { return ideale }
        let lignes = (ideale.width / max(largeur, 1)).rounded(.up)
        return CGSize(width: largeur, height: ideale.height * lignes)
    }
}

@Test func unElementPlusLargeQueLaRangeePasseALaLigneDansLaRangee() {
    let mise = RangeesQuiPassent.miseEnPage(
        [element(CGSize(width: 60, height: 20)), element(CGSize(width: 300, height: 20))],
        largeur: 200, espacement: 6)
    #expect(mise.cadres[0] == CGRect(x: 0, y: 0, width: 60, height: 20))
    #expect(
        mise.cadres[1] == CGRect(x: 0, y: 26, width: 200, height: 40), "seul sur sa ligne, à la largeur de la rangée")
    #expect(mise.taille == CGSize(width: 200, height: 66), "rien ne déborde de la rangée")
}

@Test func lesElementsQuiTiennentPartagentLaLigne() {
    let mise = RangeesQuiPassent.miseEnPage(
        [
            element(CGSize(width: 60, height: 20)), element(CGSize(width: 80, height: 24)),
            element(CGSize(width: 70, height: 20)),
        ],
        largeur: 200, espacement: 6)
    #expect(mise.cadres.map(\.origin) == [CGPoint(x: 0, y: 0), CGPoint(x: 66, y: 0), CGPoint(x: 0, y: 30)])
    #expect(mise.taille == CGSize(width: 146, height: 50))
}

@Test func sansLargeurProposeeTousSurUneLigne() {
    let mise = RangeesQuiPassent.miseEnPage(
        [element(CGSize(width: 300, height: 20)), element(CGSize(width: 300, height: 20))],
        largeur: nil, espacement: 6)
    #expect(mise.taille == CGSize(width: 606, height: 20))
}
