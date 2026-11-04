// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La boîte à idées : les plus soutenues d'abord, un filtre par état, le cœur pour
/// voter (une bascule). Un toucher ouvre l'idée et ses réponses.
struct OngletIdees: View {
    let etat: EtatCommunaute
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var filtre: String?

    static let textes = TextesListe(
        vide: "Aucune idée pour l'instant", videDetail: "Soyez le premier à proposer une idée !",
        erreur: "Impossible d'afficher les idées", enCours: "Aucune idée en cours",
        enCoursDetail: "Les idées décidées sont rangées dans les Archives, ci-dessous.", symbole: "lightbulb")

    var body: some View {
        let liste = etat.idees
        // Comme le site : les plus soutenues d'abord, puis le filtre par état.
        let triees = liste.elements.sorted { $0.nbVotes > $1.nbVotes }.filter { filtre == nil || $0.statut == filtre }
        let enCours = triees.filter { $0.archivee != true }
        List {
            if liste.phase == .pret {
                Section {
                    ForEach(enCours) { ligne($0) }
                } header: {
                    filtres(compte: enCours.count)
                }
                SectionArchives(elements: triees.filter { $0.archivee == true }) { ligne($0) }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .overlay {
            EtatListeCommunaute(
                phase: liste.phase.neutre, vide: liste.elements.isEmpty,
                toutArchive: enCours.isEmpty && !triees.isEmpty, textes: Self.textes
            ) { Task { await etat.charger(.idees, installation, avec: parcours.serviceCommunaute) } }
        }
        .refreshable { await etat.charger(.idees, installation, avec: parcours.serviceCommunaute) }
        .task { await etat.charger(.idees, installation, avec: parcours.serviceCommunaute) }
    }

    private func ligne(_ idee: Idee) -> some View {
        NavigationLink {
            DetailIdee(etat: etat, id: idee.id, installation: installation)
        } label: {
            LigneIdee(idee: idee) {
                Task { await etat.basculerVote(idee, installation, avec: parcours.serviceCommunaute) }
            }
        }
        .listRowBackground(palette.surface)
        .accessibilityIdentifier("idee.\(idee.id)")
    }

    /// « Toutes », puis chaque état ; la pastille retenue porte le nombre affiché.
    private func filtres(compte: Int) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Pastille(libelle: "Toutes", retenue: filtre == nil) { choisir(nil) }
                ForEach(RegleCommunaute.statutsIdee, id: \.code) { statut in
                    Pastille(libelle: statut.libelle, retenue: filtre == statut.code) { choisir(statut.code) }
                }
            }
            .padding(.vertical, 4)
        }
        .textCase(nil)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
        .sensoryFeedback(.selection, trigger: filtre)
    }

    private func choisir(_ statut: String?) {
        withAnimation(.snappy) { filtre = statut }
    }
}

/// Une idée : le cœur et ses voix à gauche, le titre, l'état, l'aperçu, les réponses.
private struct LigneIdee: View {
    let idee: Idee
    let voter: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            BoutonCoeur(idee: idee, voter: voter)
            VStack(alignment: .leading, spacing: 6) {
                Text(idee.titre).font(.headline).foregroundStyle(palette.text)
                let statut = RegleCommunaute.statutsIdee.first { $0.code == idee.statut }
                PastilleTeinte(libelle: statut?.libelle ?? idee.statut, badge: statut?.pastille ?? "badge-gray")
                Text(TexteDuSite.apercu(idee.description))
                    .font(.subheadline)
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(3)
                if let nombre = idee.reponses?.count, nombre > 0 {
                    Label(nombre > 1 ? "\(nombre) réponses" : "1 réponse", systemImage: "bubble.left")
                        .font(.caption)
                        .foregroundStyle(palette.textMuted)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Le cœur : plein quand on soutient l'idée ; un toucher bascule, sans ouvrir l'idée.
struct BoutonCoeur: View {
    let idee: Idee
    let voter: () -> Void
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit

    var body: some View {
        Button(action: voter) {
            VStack(spacing: 2) {
                Image(systemName: idee.monVote ? "heart.fill" : "heart")
                    .font(.title3)
                    .foregroundStyle(idee.monVote ? palette.danger : palette.textMuted)
                    .symbolEffect(.bounce, value: mouvementReduit ? false : idee.monVote)
                Text(idee.nbVotes, format: .number)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(idee.nbVotes)))
                    .foregroundStyle(palette.text)
            }
            .frame(minWidth: Mise.cible, minHeight: Mise.cible)
            .contentShape(.rect)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(idee.monVote ? "Retirer mon vote" : "Voter pour cette idée")
        .accessibilityValue("\(idee.nbVotes) votes")
        .accessibilityIdentifier("idee.\(idee.id).voter")
    }
}

/// Une idée ouverte : sa description entière, le cœur, et le fil des réponses.
struct DetailIdee: View {
    let etat: EtatCommunaute
    let id: Int
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var signalee: CibleCommunaute?

    var body: some View {
        let service = parcours.serviceCommunaute
        if let idee = etat.idees.elements.first(where: { $0.id == id }) {
            List {
                Section {
                    HStack(alignment: .top, spacing: 14) {
                        BoutonCoeur(idee: idee) {
                            Task { await etat.basculerVote(idee, installation, avec: service) }
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            let statut = RegleCommunaute.statutsIdee.first { $0.code == idee.statut }
                            PastilleTeinte(
                                libelle: statut?.libelle ?? idee.statut, badge: statut?.pastille ?? "badge-gray")
                            Text(idee.titre).font(.titre(.title2)).foregroundStyle(palette.text)
                                .accessibilityAddTraits(.isHeader)
                            Text(FormatsDuSite.dateCourte(idee.creeLe))
                                .font(.footnote).foregroundStyle(palette.textMuted)
                        }
                    }
                    Text(TexteDuSite.riche(idee.description))
                        .font(.body).foregroundStyle(palette.text).tint(palette.primary)
                }
                .listRowBackground(palette.surface)
                FilReponses(
                    reponses: idee.reponses ?? [], cible: .idee(idee.id), etat: etat, installation: installation,
                    onglet: .idees, signalee: $signalee)
            }
            .scrollContentBackground(.hidden)
            .background(palette.bg)
            .navigationTitle("Idée")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if idee.auteurId != etat.moi?.id {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                signalee = .idee(idee.id)
                            } label: {
                                Label("Signaler cette idée au conseil syndical", systemImage: "flag")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle").accessibilityLabel("Plus d'actions")
                        }
                    }
                }
            }
            .modifier(SignalementCommunaute(cible: $signalee) { cible, motif in
                Task { await etat.signaler(cible, motif: motif, installation, avec: service) }
            })
            .safeAreaInset(edge: .bottom, spacing: 0) {
                @Bindable var etat = etat
                BandeauCommunaute(bandeau: $etat.bandeau)
            }
        } else {
            ContentUnavailableView("Idée introuvable", systemImage: "lightbulb.slash")
        }
    }
}
