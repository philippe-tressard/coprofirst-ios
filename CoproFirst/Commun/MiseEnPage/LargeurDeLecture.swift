// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

extension View {
    /// Une colonne de lecture : le contenu d'un écran ne s'étire pas au-delà de
    /// `Mise.lecture`, centré dans la largeur qui reste (#223) — une ligne de texte ne court
    /// pas sur les 1 300 points d'un iPad en paysage. Sans effet sur iPhone, plus étroit.
    ///
    /// La largeur suit Dynamic Type : en grand texte, autant de mots par ligne qu'au texte
    /// par défaut. Se pose SUR LE CONTENU d'un `ScrollView`, ou sur une `List` dont le fond
    /// est posé après (la colonne laisse voir le fond de la page autour d'elle).
    func largeurDeLecture() -> some View {
        modifier(LargeurDeLecture())
    }
}

private struct LargeurDeLecture: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var lecture = Mise.lecture

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: lecture)
            .frame(maxWidth: .infinity)
    }
}
