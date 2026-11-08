// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Une délégation : qui est aidé, par qui, son état et sa période, son motif ; et les
/// gestes que le serveur ouvre au compte qui lit (`peutAccepter`, `peutRevoquer`, #56).
struct CarteDelegation: View {
    let delegation: Delegation
    let enCours: Bool
    let accepter: () -> Void
    let revoquer: () -> Void
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var taille

    var body: some View {
        Carte {
            VStack(alignment: .leading, spacing: 12) {
                personnes
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { statut }
                    VStack(alignment: .leading, spacing: 6) { statut }
                }
                if !delegation.motif.isEmpty {
                    Text(delegation.motif)
                        .font(.subheadline.italic())
                        .foregroundStyle(palette.textMuted)
                }
                if delegation.peutAccepter || delegation.peutRevoquer { gestes }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("delegation.\(delegation.id)")
    }

    /// Personne aidée → aidant ; l'une sous l'autre aux tailles d'accessibilité.
    private var personnes: some View {
        let disposition =
            taille.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        return disposition {
            personne(TextesDelegations.personneAidee, delegation.mandantNom)
            Image(systemName: taille.isAccessibilitySize ? "arrow.down" : "arrow.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.textMuted)
                .accessibilityHidden(true)
            personne(TextesDelegations.aidant, delegation.aidantNom)
        }
    }

    private func personne(_ role: String, _ nom: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(role).styleLibelle()
            Text(nom).font(.headline).foregroundStyle(palette.text)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var statut: some View {
        let libelle = delegation.libelleStatut
        PastilleTeinte(libelle: libelle.libelle, badge: libelle.badge)
            .accessibilityIdentifier("delegation.\(delegation.id).statut")
        Text(TextesDelegations.periode(delegation))
            .font(.subheadline)
            .foregroundStyle(palette.textMuted)
    }

    private var gestes: some View {
        HStack(spacing: 10) {
            if delegation.peutAccepter {
                Button(TextesDelegations.accepter, action: accepter)
                    .buttonStyle(.borderedProminent)
                    .tint(palette.primaryPlein)
                    .accessibilityIdentifier("delegation.\(delegation.id).accepter")
            }
            if delegation.peutRevoquer {
                Button(TextesDelegations.revoquer, role: .destructive, action: revoquer)
                    .buttonStyle(.bordered)
                    .tint(palette.danger)
                    .accessibilityIdentifier("delegation.\(delegation.id).revoquer")
            }
            if enCours { ProgressView().padding(.leading, 4) }
        }
        .controlSize(.regular)
        .disabled(enCours)
    }
}
