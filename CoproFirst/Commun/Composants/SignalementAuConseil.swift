// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « Signaler au conseil syndical » : un motif obligatoire, puis l'envoi — les mots de
/// `signaler()` du site (`lib/signalements.ts`). Deux lecteurs : la Communauté et la
/// fiche d'un sondage (#38). La cible est celle de l'écran (une idée, un commentaire…).
struct SignalementAuConseil<Cible>: ViewModifier {
    @Binding var cible: Cible?
    let envoyer: (Cible, String) -> Void
    @State private var motif = ""

    func body(content: Content) -> some View {
        content.alert(
            "Signaler au conseil syndical", isPresented: Binding(get: { cible != nil }, set: { if !$0 { cible = nil } })
        ) {
            TextField("Pourquoi signalez-vous ce contenu ?", text: $motif, axis: .vertical)
            Button("Annuler", role: .cancel) { motif = "" }
            Button("Signaler") {
                if let cible { envoyer(cible, motif.trimmingCharacters(in: .whitespacesAndNewlines)) }
                motif = ""
            }
            .disabled(motif.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Le motif sera transmis au conseil syndical, avec le contenu concerné.")
        }
    }
}

extension View {
    func signalementAuConseil<Cible>(_ cible: Binding<Cible?>, envoyer: @escaping (Cible, String) -> Void)
        -> some View {
        modifier(SignalementAuConseil(cible: cible, envoyer: envoyer))
    }
}
