// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le fil des MESSAGES d'une affaire, sous l'Historique — `FilMessagesTicket.svelte`.
///
/// ⚠️ Ce n'est pas l'Historique : celui-ci porte les évolutions du dossier, ce fil les
/// messages échangés (« Répondre »). Deux tables, deux fils — le site les sépare exprès.
/// Jamais sur une actualité : `DetailAffaireView` ne le pose pas.
///
/// Écarts déclarés avec le site (`standards/11` §14) :
/// - un intitulé « Messages » le sépare de l'Historique, qui a le sien ; le site n'en
///   met pas, son fil suit la carte ;
/// - l'auteur : la bulle dit « Vous » pour le compte (`est_auteur` servi, contrat
///   1.26.0, #138), le nom servi sinon (`auteur_nom`) ; sans nom servi, la qualité servie
///   (`auteur_qualite`).
///
/// Son propre message se modifie et se retire tant que l'affaire n'est pas close (#211,
/// `GesteMessage`) : le « ⋯ » de sa bulle ; l'écran présente la feuille et la question
/// (`gestesHistorique`).
struct FilMessagesAffaire: View {
    let affaire: DetailAffaire
    let installation: Installation

    var body: some View {
        let messages = affaire.messages
        if !messages.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Messages")
                    .styleLibelle()
                    .accessibilityAddTraits(.isHeader)
                ForEach(messages) { message in
                    BulleMessage(
                        message: message, installation: installation,
                        gestes: GesteMessage.offerts(pour: message, dans: affaire))
                }
            }
        }
    }
}

/// Une bulle : à droite et teintée pour le compte (`deMoi`, servi), à gauche pour les
/// autres ; une note interne, en jaune, porte sa pastille.
private struct BulleMessage: View {
    let message: MessageAffaire
    let installation: Installation
    let gestes: [GesteMessage]
    /// Hors d'un écran qui les présente (le squelette, un aperçu) : aucun geste.
    @Environment(ChoixDeSuite.self) private var choix: ChoixDeSuite?
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            if message.deMoi { Spacer(minLength: 32) }
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            if let auteur = message.auteur {
                                Text(auteur)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(palette.text)
                            }
                            if message.interne {
                                PastilleTeinte(libelle: "interne", badge: "badge-yellow", compacte: true)
                            }
                            Spacer(minLength: 8)
                            Text(FormatsDuSite.dateHeure(message.date))
                                .font(.caption)
                                .foregroundStyle(palette.textMuted)
                        }
                        TexteRiche(html: message.contenu)
                            .font(.body)
                            .foregroundStyle(palette.text)
                            .tint(palette.primary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // Le texte se lit d'un trait ; chaque pièce, à part, s'ouvre. Les gestes y sont
                    // aussi des actions d'accessibilité.
                    .accessibilityElement(children: .combine)
                    .accessibilityActions {
                        if let choix {
                            ForEach(gestes) { geste in Button(geste.libelle) { choix.choisir(geste, message) } }
                        }
                    }
                    .accessibilityIdentifier("affaire.message.\(message.id)")
                    // Hors du texte lu d'un trait : le « ⋯ » reste un bouton à part (#211).
                    if let choix, !gestes.isEmpty {
                        BoutonDesGestes(
                            gestes: gestes, prefixe: "message", id: message.id, libelleVocal: TextesMessage.gestes
                        ) { choix.choisir($0, message) }
                    }
                }
                PiecesJointesView(pieces: message.pieces, installation: installation, format: .compact)
            }
            .padding(12)
            .background(fond, in: .rect(cornerRadius: Mise.rayon, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Mise.rayon, style: .continuous)
                    .strokeBorder(bordure, lineWidth: 1)
            }
            if !message.deMoi { Spacer(minLength: 32) }
        }
    }

    private var fond: Color {
        message.interne ? palette.jauneFond : message.deMoi ? palette.infoFond : palette.surface
    }

    private var bordure: Color {
        message.interne ? palette.warningBordure : message.deMoi ? palette.infoBordure : palette.border
    }
}
