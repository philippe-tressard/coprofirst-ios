// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les sondages : ceux en cours, puis les Archives repliées ; un toucher ouvre le
/// sondage (vote et résultats, `SondageView`). L'ordre est celui du serveur.
struct OngletSondages: View {
    let etat: EtatCommunaute
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette

    static let textes = TextesListe(
        vide: "Aucun sondage", videDetail: "Les sondages du conseil syndical apparaîtront ici.",
        erreur: "Impossible d'afficher les sondages", enCours: "Aucun sondage en cours",
        enCoursDetail: "Les sondages clos sont rangés dans les Archives, ci-dessous.", symbole: "chart.bar")

    var body: some View {
        let liste = etat.sondages
        let enCours = liste.elements.filter { !$0.archivee }
        List {
            if liste.phase == .pret {
                Section {
                    ForEach(enCours) { ligne($0) }
                } footer: {
                    // Qui crée un sondage est SERVI (`peut_creer`, GET /sondages/gestes, #87).
                    if etat.peutCreerUnSondage {
                        Text("Créer, modifier ou stopper un sondage se fait sur le site.")
                            .font(.footnote)
                            .foregroundStyle(palette.textMuted)
                            .accessibilityIdentifier("sondages.creation")
                    }
                }
                SectionArchives(elements: liste.elements.filter(\.archivee)) { ligne($0) }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .overlay {
            EtatListeCommunaute(
                phase: liste.phase.neutre, vide: liste.elements.isEmpty,
                toutArchive: enCours.isEmpty && !liste.elements.isEmpty, textes: Self.textes
            ) { recharger() }
        }
        .refreshable { await etat.charger(.sondages, installation, avec: parcours.serviceCommunaute) }
        .task { await etat.charger(.sondages, installation, avec: parcours.serviceCommunaute) }
    }

    private func ligne(_ sondage: SondageResume) -> some View {
        NavigationLink {
            SondageView(id: sondage.id, installation: installation)
        } label: {
            LigneSondage(sondage: sondage)
        }
        .listRowBackground(palette.surface)
        .accessibilityIdentifier("sondage.\(sondage.id)")
    }

    private func recharger() {
        Task { await etat.charger(.sondages, installation, avec: parcours.serviceCommunaute) }
    }
}

/// Un sondage : la question, son état, sa clôture et ses votants, qui le lit et son lieu. Anonyme, comme sur
/// le site : aucun auteur.
private struct LigneSondage: View {
    let sondage: SondageResume
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sondage.question)
                .font(.headline)
                .foregroundStyle(palette.text)
            if let description = sondage.description.map(TexteDuSite.apercu), !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(2)
            }
            FlowEtiquettes {
                PastilleTeinte(
                    libelle: sondage.cloture ? "🔒 Clôturé" : "Ouvert",
                    badge: sondage.cloture ? "badge-gray" : "badge-green")
                if let fin = sondage.clotureLe, !sondage.cloture {
                    Text("Clôture le \(FormatsDuSite.dateCourte(fin))")
                }
                Text(sondage.nbVotants == 1 ? "1 votant" : "\(sondage.nbVotants) votants")
                PastilleLecture(lecture: sondage.lecture, masculin: true)
                EtiquetteLieu(lieu: sondage.lieu)
            }
            .font(.caption)
            .foregroundStyle(palette.textMuted)
        }
        .padding(.vertical, 4)
    }
}
