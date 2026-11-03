// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « Répondre » : une suite écrite, ajoutée à l'Historique (POST …/evolutions).
struct RepondreFeuille: View {
    let affaire: DetailAffaire
    let installation: Installation
    let envoyee: () -> Void
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var texte = ""
    @State private var enCours = false
    @State private var erreur: ErreurService?
    @State private var reussite = 0
    @FocusState private var actif: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text(affaire.titre)
                    .font(.subheadline)
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(2)
                TextEditor(text: $texte)
                    .focused($actif)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 140)
                    .background(palette.surface, in: .rect(cornerRadius: Mise.rayon, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Mise.rayon, style: .continuous)
                            .strokeBorder(palette.borderChamp, lineWidth: 1)
                    }
                    .accessibilityLabel("Votre réponse")
                    .accessibilityIdentifier("repondre.texte")
                if let erreur { MessageErreur(texte: erreur.phrase) }
                Spacer(minLength: 0)
            }
            .padding(Mise.marge)
            .background(palette.bg)
            .navigationTitle("Répondre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Envoyer") { Task { await envoyer() } }
                        .disabled(texte.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || enCours)
                        .accessibilityIdentifier("repondre.envoyer")
                }
            }
            .onAppear { actif = true }
            .sensoryFeedback(.success, trigger: reussite)
            .sensoryFeedback(.error, trigger: erreur) { _, nouvelle in nouvelle != nil }
        }
    }

    private func envoyer() async {
        enCours = true
        defer { enCours = false }
        do {
            try await parcours.service.repondre(
                texte.trimmingCharacters(in: .whitespacesAndNewlines), a: affaire.id, dans: installation)
            reussite += 1
            envoyee()
        } catch {
            withAnimation(.snappy) { erreur = ErreurService.depuis(error) }
        }
    }
}
