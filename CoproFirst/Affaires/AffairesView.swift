// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Écran 4 — les affaires de la résidence : recherche, filtres, cartes.
struct AffairesView: View {
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(Reseau.self) private var reseau
    @State private var etat = EtatAffaires()
    @State private var nouvelle = false

    var body: some View {
        List {
            Section {
                ForEach(lignes) { ligne in
                    switch ligne {
                    case .squelette:
                        CarteAffaireSquelette().rangee()
                    case .affaire(let affaire):
                        CarteAffaire(affaire: affaire)
                            .rangee()
                            .swipeActions(edge: .trailing) { actionArchiver(affaire) }
                            .contextMenu { menu(affaire) }
                    }
                }
            } header: {
                Filtres(etat: etat)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Charte.bg)
        .overlay { etatVide }
        .navigationTitle("Affaires")
        .searchable(text: $etat.recherche, prompt: "Rechercher une affaire")
        .refreshable { await etat.charger(installation, avec: parcours.service) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    nouvelle = true
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .tint(Charte.primaryPlein)
                .accessibilityLabel("Nouvelle affaire")
                .accessibilityIdentifier("affaires.nouvelle")
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !reseau.enLigne { BandeauHorsLigne() }
        }
        .sheet(isPresented: $nouvelle) {
            NouvelleAffaireView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task { await etat.charger(installation, avec: parcours.service) }
    }

    private enum Ligne: Identifiable {
        case squelette(Int)
        case affaire(Affaire)

        var id: String {
            switch self {
            case .squelette(let n): "squelette-\(n)"
            case .affaire(let affaire): "affaire-\(affaire.id)"
            }
        }
    }

    private var lignes: [Ligne] {
        etat.phase == .chargement ? (0..<4).map(Ligne.squelette) : etat.retenues.map(Ligne.affaire)
    }

    @ViewBuilder
    private var etatVide: some View {
        if case .erreur(let erreur) = etat.phase {
            MessageErreur(texte: erreur.phrase) {
                Task { await etat.charger(installation, avec: parcours.service) }
            }
            .padding(Mise.marge)
        } else if etat.phase == .pret, etat.retenues.isEmpty {
            if !etat.recherche.isEmpty {
                ContentUnavailableView.search(text: etat.recherche)
            } else {
                ContentUnavailableView {
                    Label("Aucune affaire", systemImage: "checkmark.bubble")
                } description: {
                    Text("Rien à signaler ici. Un problème dans la résidence ? Signalez-le.")
                } actions: {
                    Button("Nouvelle affaire") { nouvelle = true }
                        .buttonStyle(.plein)
                        .fixedSize()
                }
            }
        }
    }

    @ViewBuilder
    private func actionArchiver(_ affaire: Affaire) -> some View {
        // L'écran n'offre que ce que le serveur permet ; archiver, jamais supprimer.
        if parcours.service.peutArchiver(installation) {
            Button {
                Task { await etat.archiver(affaire, dans: installation, avec: parcours.service) }
            } label: {
                Label("Archiver", systemImage: "archivebox")
            }
            .tint(Charte.primaryPlein)
        }
    }

    @ViewBuilder
    private func menu(_ affaire: Affaire) -> some View {
        Button {
            UIPasteboard.general.string = affaire.numero
        } label: {
            Label("Copier le numéro", systemImage: "number")
        }
        ShareLink(item: installation.adresse.appending(path: "tickets/\(affaire.id)")) {
            Label("Partager le lien", systemImage: "square.and.arrow.up")
        }
        actionArchiver(affaire)
    }
}

private extension View {
    /// Une carte posée dans la liste : sans séparateur, sur le fond de la page.
    func rangee() -> some View {
        listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 6, leading: Mise.marge, bottom: 6, trailing: Mise.marge))
    }
}
