// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les textes des notifications sur le téléphone, écrits une fois.
enum TextesPush {
    static let titre = "Être averti sur ce téléphone"
    static let explication =
        "Quand une alerte arrive, votre téléphone vous prévient. "
        + "Le message ne dit rien de son contenu : vous le lisez ici."
    static let activer = "Activer"
    static let plusTard = "Plus tard"
}

/// L'offre d'activer les notifications, en tête de la cloche — le moment où la
/// personne regarde ses alertes, jamais au lancement (`ux-patterns-ios`). L'alerte
/// d'iOS ne s'ouvre qu'après « Activer » ; « Plus tard » tait l'offre quelques jours.
/// Rien n'est proposé si iOS a déjà la réponse (accordée ou refusée).
struct OffrePush: View {
    @Environment(NotificationsPush.self) private var push
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var taille
    @ScaledMetric(relativeTo: .title2) private var pictogramme = 28

    var body: some View {
        if push.offreDue {
            Section {
                Carte {
                    VStack(alignment: .leading, spacing: 12) {
                        entete
                        Text(TextesPush.explication)
                            .font(.subheadline)
                            .foregroundStyle(palette.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                        boutons
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("push.offre")
            }
            .listRowBackground(Color.clear)
            // Aligné sur les sections de la liste, qui portent déjà leur marge.
            .listRowInsets(.init(top: 4, leading: 0, bottom: 4, trailing: 0))
            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
        }
    }

    /// Le pictogramme et le titre côte à côte ; aux tailles d'accessibilité, le
    /// pictogramme au-dessus, qui laisse toute la largeur au titre.
    private var entete: some View {
        let disposition =
            taille.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        return disposition {
            Image(systemName: "bell.badge")
                .font(.system(size: pictogramme))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(palette.primary)
                .accessibilityHidden(true)
            Text(TextesPush.titre)
                .font(.headline)
                .foregroundStyle(palette.text)
                .accessibilityAddTraits(.isHeader)
        }
    }

    /// Côte à côte ; aux tailles d'accessibilité, l'un sous l'autre, pleine largeur.
    private var boutons: some View {
        let disposition =
            taille.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        return disposition {
            Button(TextesPush.activer) {
                Task { await push.activer() }
            }
            .buttonStyle(.plein)
            .accessibilityIdentifier("push.activer")
            Button(TextesPush.plusTard) {
                push.reporter()
            }
            .buttonStyle(.clair)
            .accessibilityIdentifier("push.plusTard")
        }
    }
}
