// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les petites annonces : un filtre par type, une catégorie et un tri en menu, puis
/// les annonces ; un toucher ouvre l'annonce (photos, contact, réponses).
struct OngletAnnonces: View {
    let etat: EtatCommunaute
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var type: String?
    @State private var categorie: String?
    /// Un code de `TRIS_ANNONCE` : le premier est celui par défaut.
    @State private var tri = RegleCommunaute.trisAnnonce.first?.code ?? "recent"

    static let textes = TextesListe(
        vide: "Aucune annonce", videDetail: "Déposez la première annonce en touchant « + ».",
        erreur: "Impossible d'afficher les annonces", enCours: "Aucune annonce en cours",
        enCoursDetail: "Les annonces conclues sont rangées dans les Archives, ci-dessous.", symbole: "tag")

    var body: some View {
        let liste = etat.annonces
        let retenues = trier(
            liste.elements.filter {
                (type == nil || $0.typeAnnonce == type) && (categorie == nil || $0.categorie == categorie)
            })
        let enCours = retenues.filter { $0.archivee != true }
        List {
            if liste.phase == .pret {
                Section {
                    ForEach(enCours) { ligne($0) }
                } header: {
                    filtres
                }
                SectionArchives(elements: retenues.filter { $0.archivee == true }) { ligne($0) }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .overlay {
            EtatListeCommunaute(
                phase: liste.phase.neutre, vide: liste.elements.isEmpty,
                toutArchive: enCours.isEmpty && !retenues.isEmpty, textes: Self.textes
            ) { Task { await etat.charger(.annonces, installation, avec: parcours.serviceCommunaute) } }
        }
        .refreshable { await etat.charger(.annonces, installation, avec: parcours.serviceCommunaute) }
        .task { await etat.charger(.annonces, installation, avec: parcours.serviceCommunaute) }
    }

    private func ligne(_ annonce: Annonce) -> some View {
        NavigationLink {
            DetailAnnonce(etat: etat, id: annonce.id, installation: installation)
        } label: {
            LigneAnnonce(annonce: annonce)
        }
        .listRowBackground(palette.surface)
        .accessibilityIdentifier("annonce.\(annonce.id)")
    }

    /// Le prix absent passe toujours après les prix (le site le compte 999 999 en
    /// croissant, 0 en décroissant : même place).
    private func trier(_ annonces: [Annonce]) -> [Annonce] {
        switch tri {
        case "prix_asc": annonces.sorted { ($0.prix ?? .infinity) < ($1.prix ?? .infinity) }
        case "prix_desc": annonces.sorted { ($0.prix ?? -1) > ($1.prix ?? -1) }
        default: annonces.sorted { $0.creeLe > $1.creeLe }
        }
    }

    private var filtres: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Pastille(libelle: "Tous", retenue: type == nil) { withAnimation(.snappy) { type = nil } }
                    ForEach(RegleCommunaute.typesAnnonce, id: \.code) { genre in
                        Pastille(libelle: genre.libelle, retenue: type == genre.code) {
                            withAnimation(.snappy) { type = genre.code }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            // Côte à côte quand ils tiennent, l'un sous l'autre aux grandes tailles.
            ViewThatFits(in: .horizontal) {
                HStack { menuCategorie; Spacer(); menuTri }
                VStack(alignment: .leading, spacing: 8) { menuCategorie; menuTri }
            }
            .font(.subheadline.weight(.medium))
            .tint(palette.primary)
        }
        .textCase(nil)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
        .sensoryFeedback(.selection, trigger: [type ?? "", categorie ?? "", tri])
    }

    private var menuCategorie: some View {
        Menu {
            Picker("Catégorie", selection: $categorie.animation(.snappy)) {
                Text("Toutes catégories").tag(String?.none)
                ForEach(RegleCommunaute.categoriesAnnonce, id: \.code) {
                    Text($0.libelle).tag(Optional($0.code))
                }
            }
        } label: {
            Label(
                categorie.map { RegleCommunaute.libelle($0, dans: RegleCommunaute.categoriesAnnonce) }
                    ?? "Toutes catégories", systemImage: "line.3.horizontal.decrease.circle")
        }
    }

    private var menuTri: some View {
        Menu {
            Picker("Tri", selection: $tri.animation(.snappy)) {
                ForEach(RegleCommunaute.trisAnnonce, id: \.code) { Text($0.libelle).tag($0.code) }
            }
        } label: {
            Label(
                RegleCommunaute.libelle(tri, dans: RegleCommunaute.trisAnnonce),
                systemImage: "arrow.up.arrow.down")
        }
    }
}

/// Une annonce : le type, le titre, son statut, sa catégorie, le prix, l'auteur.
private struct LigneAnnonce: View {
    let annonce: Annonce
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(RegleCommunaute.libelle(annonce.typeAnnonce, dans: RegleCommunaute.typesAnnonce))
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.textMuted)
            Text(annonce.titre).font(.headline).foregroundStyle(palette.text)
            EtiquettesAnnonce(annonce: annonce)
            Text(TexteDuSite.apercu(annonce.description))
                .font(.subheadline)
                .foregroundStyle(palette.textMuted)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

/// Le statut, la catégorie, le prix (« Négociable ») et l'auteur — dans l'ordre du site ;
/// puis qui la lit et son lieu, servis (#129, #130).
struct EtiquettesAnnonce: View {
    let annonce: Annonce
    @Environment(\.palette) private var palette

    var body: some View {
        FlowEtiquettes(espace: 6) {
            let statut = RegleCommunaute.statutsAnnonce.first { $0.code == annonce.statut }
            PastilleTeinte(libelle: statut?.libelle ?? annonce.statut, badge: statut?.pastille ?? "badge-gray")
            PastilleTeinte(
                libelle: RegleCommunaute.libelle(annonce.categorie, dans: RegleCommunaute.categoriesAnnonce),
                badge: "badge-gray")
            if let prix = annonce.prix {
                Text(FormatsDuSite.montant(prix))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.text)
                if annonce.negotiable == true {
                    Text("Négociable").font(.caption).foregroundStyle(palette.textMuted)
                }
            }
            if let auteur = annonce.auteur {
                Text(auteur).font(.caption).foregroundStyle(palette.textMuted)
            }
            PastilleLecture(lecture: annonce.lecture)
            EtiquetteLieu(lieu: annonce.lieu).font(.caption).foregroundStyle(palette.textMuted)
        }
    }
}

extension Annonce {
    /// Le nom de l'auteur tel que le serveur le sert (prénom, nom).
    var auteur: String? {
        let nom = [auteurPrenom, auteurNom].compactMap { $0 }.joined(separator: " ")
        return nom.isEmpty ? nil : nom
    }
}
