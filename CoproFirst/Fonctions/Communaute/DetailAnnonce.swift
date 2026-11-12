// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Une annonce ouverte : la description entière, les photos, le contact, « Où en est
/// cette annonce ? » pour son auteur, puis le fil des réponses. Corriger le texte ou
/// les photos se fait sur le site.
struct DetailAnnonce: View {
    let etat: EtatCommunaute
    let id: Int
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var fermer
    @State private var signalee: CibleCommunaute?
    @State private var aSupprimer = false
    @State private var retrait = RetraitDeReponse()

    var body: some View {
        if let annonce = etat.annonces.elements.first(where: { $0.id == id }) {
            let gestes = etat.gestesReponses(
                .annonce(annonce.id), onglet: .annonces, installation, avec: parcours.serviceCommunaute
            ) { signalee = .reponse($0.id) }
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(RegleCommunaute.libelle(annonce.typeAnnonce, dans: RegleCommunaute.typesAnnonce))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.textMuted)
                        Text(annonce.titre).font(.titre(.title2)).foregroundStyle(palette.text)
                            .accessibilityAddTraits(.isHeader)
                        EtiquettesAnnonce(annonce: annonce)
                        Text(FormatsDuSite.dateCourte(annonce.creeLe))
                            .font(.footnote).foregroundStyle(palette.textMuted)
                    }
                    Text(TexteDuSite.riche(annonce.description))
                        .font(.body).foregroundStyle(palette.text).tint(palette.primary)
                    PiecesJointesView(pieces: PiecesJointes(urls: annonce.photos ?? []), installation: installation)
                    contact(annonce)
                }
                .listRowBackground(palette.surface)
                if annonce.estAuteur == true { suivi(annonce) }
                FilReponses(
                    reponses: annonce.reponses ?? [], moi: etat.moi?.id, gestes: gestes, retrait: retrait,
                    invite: "Une question sur cette annonce ?")
            }
            .scrollContentBackground(.hidden)
            .background(palette.bg)
            .navigationTitle("Annonce")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { actions(annonce) }
            .confirmationDeRetrait(retrait, gestes: gestes)
            .signalementAuConseil($signalee) { cible, motif in
                Task { await etat.signaler(cible, motif: motif, installation, avec: parcours.serviceCommunaute) }
            }
            .confirmationDialog(
                "Supprimer définitivement", isPresented: $aSupprimer, titleVisibility: .visible
            ) {
                Button("Supprimer", role: .destructive) { Task { await supprimer(annonce) } }
            } message: {
                Text("L'annonce « \(annonce.titre) »\n\nCette action est irréversible.")
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                @Bindable var etat = etat
                BandeauCommunaute(bandeau: $etat.bandeau)
            }
        } else {
            ContentUnavailableView("Annonce introuvable", systemImage: "tag.slash")
        }
    }

    /// « 📬 Nom » : un courriel si l'auteur montre ses coordonnées, son nom sinon.
    @ViewBuilder
    private func contact(_ annonce: Annonce) -> some View {
        if let auteur = annonce.auteur {
            if let courriel = annonce.auteurEmail, let lien = URL(string: "mailto:\(courriel)") {
                Link(destination: lien) { Label(auteur, systemImage: "envelope") }
                    .tint(palette.primary)
                    .accessibilityIdentifier("annonce.contact")
            } else {
                Label(auteur, systemImage: "person").foregroundStyle(palette.textMuted)
            }
        }
    }

    /// Pour l'auteur : l'état de l'annonce, en pastilles.
    private func suivi(_ annonce: Annonce) -> some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(RegleCommunaute.statutsAnnonce, id: \.code) { statut in
                        Pastille(libelle: statut.libelle, retenue: annonce.statut == statut.code) {
                            Task { await changer(annonce, statut.code) }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        } header: {
            Text("Où en est cette annonce ?").styleLibelle()
        }
    }

    @ToolbarContentBuilder
    private func actions(_ annonce: Annonce) -> some ToolbarContent {
        let peutSupprimer = annonce.peutSupprimer
        let peutSignaler = annonce.estAuteur != true
        if peutSupprimer || peutSignaler {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if peutSignaler {
                        Button { signalee = .annonce(annonce.id) } label: {
                            Label("Signaler l'annonce", systemImage: "flag")
                        }
                    }
                    if peutSupprimer {
                        Button(role: .destructive) { aSupprimer = true } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").accessibilityLabel("Plus d'actions")
                }
            }
        }
    }

    private func changer(_ annonce: Annonce, _ statut: String) async {
        guard statut != annonce.statut else { return }
        let service = parcours.serviceCommunaute
        _ = await etat.agir("Statut mis à jour", recharger: .annonces, installation, avec: service) {
            try await service.changerStatutAnnonce(annonce.id, statut: statut, dans: installation)
            return nil
        }
    }

    private func supprimer(_ annonce: Annonce) async {
        let service = parcours.serviceCommunaute
        let reussi = await etat.agir("Annonce supprimée", recharger: .annonces, installation, avec: service) {
            try await service.supprimerAnnonce(annonce.id, dans: installation)
            return nil
        }
        if reussi { fermer() }
    }
}
