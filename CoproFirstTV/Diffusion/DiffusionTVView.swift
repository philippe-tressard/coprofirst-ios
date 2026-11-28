// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI
import UIKit

/// La diffusion des affiches (#218, lot 3) : le nom de la résidence en tête, une affiche à la
/// fois — son titre, son message, ses photos à droite —, un repère par affiche en bas. Celle
/// d'une installation qui ne sert pas le Fil de l'écran (#429). L'écran allumé, le clic de la
/// télécommande et le retrait : `GestesDuHall`.
struct DiffusionTVView: View {
    @State private var diffusion: DiffusionTV
    let retire: () -> Void
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit

    init(appairage: MemoireEcran.Appairage, service: any ServiceEcranTV, retire: @escaping () -> Void) {
        _diffusion = State(
            initialValue: DiffusionTV(residence: appairage.residence, jeton: appairage.jeton, service: service))
        self.retire = retire
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Mise.marge) {
            Text(diffusion.residence.nom)
                .styleLibelle()
                .accessibilityIdentifier("hall.residence")
            contenu
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if diffusion.affiches.count > 1 { reperes }
        }
        .padding(Mise.marge * 3)
        .gestesDuHall(retiree: diffusion.retire, retire: retire)
        .task { await diffusion.diffuser() }
    }

    @ViewBuilder
    private var contenu: some View {
        if let affiche = diffusion.affiche {
            AfficheTVView(affiche: affiche, diffusion: diffusion)
                .id(affiche.id)
                .transition(.opacity)
                .animation(mouvementReduit ? nil : .easeOut(duration: RythmeTV.fondu), value: affiche.id)
        } else if diffusion.lue {
            ContentUnavailableView(
                EcranDeHall.aucuneTitre, systemImage: "rectangle.on.rectangle",
                description: Text(EcranDeHall.aucuneMessage))
            .accessibilityIdentifier("hall.aucune")
        } else {
            ProgressView(EcranDeHall.lecture)
        }
    }

    /// Un point par affiche, la courante pleine : on sait d'un coup d'œil combien il y en a.
    private var reperes: some View {
        HStack(spacing: MiseTV.repere) {
            ForEach(diffusion.affiches.indices, id: \.self) { rang in
                Circle()
                    .fill(rang == diffusion.rang ? palette.primary : palette.border)
                    .frame(width: MiseTV.repere, height: MiseTV.repere)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(EcranDeHall.position(diffusion.rang, sur: diffusion.affiches.count))
        .accessibilityIdentifier("hall.reperes")
    }
}

/// Une affiche : le titre et le message (le HTML assaini du serveur, `TexteRiche`) dans leur
/// mesure, et ses photos dans une colonne à droite, lues avec le jeton de l'écran.
private struct AfficheTVView: View {
    let affiche: AfficheHall
    let diffusion: DiffusionTV
    @State private var photos: [UIImage] = []
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .top, spacing: Mise.marge * 3) {
            VStack(alignment: .leading, spacing: Mise.marge) {
                Text(affiche.titre)
                    .font(.titre(.largeTitle))
                    .foregroundStyle(palette.text)
                    .accessibilityIdentifier("hall.affiche.\(affiche.id)")
                TexteRiche(html: affiche.message)
                    .font(.title3)
                    .foregroundStyle(palette.text)
                    .tint(palette.primary)
            }
            .frame(maxWidth: MiseTV.mesure, alignment: .leading)
            if !photos.isEmpty {
                VStack(spacing: MiseTV.ecart) {
                    ForEach(photos.indices, id: \.self) { rang in
                        Image(uiImage: photos[rang])
                            .resizable()
                            .scaledToFit()
                            .clipShape(.rect(cornerRadius: Mise.rayon, style: .continuous))
                            .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: MiseTV.colonnePhotos)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: affiche.id) {
            photos = await diffusion.imagesDe(affiche).compactMap(UIImage.init(data:))
        }
    }
}
