// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « Nouvelle affaire » : la Création du cadre, en feuille — catégorie, titre,
/// description, lieu, urgence. Ce que l'app ne sait pas encore poser est dit,
/// jamais caché : les pièces jointes, et les sections que le conseil remplit. Elle se
/// compose selon la saisie du compte (`forme`, #69), comme le site.
struct NouvelleAffaireView: View {
    let installation: Installation
    let droits: DroitsAffaires
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
                ChampsAffaire(
                    saisie: $saisie, categories: droits.categories, installation: installation, service: service,
                    prefixe: "nouvelle", poserLeDefaut: true, forme: forme)
                Section {
                    Label {
                        Text(aPoserSurLeSite)
                    } icon: {
                        Image(systemName: "safari")
                    }
                    .font(.footnote)
                    .foregroundStyle(palette.textMuted)
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
                    .accessibilityIdentifier("nouvelle.envoyer")
            }
        }
    }

    /// Ce que cette feuille ne pose pas, selon qui la remplit.
    private var aPoserSurLeSite: String {
        let pieces = "Les photos et les documents s'ajoutent depuis le site."
        return droits.moderateur
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
