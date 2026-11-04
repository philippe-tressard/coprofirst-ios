// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'onglet « Consommations » (`OngletConsommations.svelte`) : un compteur à la
/// fois (pastilles, sans « Tous »), ses relevés groupés par année, les plus récents
/// d'abord.
struct OngletConsommations: View {
    let donnees: DonneesPrestataires
    let installation: Installation
    let service: any ServicePrestataires
    let conseil: Bool
    @State private var compteurs: [Compteur]?
    @State private var choisi: String?
    @State private var releves: [Releve]?
    @State private var erreur: String?
    @State private var photo: String?
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let erreur { MessageErreur(texte: erreur) }
            if let compteurs, !compteurs.isEmpty {
                Text(TextesPrestataires.compteur).styleLibelle()
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(compteurs) { compteur in
                            Pastille(
                                libelle: compteur.libelle, retenue: compteur.typeCompteur == choisi
                            ) {
                                choisi = compteur.typeCompteur
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
                .sensoryFeedback(.selection, trigger: choisi)
                if conseil, let compteur = compteurs.first(where: { $0.typeCompteur == choisi }) {
                    let fournisseur = donnees.prestataires.first { $0.id == compteur.prestataireId }
                    PastilleTeinte(
                        libelle: fournisseur.map { "🔧 \($0.nom)" } ?? TextesPrestataires.aucunFournisseur,
                        badge: fournisseur == nil ? "badge-gray" : "badge-blue")
                }
            }
            if let releves {
                if releves.isEmpty {
                    NoteAcces(
                        titre: TextesPrestataires.aucunReleve, texte: "",
                        pictogramme: "gauge.with.dots.needle.33percent")
                } else {
                    ForEach(parAnnee(releves), id: \.annee) { groupe in
                        Intertitre(titre: groupe.annee.map(String.init) ?? FormatsDuSite.tiret)
                        ForEach(groupe.releves) { carte($0) }
                    }
                }
            } else if compteurs?.isEmpty == false {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .task {
            do {
                let lus = try await service.compteurs(installation).sorted { $0.ordre < $1.ordre }
                compteurs = lus
                choisi = choisi ?? lus.first?.typeCompteur
                if lus.isEmpty { releves = [] }
            } catch {
                erreur = RefusDuServeur.phrase(error)
            }
        }
        .task(id: choisi) {
            guard let choisi else { return }
            releves = nil
            do {
                releves = try await service.releves(choisi, dans: installation)
                erreur = nil
            } catch {
                erreur = RefusDuServeur.phrase(error)
            }
        }
        .sheet(item: Binding(get: { photo.map(PhotoOuverte.init) }, set: { photo = $0?.chemin })) { ouverte in
            PhotoProtegee(chemin: ouverte.chemin, installation: installation, remplir: false)
                .presentationDragIndicator(.visible)
        }
    }

    private struct PhotoOuverte: Identifiable {
        let chemin: String
        var id: String { chemin }
    }

    private func carte(_ releve: Releve) -> some View {
        Carte {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(FormatsDuSite.date(releve.dateReleve)).font(.caption).foregroundStyle(palette.textMuted)
                    Text(
                        releve.index.map { TextesPrestataires.index(FormatsDuSite.nombre($0)) }
                            ?? TextesPrestataires.releveSansIndex)
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(palette.text)
                    if let note = releve.note, !note.isEmpty {
                        Text(note).font(.subheadline).foregroundStyle(palette.textMuted)
                    }
                }
                Spacer(minLength: 0)
                if let chemin = releve.photoUrl {
                    Button { photo = chemin } label: {
                        PhotoProtegee(chemin: chemin, installation: installation)
                            .frame(width: 64, height: 64)
                            .clipShape(.rect(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(TextesPrestataires.photoDuReleve)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Les relevés par année (fuseau de l'appareil), les années récentes d'abord ;
    /// dans une année, l'ordre de l'API.
    private func parAnnee(_ releves: [Releve]) -> [(annee: Int?, releves: [Releve])] {
        var annees: [Int?] = []
        var parAnnee: [Int?: [Releve]] = [:]
        for releve in releves {
            let annee = FormatsDuSite.lire(releve.dateReleve).map {
                Calendar.current.component(.year, from: $0)
            }
            if parAnnee[annee] == nil { annees.append(annee) }
            parAnnee[annee, default: []].append(releve)
        }
        return annees.sorted { ($0 ?? .min) > ($1 ?? .min) }.map { ($0, parAnnee[$0] ?? []) }
    }
}
