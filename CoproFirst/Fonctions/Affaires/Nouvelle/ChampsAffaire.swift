// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les champs d'une affaire, écrits UNE fois pour ses deux rendus de saisie — la
/// Création (« Nouvelle affaire ») et l'Édition (« Modifier l'affaire ») : catégorie,
/// titre, description, lieu, urgence. Des sections, à poser dans un `Form`.
///
/// Ce que l'Édition ne peut pas réenregistrer sans perte se montre sans se toucher :
/// une description mise en forme sur le site (`descriptionFigee`), plusieurs lieux.
struct ChampsAffaire: View {
    @Binding var saisie: SaisieAffaire
    /// Les catégories proposées — vide : la catégorie ne se choisit pas ici.
    let categories: [CategorieAffaire]
    let installation: Installation
    let service: (any ServicePerimetres)?
    /// Le préfixe des identifiants d'accessibilité (`nouvelle`, `modifier`).
    let prefixe: String
    /// Création : présélectionner le lieu que le serveur désigne par défaut.
    var poserLeDefaut = false
    /// Le HTML d'une description que l'app ne sait pas réécrire, montré tel quel.
    var descriptionFigee: String?
    var lieuModifiable = true
    @Environment(\.palette) private var palette
    @State private var perimetres: [Perimetre] = []
    @FocusState private var champ: Champ?

    private enum Champ { case titre, description }

    var body: some View {
        if !categories.isEmpty {
            Section {
                ChoixCategorie(categories: categories, choisie: categorie)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
            } header: {
                Text("Catégorie")
            } footer: {
                if categories.contains(where: \.carnet) {
                    Text("Le liseré doré : une affaire résolue y alimente le carnet d'entretien.")
                }
            }
        }
        Section("Titre") {
            TextField("En quelques mots", text: $saisie.titre)
                .focused($champ, equals: .titre)
                .submitLabel(.next)
                .onSubmit { champ = descriptionFigee == nil ? .description : nil }
                .accessibilityIdentifier("\(prefixe).titre")
        }
        description
        lieu
        urgence
    }

    /// La catégorie choisie ; un bogue ne s'urge pas (`OPTIONS_TICKET` du site).
    private var categorie: Binding<String?> {
        Binding(
            get: { saisie.categorie.isEmpty ? nil : saisie.categorie },
            set: { code in
                saisie.categorie = code ?? ""
                if code == SaisieAffaire.bogue { saisie.urgente = false }
            })
    }

    @ViewBuilder
    private var description: some View {
        if let descriptionFigee {
            Section {
                Text(TexteDuSite.riche(descriptionFigee))
                    .foregroundStyle(palette.textMuted)
            } header: {
                Text("Description")
            } footer: {
                Text("Sa mise en forme (gras, listes, liens) se modifie depuis le site.")
            }
        } else {
            Section("Description") {
                TextField("Le problème, en détail", text: $saisie.description, axis: .vertical)
                    .lineLimit(4...12)
                    .focused($champ, equals: .description)
                    .accessibilityIdentifier("\(prefixe).description")
            }
        }
    }

    private var lieu: some View {
        Section {
            if saisie.estBogue {
                Text("Un bogue concerne le site, pas un lieu de la copropriété.")
                    .font(.footnote)
                    .foregroundStyle(palette.textMuted)
            } else if !lieuModifiable {
                Text("Plusieurs lieux sont désignés : ils se modifient depuis le site.")
                    .font(.footnote)
                    .foregroundStyle(palette.textMuted)
            } else if !perimetres.isEmpty {
                Picker("Lieu", selection: $saisie.perimetre) {
                    // Sans lieu, le serveur pose le défaut qu'il DÉSIGNE (`par_defaut`, #54).
                    Text("Non précisé").tag(String?.none)
                    ForEach(perimetres) { perimetre in
                        Text(String(repeating: "   ", count: perimetre.profondeur) + perimetre.libelle)
                            .tag(Optional(perimetre.code))
                    }
                }
                .pickerStyle(.navigationLink)
                .accessibilityIdentifier("\(prefixe).lieu")
            }
        } header: {
            Text("De quoi s'agit-il ?")
        }
        .task { await chargerLesLieux() }
    }

    @ViewBuilder
    private var urgence: some View {
        if !saisie.estBogue {
            Section {
                Toggle(isOn: $saisie.urgente.animation(.snappy)) {
                    Label("Urgente", systemImage: "light.beacon.max")
                }
                .tint(palette.dangerPlein)
                .accessibilityIdentifier("\(prefixe).urgente")
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

    private func chargerLesLieux() async {
        guard let service, let lus = try? await service.perimetres(installation) else { return }
        withAnimation(.snappy) {
            perimetres = lus.filter(\.selectionnable)
            if poserLeDefaut, saisie.perimetre == nil { saisie.perimetre = Perimetre.codeParDefaut(perimetres) }
        }
    }
}
