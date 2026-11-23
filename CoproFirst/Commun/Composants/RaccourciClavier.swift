// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Un raccourci du clavier matériel de l'iPad sans surface (#223) : un bouton que le
/// clavier seul atteint, listé sous son titre dans le panneau que montre ⌘ tenu.
/// VoiceOver ne le voit pas : il garde le geste ou le contrôle visible qui fait la même
/// chose. Posé en fond (`.background { RaccourciClavier(…) }`) de ce qu'il commande.
///
/// Une touche que le système tient déjà (⌘F « Rechercher », ⌘G, ⌘U…) ne l'atteint pas :
/// on répond alors à l'action du système (`RechercheAuClavier.swift`, #223).
/// Aucune animation : un raccourci se répète, il agit à l'instant.
struct RaccourciClavier: View {
    let titre: String
    let touche: KeyEquivalent
    let action: () -> Void

    var body: some View {
        Button(titre, action: action)
            .keyboardShortcut(touche)
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
    }
}

enum TextesClavier {
    static let actualiser = "Actualiser"
    static let nouvelleAffaire = "Nouvelle affaire"
    static let rechercher = "Rechercher"
}
