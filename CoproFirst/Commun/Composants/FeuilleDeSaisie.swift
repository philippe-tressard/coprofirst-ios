// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le squelette d'une feuille de saisie, écrit une fois (#348) : sa pile de navigation, un
/// formulaire sur le fond de la page, la phrase du serveur en tête quand un envoi a échoué,
/// le titre en ligne et sa barre — `BoutonsFeuille`, à côté. Ce que la feuille ajoute
/// (fermeture retenue, tâche, confirmation) se pose sur elle.
struct FeuilleDeSaisie<Contenu: View, Barre: ToolbarContent>: View {
    let titre: String
    let erreur: String?
    @ViewBuilder let contenu: () -> Contenu
    @ToolbarContentBuilder let barre: () -> Barre
    @Environment(\.palette) private var palette

    var body: some View {
        NavigationStack {
            Form {
                if let erreur {
                    Section { MessageErreur(texte: erreur).listRowInsets(EdgeInsets()) }
                        .listRowBackground(Color.clear)
                }
                contenu()
            }
            .scrollContentBackground(.hidden)
            .background(palette.bg)
            .navigationTitle(titre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: barre)
        }
    }
}
