// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

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
                let donnees = try await parcours.service.fichierProtege(chemin, dans: installation)
                image = UIImage(data: donnees)
                echec = image == nil
            } catch {
                echec = true
            }
        }
    }
}
