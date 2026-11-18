// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Profil › Personnes masquées (#286) — `PersonnesMasquees.svelte` du site : les résidents
/// dont on masque ce qu'ils publient, et « Ne plus masquer ». Le masque se POSE depuis une
/// publication ; il se défait ici, et seulement ici — l'endroit qu'annonce la confirmation.
/// Une liste qui peut être vide, en erreur ou en cours : `Chargement`, jamais un « personne »
/// qui prendrait un échec pour une absence.
struct PersonnesMasqueesView: View {
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit
    /// Ceux qu'on ne masque plus : ils quittent la liste sans la relire (le site fait de même).
    @State private var retires: Set<Int> = []
    @State private var avis = AvisDuGeste()

    var body: some View {
        let service = parcours.service.masquages
        Chargement {
            guard let service else { throw ErreurService.inattendue(501) }
            return try await service.masques(dans: installation)
        } contenu: { masques, _ in
            liste(masques.filter { !retires.contains($0.auteurId) })
        } squelette: {
            liste([Masquage(auteurId: 0, auteur: "Prénom NOM", creeLe: .now)])
        }
        .background(palette.bg)
        .navigationTitle(TextesMasquage.titreListe)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top, spacing: 0) { BandeauHorsLigne() }
        .avisEphemere(avis)
    }

    private func liste(_ masques: [Masquage]) -> some View {
        List {
            Section {
                ForEach(masques) { ligne($0) }
            } footer: {
                Text(TextesMasquage.aide).foregroundStyle(palette.textMuted)
            }
        }
        .scrollContentBackground(.hidden)
        .overlay {
            if masques.isEmpty {
                ContentUnavailableView(
                    TextesMasquage.personne, systemImage: TextesMasquage.symbole,
                    description: Text(TextesMasquage.ouSeTrouve))
            }
        }
    }

    /// Le nom, depuis quand, puis « Ne plus masquer » — en colonne au très grand texte.
    private func ligne(_ masque: Masquage) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { identite(masque); Spacer(minLength: 8); bouton(masque) }
            VStack(alignment: .leading, spacing: 8) { identite(masque); bouton(masque) }
        }
        .padding(.vertical, 4)
        .listRowBackground(palette.surface)
        // Un conteneur : l'identifiant de la rangée ne recouvre pas celui de son bouton.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("masque.\(masque.auteurId)")
    }

    private func identite(_ masque: Masquage) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(masque.auteur).font(.body.weight(.semibold)).foregroundStyle(palette.text)
            Text(TextesMasquage.depuis(masque.creeLe)).font(.footnote).foregroundStyle(palette.textMuted)
        }
    }

    private func bouton(_ masque: Masquage) -> some View {
        Button { Task { await demasquer(masque) } } label: {
            Label(TextesMasquage.nePlusMasquer, systemImage: "eye")
        }
        .buttonStyle(.contour)
        .gesteEnLigne()
        .accessibilityLabel("\(TextesMasquage.nePlusMasquer) \(masque.auteur)")
        .accessibilityIdentifier("masque.\(masque.auteurId).demasquer")
    }

    private func demasquer(_ masque: Masquage) async {
        await avis.agir(avec: parcours.service.masquages, reussite: TextesMasquage.demasque(masque.auteur)) {
            try await $0.demasquer(masque.auteurId, dans: installation)
            // La ligne quitte la liste au ressort de l'app ; d'un coup en mouvement réduit.
            _ = withAnimation(mouvementReduit ? nil : .snappy) { retires.insert(masque.auteurId) }
        }
    }
}
