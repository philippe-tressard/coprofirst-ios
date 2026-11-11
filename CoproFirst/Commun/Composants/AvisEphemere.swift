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
    /// Le ton de la phrase à l'écran : un succès, sauf quand le serveur en dit un autre.
    private(set) var ton = TonAvis.success
    /// La phrase d'une feuille qui se ferme, en attendant la fin de sa fermeture.
    @ObservationIgnored private var enAttente: PhraseAvis?

    init(_ texte: String? = nil) { self.texte = texte }

    /// Dire la phrase ; elle remplace celle qui est à l'écran.
    func dire(_ texte: String, ton: TonAvis = .success) {
        self.ton = ton
        self.texte = texte
    }

    /// Dire une phrase servie avec son ton (l'`annonce` d'un geste, #55).
    func dire(_ phrase: PhraseAvis) { dire(phrase.texte, ton: phrase.ton) }

    /// Dite par une FEUILLE qui va se fermer : la phrase attend la fin de la fermeture
    /// (`.sheet(…, onDismiss: { avis.feuilleFermee() })`). Dite tout de suite, elle
    /// passait l'essentiel de ses 4 s derrière la feuille — invisible, à l'écran comme
    /// pour l'accessibilité (#43, #48).
    func direApresFermeture(_ texte: String, ton: TonAvis = .success) {
        enAttente = PhraseAvis(texte: texte, ton: ton)
    }

    func direApresFermeture(_ phrase: PhraseAvis) { enAttente = phrase }

    /// La feuille est fermée : la phrase qu'elle a laissée se dit maintenant.
    func feuilleFermee() {
        guard let phrase = enAttente else { return }
        enAttente = nil
        dire(phrase)
    }

    /// Retirer CETTE phrase — pas celle qui l'a remplacée entre-temps.
    func retirer(_ texte: String) {
        if self.texte == texte { self.texte = nil }
    }
}

/// Le ton d'un avis, celui du site (`success | warning | error | info`) : l'`annonce`
/// d'un geste le sert (validation d'un compte, #55) — un avertissement s'y lit comme tel.
enum TonAvis: String, Hashable, Sendable {
    case success, warning, error, info

    var pictogramme: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        case .info: "info.circle.fill"
        }
    }

    var retour: SensoryFeedback {
        switch self {
        case .success: .success
        case .warning: .warning
        case .error: .error
        case .info: .impact(weight: .light)
        }
    }
}

/// Une phrase et son ton.
struct PhraseAvis: Hashable, Sendable {
    var texte: String
    var ton = TonAvis.success
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
                    Label(texte, systemImage: avis.ton.pictogramme)
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
                            #if DEBUG
                            // Sous les tests d'interface, l'avis reste jusqu'au suivant : en 4 s, il
                            // repartait avant d'être lu par un runner qui met 30 s à une requête.
                            if LancementSimule.avisDurable(ProcessInfo.processInfo.arguments) { return }
                            #endif
                            // Remplacée avant la fin : la tâche est annulée, l'avis suivant reste.
                            guard (try? await Task.sleep(for: AvisDuSite.duree)) != nil else { return }
                            avis.retirer(texte)
                        }
                }
            }
            .animation(.snappy(duration: 0.25), value: avis.texte)
            .sensoryFeedback(trigger: avis.texte) { _, nouveau in nouveau == nil ? nil : avis.ton.retour }
    }
}

extension View {
    func avisEphemere(_ avis: AvisDuGeste) -> some View { modifier(AvisEphemere(avis: avis)) }
}
