// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « Saisie d'une affaire », Essentielle ou Complète (#69) — entre la sécurité et le
/// thème, comme le Profil du site (`ChoixSaisieAffaire.svelte`).
///
/// Le choix vit sur le COMPTE, pour tous les appareils — au contraire du thème : la
/// saisie ne doit pas différer entre le téléphone et l'ordinateur. Il s'applique
/// sur-le-champ : la pastille change d'abord, puis la requête part ; un refus la remet
/// où elle était. Ce qui est coché est ce que le serveur sert (`saisie_affaire_effective`),
/// jamais un défaut déduit ici. Un serveur qui ne le sert pas : la section se tait.
struct SectionSaisieAffaire: View {
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    /// Le choix en cours d'envoi ; `nil` : celui que le serveur sert.
    @State private var demande: String?
    @State private var refus: String?

    private var servi: String? { parcours.ouverteAJour?.profil?.saisieAffaire }
    private var coche: String? { demande ?? servi }

    var body: some View {
        if let coche {
            Section {
                // Une fermeture, pas la référence `set: choisir` : Swift 6.3.3 (Xcode 26.6, la
                // CI) plantait en IRGen sur le thunk `@isolated(any) @Sendable` qu'elle exige.
                Picker("Saisie d'une affaire", selection: Binding(get: { coche }, set: { choisir($0) })) {
                    ForEach(TablesSaisie.options, id: \.code) { option in
                        Text(option.libelle).tag(option.code).accessibilityHint(option.detail)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .gesteEnLigne()
                .listRowBackground(palette.surface)
                .accessibilityIdentifier("profil.saisie")
            } header: {
                Text("Saisie d'une affaire").styleLibelle()
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if let detail = TablesSaisie.options.first(where: { $0.code == coche })?.detail {
                        Text("""
                            \(detail). En saisie essentielle, les autres sections se rangent dans « Plus de \
                            détails », avec leur valeur par défaut. Ce choix vaut pour votre compte, sur tous vos \
                            appareils.
                            """)
                    }
                    if let refus {
                        Text(refus).foregroundStyle(palette.danger).transition(.opacity)
                    }
                }
                .contentTransition(.opacity)
            }
            .sensoryFeedback(.selection, trigger: coche)
        }
    }

    private func choisir(_ mode: String) {
        guard mode != coche else { return }
        withAnimation(.snappy) {
            demande = mode
            refus = nil
        }
        Task {
            do {
                try await parcours.serviceProfil.choisirSaisie(mode, dans: installation)
                // Le mode effectif, recalculé par le serveur, devient celui du profil.
                await parcours.rafraichirProfil()
            } catch {
                let phrase = ErreurService.phrase(error, sinon: "Le réglage de la saisie n'a pas pu être enregistré")
                withAnimation(.snappy) { refus = phrase }
            }
            withAnimation(.snappy) { demande = nil }
        }
    }
}
