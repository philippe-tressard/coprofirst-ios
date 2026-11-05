// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Approuver un compte (`ValidationCompte.svelte`) : la case « Nouvel Arrivant », qui
/// ouvre deux champs et déclenche l'accueil ; puis l'enregistrement.
struct ValidationCompteFeuille: View {
    let compte: CompteEnAttente
    let valider: (AccueilArrivant?) async throws -> String
    let fait: (String) -> Void
    @State private var nouvelArrivant = false
    @State private var accueil = AccueilArrivant()
    @State private var envoi = false
    @State private var erreur: String?
    @Environment(\.dismiss) private var fermer
    @Environment(\.palette) private var palette

    var body: some View {
        NavigationStack {
            Form {
                if let erreur {
                    Section { MessageErreur(texte: erreur).listRowInsets(EdgeInsets()) }
                }
                Section {
                    Toggle(isOn: $nouvelArrivant.animation(.snappy)) {
                        Label(TextesComptesCS.nouvelArrivant, systemImage: "house")
                            .font(.headline)
                    }
                    .tint(palette.primaryPlein)
                    .accessibilityIdentifier("cs.validation.nouvel-arrivant")
                } footer: {
                    let miseEnGarde = Text(TextesComptesCS.nouvelArrivantMiseEnGarde).italic()
                    Text("\(TextesComptesCS.nouvelArrivantAide) \(miseEnGarde)")
                }
                if nouvelArrivant {
                    Section {
                        LabeledContent(TextesComptesCS.batimentLogement) {
                            TextField(TextesComptesCS.batimentIndication, text: $accueil.batiment)
                                .multilineTextAlignment(.trailing)
                        }
                        LabeledContent(TextesComptesCS.ancienResident) {
                            TextField(TextesComptesCS.ancienResidentIndication, text: $accueil.ancienResident)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.bg)
            .navigationTitle(FormatsDuSite.nom(compte.prenom, compte.nom))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { BoutonsFeuille(
                    envoi: envoi, libelle: TextesEspaceCS.approuver, identifiant: "cs.validation.enregistrer",
                    envoyer: envoyer) }
            .disabled(envoi)
        }
    }

    private func envoyer() async {
        envoi = true
        defer { envoi = false }
        do {
            fait(try await valider(nouvelArrivant ? accueil : nil))
            fermer()
        } catch {
            withAnimation(.snappy) { erreur = ErreurService.depuis(error).phrase }
        }
    }
}
