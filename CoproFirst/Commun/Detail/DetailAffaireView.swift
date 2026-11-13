// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le détail d'une affaire — et d'une actualité, qui en est une de catégorie
/// Actualité : en-tête, le fil de l'affaire (la demande, la suite, les comptes rendus, la
/// synthèse — `FilAffaire`), le fil des messages (pas sur
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
                    .gestesHistorique(affaire, installation: installation, recharger: recharger)
            },
            squelette: { ContenuAffaire(affaire: Self.squelette, installation: installation, recharger: {}) }
        )
        .background(palette.bg)
        .navigationBarTitleDisplayMode(.inline)
        // Hors ligne : d'où vient ce qu'on lit, et pourquoi le bandeau du bas est grisé (#101).
        .safeAreaInset(edge: .top, spacing: 0) { BandeauHorsLigne() }
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
                // La demande, la suite, les comptes rendus, la synthèse : le fil (#178).
                FilAffaire(affaire: affaire, installation: installation)
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
                if let etat = affaire.etat { PastilleStatut(etat) }
            }
            Text(affaire.titre)
                .font(.titre(.title))
                .foregroundStyle(palette.text)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 4) {
                EtiquetteLieu(lieu: affaire.lieu)
                Label {
                    Text(affaire.creeLe, format: .dateTime.day().month(.wide).year().hour().minute())
                } icon: {
                    Image(systemName: "calendar")
                }
                if let auteur = affaire.auteur {
                    Label(auteur, systemImage: "person")
                }
                // Une ligne par prestataire, le rythme après le dernier (#181).
                if let intervenant = affaire.intervenant {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(affaire.intervenants.enumerated()), id: \.offset) { Text($0.element) }
                        }
                    } icon: {
                        Image(systemName: "wrench.and.screwdriver")
                    }
                    // Un seul élément : sous iOS 26, l'identifiant d'un Label se résout en son image (#183).
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        TextesPrestatairesAffaire.intervenant(intervenant, nombre: affaire.prestataires.count))
                    .accessibilityIdentifier("affaire.intervenant")
                }
            }
            .font(.subheadline)
            .foregroundStyle(palette.textMuted)
            LectureDetaillee(lecture: affaire.lecture)
        }
        .padding(.leading, affaire.urgente ? 12 : 0)
        .overlay(alignment: .leading) {
            if affaire.urgente { palette.danger.frame(width: 4).clipShape(.capsule) }
        }
    }
}
