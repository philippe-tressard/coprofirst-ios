// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « Nouvelle annonce » (`FormulaireAnnonceHall.svelte`) : le titre, le message, le
/// périmètre, le format et la Diffusion — puis l'affiche est créée (PDF rendu et envois
/// faits par le serveur). Sans photo ni assistant : ceux-là restent au site.
struct NouvelleAnnonceHall: View {
    let service: any ServiceAnnoncesHallCS
    let installation: Installation
    let creee: (AnnonceHall) -> Void
    @Environment(\.palette) private var palette
    @State private var saisie = SaisieAnnonceHall()
    @State private var perimetres: [Perimetre] = []
    @State private var envoi = false
    @State private var erreur: ErreurService?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ChampSaisie(libelle: TextesAnnoncesHall.titre) {
                TextField(TextesAnnoncesHall.titreExemple, text: $saisie.titre)
                    .accessibilityIdentifier("nouvelle-annonce-hall.titre")
            }
            ChampSaisie(libelle: TextesAnnoncesHall.message) {
                TextField(TextesAnnoncesHall.messageExemple, text: $saisie.message, axis: .vertical)
                    .lineLimit(4...12)
                    .padding(.vertical, 12)
                    .accessibilityIdentifier("nouvelle-annonce-hall.message")
            }
            if !perimetres.isEmpty { choixPerimetres }
            choixFormat
            diffusion
            if let erreur { MessageErreur(texte: erreur.phrase) }
            Button(action: creer) {
                if envoi { ProgressView().tint(palette.surPlein) } else { Text(TextesAnnoncesHall.creer) }
            }
            .buttonStyle(.plein)
            .disabled(!saisie.complete || envoi)
            .accessibilityIdentifier("nouvelle-annonce-hall.creer")
        }
        .animation(.snappy, value: erreur)
        .task {
            // Non bloquant : sans périmètres, l'affiche prend celui que le serveur pose.
            perimetres = Perimetre.aSaisir((try? await service.perimetres(installation)) ?? [])
        }
    }

    private var choixPerimetres: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(TextesAnnoncesHall.perimetre).styleLibelle()
            Carte {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(perimetres) { perimetre in
                        Toggle(isOn: coche(perimetre.code)) {
                            Text(perimetre.libelle).font(.subheadline)
                        }
                        .padding(.leading, CGFloat(perimetre.profondeur) * 16)
                        .frame(minHeight: Mise.cible)
                        .tint(palette.primaryPlein)
                        .accessibilityIdentifier("nouvelle-annonce-hall.perimetre.\(perimetre.code)")
                    }
                }
            }
            Text(TextesAnnoncesHall.perimetreAide).font(.footnote).foregroundStyle(palette.textMuted)
        }
    }

    private var choixFormat: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(TextesAnnoncesHall.format).styleLibelle()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TablesAnnoncesHall.formats, id: \.code) { format in
                        Pastille(libelle: format.libelle, retenue: saisie.format == format.code) {
                            withAnimation(.snappy) { saisie.format = format.code }
                        }
                        .accessibilityIdentifier("nouvelle-annonce-hall.format.\(format.code)")
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: saisie.format)
            Text(TextesAnnoncesHall.formatAide).font(.footnote).foregroundStyle(palette.textMuted)
        }
    }

    /// La Diffusion : trois cases, décochées — la valeur par défaut d'un envoi est
    /// « ne pas envoyer ».
    private var diffusion: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(TextesAnnoncesHall.diffusion).styleLibelle()
            Carte {
                VStack(alignment: .leading, spacing: 0) {
                    Toggle(TextesAnnoncesHall.envoyerCS, isOn: $saisie.envoyerCS)
                        .accessibilityIdentifier("nouvelle-annonce-hall.envoyer-cs")
                    Toggle(TextesAnnoncesHall.envoyerSyndic, isOn: $saisie.envoyerSyndic)
                    Toggle(TextesAnnoncesHall.envoyerAuteur, isOn: $saisie.envoyerAuteur)
                }
                .font(.subheadline)
                .tint(palette.primaryPlein)
                .frame(minHeight: Mise.cible)
            }
        }
    }

    private func coche(_ code: String) -> Binding<Bool> {
        Binding(
            get: { saisie.perimetres.contains(code) },
            set: { if $0 { saisie.perimetres.insert(code) } else { saisie.perimetres.remove(code) } })
    }

    private func creer() {
        envoi = true
        erreur = nil
        let saisie = saisie
        Task {
            do {
                let annonce = try await service.creerAnnonceHall(saisie, dans: installation)
                self.saisie = SaisieAnnonceHall()
                creee(annonce)
            } catch {
                self.erreur = ErreurService.depuis(error)
            }
            envoi = false
        }
    }
}
