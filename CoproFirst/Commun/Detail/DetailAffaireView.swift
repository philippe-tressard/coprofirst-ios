// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le détail d'une affaire — et d'une actualité, qui en est une de catégorie
/// Actualité : en-tête, description, pièces jointes, Historique, le fil des messages (pas sur
/// une actualité), et le bandeau de ses gestes (`BandeauAffaire`), selon ce que le
/// serveur ouvre au lecteur.
struct DetailAffaireView: View {
    let id: Int
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette

    var body: some View {
        let service = parcours.service
        let installation = installation
        Chargement(
            charger: { [id] in try await service.affaire(id, dans: installation) },
            contenu: { affaire, recharger in
                ContenuAffaire(affaire: affaire, installation: installation, recharger: recharger)
                    .bandeauAffaire(affaire, installation: installation, recharger: recharger)
            },
            squelette: { ContenuAffaire(affaire: Self.squelette, installation: installation, recharger: {}) }
        )
        .background(palette.bg)
        .navigationBarTitleDisplayMode(.inline)
        // Le bandeau occupe le bas : la barre d'onglets s'efface dès l'arrivée — squelette
        // compris, pour ne pas sauter — et revient au retour, comme Photos ou Fichiers.
        .toolbar(.hidden, for: .tabBar)
    }

    /// La forme d'une affaire, le temps qu'elle arrive.
    static let squelette = DetailAffaire(
        id: 0, numero: "A-0000", titre: "Une affaire de la résidence qui se charge",
        description: String(repeating: "Le détail de l'affaire arrive. ", count: 5), categorie: "",
        statut: "ouvert", urgente: false, creeLe: .now, auteur: "Le conseil syndical", lieu: "Bâtiment",
        suites: [])
}

private struct ContenuAffaire: View {
    let affaire: DetailAffaire
    let installation: Installation
    let recharger: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                EnTeteAffaire(affaire: affaire)
                TexteRiche(html: affaire.description)
                    .font(.body)
                    .foregroundStyle(palette.text)
                    .tint(palette.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                PiecesJointesView(pieces: affaire.pieces, installation: installation)
                Historique(suites: affaire.suites, installation: installation)
                // Pas de messages sur une actualité : elle informe, on n'y répond pas.
                if !affaire.estActualite {
                    FilMessagesAffaire(messages: affaire.messages, installation: installation)
                }
            }
            .padding(Mise.marge)
        }
        .background(palette.bg)
        .navigationTitle(affaire.numero)
        .refreshable { recharger() }
    }
}

private struct EnTeteAffaire: View {
    let affaire: DetailAffaire
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(affaire.estActualite ? "Actualité" : "Affaire")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(affaire.estActualite ? palette.primary : palette.filRouge)
                if affaire.urgente {
                    Label("Urgente", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.danger)
                }
                if affaire.epingle {
                    Image(systemName: "pin.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.primary)
                        .accessibilityLabel(OptionAffaire.toutes.first { $0.cle == "epingle" }?.etat ?? "")
                }
                if affaire.archivee {
                    Label("Archivée", systemImage: "archivebox")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.textMuted)
                }
                Spacer(minLength: 0)
                PastilleStatut(statut: affaire.statut)
            }
            Text(affaire.titre)
                .font(.titre(.title))
                .foregroundStyle(palette.text)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 4) {
                if let lieu = affaire.lieu {
                    Label(lieu, systemImage: "mappin")
                }
                Label {
                    Text(affaire.creeLe, format: .dateTime.day().month(.wide).year().hour().minute())
                } icon: {
                    Image(systemName: "calendar")
                }
                if let auteur = affaire.auteur {
                    Label(auteur, systemImage: "person")
                }
            }
            .font(.subheadline)
            .foregroundStyle(palette.textMuted)
        }
        .padding(.leading, affaire.urgente ? 12 : 0)
        .overlay(alignment: .leading) {
            if affaire.urgente { palette.danger.frame(width: 4).clipShape(.capsule) }
        }
    }
}

/// L'Historique, dans l'ordre : ce qui a été écrit, et ce qui a changé d'état.
private struct Historique: View {
    let suites: [SuiteAffaire]
    let installation: Installation
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Historique")
                .styleLibelle()
                .accessibilityAddTraits(.isHeader)
            if suites.isEmpty {
                Text("Aucune suite pour l'instant.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textMuted)
            }
            ForEach(suites) { suite in
                Carte {
                    VStack(alignment: .leading, spacing: 10) {
                        EntreeHistorique(suite: suite)
                        // Hors de l'élément lu d'un trait : chaque pièce s'ouvre à part.
                        PiecesJointesView(pieces: suite.pieces, installation: installation, format: .compact)
                    }
                }
            }
        }
    }
}

/// Ce qu'une suite dit : son auteur, sa date, le changement d'état, son texte — lu d'un trait.
private struct EntreeHistorique: View {
    let suite: SuiteAffaire
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(suite.auteur ?? "La résidence")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.text)
                Spacer(minLength: 8)
                Text(suite.date, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(palette.textMuted)
            }
            if let changement = suite.changementDEtat {
                Label(changement, systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(palette.primary)
            }
            if let contenu = suite.contenu.map(TexteRiche.init(html:)), !contenu.vide {
                contenu
                    .font(.body)
                    .foregroundStyle(palette.text)
                    .tint(palette.primary)
                    .textSelection(.enabled)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
