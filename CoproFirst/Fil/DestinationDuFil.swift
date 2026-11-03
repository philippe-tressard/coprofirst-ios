// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Une carte du fil qui s'ouvre : poussée (affaire, actualité, sondage, document)
/// ou en feuille (résumé). Le toucher se voit à l'instant.
struct CarteOuvrable: View {
    let element: ElementDuFil
    let zoom: Namespace.ID
    let ouvrirResume: () -> Void

    var body: some View {
        Group {
            if case .resume = element.cible {
                Button(action: ouvrirResume) { CarteDuFil(element: element) }
            } else {
                NavigationLink(value: element) { CarteDuFil(element: element) }
            }
        }
        .buttonStyle(StyleCarte())
        .sourceZoom(id: element.id, dans: zoom)
        .accessibilityHint(element.cible.libelle)
        .accessibilityIdentifier("fil.\(element.id)")
    }
}

/// L'écran qu'ouvre une carte poussée — selon sa cible, la règle du site.
struct DestinationDuFil: View {
    let element: ElementDuFil
    let installation: Installation

    var body: some View {
        switch element.cible {
        case .affaire(let id):
            DetailAffaireView(id: id, installation: installation)
        case .sondage(let id):
            SondageView(id: id, installation: installation)
        case .document(let id, let nom):
            DocumentView(id: id, nom: nom, titre: element.titre, installation: installation)
        case .resume:
            ResumeFeuille(element: element, installation: installation)
        }
    }
}

/// L'appui sur une carte : un léger enfoncement, aussitôt défait ; rien si le
/// mouvement est réduit.
struct StyleCarte: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !mouvementReduit ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
            .contentShape(.rect(cornerRadius: Mise.rayon))
    }
}
