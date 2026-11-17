// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

extension View {
    /// Le titre d'un écran de menu : grand titre (serif, `ApparenceNavigation`) aux
    /// tailles ordinaires, titre en ligne aux tailles d'accessibilité — un grand titre
    /// y coupe ses mots et mange la moitié de l'écran (#33, #41). Une fiche ouverte à
    /// côté (iPad, #222) : la barre court sur la page ET la fiche, un titre en ligne s'y
    /// centrerait sur leur séparation — il se pose en tête, en grand (`.inlineLarge`).
    func titreDeMenu() -> some View { modifier(TitreDeMenu()) }
}

private struct TitreDeMenu: ViewModifier {
    @Environment(\.dynamicTypeSize) private var tailleTexte
    @Environment(\.colonneDeFiche) private var colonne

    func body(content: Content) -> some View {
        if colonne?.ouverte == true {
            content.toolbarTitleDisplayMode(.inlineLarge)
        } else {
            content.navigationBarTitleDisplayMode(tailleTexte.isAccessibilitySize ? .inline : .large)
        }
    }
}
