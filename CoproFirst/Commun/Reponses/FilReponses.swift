// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Ce qu'un fil de réponses fait au serveur : l'écran qui le porte le dit (la Communauté
/// relit son onglet, la fiche d'un sondage se recharge). `publier` rend `false` sur un
/// échec : le texte saisi reste alors dans le champ (`Reponses.svelte`).
struct GestesReponses {
    let publier: @MainActor (String) async -> Bool
    let retirer: @MainActor (ReponseCommunaute) async -> Void
    let signaler: @MainActor (ReponseCommunaute) -> Void
}

/// La réponse dont on demande le retrait. La confirmation se pose sur la LISTE qui porte le
/// fil (`.confirmationDeRetrait`) : posée sur une section ou une rangée de liste, elle
/// s'affichait sans entrer dans l'arbre d'accessibilité, ou ne s'affichait qu'une fois sur
/// deux (#38).
@MainActor @Observable
final class RetraitDeReponse {
    var aRetirer: ReponseCommunaute?
}

extension View {
    /// « Supprimer définitivement » une réponse du fil — la boîte du site, en rouge.
    func confirmationDeRetrait(_ retrait: RetraitDeReponse, gestes: GestesReponses) -> some View {
        confirmationDialog(
            "Supprimer définitivement",
            isPresented: Binding(get: { retrait.aRetirer != nil }, set: { if !$0 { retrait.aRetirer = nil } }),
            titleVisibility: .visible, presenting: retrait.aRetirer
        ) { reponse in
            Button("Supprimer", role: .destructive) { Task { await gestes.retirer(reponse) } }
                .accessibilityIdentifier("reponses.confirmerSuppression")
        } message: { _ in
            Text("Cette réponse\n\nCette action est irréversible.")
        }
    }
}

/// Le fil des réponses — d'une idée, d'une annonce, ou les commentaires d'un sondage
/// (`Reponses.svelte`, le composant partagé du site ; deux lecteurs ici, #38) : chaque
/// réponse (le conseil syndical en tête et en bleu — le serveur trie), puis le champ
/// pour répondre. Texte brut : une réponse n'est jamais du HTML.
///
/// Les droits sont SERVIS : « Supprimer » suit `peut_supprimer` ; « Signaler » s'offre
/// sur les réponses des autres (`rep.auteur_id !== currentUserId`, la règle du site).
struct FilReponses: View {
    let reponses: [ReponseCommunaute]
    /// L'identifiant du compte (GET /auth/me) : on ne signale pas sa propre réponse.
    let moi: Int?
    let gestes: GestesReponses
    /// Tenu par l'écran, qui pose `.confirmationDeRetrait` sur sa liste.
    let retrait: RetraitDeReponse
    var invite = "Votre réponse…"
    /// L'en-tête de la section ; celui de la Communauté par défaut.
    var entete: (Int) -> String = FilReponses.enteteReponses
    @Environment(\.palette) private var palette
    @State private var texte = ""
    @State private var envoi = false
    @FocusState private var saisie: Bool

    /// « 💬 Répondre », « 💬 1 réponse », « 💬 3 réponses » — le bouton du site.
    nonisolated static func enteteReponses(_ nombre: Int) -> String {
        switch nombre {
        case 0: "💬 Répondre"
        case 1: "💬 1 réponse"
        default: "💬 \(nombre) réponses"
        }
    }

    var body: some View {
        Section {
            ForEach(reponses) { reponse in
                LigneReponse(reponse: reponse)
                    .listRowBackground(reponse.estCs == true ? palette.infoFond : palette.surface)
                    // Pas de balayage complet : il supprimerait ou signalerait d'un seul geste.
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if reponse.peutSupprimer {
                            Button(role: .destructive) { retrait.aRetirer = reponse } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                            .tint(palette.danger)
                            .accessibilityIdentifier("reponse.\(reponse.id).supprimer")
                        }
                        if peutSignaler(reponse) {
                            Button { gestes.signaler(reponse) } label: { Label("Signaler", systemImage: "flag") }
                                .tint(palette.orange)
                                .accessibilityIdentifier("reponse.\(reponse.id).signaler")
                        }
                    }
                    .contextMenu {
                        if peutSignaler(reponse) {
                            Button { gestes.signaler(reponse) } label: {
                                Label("Signaler cette réponse", systemImage: "flag")
                            }
                        }
                        if reponse.peutSupprimer {
                            Button(role: .destructive) { retrait.aRetirer = reponse } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                        }
                    }
                    .accessibilityIdentifier("reponse.\(reponse.id)")
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
            Text(entete(reponses.count))
                .styleLibelle()
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("reponses.entete")
        }
    }

    private func peutSignaler(_ reponse: ReponseCommunaute) -> Bool { reponse.auteurId != moi }

    private func envoyer() async {
        let contenu = texte.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !contenu.isEmpty else { return }
        envoi = true
        defer { envoi = false }
        if await gestes.publier(contenu) {
            texte = ""
            saisie = false
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
