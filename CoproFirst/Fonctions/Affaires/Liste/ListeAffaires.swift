// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'onglet Liste : les actualités et les affaires en cours — recherche au serveur,
/// filtre « Suivi », nature et portée ; un toucher ouvre l'affaire.
struct ListeAffaires: View {
    @Bindable var etat: EtatAffaires
    let installation: Installation
    let droits: DroitsAffaires
    let service: (any ServiceAffaires)?
    let ouvrir: (Affaire) -> Void
    let nouvelle: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        List {
            Section {
                if etat.recherche.count >= EtatAffaires.rechercheMinimale, etat.archiveesTrouvees > 0 {
                    inclureArchives.rangeeDAffaire()
                }
                ForEach(lignes) { ligne in
                    switch ligne {
                    case .squelette:
                        CarteAffaireSquelette().rangeeDAffaire()
                    case .affaire(let affaire):
                        // Un bouton plutôt qu'un lien : une liste ajouterait son chevron à la carte.
                        Button {
                            ouvrir(affaire)
                        } label: {
                            CarteAffaire(affaire: affaire, archive: affaire.archivee)
                        }
                        .buttonStyle(StyleCarte())
                        .rangeeDAffaire()
                        .swipeActions(edge: .trailing) { actionArchiver(affaire) }
                        .contextMenu { menu(affaire) }
                        .accessibilityIdentifier("affaires.carte.\(affaire.numero)")
                    }
                }
            } header: {
                PastillesDeSuivi(etat: etat)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .overlay { etatVide }
        .searchable(text: $etat.recherche, prompt: "Rechercher une affaire")
        .task(id: etat.recherche) { await etat.chercher(installation, avec: service) }
        .refreshable { await etat.charger(installation, avec: service) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { MenuFiltresAffaires(etat: etat) }
        }
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
        etat.phase == .chargement ? (0..<4).map(Ligne.squelette) : etat.liste.map(Ligne.affaire)
    }

    /// La recherche a trouvé des affaires archivées : on les propose, sans les imposer.
    private var inclureArchives: some View {
        Toggle(isOn: $etat.avecArchives.animation(.snappy)) {
            Label {
                Text("Inclure les archives (\(etat.archiveesTrouvees, format: .number))")
            } icon: {
                Image(systemName: "archivebox")
            }
            .foregroundStyle(palette.text)
        }
        .tint(palette.primaryPlein)
        .padding(.horizontal, 4)
        .accessibilityIdentifier("affaires.inclureArchives")
    }

    @ViewBuilder
    private var etatVide: some View {
        if case .erreur(let erreur) = etat.phase {
            ContentUnavailableView {
                Label("Impossible d'afficher les affaires", systemImage: "exclamationmark.triangle")
            } description: {
                Text(erreur.phrase)
            } actions: {
                Button("Réessayer") { Task { await etat.charger(installation, avec: service) } }
                    .buttonStyle(.plein)
                    .fixedSize()
            }
        } else if etat.phase == .pret, etat.liste.isEmpty {
            if etat.trouvees != nil {
                ContentUnavailableView {
                    Label("Aucune affaire trouvée", systemImage: "magnifyingglass")
                } description: {
                    Text("Essayez un autre mot, ou incluez les Archives.")
                }
            } else if !etat.rechercheEnCours {
                ContentUnavailableView {
                    Label("Aucune affaire", systemImage: "checkmark.bubble")
                } description: {
                    Text("Signalez un problème ou posez une question au conseil syndical.")
                } actions: {
                    Button("Nouvelle affaire", action: nouvelle)
                        .buttonStyle(.plein)
                        .fixedSize()
                }
            }
        }
    }

    @ViewBuilder
    private func actionArchiver(_ affaire: Affaire) -> some View {
        // Le conseil seul archive (`archive_manuel`, 403 sinon) ; archiver, jamais supprimer.
        if droits.moderateur, !affaire.archivee {
            Button {
                Task { await etat.archiver(affaire, dans: installation, avec: service) }
            } label: {
                Label("Archiver", systemImage: "archivebox")
            }
            .tint(palette.primaryPlein)
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

extension View {
    /// Une carte posée dans une liste : sans séparateur, sur le fond de la page.
    func rangeeDAffaire() -> some View {
        listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 6, leading: Mise.marge, bottom: 6, trailing: Mise.marge))
    }
}
