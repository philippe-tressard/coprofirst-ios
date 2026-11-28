// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI
import UIKit

/// Ce que toute diffusion de l'écran de hall porte, écrit une fois — les affiches
/// (`DiffusionTVView`) comme le Fil en tuiles (`DiffusionDuFilView`, #429) :
///
/// - l'écran reste allumé tant qu'il diffuse (`isIdleTimerDisabled`, rendu en quittant) : une
///   Apple TV en veille ne montrerait rien au hall ;
/// - un clic de la télécommande propose « Désappairer » (#218, lot 5), confirmé, et « À propos »
///   (#320) : rien à l'écran ne l'annonce, l'écran est fait pour être lu, pas manié ;
/// - le serveur ne reconnaît plus le jeton (`retiree`) : l'écran revient à l'appairage.
struct GestesDuHall: ViewModifier {
    let retiree: Bool
    let retire: () -> Void
    @State private var gestes = false
    @State private var aPropos = false

    func body(content: Content) -> some View {
        content
            .focusable()
            .focusEffectDisabled()
            .onTapGesture { gestes = true }
            .confirmationDialog(EcranDeHall.gestesTitre, isPresented: $gestes, titleVisibility: .visible) {
                Button(EcranDeHall.desappairer, role: .destructive, action: retire)
                    .accessibilityIdentifier("hall.desappairer")
                Button(EcranDeHall.aPropos) { aPropos = true }
                    .accessibilityIdentifier("hall.a-propos")
            } message: {
                Text(EcranDeHall.desappairerMessage)
            }
            .modifier(AProposTVPresente(ouvert: $aPropos))
            .onChange(of: retiree) { _, retiree in if retiree { retire() } }
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

extension View {
    func gestesDuHall(retiree: Bool, retire: @escaping () -> Void) -> some View {
        modifier(GestesDuHall(retiree: retiree, retire: retire))
    }
}
