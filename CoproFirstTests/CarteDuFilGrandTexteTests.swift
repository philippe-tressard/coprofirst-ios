// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI
import Testing
import UIKit

@testable import CoproFirst

// #266 — au plus grand texte, la carte du fil coupait ses mots (« Urgen-t », « pla-fond »)
// parce que la gouttière et la vignette des pièces gardaient leur place à côté du texte.

/// La carte s'empile à toutes les tailles d'accessibilité, et à elles seules.
@Test func laCarteSEmpileAuxTaillesDAccessibiliteSeulement() {
    for taille in DynamicTypeSize.allCases {
        #expect(CarteDuFil.empilee(taille) == taille.isAccessibilitySize, "\(taille)")
    }
}

/// Empilée, le texte a toute la largeur de la carte : sur l'iPhone le plus étroit servi
/// (375 pt, moins la marge de la liste), chaque mot du cas relevé tient entier en AX5 —
/// le titre en `headline`, « Urgent » en `caption`. Le témoin : en ligne, à côté de la
/// gouttière (36 pt mis à l'échelle, plafonnée à xxxLarge) et de trois espaces de 12 pt —
/// sans même compter le chevron ni les pièces —, « Infiltration » ne tenait plus.
@Test func empileeChaqueMotTientEnAX5SurUnIPhone() {
    let carte: CGFloat = 375 - 2 * Mise.marge
    let texte = carte - 2 * CarteDuFil.marge - CarteDuFil.lisere
    for mot in ["Infiltration", "plafond", "parking", "Consultée"] {
        #expect(TexteSansCoupure.largeurDe(mot, en: .accessibility5, style: .headline) <= texte, "\(mot)")
    }
    #expect(TexteSansCoupure.largeurDe("Urgent", en: .accessibility5, style: .caption) <= texte)
    let plafond = UITraitCollection(preferredContentSizeCategory: .extraExtraExtraLarge)
    let gouttiere = UIFontMetrics(forTextStyle: .body).scaledValue(for: 36, compatibleWith: plafond)
    let enLigne = texte - gouttiere - 3 * 12
    #expect(TexteSansCoupure.largeurDe("Infiltration", en: .accessibility5, style: .headline) > enLigne, "le témoin")
}
