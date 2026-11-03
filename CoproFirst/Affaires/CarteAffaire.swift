// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Une affaire dans la liste : date, titre, aperçu sur trois lignes, lieu et messages.
/// Une affaire urgente porte un liseré rouge à gauche.
struct CarteAffaire: View {
    @Environment(\.palette) private var palette
    let affaire: Affaire
    @Environment(\.dynamicTypeSize) private var tailleTexte

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Aux tailles d'accessibilité, l'en-tête passe en colonne au lieu de se couper.
            let enTete =
                tailleTexte.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                : AnyLayout(HStackLayout(spacing: 8))
            enTete {
                Text(affaire.creeLe, format: .relative(presentation: .named))
                    .font(.footnote)
                    .foregroundStyle(palette.textMuted)
                if affaire.urgente {
                    Text("Urgente")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.danger)
                }
                if !tailleTexte.isAccessibilitySize { Spacer(minLength: 0) }
                Text(affaire.numero)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(palette.textMuted)
            }
            Text(affaire.titre)
                .font(.headline)
                .foregroundStyle(palette.text)
            Text(TexteDuSite.apercu(affaire.apercu))
                .font(.subheadline)
                .foregroundStyle(palette.textMuted)
                .lineLimit(3)
            if affaire.lieu != nil || affaire.messages != nil {
                HStack(spacing: 16) {
                    if let lieu = affaire.lieu {
                        Label(lieu, systemImage: "mappin")
                    }
                    if let messages = affaire.messages {
                        Label {
                            Text(messages, format: .number).monospacedDigit()
                        } icon: {
                            Image(systemName: "bubble.left.and.bubble.right")
                        }
                    }
                }
                .font(.footnote)
                .foregroundStyle(palette.textMuted)
                .labelStyle(.titleAndIcon)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .padding(.leading, affaire.urgente ? 4 : 0)
        .background(palette.surface)
        .overlay(alignment: .leading) {
            if affaire.urgente {
                palette.danger.frame(width: 4)
            }
        }
        .clipShape(.rect(cornerRadius: Mise.rayon, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Mise.rayon, style: .continuous)
                .strokeBorder(palette.border, lineWidth: 1)
        }
        .contentShape(.rect(cornerRadius: Mise.rayon))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(libelleVocal)
    }

    /// Ce que VoiceOver lit, dans l'ordre utile : l'urgence d'abord.
    private var libelleVocal: Text {
        var morceaux: [String] = []
        if affaire.urgente { morceaux.append("Urgente") }
        morceaux.append(affaire.titre)
        morceaux.append(affaire.creeLe.formatted(.relative(presentation: .named)))
        if let lieu = affaire.lieu { morceaux.append(lieu) }
        if let messages = affaire.messages { morceaux.append("\(messages) messages") }
        morceaux.append(TexteDuSite.apercu(affaire.apercu))
        return Text(morceaux.joined(separator: ", "))
    }
}

/// La même carte, en squelette, pendant le chargement.
struct CarteAffaireSquelette: View {
    var body: some View {
        CarteAffaire(affaire: ServiceSimule.affaires[2])
            .redacted(reason: .placeholder)
            .accessibilityHidden(true)
    }
}
