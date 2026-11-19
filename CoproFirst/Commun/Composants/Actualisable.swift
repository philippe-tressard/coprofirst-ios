// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

extension View {
    /// Tirer pour actualiser (`refreshable`), et ⌘R au clavier matériel de l'iPad (#223) :
    /// la même action, listée dans le panneau des raccourcis que montre ⌘ tenu.
    func actualisable(@_inheritActorContext _ action: @escaping @Sendable () async -> Void) -> some View {
        modifier(ActualiserAuClavier()).refreshable(action: action)
    }
}

/// Le raccourci lit l'action que `refreshable` pose dans l'environnement : posé AVANT lui,
/// il est dedans — une seule action, jamais deux qui divergent.
private struct ActualiserAuClavier: ViewModifier {
    @Environment(\.refresh) private var actualiser

    func body(content: Content) -> some View {
        content.background {
            if let actualiser {
                // Un bouton sans surface : le clavier seul l'atteint, VoiceOver garde le geste.
                Button(TextesClavier.actualiser) { Task { await actualiser() } }
                    .keyboardShortcut("r")
                    .frame(width: 0, height: 0)
                    .opacity(0)
                    .accessibilityHidden(true)
            }
        }
    }
}

enum TextesClavier {
    static let actualiser = "Actualiser"
    static let nouvelleAffaire = "Nouvelle affaire"
}
