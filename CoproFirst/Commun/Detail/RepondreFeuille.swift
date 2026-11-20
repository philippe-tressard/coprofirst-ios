// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « Répondre » : un message du fil de l'affaire (POST …/messages), comme le site. Avec
/// `corrige`, la même feuille modifie SON message (PATCH …/messages/{id}, #211) : elle part
/// de son texte, et n'enregistre qu'un changement.
struct RepondreFeuille: View {
    let affaire: DetailAffaire
    let installation: Installation
    var corrige: MessageAffaire?
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
            .navigationTitle(corrige == nil ? "Répondre" : TextesMessage.titreCorrection)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(corrige == nil ? "Envoyer" : TextesMessage.enregistrer) { Task { await envoyer() } }
                        .disabled(!aEnvoyer || enCours)
                        .gesteEnLigne()
                        .accessibilityIdentifier("repondre.envoyer")
                }
            }
            .onAppear {
                if let corrige, texte.isEmpty { texte = TexteDuSite.saisi(html: corrige.contenu) ?? "" }
                actif = true
            }
            .sensoryFeedback(.success, trigger: reussite)
            .sensoryFeedback(.error, trigger: erreur) { _, nouvelle in nouvelle != nil }
        }
    }

    /// Un texte, et — pour une correction — un texte qui a changé.
    private var aEnvoyer: Bool {
        let saisi = texte.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !saisi.isEmpty else { return false }
        return corrige.map { TexteDuSite.html(saisi: saisi) != $0.contenu } ?? true
    }

    private func envoyer() async {
        enCours = true
        defer { enCours = false }
        let saisi = texte.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if let corrige {
                guard let service = parcours.service.gestesAffaire else {
                    throw ErreurService.refus(.init(phrase: AvisDuGeste.indisponible))
                }
                try await service.corrigerMessage(
                    TexteDuSite.html(saisi: saisi), corrige.id, de: affaire.id, dans: installation)
            } else {
                try await parcours.service.repondre(saisi, a: affaire.id, dans: installation)
            }
            reussite += 1
            envoyee()
        } catch {
            withAnimation(.snappy) { erreur = ErreurService.depuis(error) }
        }
    }
}
