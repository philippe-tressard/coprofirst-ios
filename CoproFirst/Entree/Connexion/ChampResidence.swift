// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « VOTRE RÉSIDENCE » : l'adresse du site, une coche verte une fois reconnue (GET
/// /config), l'icône du QR code DANS le champ. Aucun annuaire.
struct ChampResidence: View {
    @Binding var saisie: String
    let reconnue: Installation?
    let enCours: Bool
    let erreur: ErreurService?
    let scanner: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ChampSaisie(
                libelle: "Votre résidence",
                champ: {
                    HStack(spacing: 10) {
                        TextField("residence.exemple.fr", text: $saisie)
                            .keyboardType(.URL)
                            .textContentType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.next)
                            .accessibilityIdentifier("connexion.residence")
                        etat
                        Button(action: scanner) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.title3)
                                .foregroundStyle(palette.primary)
                                .frame(width: Mise.cible, height: Mise.cible)
                        }
                        .accessibilityLabel("Scanner le QR code de la fiche d'arrivée")
                    }
                }, enErreur: erreur != nil)
            if let reconnue {
                HStack(spacing: 8) {
                    LogoResidence(installation: reconnue).frame(width: 20, height: 20)
                    Text(reconnue.nom)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.text)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("Résidence reconnue : \(reconnue.nom)"))
            } else if let erreur {
                MessageErreur(texte: erreur.phrase)
            }
        }
    }

    @ViewBuilder
    private var etat: some View {
        if enCours {
            ProgressView().tint(palette.primary)
        } else if reconnue != nil {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(palette.success)
                .symbolEffect(.bounce, value: reconnue?.id)
                .accessibilityLabel("Reconnue")
        }
    }
}
