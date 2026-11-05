// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// En haut à droite de chaque écran après l'accueil : « où suis-je » — le logo et le
/// nom de la résidence (CoproFirst avant toute résidence), un toucher pour en
/// changer ; la cloche à côté.
struct PastilleOuSuisJe: ToolbarContent {
    let installation: Installation?
    var cloche = false
    /// La largeur du nom : 150 pt seule dans la barre ; moins quand un élément occupe
    /// la gauche (le logement du fil), sans quoi iOS replierait la pastille dans « … ».
    var largeurNom: CGFloat = 150

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Pastille(installation: installation, largeurNom: largeurNom)
        }
        if cloche, let installation { ClocheNotifications(installation: installation) }
    }

    private struct Pastille: View {
        let installation: Installation?
        let largeurNom: CGFloat
        @Environment(Parcours.self) private var parcours
        @Environment(\.palette) private var palette

        var body: some View {
            Button {
                parcours.changerDeResidence = true
            } label: {
                HStack(spacing: 6) {
                    Logo(installation: installation).frame(width: 22, height: 22)
                    Text(installation?.nom ?? ContenuVitrine.nom)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .frame(maxWidth: largeurNom, alignment: .leading)
                }
                .foregroundStyle(palette.text)
            }
            .accessibilityLabel(Text("Résidence : \(installation?.nom ?? ContenuVitrine.nom)"))
            .accessibilityHint("Changer de résidence")
            .accessibilityIdentifier("pastille.residence")
        }
    }
}

/// Le logo téléversé par la résidence, sinon celui de CoproFirst — comme le site, qui
/// montre le logo neutre tant que la résidence n'a pas téléversé le sien.
struct Logo: View {
    let installation: Installation?

    var body: some View {
        if let adresse = installation?.adresseLogo {
            AsyncImage(url: adresse) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                MedaillonPlein()
            }
            .clipShape(.rect(cornerRadius: 5, style: .continuous))
        } else {
            MedaillonPlein()
        }
    }
}

/// Le logo de CoproFirst qui remplit son cadre (pastille, ligne de liste).
private struct MedaillonPlein: View {
    var body: some View {
        Image("Logo")
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
    }
}
