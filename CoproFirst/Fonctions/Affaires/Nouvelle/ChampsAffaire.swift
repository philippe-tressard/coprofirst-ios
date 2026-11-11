// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les champs d'une affaire, écrits UNE fois pour ses deux rendus de saisie — la
/// Création (« Nouvelle affaire ») et l'Édition (« Modifier l'affaire ») : catégorie,
/// titre, description, lieu, urgence. Des sections, à poser dans un `Form`.
///
/// Ce que l'Édition ne peut pas réenregistrer sans perte se montre sans se toucher :
/// une description mise en forme sur le site (`descriptionFigee`), plusieurs lieux.
///
/// Selon la saisie du compte (`forme`, #69) : en Essentielle, ce qui n'est pas essentiel
/// pour la catégorie se range dans « Plus de détails », en fin de formulaire — le
/// serveur dit quoi (`FormeDeSaisie`), la vue ne décide rien.
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
    /// `nil` : un serveur qui ne sert pas la saisie — tout à son rang, sans phrase.
    var forme: FormeDeSaisie?
    @Environment(\.palette) private var palette
    @State private var perimetres: [Perimetre] = []
    @State private var plusDeDetails = false
    @State private var lieuParDefaut: String?
    @FocusState private var champ: Champ?

    private enum Champ { case titre, description }

    /// Un bogue n'a ni lieu à choisir ni urgence : rien de lui ne se range.
    private var eteintes: Set<SectionAffaire> { saisie.estBogue ? [.perimetre, .miseEnAvant] : [] }
    private var rangees: [SectionAffaire] { forme?.rangees(categorie: saisie.categorie, eteintes: eteintes) ?? [] }

    var body: some View {
        Group {
            if let forme {
                Text(forme.phrase(rangees: rangees.count))
                    .font(.footnote)
                    .foregroundStyle(palette.textMuted)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                    .accessibilityIdentifier("\(prefixe).modeSaisie")
            }
            champs
        }
        .task { await chargerLesLieux() }
        // Une correction ne cache jamais ce qui a été saisi (`repartition` du site) : le
        // groupe s'ouvre d'office si une section rangée porte autre chose que son défaut.
        .onChange(of: rangees.contains(where: renseignee), initial: true) { _, ouvrir in
            if ouvrir { withAnimation(.snappy) { plusDeDetails = true } }
        }
    }

    @ViewBuilder
    private var champs: some View {
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
        if !rangees.contains(.perimetre) {
            Section {
                lieu
            } header: {
                Text("De quoi s'agit-il ?")
            }
        }
        if !saisie.estBogue, !rangees.contains(.miseEnAvant) {
            Section { urgence }
        }
        if !rangees.isEmpty { replies }
    }

    /// « Plus de détails (n sections) » : les sections rangées, à leur rang, dans un groupe
    /// plié. Plié, rien ne se perd — la saisie vit dans `saisie`, et part telle quelle.
    private var replies: some View {
        Section {
            DisclosureGroup(isExpanded: $plusDeDetails.animation(.snappy)) {
                ForEach(rangees, id: \.self) { section in
                    switch section {
                    case .perimetre: lieu
                    case .miseEnAvant: urgence
                    default: EmptyView()
                    }
                }
            } label: {
                // L'identifiant sur l'intitulé seul : posé sur le groupe, il couvrirait ses lignes.
                Text(FormeDeSaisie.intitule(rangees.count))
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.primary)
                    .accessibilityIdentifier("\(prefixe).plusDeDetails")
            }
        }
    }

    /// La section rangée porte-t-elle autre chose que sa valeur par défaut ?
    private func renseignee(_ section: SectionAffaire) -> Bool {
        switch section {
        case .miseEnAvant: saisie.urgente
        case .perimetre: saisie.perimetre != lieuParDefaut
        default: false
        }
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

    /// Le lieu (`perimetre` du cadre) : à son rang, ou rangé dans « Plus de détails ».
    @ViewBuilder
    private var lieu: some View {
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
    }

    /// L'urgence (`mise_en_avant` du cadre) : à son rang, ou rangée dans « Plus de détails ».
    @ViewBuilder
    private var urgence: some View {
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

    private func chargerLesLieux() async {
        guard let service, let lus = try? await service.perimetres(installation) else { return }
        withAnimation(.snappy) {
            perimetres = Perimetre.aSaisir(lus, garder: saisie.perimetre)
            lieuParDefaut = Perimetre.codeParDefaut(perimetres)
            if poserLeDefaut, saisie.perimetre == nil { saisie.perimetre = lieuParDefaut }
        }
    }
}
