// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La carte qui devient l'écran qu'elle ouvre (zoom d'iOS 18) ; avant iOS 18, la
/// transition standard de la pile.
extension View {
    @ViewBuilder
    func sourceZoom(id: some Hashable, dans espace: Namespace.ID) -> some View {
        if #available(iOS 18, *) {
            matchedTransitionSource(id: id, in: espace)
        } else {
            self
        }
    }

    @ViewBuilder
    func destinationZoom(id: some Hashable, dans espace: Namespace.ID) -> some View {
        if #available(iOS 18, *) {
            navigationTransition(.zoom(sourceID: id, in: espace))
        } else {
            self
        }
    }
}
