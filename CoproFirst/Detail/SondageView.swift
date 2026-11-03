// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Un sondage : ses options et le vote s'il est ouvert ; le résultat quand le
/// serveur le rend visible (`resultats_visibles`, sa décision — jamais recomposée).
struct SondageView: View {
    let id: Int
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette

    var body: some View {
        let service = parcours.service
        let installation = installation
        Chargement(
            charger: { [id] in try await service.sondage(id, dans: installation) },
            contenu: { sondage, recharger in
                ContenuSondage(sondage: sondage, installation: installation, recharger: recharger)
            },
            squelette: { ContenuSondage(sondage: Self.squelette, installation: installation, recharger: {}) }
        )
        .background(palette.bg)
        .navigationTitle("Sondage")
        .navigationBarTitleDisplayMode(.inline)
    }

    static let squelette = DetailSondage(
        id: 0, question: "Une question posée à la résidence", description: "Le sondage se charge.",
        options: (1...3).map { OptionSondage(id: $0, libelle: "Une réponse possible", nbVotes: nil) },
        monVote: nil, cloture: false, resultatsVisibles: false)
}

private struct ContenuSondage: View {
    let sondage: DetailSondage
    let installation: Installation
    let recharger: () -> Void
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var enCours: Int?
    @State private var erreur: ErreurService?
    @State private var vote = 0

    private var peutVoter: Bool { !sondage.cloture && sondage.monVote == nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    Text("Sondage").font(.caption.weight(.bold)).foregroundStyle(palette.filViolet)
                    Text(sondage.cloture ? "Clos" : "Ouvert")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.textMuted)
                }
                Text(sondage.question)
                    .font(.titre(.title))
                    .foregroundStyle(palette.text)
                    .accessibilityAddTraits(.isHeader)
                if let description = sondage.description, !description.isEmpty {
                    Text(description).font(.body).foregroundStyle(palette.textMuted)
                }
                VStack(spacing: 10) {
                    ForEach(sondage.options) { option in
                        LigneOption(
                            option: option, total: sondage.totalVotes, choisie: sondage.monVote == option.id,
                            resultats: sondage.resultatsVisibles, peutVoter: peutVoter, enCours: enCours == option.id
                        ) {
                            Task { await voter(option) }
                        }
                    }
                }
                if let erreur { MessageErreur(texte: erreur.phrase) }
                if !sondage.resultatsVisibles, !peutVoter {
                    Text("Les résultats seront visibles à la clôture du sondage.")
                        .font(.footnote)
                        .foregroundStyle(palette.textMuted)
                }
            }
            .padding(Mise.marge)
        }
        .sensoryFeedback(.success, trigger: vote)
    }

    private func voter(_ option: OptionSondage) async {
        enCours = option.id
        defer { enCours = nil }
        do {
            try await parcours.service.voter(option.id, au: sondage.id, dans: installation)
            vote += 1
            recharger()
        } catch {
            withAnimation(.snappy) { erreur = ErreurService.depuis(error) }
        }
    }
}

private struct LigneOption: View {
    let option: OptionSondage
    let total: Int
    let choisie: Bool
    let resultats: Bool
    let peutVoter: Bool
    let enCours: Bool
    let voter: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: voter) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: choisie ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(choisie ? palette.primary : palette.textMuted)
                    Text(option.libelle).font(.body.weight(.medium)).foregroundStyle(palette.text)
                    Spacer(minLength: 8)
                    if enCours {
                        ProgressView()
                    } else if resultats, let votes = option.nbVotes {
                        Text(votes, format: .number).monospacedDigit().font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.textMuted)
                    }
                }
                if resultats, let votes = option.nbVotes, total > 0 {
                    ProgressView(value: Double(votes), total: Double(total))
                        .tint(choisie ? palette.primary : palette.filViolet)
                }
            }
            .padding(14)
            .frame(minHeight: Mise.cible)
            .background(palette.surface, in: .rect(cornerRadius: Mise.rayon, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Mise.rayon, style: .continuous)
                    .strokeBorder(choisie ? palette.primary : palette.border, lineWidth: choisie ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!peutVoter)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(choisie ? .isSelected : [])
        .accessibilityHint(peutVoter ? "Voter pour cette réponse" : "")
    }
}
