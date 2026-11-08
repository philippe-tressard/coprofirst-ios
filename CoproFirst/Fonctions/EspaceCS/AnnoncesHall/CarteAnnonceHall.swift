// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Ce qu'on peut faire d'une affiche, depuis sa carte.
enum GesteAnnonceHall: Hashable { case renvoyer, archiver, supprimer }

/// Une affiche (`HistoriqueAnnoncesHall.svelte`) : QUAND, puis CE QUI LA CLASSE — son
/// format —, son titre et son aperçu ; dépliée, son message et ses envois. Ses gestes
/// passent par le menu « … » : renvoyer au CS, archiver ou restaurer, supprimer.
struct CarteAnnonceHall: View {
    let annonce: AnnonceHall
    let geste: (GesteAnnonceHall) -> Void
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit
    @State private var ouverte = false

    var body: some View {
        Carte {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(FormatsDuSite.date(annonce.creeLe))
                        .font(.footnote)
                        .foregroundStyle(palette.textMuted)
                    PastilleTeinte(libelle: annonce.formatLabel, badge: "badge-blue", compacte: true)
                        .accessibilityLabel("Format \(annonce.formatLabel)")
                    Spacer(minLength: 0)
                    menu
                }
                Button {
                    withAnimation(mouvementReduit ? nil : .snappy) { ouverte.toggle() }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(annonce.titre)
                            .font(.headline)
                            .foregroundStyle(palette.text)
                            .multilineTextAlignment(.leading)
                        if !ouverte {
                            Text(annonce.apercu)
                                .font(.subheadline)
                                .foregroundStyle(palette.textMuted)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityHint(ouverte ? "Replie l'annonce" : "Montre le message et ses envois")
                .accessibilityIdentifier("annonce-hall.\(annonce.id)")
                if ouverte { corps.transition(.opacity.combined(with: .move(edge: .top))) }
                marqueurs
            }
        }
        .sensoryFeedback(.selection, trigger: ouverte)
    }

    private var corps: some View {
        VStack(alignment: .leading, spacing: 8) {
            TexteRiche(html: annonce.message)
                .font(.body)
                .foregroundStyle(palette.text)
                .tint(palette.primary)
            if !annonce.destinataires.isEmpty {
                Text(TextesAnnoncesHall.envoi(annonce))
                    .font(.footnote)
                    .foregroundStyle(palette.textMuted)
            }
        }
    }

    /// La dernière ligne, dans l'ordre du site : état, périmètre, provenance, envoi, auteur.
    private var marqueurs: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { pastilles }
            VStack(alignment: .leading, spacing: 6) { pastilles }
        }
    }

    @ViewBuilder private var pastilles: some View {
        if annonce.archivee {
            PastilleTeinte(libelle: TextesAnnoncesHall.archivee, badge: "badge-gray", compacte: true)
        }
        PastilleTeinte(libelle: annonce.perimetreLabel, badge: "badge-gray", compacte: true)
        if annonce.ticketId != nil {
            PastilleTeinte(libelle: TextesAnnoncesHall.actualite, badge: "badge-gray", compacte: true)
        }
        if annonce.destinataires.isEmpty {
            PastilleTeinte(libelle: TextesAnnoncesHall.nonEnvoyee, badge: "badge-orange", compacte: true)
        } else {
            PastilleTeinte(
                libelle: TextesAnnoncesHall.destinataires(annonce.destinataires.count), badge: "badge-gray",
                compacte: true)
        }
        Text(annonce.auteurNom).font(.caption).foregroundStyle(palette.textMuted)
        if annonce.assisteIa == true {
            Image(systemName: "sparkles").font(.caption).foregroundStyle(palette.violet)
                .accessibilityLabel("Rédigée avec l'assistant")
        }
    }

    private var menu: some View {
        Menu {
            Button(TextesAnnoncesHall.renvoyer, systemImage: "envelope") { geste(.renvoyer) }
            // Les gestes que le serveur ouvre (#56) : restaurer, seulement une affiche
            // rangée à la main ; supprimer, l'administrateur.
            if annonce.peutArchiver || annonce.peutRestaurer {
                Button(
                    annonce.archivee ? TextesAnnoncesHall.restaurer : TextesAnnoncesHall.archiver,
                    systemImage: annonce.archivee ? "arrow.uturn.backward" : "archivebox"
                ) { geste(.archiver) }
            }
            if annonce.peutSupprimer {
                Button(TextesAnnoncesHall.supprimer, systemImage: "trash", role: .destructive) { geste(.supprimer) }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .foregroundStyle(palette.primary)
                .frame(minWidth: Mise.cible, minHeight: Mise.cible)
        }
        .accessibilityLabel(TextesAnnoncesHall.gestes)
        .accessibilityIdentifier("annonce-hall.\(annonce.id).gestes")
    }
}
