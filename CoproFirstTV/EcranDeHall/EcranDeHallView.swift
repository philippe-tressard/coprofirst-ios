// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'écran de hall : l'entrée tant qu'aucune résidence n'est reconnue, puis la résidence,
/// à SA palette (`site_palette`), comme `RacineView` sur l'iPhone.
struct EcranDeHallView: View {
    @State private var entree: EntreeTV

    init(entree: EntreeTV = EntreeTV()) {
        _entree = State(initialValue: entree)
    }

    var body: some View {
        let palette = entree.residence?.palette ?? Palette.pour(code: nil)
        Group {
            if let residence = entree.residence {
                AttenteAppairageView(residence: residence) { withAnimation(.snappy) { entree.changer() } }
                    .transition(.opacity)
            } else {
                EntreeTVView(entree: entree)
                    .transition(.opacity)
            }
        }
        .padding(Mise.marge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bg)
        .tint(palette.primary)
        .environment(\.palette, palette)
        .animation(.smooth(duration: 0.4), value: palette.code)
        .animation(.snappy, value: entree.residence)
    }
}

/// L'en-tête commun aux deux états : le nom, puis ce qu'est l'écran.
/// Lu de loin (trois mètres et plus) : les styles de texte de tvOS, déjà à cette échelle.
private struct EnTeteHall: View {
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
            }
            ProgressView()
                .opacity(entree.decouverte.enCours ? 1 : 0)
                .accessibilityHidden(!entree.decouverte.enCours)
        }
    }
}

/// La résidence reconnue, à sa palette, en attendant l'appairage (lot 3, #218).
struct AttenteAppairageView: View {
    let residence: Installation
    let changer: () -> Void

    var body: some View {
        VStack(spacing: Mise.marge) {
            EnTeteHall(titre: residence.nom, phrase: EcranDeHall.attente)
            Button(EcranDeHall.changer, action: changer)
                .accessibilityIdentifier("hall.changer")
        }
    }
}
