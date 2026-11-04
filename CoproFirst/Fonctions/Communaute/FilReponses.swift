// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le fil des réponses d'une idée ou d'une annonce : chaque réponse (le conseil
/// syndical en tête et en bleu — le serveur trie), puis le champ pour répondre.
/// Texte brut : une réponse n'est jamais du HTML.
struct FilReponses: View {
    let reponses: [ReponseCommunaute]
    let cible: CibleCommunaute
    let etat: EtatCommunaute
    let installation: Installation
    let onglet: OngletCommunaute
    @Binding var signalee: CibleCommunaute?
    var invite = "Votre réponse…"
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var texte = ""
    @State private var envoi = false
    @State private var aRetirer: ReponseCommunaute?
    @FocusState private var saisie: Bool

    var body: some View {
        Section {
            ForEach(reponses) { reponse in
                LigneReponse(reponse: reponse)
                    .listRowBackground(reponse.estCs == true ? palette.infoFond : palette.surface)
                    .swipeActions(edge: .trailing) {
                        if etat.peutRetirer(reponse) {
                            Button(role: .destructive) { aRetirer = reponse } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                        }
                        if reponse.auteurId != etat.moi?.id {
                            Button { signalee = .reponse(reponse.id) } label: { Label("Signaler", systemImage: "flag") }
                                .tint(palette.orange)
                        }
                    }
                    .contextMenu {
                        if reponse.auteurId != etat.moi?.id {
                            Button { signalee = .reponse(reponse.id) } label: {
                                Label("Signaler cette réponse", systemImage: "flag")
                            }
                        }
                        if etat.peutRetirer(reponse) {
                            Button(role: .destructive) { aRetirer = reponse } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                        }
                    }
            }
            HStack(alignment: .bottom, spacing: 10) {
                TextField(invite, text: $texte, axis: .vertical)
                    .lineLimit(1...6)
                    .focused($saisie)
                    .accessibilityIdentifier("reponses.saisie")
                Button {
                    Task { await envoyer() }
                } label: {
                    if envoi {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.up.circle.fill").font(.title2)
                    }
                }
                .disabled(texte.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || envoi)
                .frame(minWidth: Mise.cible, minHeight: Mise.cible)
                .accessibilityLabel("Répondre")
                .accessibilityIdentifier("reponses.envoyer")
            }
            .listRowBackground(palette.surface)
        } header: {
            let compte = reponses.count > 1 ? "💬 \(reponses.count) réponses" : "💬 1 réponse"
            Text(reponses.isEmpty ? "💬 Répondre" : compte)
                .styleLibelle()
        }
        .confirmationDialog(
            "Supprimer définitivement",
            isPresented: Binding(get: { aRetirer != nil }, set: { if !$0 { aRetirer = nil } }),
            titleVisibility: .visible, presenting: aRetirer
        ) { reponse in
            Button("Supprimer", role: .destructive) { Task { await retirer(reponse) } }
        } message: { _ in
            Text("Cette réponse\n\nCette action est irréversible.")
        }
    }

    private func envoyer() async {
        let contenu = texte.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !contenu.isEmpty else { return }
        envoi = true
        defer { envoi = false }
        let service = parcours.serviceCommunaute
        let reussi = await etat.agir("Réponse publiée", recharger: onglet, installation, avec: service) {
            try await service.repondreCommunaute(contenu, a: cible, dans: installation)
            return nil
        }
        if reussi {
            texte = ""
            saisie = false
        }
    }

    private func retirer(_ reponse: ReponseCommunaute) async {
        let service = parcours.serviceCommunaute
        _ = await etat.agir("Réponse supprimée", recharger: onglet, installation, avec: service) {
            try await service.supprimerReponseCommunaute(reponse.id, de: cible, dans: installation)
            return nil
        }
    }
}

/// Une réponse : son auteur, son bâtiment et son rôle, la date, puis le texte.
private struct LigneReponse: View {
    let reponse: ReponseCommunaute
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FlowEtiquettes(espace: 6) {
                Text(reponse.auteurNom ?? "Un résident")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.text)
                if let batiment = reponse.auteurBatiment { PastilleTeinte(libelle: batiment, badge: "badge-gray") }
                if let role = reponse.auteurRole {
                    PastilleTeinte(libelle: role, badge: reponse.estCs == true ? "badge-blue" : "badge-gray")
                }
                if reponse.estCs == true { Text("⭐").accessibilityHidden(true) }
                Text(FormatsDuSite.dateCourte(reponse.creeLe)).font(.caption).foregroundStyle(palette.textMuted)
            }
            Text(reponse.contenu)
                .font(.body)
                .foregroundStyle(palette.text)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
