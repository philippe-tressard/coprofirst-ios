// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Observation
import SwiftUI

/// La phrase brève qui suit un geste (le « toast » du site), portée HORS du corps de
/// l'écran : seul `avisEphemere` la lit.
///
/// ⚠️ Jamais une `Binding<String?>` vers l'écran : une `Binding` lit sa valeur dès sa
/// création, donc l'écran qui la fabrique se recalcule à l'arrivée ET au retrait de
/// l'avis — et reconstruit ses menus de barre d'outils sous le doigt. Un toucher sur
/// « Déclarer un accès » s'y perdait (AccesUITests, CI iOS 26.5, #48).
@MainActor @Observable
final class AvisDuGeste {
    private(set) var texte: String?

    init(_ texte: String? = nil) { self.texte = texte }

    /// Dire la phrase ; elle remplace celle qui est à l'écran.
    func dire(_ texte: String) { self.texte = texte }

    /// Retirer CETTE phrase — pas celle qui l'a remplacée entre-temps.
    func retirer(_ texte: String) {
        if self.texte == texte { self.texte = nil }
    }
}

/// L'avis : il monte du bas, reste le temps du site (`AvisDuSite.duree`, généré), et se
/// retire — un fondu seul quand le mouvement est réduit.
struct AvisEphemere: ViewModifier {
    let avis: AvisDuGeste
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let texte = avis.texte {
                    Label(texte, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.textInverse)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(palette.text.opacity(0.92), in: .capsule)
                        .padding(.bottom, 12)
                        .padding(.horizontal, Mise.marge)
                        .transition(mouvementReduit ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        .accessibilityAddTraits(.updatesFrequently)
                        .task(id: texte) {
                            AccessibilityNotification.Announcement(texte).post()
                            // Remplacée avant la fin : la tâche est annulée, l'avis suivant reste.
                            guard (try? await Task.sleep(for: AvisDuSite.duree)) != nil else { return }
                            avis.retirer(texte)
                        }
                }
            }
            .animation(.snappy(duration: 0.25), value: avis.texte)
            .sensoryFeedback(.success, trigger: avis.texte) { _, nouveau in nouveau != nil }
    }
}

extension View {
    func avisEphemere(_ avis: AvisDuGeste) -> some View { modifier(AvisEphemere(avis: avis)) }
}
