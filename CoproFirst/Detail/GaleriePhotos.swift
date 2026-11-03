// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les photos d'une affaire, en bande : lues avec la session (fichiers protégés).
/// Un toucher ouvre la photo en grand.
struct GaleriePhotos: View {
    let chemins: [String]
    let installation: Installation
    @State private var ouverte: PhotoOuverte?

    /// La photo montrée en grand (une feuille par photo).
    private struct PhotoOuverte: Identifiable {
        let chemin: String
        var id: String { chemin }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Photos")
                .styleLibelle()
                .accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(chemins, id: \.self) { chemin in
                        Button {
                            ouverte = PhotoOuverte(chemin: chemin)
                        } label: {
                            PhotoProtegee(chemin: chemin, installation: installation)
                                .frame(width: 200, height: 150)
                                .clipShape(.rect(cornerRadius: Mise.rayon, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Photo \((chemins.firstIndex(of: chemin) ?? 0) + 1) sur \(chemins.count)")
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .sheet(item: $ouverte) { ouverte in
            PhotoProtegee(chemin: ouverte.chemin, installation: installation, remplir: false)
                .padding()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

/// Une photo de `/uploads/`, chargée par le service (session de l'installation).
struct PhotoProtegee: View {
    let chemin: String
    let installation: Installation
    var remplir = true
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var image: UIImage?
    @State private var echec = false

    var body: some View {
        ZStack {
            palette.neutreFond
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: remplir ? .fill : .fit)
                    .transition(.opacity)
            } else if echec {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.title2)
                    .foregroundStyle(palette.textMuted)
                    .accessibilityLabel("Photo indisponible")
            } else {
                ProgressView()
            }
        }
        .animation(.smooth(duration: 0.2), value: image != nil)
        .task(id: chemin) {
            do {
                let donnees = try await parcours.service.photo(chemin, dans: installation)
                image = UIImage(data: donnees)
                echec = image == nil
            } catch {
                echec = true
            }
        }
    }
}
