// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La PORTE d'un compte au mot de passe temporaire (#377, coprofirst#3019) : les deux
/// comptes initiaux d'une installation neuve. Tant que le compte servi porte
/// `mot_de_passe_a_changer`, `RacineView` n'ouvre que cet écran — le serveur refuse de
/// toute façon les autres routes (403, `TablesProfil.motifMotDePasseAChanger`). Le
/// formulaire est celui du Profil (`MotDePasseView`) ; la déconnexion reste à un toucher.
struct MotDePasseTemporaireView: View {
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var geste: GesteDeSortie?

    /// Changé, mais le compte n'a pas encore été relu (réseau) : tirer vers le bas le relit.
    static let nonRelu =
        "Votre mot de passe est changé. La résidence n'a pas pu être relue : tirez vers le bas pour l'ouvrir."

    var body: some View {
        NavigationStack {
            MotDePasseView(installation: installation, temporaire: true)
                .actualisable { await parcours.rafraichirProfil() }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Se déconnecter", role: .destructive) { geste = .deconnecter(installation) }
                            .accessibilityIdentifier("residence.deconnecter")
                    }
                }
        }
        .tint(palette.primary)
        .confirmationDeSortie($geste, parcours: parcours)
    }
}
