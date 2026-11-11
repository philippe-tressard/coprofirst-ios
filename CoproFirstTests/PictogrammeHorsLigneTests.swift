// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Testing
import UIKit

@testable import CoproFirst

/// Le pictogramme du bandeau hors ligne est un SYMBOLE du catalogue : un modèle mal
/// formé se compilerait en image fixe (ou en rien), et le bandeau perdrait le
/// pictogramme, ou sa taille avec le texte, sans qu'aucun build n'échoue.
@MainActor
@Test func lePictogrammeHorsLigneEstUnSymbole() throws {
    let image = try #require(UIImage(named: BandeauHorsLigne.pictogramme))
    #expect(image.isSymbolImage)
    let petit = try #require(image.applyingSymbolConfiguration(.init(pointSize: 17)))
    let grand = try #require(image.applyingSymbolConfiguration(.init(pointSize: 34)))
    #expect(grand.size.height > petit.size.height * 1.5)
}
