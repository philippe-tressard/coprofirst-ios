// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les résultats d'un sondage (`ResultatsSondage.svelte`) : une barre par réponse, son
/// pourcentage et ses votes, « Mon vote ✓ », et sous chaque option à préciser les
/// réponses libres des votants. Masqués, ils ne sont pas des barres vides : le serveur
/// n'envoie pas les décomptes, et « 0 vote » se lirait « personne n'a voté ».
struct ResultatsSondage: View {
    let sondage: DetailSondage
    @Environment(\.palette) private var palette

    var body: some View {
        Section {
            if sondage.resultatsVisibles {
                ForEach(sondage.options) { option in
                    LigneResultat(option: option, total: sondage.totalVotes, mienne: option.id == sondage.monVote)
                }
            } else {
                Text(TextesSondage.resultatsMasques)
                    .font(.subheadline)
                    .foregroundStyle(palette.textMuted)
                    .accessibilityIdentifier("sondage.resultatsMasques")
                if let mienne = sondage.options.first(where: { $0.id == sondage.monVote }) {
                    HStack(spacing: 8) {
                        Text(mienne.libelle).font(.body.weight(.medium)).foregroundStyle(palette.text)
                        PastilleTeinte(libelle: TextesSondage.monVote, badge: "badge-blue")
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .listRowBackground(palette.surface)
    }
}

/// Une réponse : libellé, ✏️, « Mon vote ✓ », la barre, le pourcentage et les votes ;
/// puis ses réponses libres, entre guillemets.
private struct LigneResultat: View {
    let option: OptionSondage
    let total: Int
    let mienne: Bool
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit
    @Environment(\.dynamicTypeSize) private var taille
    @State private var deploye = false

    private var votes: Int { option.nbVotes ?? 0 }
    private var pourcentage: Int { TextesSondage.pourcentage(votes, sur: total) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FlowEtiquettes(espace: 8) {
                Text(option.libelle).font(.body.weight(.medium)).foregroundStyle(palette.text)
                if option.champLibre { Text("✏️").accessibilityLabel("Champ de précision") }
                if mienne { PastilleTeinte(libelle: TextesSondage.monVote, badge: "badge-blue") }
            }
            let chiffres = Group {
                Text("\(pourcentage) %").font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                Text(FormatsDuSite.nombre(votes)).font(.subheadline).foregroundStyle(palette.textMuted)
            }
            .monospacedDigit()
            if taille.isAccessibilitySize {
                barre
                HStack(spacing: 12) { chiffres }
            } else {
                HStack(spacing: 12) {
                    barre
                    chiffres
                }
            }
            if option.champLibre, !option.reponsesLibres.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(option.reponsesLibres.enumerated()), id: \.offset) { _, reponse in
                        Text("« \(reponse) »")
                            .font(.subheadline.italic())
                            .foregroundStyle(palette.textMuted)
                            .padding(.leading, 12)
                            .overlay(alignment: .leading) {
                                Capsule().fill(palette.border).frame(width: 3)
                            }
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("sondage.resultat.\(option.id)")
        .onAppear {
            // Les barres se remplissent une fois, à l'arrivée des résultats.
            if mouvementReduit { deploye = true } else { withAnimation(.smooth(duration: 0.6)) { deploye = true } }
        }
    }

    private var barre: some View {
        Capsule()
            .fill(palette.border.opacity(0.5))
            .frame(height: 8)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(mienne ? palette.primary : palette.filViolet)
                    .scaleEffect(x: deploye ? CGFloat(pourcentage) / 100 : 0, anchor: .leading)
            }
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }
}
