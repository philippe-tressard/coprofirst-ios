// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « Nouvelle affaire » : la Création du cadre, en feuille — catégorie, titre,
/// description, lieu, urgence. Ce que l'app ne sait pas encore poser est dit,
/// jamais caché : les pièces jointes, et les sections que le conseil remplit. Elle se
/// compose selon la saisie du compte (`forme`, #69), comme le site.
struct NouvelleAffaireView: View {
    let installation: Installation
    /// Les catégories que le serveur PERMET à ce compte (`ReferentielsAffaires.permises`,
    /// #105) — `nil` tant que les référentiels ne sont pas lus.
    let categories: [CategorieAffaire]?
    /// Pourquoi elles n'ont pas pu être lues : la feuille le dit au lieu d'offrir une grille vide.
    var erreurCategories: ErreurAffaires?
    /// Ce compte pose ce que le serveur réserve au conseil syndical
    /// (`ReferentielsAffaires.poseLesReservees`, servi) : la feuille lui dit ce qu'il
    /// ajoutera lui-même depuis le site.
    var poseLesReservees = false
    let service: (any ServiceAffaires)?
    var forme: FormeDeSaisie?
    let creee: (Affaire) -> Void
    @Environment(\.dismiss) private var fermer
    @Environment(\.palette) private var palette
    @State private var saisie = SaisieAffaire(categorie: "", titre: "", description: "", urgente: false)
    @State private var envoi = false
    @State private var erreur: String?
    @State private var abandon = false
    @State private var envoyees = 0

    private var prete: Bool { service != nil && !saisie.categorie.isEmpty && saisie.complete && !envoi }
    private var entamee: Bool { !saisie.categorie.isEmpty || !saisie.titre.isEmpty || !saisie.description.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                if let erreur {
                    Section { MessageErreur(texte: erreur).listRowInsets(EdgeInsets()) }
                        .listRowBackground(Color.clear)
                }
                if let categories {
                    ChampsAffaire(
                        saisie: $saisie, categories: categories, installation: installation, service: service,
                        prefixe: "nouvelle", poserLeDefaut: true, forme: forme)
                } else if let erreurCategories {
                    Section { MessageErreur(texte: erreurCategories.phrase).listRowInsets(EdgeInsets()) }
                        .listRowBackground(Color.clear)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .accessibilityLabel("Chargement des catégories")
                }
                Section {
                    Label {
                        Text(aPoserSurLeSite)
                    } icon: {
                        Image(systemName: "safari")
                    }
                    .font(.footnote)
                    .foregroundStyle(palette.textMuted)
                    .accessibilityIdentifier("nouvelle.depuisLeSite")
                } header: {
                    Text("Depuis le site")
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.bg)
            .navigationTitle("Nouvelle affaire")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { barre }
            .interactiveDismissDisabled(entamee)
            .confirmationDialog("Abandonner cette affaire ?", isPresented: $abandon, titleVisibility: .visible) {
                Button("Abandonner la saisie", role: .destructive) { fermer() }
                Button("Continuer la saisie", role: .cancel) {}
            }
            .sensoryFeedback(.success, trigger: envoyees)
            .task {
                if service == nil { erreur = ErreurAffaires.serviceAbsent.phrase }
            }
        }
    }

    @ToolbarContentBuilder
    private var barre: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Annuler") { if entamee { abandon = true } else { fermer() } }
        }
        ToolbarItem(placement: .confirmationAction) {
            if envoi {
                ProgressView()
            } else {
                Button("Envoyer") { Task { await envoyer() } }
                    .fontWeight(.semibold)
                    .disabled(!prete)
                    .gesteEnLigne()
                    .accessibilityIdentifier("nouvelle.envoyer")
            }
        }
    }

    /// Ce que cette feuille ne pose pas, selon ce que le serveur permet à qui la remplit.
    private var aPoserSurLeSite: String {
        let pieces = "Les photos et les documents s'ajoutent depuis le site."
        return poseLesReservees
            ? "\(pieces) L'équipement, la date, l'intervenant, les destinataires et les affaires liées aussi."
            : "\(pieces) Le conseil syndical désigne l'équipement, la date, l'intervenant et les destinataires."
    }

    private func envoyer() async {
        guard let service, prete else { return }
        envoi = true
        defer { envoi = false }
        var envoyee = saisie
        if envoyee.estBogue { envoyee.perimetre = nil }
        do {
            let affaire = try await service.creer(envoyee, dans: installation)
            envoyees += 1
            withAnimation(.snappy) { erreur = nil }
            creee(affaire)
            fermer()
        } catch {
            withAnimation(.snappy) { self.erreur = ErreurAffaires.depuis(error).phrase }
        }
    }
}
