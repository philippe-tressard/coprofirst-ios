// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les gestes de rôle d'un compte (#89) — « + CS », « – Admin », « + Opérateur » :
/// EXACTEMENT ceux que le serveur sert (`gestes_roles`), dans son ordre, jamais un de
/// plus (`GestesRolesCompte.svelte`). La teinte est celle du site : le conseil en
/// information, l'administration en orange, l'opérateur en violet, un retrait en danger.
///
/// Le geste lui-même — la confirmation, puis l'appel — reste à la fiche (`demander`).
struct GestesRolesCompte: View {
    let gestes: [GesteDeRole]
    let demander: (GesteDeRole) -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Section(TextesUtilisateursAdmin.gestesRoles) {
            ForEach(gestes) { offert in
                Button { demander(offert) } label: {
                    Label(
                        TextesUtilisateursAdmin.bouton(offert),
                        systemImage: offert.geste == .ajouter ? "plus.circle" : "minus.circle")
                }
                .tint(teinte(offert))
                .accessibilityLabel(TextesUtilisateursAdmin.actionRole(offert))
                .accessibilityIdentifier("admin.fiche.role.\(offert.role)")
            }
        }
    }

    private func teinte(_ offert: GesteDeRole) -> Color {
        guard offert.geste == .ajouter else { return palette.danger }
        switch offert.role {
        case "admin": return palette.orange
        case "operateur": return palette.violet
        default: return palette.info
        }
    }
}
