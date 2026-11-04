// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'onglet « Courriels affaires » de l'Espace CS (`OngletCourriels.svelte`, #15) : ce
/// que la relève a fait de chaque message reçu à l'adresse des affaires, et pourquoi —
/// une pliure par message, du plus récent au plus ancien.
struct OngletCourriels: View {
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette

    var body: some View {
        if let service = parcours.serviceCourriels {
            let installation = installation
            VStack(alignment: .leading, spacing: 16) {
                Chargement(
                    charger: { try await service.journalCourriels(installation) },
                    contenu: { journal, recharger in
                        JournalView(journal: journal, installation: installation, recharger: recharger)
                    },
                    squelette: { JournalView(journal: Self.squelette, installation: installation, recharger: {}) }
                )
            }
        } else {
            MessageErreur(texte: ErreurService.inattendue(501).phrase)
        }
    }

    private static let squelette = JournalCourriels(
        limite: 50,
        messages: (0..<4).map {
            CourrielReleve(
                id: -$0 - 1, releveLe: .now, envoyeLe: nil, expediteur: "Un expéditeur",
                objet: "L'objet d'un message relevé", decision: "ignore", motif: "", ticketId: nil, affaire: nil)
        })
}

private struct JournalView: View {
    let journal: JournalCourriels
    let installation: Installation
    let recharger: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(TextesCourriels.aide(journal.limite))
                    .font(.footnote)
                    .foregroundStyle(palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button(action: recharger) {
                    Label(TextesCourriels.rafraichir, systemImage: "arrow.clockwise").labelStyle(.iconOnly)
                }
                .frame(minWidth: Mise.cible, minHeight: Mise.cible)
                .tint(palette.primary)
                .accessibilityIdentifier("courriels.rafraichir")
            }
            if journal.messages.isEmpty {
                ContentUnavailableView(TextesCourriels.aucun, systemImage: "tray")
                    .accessibilityIdentifier("courriels.vide")
            } else {
                Carte {
                    VStack(spacing: 0) {
                        ForEach(journal.messages) { message in
                            LigneCourriel(message: message, installation: installation)
                            if message.id != journal.messages.last?.id { Divider().overlay(palette.border) }
                        }
                    }
                }
            }
        }
    }
}

/// Un message : son objet, son verdict et sa date ; dépliée, l'expéditeur, le motif et
/// l'affaire rejointe.
private struct LigneCourriel: View {
    let message: CourrielReleve
    let installation: Installation
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit
    @State private var ouvert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(mouvementReduit ? nil : .snappy) { ouvert.toggle() }
            } label: {
                tete
            }
            .buttonStyle(.plain)
            .accessibilityHint(ouvert ? TextesCourriels.replier : TextesCourriels.deplier)
            .accessibilityIdentifier("courriel.\(message.id)")
            if ouvert {
                corps.transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 10)
        .sensoryFeedback(.selection, trigger: ouvert)
    }

    private var tete: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(message.objet.isEmpty ? TextesCourriels.sansObjet : message.objet)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.text)
                    .multilineTextAlignment(.leading)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { verdictEtDate }
                    VStack(alignment: .leading, spacing: 4) { verdictEtDate }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.textMuted)
                .rotationEffect(.degrees(ouvert ? 90 : 0))
                .accessibilityHidden(true)
        }
        .contentShape(.rect)
    }

    @ViewBuilder private var verdictEtDate: some View {
        PastilleTeinte(libelle: message.verdict.libelle, badge: message.verdict.badge, compacte: true)
        Text(FormatsDuSite.dateHeureCourte(message.releveLe))
            .font(.caption)
            .foregroundStyle(palette.textMuted)
            .monospacedDigit()
    }

    private var corps: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(TextesCourriels.sousTitre(message))
                .font(.footnote)
                .foregroundStyle(palette.textMuted)
            if !message.motif.isEmpty {
                Text(message.motif).font(.subheadline).foregroundStyle(palette.text)
            }
            if let ticket = message.ticketId {
                NavigationLink {
                    DetailAffaireView(id: ticket, installation: installation)
                } label: {
                    Label(TextesCourriels.affaire(message.affaire), systemImage: "arrow.up.right.square")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.primary)
                }
                .frame(minHeight: Mise.cible)
                .accessibilityIdentifier("courriel.\(message.id).affaire")
            }
        }
    }

}
