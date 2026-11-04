// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

extension View {
    /// Le titre d'un écran de menu : grand titre (serif, `ApparenceNavigation`) aux
    /// tailles ordinaires, titre en ligne aux tailles d'accessibilité — un grand titre
    /// y coupe ses mots et mange la moitié de l'écran (#33, #41).
    func titreDeMenu() -> some View { modifier(TitreDeMenu()) }
}

private struct TitreDeMenu: ViewModifier {
    @Environment(\.dynamicTypeSize) private var tailleTexte

    func body(content: Content) -> some View {
        content.navigationBarTitleDisplayMode(tailleTexte.isAccessibilitySize ? .inline : .large)
    }
}
