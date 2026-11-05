// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La phrase brève qui suit un geste (le « toast » du site) : elle monte du bas,
/// reste le temps du site (`AvisDuSite.duree`, généré), et se retire — un fondu seul
/// quand le mouvement est réduit.
struct AvisEphemere: ViewModifier {
    @Binding var avis: String?
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let avis {
                    Label(avis, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.textInverse)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(palette.text.opacity(0.92), in: .capsule)
                        .padding(.bottom, 12)
                        .padding(.horizontal, Mise.marge)
                        .transition(mouvementReduit ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        .accessibilityAddTraits(.updatesFrequently)
                        .task(id: avis) {
                            AccessibilityNotification.Announcement(avis).post()
                            try? await Task.sleep(for: AvisDuSite.duree)
                            self.avis = nil
                        }
                }
            }
            .animation(.snappy(duration: 0.25), value: avis)
            .sensoryFeedback(.success, trigger: avis) { _, nouveau in nouveau != nil }
    }
}

extension View {
    func avisEphemere(_ avis: Binding<String?>) -> some View { modifier(AvisEphemere(avis: avis)) }
}
