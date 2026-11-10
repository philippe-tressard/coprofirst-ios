// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le vote, comme le formulaire de la fiche du site : choisir une réponse, la préciser
/// si l'option le demande (`champ_libre`), commenter si l'on veut, s'engager à la charte,
/// puis « Voter ». Le bouton attend que rien ne manque, et dit ce qui manque.
struct FormulaireVote: View {
    let sondage: DetailSondage
    @Binding var vote: VoteSondage
    let envoi: Bool
    let voter: () -> Void
    @Environment(\.palette) private var palette

    private var champLibre: Bool {
        sondage.options.first { $0.id == vote.option }?.champLibre ?? false
    }

    var body: some View {
        Section {
            ForEach(sondage.options) { option in
                LigneChoix(
                    option: option, choisie: vote.option == option.id, resultats: sondage.resultatsVisibles
                ) {
                    withAnimation(.snappy) {
                        // Changer de réponse vide la précision : elle valait pour l'autre (le site).
                        if vote.option != option.id { vote.reponseLibre = "" }
                        vote.option = option.id
                    }
                }
            }
        }
        .listRowBackground(palette.surface)

        if champLibre {
            Section {
                TextField(TextesSondage.preciserInvite, text: $vote.reponseLibre, axis: .vertical)
                    .lineLimit(3...8)
                    .accessibilityLabel(TextesSondage.preciser)
                    .accessibilityIdentifier("sondage.precision")
            } header: {
                EnteteRequis(texte: TextesSondage.preciser, vide: VoteSondage.nettoye(vote.reponseLibre) == nil)
            }
            .listRowBackground(palette.primaryLight)
            .transition(.opacity)
        }

        Section {
            TextField(TextesSondage.commentaireInvite, text: $vote.commentaire, axis: .vertical)
                .lineLimit(3...8)
                .accessibilityLabel(TextesSondage.commentaire)
                .accessibilityIdentifier("sondage.commentaire")
        } header: {
            Text(TextesSondage.commentaire).styleLibelle()
        }
        .listRowBackground(palette.surface)

        Section {
            CaseCharte(acceptee: $vote.charteAcceptee)
        }
        .listRowBackground(palette.warningFond)

        Section {
            VStack(spacing: 10) {
                Button(action: voter) {
                    HStack(spacing: 8) {
                        if envoi { ProgressView().tint(palette.surPlein) }
                        Text(envoi ? TextesSondage.envoi : TextesSondage.voter)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plein)
                .disabled(envoi || manque != nil)
                .accessibilityIdentifier("sondage.voter")
                if let manque, !envoi {
                    Text(manque)
                        .font(.footnote)
                        .foregroundStyle(palette.textMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("sondage.manque")
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 4, trailing: 0))
        }
    }

    private var manque: String? { vote.manque(champLibre: champLibre) }
}

/// Une réponse possible : le rond qui se coche, le libellé, ✏️ si elle demande une
/// précision, et ses votes quand le serveur les montre.
private struct LigneChoix: View {
    let option: OptionSondage
    let choisie: Bool
    let resultats: Bool
    let choisir: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: choisir) {
            HStack(spacing: 12) {
                Image(systemName: choisie ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(choisie ? palette.primary : palette.textMuted)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
                Text(option.libelle).font(.body.weight(.medium)).foregroundStyle(palette.text)
                if option.champLibre {
                    Text("✏️").accessibilityLabel("Cette réponse inclut un champ de précision")
                }
                Spacer(minLength: 8)
                if resultats, let votes = option.nbVotes {
                    Text(TextesSondage.votes(votes))
                        .monospacedDigit()
                        .font(.subheadline)
                        .foregroundStyle(palette.textMuted)
                }
            }
            .frame(minHeight: Mise.cible)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowBackground(choisie ? palette.primaryLight : palette.surface)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(choisie ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("sondage.option.\(option.id)")
        .sensoryFeedback(.selection, trigger: choisie) { _, nouveau in nouveau }
    }
}

/// « Je m'engage à rester respectueux… » : une case, sur le fond d'avertissement du site.
private struct CaseCharte: View {
    @Binding var acceptee: Bool
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var taille

    var body: some View {
        Button {
            withAnimation(.snappy) { acceptee.toggle() }
        } label: {
            // Aux tailles d'accessibilité, la case passe au-dessus du texte : à côté, elle
            // lui prendrait un tiers de la largeur.
            let disposition = taille.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
            disposition {
                Image(systemName: acceptee ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(acceptee ? palette.primary : palette.warningTexte)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
                Text(TextesSondage.charte)
                    .font(.subheadline)
                    .foregroundStyle(palette.warningTexte)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(.rect)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(acceptee ? "Cochée" : "Non cochée")
        .accessibilityIdentifier("sondage.charte")
        .sensoryFeedback(.selection, trigger: acceptee)
    }
}

/// L'en-tête d'un champ requis : l'étoile reste rouge tant que le champ est vide
/// (`EtoileRequis` du site).
private struct EnteteRequis: View {
    let texte: String
    let vide: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 2) {
            Text(texte).styleLibelle()
            Text("*")
                .font(.footnote.weight(.bold))
                .foregroundStyle(vide ? palette.danger : palette.textMuted)
                .accessibilityLabel("requis")
        }
    }
}
