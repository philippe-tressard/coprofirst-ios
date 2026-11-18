// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI
import UIKit

/// La couleur qui suit le thème, sur l'iPhone et l'Apple TV. La montre, toujours en sombre,
/// a la sienne (`CoproFirstWatch/CouleurMontre.swift`) : watchOS n'a pas de couleur à
/// fournisseur dynamique (#226).
extension Color {
    /// Une couleur qui suit le thème du système : la valeur claire de `socle.css`,
    /// la sombre de `palette-sombre.css` (Palette+*.swift, générés).
    init(clair: RVBA, sombre: RVBA) {
        self.init(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? sombre.uiColor : clair.uiColor
            }
        )
    }
}
