// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « Prestataires » de « Modifier l'affaire » (#181, coprofirst#2704) : une ligne par
/// prestataire avec son ×, puis « Ajouter un prestataire », comme les pièces jointes du
/// site. Offerte selon le droit SERVI seul (`peut_changer_prestataires`) : l'écran ne
/// juge ni la catégorie ni l'état de l'affaire.
///
/// L'ordre compte (le premier est celui du Kanban) : « Monter » et « Descendre » au menu
/// contextuel d'une ligne et en actions d'accessibilité — les ↑ ↓ du site. « Ajouter »
/// propose les prestataires de la résidence (GET /prestataires) qui n'y sont pas encore.
struct SectionPrestataires: View {
    @Binding var choisis: [PrestataireAffaire]
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit
    /// `nil` tant que la liste n'est pas lue (ou illisible : `illisible` le dit).
    @State private var catalogue: [Prestataire]?
    @State private var illisible = false

    private typealias Textes = TextesPrestatairesAffaire

    /// Les prestataires de la résidence qui ne sont pas déjà sur l'affaire.
    private var disponibles: [Prestataire] {
        let deja = Set(choisis.compactMap(\.id))
        return (catalogue ?? []).filter { !deja.contains($0.id) }
    }

    var body: some View {
        Section {
            if choisis.isEmpty {
                Text(Textes.aucun)
                    .foregroundStyle(palette.textMuted)
                    .accessibilityIdentifier("modifier.prestataires.aucun")
            }
            ForEach(Array(choisis.enumerated()), id: \.element) { rang, prestataire in
                ligne(prestataire, rang: rang)
            }
            .onDelete { rangs in changer { choisis.remove(atOffsets: rangs) } }
            ajouter
            if illisible {
                Text(Textes.catalogueIllisible)
                    .font(.footnote)
                    .foregroundStyle(palette.danger)
            }
        } header: {
            Text(Textes.section)
        } footer: {
            if choisis.count > 1 { Text(Textes.pied) }
        }
        .task { await charger() }
    }

    private func ligne(_ prestataire: PrestataireAffaire, rang: Int) -> some View {
        HStack(spacing: 12) {
            Text(prestataire.nom)
                .foregroundStyle(palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("modifier.prestataire.\(prestataire.id ?? 0)")
                .accessibilityActions { gestesDOrdre(rang) }
            Button {
                changer { _ = choisis.remove(at: rang) }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .font(.title3)
                    .foregroundStyle(palette.textMuted)
                    .frame(minWidth: Mise.cible, minHeight: Mise.cible)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Textes.retirer(prestataire.nom))
            .accessibilityIdentifier("modifier.prestataire.\(prestataire.id ?? 0).retirer")
        }
        .contextMenu { gestesDOrdre(rang) }
    }

    @ViewBuilder
    private func gestesDOrdre(_ rang: Int) -> some View {
        if rang > 0 {
            Button(Textes.monter, systemImage: "arrow.up") { changer { choisis.swapAt(rang, rang - 1) } }
        }
        if rang < choisis.count - 1 {
            Button(Textes.descendre, systemImage: "arrow.down") { changer { choisis.swapAt(rang, rang + 1) } }
        }
    }

    private var ajouter: some View {
        Menu {
            ForEach(disponibles) { prestataire in
                Button(prestataire.nom) {
                    changer { choisis.append(PrestataireAffaire(id: prestataire.id, nom: prestataire.nom)) }
                }
                .accessibilityIdentifier("modifier.prestataires.choix.\(prestataire.id)")
            }
        } label: {
            // Un Label qui porte un identifiant se résout en son image sous iOS 26 (#183) :
            // un seul élément, le libellé entier.
            Label(Textes.ajouter, systemImage: "plus.circle.fill")
                .foregroundStyle(palette.primary)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Textes.ajouter)
        }
        .disabled(disponibles.isEmpty)
        .accessibilityIdentifier("modifier.prestataires.ajouter")
        .accessibilityHint(catalogue != nil && disponibles.isEmpty ? Textes.tousChoisis : "")
    }

    /// Un ajout, un retrait, un déplacement : la liste glisse, sauf en mouvement réduit.
    private func changer(_ geste: () -> Void) {
        withAnimation(mouvementReduit ? nil : .snappy(duration: 0.25)) { geste() }
    }

    private func charger() async {
        guard catalogue == nil, let service = parcours.servicePrestataires else {
            illisible = parcours.servicePrestataires == nil
            return
        }
        do {
            catalogue = try await service.prestataires(installation, archives: false)
        } catch {
            illisible = true
        }
    }
}
