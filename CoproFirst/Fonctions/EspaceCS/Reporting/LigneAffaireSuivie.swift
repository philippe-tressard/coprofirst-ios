// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Une affaire du suivi (`TableauAffaires.svelte`) : son âge teinté par son ancienneté,
/// sa date d'ouverture, son titre et son état, le signal « a évolué », l'aperçu
/// (cinq lignes au plus) et sa catégorie — ou l'état de sa visite, en mode entretien.
/// Toucher la carte ouvre l'affaire.
struct LigneAffaireSuivie: View {
    let affaire: AffaireSuivie
    let entretien: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        Carte {
            VStack(alignment: .leading, spacing: 8) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { tete }
                    VStack(alignment: .leading, spacing: 6) { tete }
                }
                Text(affaire.titre)
                    .font(.headline)
                    .foregroundStyle(palette.text)
                    .multilineTextAlignment(.leading)
                if affaire.aEvolue && !entretien {
                    Label(affaire.evolution, systemImage: "bell.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.orangeTexte)
                }
                if !affaire.apercu.isEmpty { apercu }
                HStack(spacing: 8) {
                    PastilleStatut(statut: affaire.statut)
                    if entretien, let etat = affaire.etatVisite {
                        let visite = TablesReporting.etatsVisite[etat] ?? .brut(etat)
                        PastilleTeinte(libelle: visite.libelle, badge: visite.badge)
                    } else {
                        Text(affaire.libelleCategorie).font(.footnote).foregroundStyle(palette.textMuted)
                    }
                }
            }
        }
        .contentShape(.rect(cornerRadius: Mise.rayon))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("reporting.affaire.\(affaire.id)")
    }

    @ViewBuilder private var tete: some View {
        PastilleTeinte(libelle: TextesReporting.age(affaire.ageJours), badge: affaire.teinteAge)
            .accessibilityLabel(TextesReporting.ageLu(affaire.ageJours))
        Text(FormatsDuSite.date(affaire.ouverteLe))
            .font(.footnote)
            .foregroundStyle(palette.textMuted)
        Text(affaire.numero)
            .font(.footnote.monospaced())
            .foregroundStyle(palette.textMuted)
    }

    /// L'aperçu, marqué ✨ quand il est le résumé de l'assistant (dit à VoiceOver).
    private var apercu: some View {
        let marque = Text(Image(systemName: "sparkles")).foregroundStyle(palette.violet)
        return Text(affaire.apercuIA ? "\(marque) \(affaire.apercu)" : "\(affaire.apercu)")
            .font(.subheadline)
            .foregroundStyle(palette.textMuted)
            .lineLimit(5)
            .accessibilityLabel(
                affaire.apercuIA ? "\(TextesReporting.resumeAssistant) : \(affaire.apercu)" : affaire.apercu)
    }
}
