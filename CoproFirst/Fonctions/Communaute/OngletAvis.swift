// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les avis sur l'APPLICATION (pas sur la résidence) : un filtre par note, chaque avis
/// déplié, la réponse de l'équipe. L'auteur corrige ou archive le sien ; répondre et
/// retenir pour coprofirst.fr se fait sur le site.
struct OngletAvis: View {
    let etat: EtatCommunaute
    let installation: Installation
    let modifier: () -> Void
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var note: Int?

    static let textes = TextesListe(
        vide: "Aucun avis pour l'instant",
        videDetail: "Dites-nous ce que l'application vous apporte : votre avis nous aide à l'améliorer.",
        erreur: "Impossible d'afficher les avis", enCours: "Aucun avis en cours",
        enCoursDetail: "Les avis retirés sont rangés dans les Archives, ci-dessous.", symbole: "star")

    var body: some View {
        let liste = etat.avis
        let retenus = liste.elements.filter { note == nil || $0.note == note }
        let enCours = retenus.filter { !$0.archivee }
        List {
            Section {
                Text("""
                    Un problème, un bogue ? Les avis ne sont pas faits pour ça : ouvrez une affaire, \
                    elle sera suivie jusqu'à sa résolution.
                    """)
                    .font(.footnote)
                    .foregroundStyle(palette.textMuted)
                    .listRowBackground(palette.infoFond)
            }
            if liste.phase == .pret {
                Section {
                    ForEach(enCours) { ligne($0) }
                } header: {
                    filtres
                } footer: {
                    if etat.gestionnaireAvis {
                        Text("Répondre aux avis et retenir ceux de coprofirst.fr se fait sur le site.")
                    }
                }
                SectionArchives(elements: retenus.filter(\.archivee)) { ligne($0) }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .overlay {
            EtatListeCommunaute(
                phase: liste.phase.neutre, vide: liste.elements.isEmpty,
                toutArchive: enCours.isEmpty && !retenus.isEmpty, textes: Self.textes
            ) { Task { await etat.charger(.avis, installation, avec: parcours.serviceCommunaute) } }
        }
        .refreshable { await etat.charger(.avis, installation, avec: parcours.serviceCommunaute) }
        .task { await etat.charger(.avis, installation, avec: parcours.serviceCommunaute) }
    }

    private func ligne(_ avis: AvisResident) -> some View {
        CarteAvis(avis: avis)
            .listRowBackground(palette.surface)
            .swipeActions(edge: .trailing) { gestes(avis) }
            .contextMenu { gestes(avis) }
            .accessibilityIdentifier("avis.\(avis.id)")
    }

    /// Corriger (l'auteur), archiver (l'auteur ou celui qui gère le site), restaurer
    /// (quand le serveur le permet) — archiver, jamais supprimer.
    @ViewBuilder
    private func gestes(_ avis: AvisResident) -> some View {
        if avis.estAuteur, !avis.archivee {
            Button(action: modifier) { Label("Modifier", systemImage: "pencil") }
                .tint(palette.primaryPlein)
        }
        if !avis.archivee, avis.estAuteur || etat.gestionnaireAvis {
            Button { Task { await archiver(avis, true) } } label: { Label("Archiver", systemImage: "archivebox") }
                .tint(palette.textMuted)
        }
        if avis.archivee, avis.restaurable {
            Button { Task { await archiver(avis, false) } } label: {
                Label("Restaurer", systemImage: "arrow.uturn.backward")
            }
            .tint(palette.primaryPlein)
        }
    }

    private func archiver(_ avis: AvisResident, _ archive: Bool) async {
        let service = parcours.serviceCommunaute
        _ = await etat.agir(archive ? "Archivé" : "Restauré", recharger: .avis, installation, avec: service) {
            try await service.archiverAvis(avis.id, archive: archive, dans: installation)
            return nil
        }
    }

    private var filtres: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Pastille(libelle: "Toutes", retenue: note == nil) { withAnimation(.snappy) { note = nil } }
                ForEach([5, 4, 3, 2, 1], id: \.self) { valeur in
                    Pastille(libelle: "\(valeur) ★", retenue: note == valeur) {
                        withAnimation(.snappy) { note = valeur }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .textCase(nil)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
        .sensoryFeedback(.selection, trigger: note)
    }
}

/// Un avis : ses étoiles, le titre, à qui il se lit, l'auteur, le texte, « Ce qui a
/// manqué », et la réponse de l'équipe.
private struct CarteAvis: View {
    let avis: AvisResident
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Etoiles(note: avis.note)
            Text(avis.titre).font(.headline).foregroundStyle(palette.text)
            FlowEtiquettes(espace: 6) {
                if !avis.luDeTous { PastilleCommunaute(libelle: "Auteur et conseil seulement") }
                if avis.retenu { PastilleCommunaute(libelle: "Retenu pour coprofirst.fr", pastille: "badge-green") }
                if let auteur = [avis.auteurNom, avis.auteurRole].compactMap({ $0 }).joined(separator: " · ").nonVide {
                    Text(auteur).font(.caption).foregroundStyle(palette.textMuted)
                }
                Text(avis.creeLe.jourDuSite).font(.caption).foregroundStyle(palette.textMuted)
            }
            Text(TexteDuSite.riche(avis.description))
                .font(.subheadline).foregroundStyle(palette.text).tint(palette.primary)
            if let remarque = avis.remarque?.nonVide {
                (Text("Ce qui a manqué — ").bold() + Text(remarque))
                    .font(.subheadline)
                    .foregroundStyle(palette.orangeTexte)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.orangeFond, in: .rect(cornerRadius: 10, style: .continuous))
            }
            if let reponse = avis.reponse?.nonVide {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Réponse de l'équipe" + (avis.reponseLe.map { " · \($0.jourDuSite)" } ?? ""))
                        .styleLibelle()
                    Text(reponse).font(.subheadline).foregroundStyle(palette.text)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.infoFond, in: .rect(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(.vertical, 4)
    }
}

/// Les étoiles d'une note : « 4 étoiles sur 5 » pour VoiceOver.
private struct Etoiles: View {
    let note: Int
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { rang in
                Image(systemName: rang <= note ? "star.fill" : "star")
                    .foregroundStyle(rang <= note ? palette.warning : palette.border)
            }
        }
        .font(.subheadline)
        .accessibilityElement()
        .accessibilityLabel(note > 1 ? "\(note) étoiles sur 5" : "\(note) étoile sur 5")
    }
}

fileprivate extension String {
    /// La chaîne, ou rien si elle est vide.
    var nonVide: String? { isEmpty ? nil : self }
}
