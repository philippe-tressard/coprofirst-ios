// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les photos d'un élément en mosaïque, comme Messages les groupe : une photo occupe
/// tout le cadre ; deux, côte à côte ; trois et plus, une grande à gauche et deux
/// petites à droite, la dernière disant « +N » quand il en reste. Le cadre garde la même
/// hauteur quel que soit le nombre : le texte qui suit ne saute pas.
///
/// Les tuiles REMPLISSENT leur case (une photo portrait y perd ses bords) : la photo
/// entière se voit au toucher, dans Coup d'œil — divergence déclarée face au format
/// « grand » du site, qui montre chaque photo en entier (`ux-patterns-ios`).
struct MosaiquePhotos: View {
    let chemins: [String]
    let installation: Installation
    let hauteur: CGFloat
    /// La photo en train de s'ouvrir : un indicateur la couvre.
    let enCours: String?
    let ouvrir: (Int) -> Void

    /// L'écart entre deux tuiles : un filet, comme Messages.
    private let joint: CGFloat = 2

    var body: some View {
        Group {
            switch chemins.count {
            case 0:
                EmptyView()
            case 1:
                tuile(0)
            case 2:
                HStack(spacing: joint) {
                    tuile(0)
                    tuile(1)
                }
            default:
                GeometryReader { cadre in
                    HStack(spacing: joint) {
                        tuile(0)
                        VStack(spacing: joint) {
                            tuile(1)
                            tuile(2, reste: chemins.count - 3)
                        }
                        .frame(width: (cadre.size.width - joint) / 3)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: hauteur)
        .clipShape(.rect(cornerRadius: Mise.rayon, style: .continuous))
    }

    private func tuile(_ rang: Int, reste: Int = 0) -> some View {
        Button {
            ouvrir(rang)
        } label: {
            // La case d'abord, la photo par-dessus : une image qui REMPLIT impose sinon sa
            // largeur à la rangée, et la colonne de droite sortait du cadre.
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay { PhotoProtegee(chemin: chemins[rang], installation: installation) }
                .clipped()
                .overlay {
                    if reste > 0 {
                        Rectangle().fill(.thinMaterial)
                        Text("+\(reste)")
                            .font(.title2.weight(.semibold).monospacedDigit())
                    }
                }
                .overlay {
                    if enCours == chemins[rang] {
                        Rectangle().fill(.ultraThinMaterial)
                        ProgressView()
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(libelle(rang, reste: reste))
        .accessibilityHint("Ouvre les photos en grand.")
        .accessibilityIdentifier("pieces.photo.\(rang)")
    }

    private func libelle(_ rang: Int, reste: Int) -> String {
        let base = "Photo \(rang + 1) sur \(chemins.count)"
        return reste > 0 ? "\(base), et \(reste) de plus" : base
    }
}

/// La vignette d'une carte FERMÉE (`FluxVignette` du site) : la première photo, « +N »
/// s'il y en a d'autres ; sans photo, un trombone et le nombre de pièces. Même place,
/// même taille dans tous les cas : le rythme du fil ne bouge pas. Décorative — la carte
/// dit ses pièces au lecteur d'écran (`PiecesJointes.enClair`).
struct VignettePieces: View {
    let pieces: PiecesJointes
    let installation: Installation
    @Environment(\.palette) private var palette

    var body: some View {
        Group {
            if let premiere = pieces.photos.first {
                PhotoProtegee(chemin: premiere, installation: installation)
                    .overlay(alignment: .bottomTrailing) {
                        if pieces.photos.count > 1 {
                            Text("+\(pieces.photos.count - 1)")
                                .font(.caption2.weight(.bold).monospacedDigit())
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.thinMaterial, in: .capsule)
                                .padding(4)
                        }
                    }
            } else if !pieces.documents.isEmpty {
                VStack(spacing: 2) {
                    Image(systemName: "paperclip").font(.headline)
                    Text("\(pieces.documents.count)").font(.caption2.weight(.bold).monospacedDigit())
                }
                .foregroundStyle(palette.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(palette.infoFond)
            }
        }
        .frame(width: Mise.vignette, height: Mise.vignette)
        .clipShape(.rect(cornerRadius: Mise.rayon / 2, style: .continuous))
        .accessibilityHidden(true)
    }
}
