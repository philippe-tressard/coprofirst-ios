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
                    if etat.moi?.estConseil == true {
                        Text("Créer, modifier ou stopper un sondage se fait sur le site.")
                            .font(.footnote)
                            .foregroundStyle(palette.textMuted)
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

/// Un sondage : la question, son état, sa clôture et ses votants. Anonyme, comme sur
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
                PastilleCommunaute(
                    libelle: sondage.cloture ? "🔒 Clôturé" : "Ouvert",
                    pastille: sondage.cloture ? "badge-gray" : "badge-green")
                if let fin = sondage.clotureLe, !sondage.cloture {
                    Text("Clôture le \(fin.jourDuSite)")
                }
                Text(sondage.nbVotants == 1 ? "1 votant" : "\(sondage.nbVotants) votants")
            }
            .font(.caption)
            .foregroundStyle(palette.textMuted)
        }
        .padding(.vertical, 4)
    }
}

/// Des étiquettes côte à côte, qui passent à la ligne quand la place manque (grand texte).
struct FlowEtiquettes: Layout {
    var espace: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rangees = ranger(largeur: proposal.width ?? .infinity, subviews)
        let hauteur = rangees.map(\.hauteur).reduce(0, +) + espace * CGFloat(max(rangees.count - 1, 0))
        return CGSize(width: proposal.width ?? rangees.map(\.largeur).max() ?? 0, height: hauteur)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for rangee in ranger(largeur: bounds.width, subviews) {
            var x = bounds.minX
            for indice in rangee.indices {
                let proposition = ProposedViewSize(width: bounds.width, height: nil)
                let taille = subviews[indice].sizeThatFits(proposition)
                subviews[indice].place(
                    at: CGPoint(x: x, y: y + (rangee.hauteur - taille.height) / 2), proposal: proposition)
                x += taille.width + espace
            }
            y += rangee.hauteur + espace
        }
    }

    private struct Rangee {
        var indices: [Int] = []
        var largeur: CGFloat = 0
        var hauteur: CGFloat = 0
    }

    private func ranger(largeur: CGFloat, _ subviews: Subviews) -> [Rangee] {
        var rangees = [Rangee()]
        // Une étiquette ne dépasse jamais la largeur : trop longue, elle passe à la ligne en elle-même.
        let proposition = ProposedViewSize(width: largeur.isFinite ? largeur : nil, height: nil)
        for (indice, vue) in subviews.enumerated() {
            let taille = vue.sizeThatFits(proposition)
            let ajout = rangees[rangees.count - 1].indices.isEmpty ? taille.width : taille.width + espace
            if rangees[rangees.count - 1].largeur + ajout > largeur, !rangees[rangees.count - 1].indices.isEmpty {
                rangees.append(Rangee())
            }
            let derniere = rangees.count - 1
            rangees[derniere].largeur += rangees[derniere].indices.isEmpty ? taille.width : taille.width + espace
            rangees[derniere].hauteur = max(rangees[derniere].hauteur, taille.height)
            rangees[derniere].indices.append(indice)
        }
        return rangees
    }
}
