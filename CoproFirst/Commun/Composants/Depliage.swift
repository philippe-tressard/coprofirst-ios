// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

extension View {
    /// Un en-tête qui DÉPLIE et replie ce qu'il porte (une année d'archives, un exercice
    /// d'avis, une fiche, une règle), écrit une fois (#384) : son ÉTAT, en valeur
    /// d'accessibilité (« déplié », « replié » — ou leurs accords, `etats`), et ce que fera le
    /// prochain toucher, en indication. VoiceOver dit l'un et l'autre ; les tests d'interface
    /// lisent l'état et ne rejouent un toucher perdu qu'à état inchangé
    /// (`XCUIApplication.deplier(_:)`) — un dépliage touché deux fois se refermerait.
    ///
    /// `actif: false` : rien à déplier (une règle sans détail) — ni état ni indication.
    func depliage(
        ouvert: Bool, deplier: String, replier: String, etats: (ouvert: String, ferme: String) = ("déplié", "replié"),
        actif: Bool = true
    ) -> some View {
        accessibilityValue(actif ? (ouvert ? etats.ouvert : etats.ferme) : "")
            .accessibilityHint(actif ? (ouvert ? replier : deplier) : "")
    }
}
