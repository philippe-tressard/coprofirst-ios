// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI
import UIKit

/// La couleur d'un jeton de la charte, au poignet : la montre est toujours en sombre, et
/// watchOS n'a pas de couleur à fournisseur dynamique. Elle prend donc la valeur SOMBRE de
/// la palette générée (`palette-sombre.css`) — l'iPhone choisit entre les deux
/// (`CoproFirst/Charte/CouleurDuTheme.swift`, exclu de cette cible).
extension Color {
    init(clair: RVBA, sombre: RVBA) {
        self.init(uiColor: sombre.uiColor)
    }
}
