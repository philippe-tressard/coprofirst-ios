// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'appairage à l'écran (#218, lot 3) : le nom de la résidence, le code en très grand, lettre
/// à lettre, et où le saisir ; l'heure jusqu'à laquelle il vaut. Échu : « Afficher un nouveau
/// code ». Le conseil le confirme dans l'app ou sur le site (#295) ; l'écran diffuse aussitôt.
struct AppairageTVView: View {
    @State private var appairage: AppairageTV
    @State private var essai = 0
    let appaire: (String) -> Void
    let changer: () -> Void
    @Environment(\.palette) private var palette

    init(
        residence: Installation, service: any ServiceEcranTV, appaire: @escaping (String) -> Void,
        changer: @escaping () -> Void
    ) {
        _appairage = State(initialValue: AppairageTV(residence: residence, service: service))
        self.appaire = appaire
        self.changer = changer
    }

    var body: some View {
        VStack(spacing: Mise.marge) {
            EnTeteHall(titre: appairage.residence.nom, phrase: EcranDeHall.appairage)
            etat
                .frame(minHeight: MiseTV.placeCode)
            HStack(spacing: Mise.marge) {
                if appairage.etat == .expire || estEchec {
                    Button(EcranDeHall.nouveauCode) { essai += 1 }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("hall.nouveau-code")
                }
                Button(EcranDeHall.changer, action: changer)
                    .accessibilityIdentifier("hall.changer")
            }
        }
        .animation(.snappy, value: appairage.etat)
        .task(id: essai) {
            if let jeton = await appairage.suivre() { appaire(jeton) }
        }
    }

    private var estEchec: Bool {
        if case .echec = appairage.etat { true } else { false }
    }

    @ViewBuilder
    private var etat: some View {
        switch appairage.etat {
        case .demande:
            VStack(spacing: MiseTV.ecart) {
                ProgressView()
                Text(EcranDeHall.demande).font(.headline).foregroundStyle(palette.textMuted)
            }
        case .code(let code, let expireLe):
            VStack(spacing: MiseTV.ecart) {
                Text(code)
                    .font(.system(size: MiseTV.code, weight: .semibold, design: .monospaced))
                    .tracking(MiseTV.approcheCode)
                    .foregroundStyle(palette.text)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    // Lu lettre à lettre : « B, C, D, F… », pas un mot.
                    .accessibilityLabel(code.map(String.init).joined(separator: " "))
                    .accessibilityIdentifier("hall.code")
                Text(EcranDeHall.valable(jusqua: FormatsDuSite.heure(expireLe)))
                    .font(.headline)
                    .foregroundStyle(palette.textMuted)
            }
            .transition(.opacity)
        case .expire:
            Text(EcranDeHall.expire)
                .font(.title2)
                .foregroundStyle(palette.textMuted)
                .accessibilityIdentifier("hall.expire")
        case .echec(let erreur):
            Text(erreur.phrase)
                .font(.headline)
                .foregroundStyle(palette.danger)
                .multilineTextAlignment(.center)
                .frame(maxWidth: MiseTV.mesure)
                .accessibilityIdentifier("hall.erreur")
        }
    }
}
