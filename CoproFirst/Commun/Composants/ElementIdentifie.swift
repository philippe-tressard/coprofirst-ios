// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

extension View {
    /// Un élément que les tests retrouvent par `identifiant`, lu en UN élément qui dit
    /// `libelle` (#183).
    ///
    /// Sous iOS 26, un `Label` qui porte lui-même l'identifiant se résout en son IMAGE :
    /// l'élément n'est plus touchable et la requête du test tourne jusqu'au délai. Lu en
    /// un élément, il porte l'identifiant sur tout son texte — et VoiceOver lit une phrase
    /// au lieu d'un pictogramme puis d'un texte. `scripts/verifier-identifiants.py` refuse
    /// un `Label` identifié autrement.
    func elementIdentifie(_ identifiant: String, lu libelle: String) -> some View {
        accessibilityElement(children: .ignore)
            .accessibilityLabel(libelle)
            .accessibilityIdentifier(identifiant)
    }
}
