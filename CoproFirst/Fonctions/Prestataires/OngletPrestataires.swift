// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'onglet « Prestataires » (`OngletPrestataires.svelte`) : recherche, catégorie,
/// contrat ; les fiches groupées par catégorie, une seule dépliée à la fois ; les
/// archives repliées en bas.
struct OngletPrestataires: View {
    let donnees: DonneesPrestataires
    let installation: Installation
    let service: any ServicePrestataires
    @State private var recherche = ""
    @State private var categorie: String?
    @State private var contrat: String?
    @State private var deplie: Int?
    @State private var archives: [Prestataire]?
    @Environment(\.palette) private var palette

    var body: some View {
        let courants = filtrer(donnees.prestataires)
        let archivees = filtrer(archives ?? [])
        let filtre = !recherche.isEmpty || categorie != nil || contrat != nil
        VStack(alignment: .leading, spacing: 14) {
            ChampRecherche(texte: $recherche)
            pastilles(
                TextesPrestataires.categorie, valeur: $categorie,
                options: TablesPrestataires.types.map { ($0.code, $0.libelle) })
            pastilles(
                TextesPrestataires.contrat, valeur: $contrat, options: TablesPrestataires.filtresContrat)
            if courants.isEmpty && archivees.isEmpty {
                NoteAcces(
                    titre: filtre
                        ? TextesPrestataires.aucunPrestatairePourCriteres : TextesPrestataires.aucunPrestataire,
                    texte: "", pictogramme: "wrench.and.screwdriver")
            } else {
                if courants.isEmpty {
                    NoteAcces(titre: TextesPrestataires.aucunActif(filtre), texte: TextesPrestataires.archivesRangees)
                }
                ForEach(TablesPrestataires.types, id: \.code) { type in
                    let groupe = courants.filter { $0.type == type.code }
                    if !groupe.isEmpty { section(type, groupe, entete: categorie == nil, compact: courants.count > 7) }
                }
                let sansType = courants.filter { p in !TablesPrestataires.types.contains { $0.code == p.type } }
                ForEach(sansType) { carte($0, compact: courants.count > 7) }
                if !archivees.isEmpty {
                    DisclosureGroup {
                        VStack(spacing: 10) { ForEach(archivees) { carte($0, compact: true) } }.padding(.top, 8)
                    } label: {
                        Text("\(TextesPrestataires.archives) (\(archivees.count))").font(.headline)
                    }
                    .tint(palette.primary)
                }
            }
        }
        .animation(.snappy(duration: 0.25), value: deplie)
        .task { archives = try? await service.prestataires(installation, archives: true) }
    }

    @ViewBuilder
    private func section(
        _ type: TypePrestataire, _ groupe: [Prestataire], entete: Bool,
        compact: Bool
    ) -> some View {
        if entete {
            VStack(alignment: .leading, spacing: 2) {
                Intertitre(titre: type.libelle)
                Text(type.description).font(.subheadline).foregroundStyle(palette.textMuted)
            }
        }
        ForEach(groupe) { carte($0, compact: compact) }
    }

    private func carte(_ prestataire: Prestataire, compact: Bool) -> some View {
        CartePrestataire(
            prestataire: prestataire, donnees: donnees, compact: compact,
            deplie: Binding(
                get: { deplie == prestataire.id }, set: { deplie = $0 ? prestataire.id : nil }))
    }

    private func pastilles(
        _ titre: String, valeur: Binding<String?>, options: [(code: String, libelle: String)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titre).styleLibelle()
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Pastille(libelle: TextesPrestataires.tous, retenue: valeur.wrappedValue == nil) {
                        valeur.wrappedValue = nil
                    }
                    ForEach(options, id: \.code) { option in
                        // Sans le compte du site : `Pastille` le dit « affaires » à
                        // VoiceOver (signalé à la coordination le 04/11/2026).
                        Pastille(libelle: option.libelle, retenue: valeur.wrappedValue == option.code) {
                            withAnimation(.snappy(duration: 0.2)) {
                                valeur.wrappedValue = valeur.wrappedValue == option.code ? nil : option.code
                            }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .sensoryFeedback(.selection, trigger: valeur.wrappedValue)
        }
    }

    /// `filtrerPrestataires` : catégorie, contrat (parmi les contrats en cours), recherche.
    private func filtrer(_ liste: [Prestataire]) -> [Prestataire] {
        let sousContrat = Set(donnees.contrats.map(\.prestataireId))
        return liste.filter { p in
            (categorie == nil || p.type == categorie)
                && (contrat == nil || (contrat == "sous_contrat") == sousContrat.contains(p.id))
                && LibellesPrestataires.correspond(
                    p, equipement: donnees.equipement(p.specialite), recherche: recherche)
        }
    }
}

/// Le champ de recherche de la liste, dans la page (et non dans la barre de
/// navigation : il ne vaut que pour cet onglet).
struct ChampRecherche: View {
    @Binding var texte: String
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(palette.textMuted).accessibilityHidden(true)
            TextField(TextesPrestataires.recherche, text: $texte)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityIdentifier("prestataires.recherche")
            if !texte.isEmpty {
                Button { texte = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .foregroundStyle(palette.textMuted)
                    .accessibilityLabel("Effacer la recherche")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: Mise.cible)
        .background(palette.surface, in: .rect(cornerRadius: Mise.rayon, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Mise.rayon, style: .continuous)
                .strokeBorder(palette.borderChamp, lineWidth: 1)
        }
    }
}
