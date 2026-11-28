// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'écran de hall : l'entrée tant qu'aucune résidence n'est reconnue, l'appairage, puis la
/// diffusion — à la palette de SA résidence (`site_palette`), comme `RacineView` sur l'iPhone.
struct EcranDeHallView: View {
    let hall: HallTV
    @Environment(\.reglagesDuHall) private var reglages

    var body: some View {
        let palette = hall.residence?.palette ?? Palette.pour(code: nil)
        Group {
            switch hall.etape {
            case .entree:
                EntreeTVView(entree: hall.entree)
                    .padding(Mise.marge)
            case .appairage(let residence):
                AppairageTVView(residence: residence, service: hall.service) { jeton in
                    hall.appairer(residence, jeton: jeton)
                } changer: {
                    withAnimation(.snappy) { hall.entree.changer() }
                }
                .padding(Mise.marge)
                .id(residence.adresse)
            case .diffusion(let appairage):
                // Le Fil quand le service le sert (#429) ; les affiches sinon.
                if let fil = hall.service.filDuHall {
                    DiffusionDuFilView(appairage: appairage, service: fil, reglages: reglages) { hall.retirer() }
                        .id(appairage.jeton)
                } else {
                    DiffusionTVView(appairage: appairage, service: hall.service) { hall.retirer() }
                        .id(appairage.jeton)
                }
            }
        }
        .transition(.opacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bg)
        .tint(palette.primary)
        .environment(\.palette, palette)
        .animation(.smooth(duration: 0.4), value: palette.code)
        .animation(.snappy, value: hall.etape)
    }
}

/// L'en-tête de l'entrée et de l'appairage : le nom, puis ce qu'est l'écran.
/// Lu de loin (trois mètres et plus) : les styles de texte de tvOS, déjà à cette échelle.
struct EnTeteHall: View {
    let titre: String
    let phrase: String
    @Environment(\.palette) private var palette

    var body: some View {
        Text(titre)
            .font(.titre(.largeTitle))
            .foregroundStyle(palette.text)
            .multilineTextAlignment(.center)
            .accessibilityIdentifier("hall.titre")
        Text(EcranDeHall.sousTitre)
            .styleLibelle()
        Text(phrase)
            .font(.title3)
            .foregroundStyle(palette.textMuted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: MiseTV.mesure)
            .accessibilityIdentifier("hall.phrase")
    }
}

/// L'adresse saisie, ou la démo. Le champ ouvre le clavier de tvOS — et celui de l'iPhone
/// à proximité, que le système propose seul.
struct EntreeTVView: View {
    @Bindable var entree: EntreeTV
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: Mise.marge) {
            EnTeteHall(titre: EcranDeHall.titre, phrase: EcranDeHall.invitation)
            TextField(EcranDeHall.exempleAdresse, text: $entree.saisie)
                .keyboardType(.URL)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit { Task { await entree.entrer() } }
                .frame(maxWidth: MiseTV.mesure)
                .accessibilityLabel(EcranDeHall.libelleAdresse)
                .accessibilityIdentifier("hall.adresse")
            if let erreur = entree.decouverte.erreur {
                Text(erreur.phrase)
                    .font(.headline)
                    .foregroundStyle(palette.danger)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: MiseTV.mesure)
                    .accessibilityIdentifier("hall.erreur")
            }
            HStack(spacing: Mise.marge) {
                Button(EcranDeHall.continuer) { Task { await entree.entrer() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(entree.adresseSaisie == nil || entree.decouverte.enCours)
                    .accessibilityIdentifier("hall.continuer")
                Button(ContenuVitrine.essayerDemo) { Task { await entree.entrerEnDemo() } }
                    .disabled(entree.decouverte.enCours)
                    .accessibilityIdentifier("hall.demo")
                BoutonAProposTV()
            }
            ProgressView()
                .opacity(entree.decouverte.enCours ? 1 : 0)
                .accessibilityHidden(!entree.decouverte.enCours)
        }
    }
}
