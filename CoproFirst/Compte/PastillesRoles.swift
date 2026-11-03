// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les rôles de l'utilisateur dans une résidence, en pastilles sobres — dans l'ordre
/// de l'en-tête du site (`ProfilResidence.rolesAffiches`).
struct PastillesRoles: View {
    let profil: ProfilResidence?
    @Environment(\.palette) private var palette

    var body: some View {
        if let roles = profil?.rolesAffiches, !roles.isEmpty {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) { pastilles(roles) }
                VStack(alignment: .leading, spacing: 6) { pastilles(roles) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Rôles : \(roles.joined(separator: ", "))"))
        }
    }

    private func pastilles(_ roles: [String]) -> some View {
        ForEach(roles, id: \.self) { role in
            Text(role)
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(palette.primaryLight, in: .capsule)
        }
    }
}
