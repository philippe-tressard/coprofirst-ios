// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// En haut à droite de chaque écran après l'accueil : « où suis-je » — le logo et le
/// nom de la résidence (CoproFirst avant toute résidence), un toucher pour en
/// changer ; la cloche à côté. Aux tailles d'accessibilité, le logo seul : le nom,
/// tronqué de toute façon, prenait la place du titre de l'écran (« Ma rési… », #33) ;
/// VoiceOver le dit, et l'appui long le montre en grand, comme les barres du système.
struct PastilleOuSuisJe: ToolbarContent {
    let installation: Installation?
    var cloche = false
    /// La largeur du nom : 150 pt seule dans la barre ; moins quand un élément occupe
    /// la gauche (le logement du fil), sans quoi iOS replierait la pastille dans « … ».
    var largeurNom: CGFloat = 150
    /// Lue ici, côté écran : dans la barre, UIKit plafonne la taille de texte.
    @Environment(\.dynamicTypeSize) private var taille

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Pastille(installation: installation, largeurNom: largeurNom, logoSeul: taille.isAccessibilitySize)
        }
        if cloche, let installation { ClocheNotifications(installation: installation) }
    }

    private struct Pastille: View {
        let installation: Installation?
        let largeurNom: CGFloat
        let logoSeul: Bool
        @Environment(Parcours.self) private var parcours
        @Environment(\.palette) private var palette

        var body: some View {
            let nom = installation?.nom ?? ContenuVitrine.nom
            Button {
                parcours.changerDeResidence = true
            } label: {
                HStack(spacing: 6) {
                    LogoResidence(installation: installation).frame(width: 22, height: 22)
                    if !logoSeul {
                        Text(nom)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .frame(maxWidth: largeurNom, alignment: .leading)
                    }
                }
                .foregroundStyle(palette.text)
            }
            .accessibilityLabel(Text("Résidence : \(nom)"))
            .accessibilityShowsLargeContentViewer { Text(nom) }
            .accessibilityHint("Changer de résidence")
            .accessibilityIdentifier("pastille.residence")
        }
    }
}
