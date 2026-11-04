// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « Nouvelle affaire » : la Création du cadre, en feuille — catégorie, titre,
/// description, lieu, urgence. Ce que l'app ne sait pas encore poser est dit,
/// jamais caché : les pièces jointes, et les sections que le conseil remplit.
struct NouvelleAffaireView: View {
    let installation: Installation
    let droits: DroitsAffaires
    let service: (any ServiceAffaires)?
    let creee: (Affaire) -> Void
    @Environment(\.dismiss) private var fermer
    @Environment(\.palette) private var palette
    @State private var categorie: String?
    @State private var saisie = SaisieAffaire(categorie: "", titre: "", description: "", urgente: false)
    @State private var perimetres: [PerimetreAffaire] = []
    @State private var envoi = false
    @State private var erreur: String?
    @State private var abandon = false
    @State private var envoyees = 0
    @FocusState private var champ: Champ?

    private enum Champ { case titre, description }

    /// La catégorie d'un bogue : son lieu est le site, et il ne s'épingle ni ne s'urge.
    private static let bogue = "bug"

    private var estBogue: Bool { categorie == Self.bogue }
    private var prete: Bool { service != nil && categorie != nil && saisie.complete && !envoi }
    private var entamee: Bool { categorie != nil || !saisie.titre.isEmpty || !saisie.description.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                if let erreur {
                    Section { MessageErreur(texte: erreur).listRowInsets(EdgeInsets()) }
                        .listRowBackground(Color.clear)
                }
                Section {
                    ChoixCategorie(categories: droits.categories, choisie: $categorie)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Catégorie")
                } footer: {
                    if droits.categories.contains(where: \.carnet) {
                        Text("Le liseré doré : une affaire résolue y alimente le carnet d'entretien.")
                    }
                }
                Section("Titre") {
                    TextField("En quelques mots", text: $saisie.titre)
                        .focused($champ, equals: .titre)
                        .submitLabel(.next)
                        .onSubmit { champ = .description }
                        .accessibilityIdentifier("nouvelle.titre")
                }
                Section("Description") {
                    TextField("Le problème, en détail", text: $saisie.description, axis: .vertical)
                        .lineLimit(4...12)
                        .focused($champ, equals: .description)
                        .accessibilityIdentifier("nouvelle.description")
                }
                lieu
                urgence
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
                await chargerLesLieux()
            }
            .onChange(of: categorie) { _, code in
                saisie.categorie = code ?? ""
                if code == Self.bogue { saisie.urgente = false }
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

    @ViewBuilder
    private var lieu: some View {
        Section {
            if estBogue {
                Text("Un bogue concerne le site, pas un lieu de la copropriété.")
                    .font(.footnote)
                    .foregroundStyle(palette.textMuted)
            } else if !perimetres.isEmpty {
                Picker("Lieu", selection: $saisie.perimetre) {
                    ForEach(perimetres) { perimetre in
                        Text(String(repeating: "   ", count: perimetre.profondeur) + perimetre.libelle)
                            .tag(Optional(perimetre.code))
                    }
                }
                .pickerStyle(.navigationLink)
                .accessibilityIdentifier("nouvelle.lieu")
            }
        } header: {
            Text("De quoi s'agit-il ?")
        }
    }

    @ViewBuilder
    private var urgence: some View {
        if !estBogue {
            Section {
                Toggle(isOn: $saisie.urgente.animation(.snappy)) {
                    Label("Urgente", systemImage: "light.beacon.max")
                }
                .tint(palette.dangerPlein)
                .accessibilityIdentifier("nouvelle.urgente")
                if saisie.urgente {
                    // Ce que dit l'avertissement du site : l'app trace, elle n'alerte pas.
                    Text(
                        "Une affaire urgente laisse une trace de votre signalement ; elle n'alerte pas les "
                            + "secours. En cas de danger : 15 (SAMU) · 17 (Police secours) · 18 (Sapeurs-pompiers) · "
                            + "112 (urgences)."
                    )
                    .font(.footnote)
                    .foregroundStyle(palette.danger)
                    .transition(.opacity)
                }
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

    private func chargerLesLieux() async {
        guard let service, let lus = try? await service.perimetres(installation) else { return }
        withAnimation(.snappy) {
            perimetres = lus
            if saisie.perimetre == nil { saisie.perimetre = lus.parDefaut?.code ?? lus.first?.code }
        }
    }

    private func envoyer() async {
        guard let service, prete else { return }
        envoi = true
        defer { envoi = false }
        var envoyee = saisie
        if estBogue { envoyee.perimetre = nil }
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
