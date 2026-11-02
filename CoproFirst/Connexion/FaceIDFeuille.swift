// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Écran 4 — proposé une fois, après la première connexion à une résidence.
struct FaceIDFeuille: View {
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var active: Bool?

    var body: some View {
        ScrollView {
            contenu
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(palette.bg)
        .sensoryFeedback(.success, trigger: active) { _, nouveau in nouveau == true }
    }

    private var contenu: some View {
        VStack(spacing: 18) {
            Image(systemName: "faceid")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(palette.primary)
                .symbolEffect(.bounce, value: active)
                .accessibilityHidden(true)
                .padding(.top, 8)
            Text("Ouvrir avec Face ID ?")
                .font(.titre(.title2))
                .foregroundStyle(palette.text)
                .accessibilityAddTraits(.isHeader)
            Text(
                "La prochaine fois, un regard suffira pour retrouver le fil de \(installation.nom), "
                    + "sans ressaisir votre mot de passe."
            )
            .font(.body)
            .foregroundStyle(palette.textMuted)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 10) {
                Button("Activer") {
                    Task {
                        active = await parcours.service.activerFaceID(installation)
                        parcours.proposerFaceID = false
                    }
                }
                .buttonStyle(.plein)
                .accessibilityIdentifier("faceid.activer")
                Button("Plus tard") { parcours.proposerFaceID = false }
                    .buttonStyle(.contour)
                    .accessibilityIdentifier("faceid.plusTard")
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, Mise.marge)
        .padding(.vertical, 24)
    }
}
