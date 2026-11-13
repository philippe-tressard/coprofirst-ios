// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le pied d'une feuille de saisie, en barre d'outils : « Annuler » et le verbe de
/// soumission (« Enregistrer » par défaut — `PiedFormulaire` du site), remplacé par
/// « Enregistrement… » pendant l'envoi. `identifiant` sert aux tests d'interface.
struct BoutonsFeuille: ToolbarContent {
    let envoi: Bool
    var libelle = TextesFeuille.enregistrer
    /// Faux tant que le formulaire n'est pas assez rempli pour partir.
    var actif = true
    let identifiant: String
    let envoyer: () async -> Void
    @Environment(\.dismiss) private var fermer

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(TextesFeuille.annuler) { fermer() }
        }
        ToolbarItem(placement: .confirmationAction) {
            if envoi {
                ProgressView().accessibilityLabel(TextesFeuille.enCours)
            } else {
                Button(libelle) { Task { await envoyer() } }
                    .fontWeight(.semibold)
                    .disabled(!actif)
                    .gesteEnLigne()
                    .accessibilityIdentifier(identifiant)
            }
        }
    }
}

/// Les mots du pied de formulaire, écrits une fois (`PiedFormulaire.svelte`).
enum TextesFeuille {
    static let annuler = "Annuler"
    static let enregistrer = "Enregistrer"
    static let enCours = "Enregistrement…"
}
