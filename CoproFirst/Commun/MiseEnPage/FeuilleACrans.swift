// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

extension View {
    /// Une feuille de la charte, écrite une fois (#223) : sur iPhone, à mi-hauteur puis
    /// pleine, sa poignée visible ; sur iPad (classe régulière), le système la présente en
    /// feuille de formulaire centrée — les crans n'y ont pas cours.
    func feuilleACrans() -> some View {
        presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
    }
}
