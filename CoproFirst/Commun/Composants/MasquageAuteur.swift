// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les mots du masquage, ceux du site (`lib/masquages.ts`, `PersonnesMasquees.svelte`),
/// écrits une fois : la Communauté, une affaire et le Profil les lisent ici.
enum TextesMasquage {
    static let symbole = "eye.slash"
    static let confirmer = "Masquer"
    static let titreListe = "Personnes masquées"
    static let aide =
        "Vous ne voyez plus les annonces, les réponses ni les messages dans les affaires de ces personnes. "
        + "Elles n’en sont pas averties, et rien n’est supprimé."
    static let personne = "Personne n’est masqué"
    static let ouSeTrouve =
        "Le geste « Masquer ce que publie… » se trouve sur une annonce, une réponse ou un message."
    static let nePlusMasquer = "Ne plus masquer"
    static let message =
        "Vous ne verrez plus ses annonces, ses réponses ni ses messages dans les affaires. "
        + "Rien n’est supprimé, et cette personne n’en est pas avertie. "
        + "Vous pourrez revenir sur ce choix dans votre profil."

    /// Le geste, sur une publication : « Masquer ce que publie Camille ESSAI ».
    static func geste(_ nom: String) -> String { "Masquer ce que publie \(nom)" }
    static func question(_ nom: String) -> String { "Masquer ce que publie \(nom) ?" }
    static func masque(_ nom: String) -> String { "Ce que publie \(nom) est masqué pour vous" }
    static func demasque(_ nom: String) -> String { "Vous voyez de nouveau ce que publie \(nom)" }
    static func depuis(_ date: Date) -> String { "depuis le \(FormatsDuSite.date(date))" }
}

/// « Masquer ce que publie… » : la question du site (`confirmerPuis` de `masquer()`), puis
/// le geste que l'écran passe — il dit son avis et relit sa liste, à sa façon (la
/// Communauté par son bandeau, une affaire par son avis). Une alerte et non une feuille
/// d'actions : la phrase dit ce qui disparaît et où revenir sur ce choix, elle se lit.
struct ConfirmationMasquage: ViewModifier {
    @Binding var auteur: AuteurAMasquer?
    let masquer: (AuteurAMasquer) -> Void

    func body(content: Content) -> some View {
        content.alert(
            auteur.map { TextesMasquage.question($0.nom) } ?? "",
            isPresented: Binding(get: { auteur != nil }, set: { if !$0 { auteur = nil } }),
            presenting: auteur
        ) { choisi in
            Button("Annuler", role: .cancel) {}
            Button(TextesMasquage.confirmer) { masquer(choisi) }
                .accessibilityIdentifier("masquage.confirmer")
        } message: { _ in
            Text(TextesMasquage.message)
        }
    }
}

extension View {
    func confirmationMasquage(_ auteur: Binding<AuteurAMasquer?>, masquer: @escaping (AuteurAMasquer) -> Void)
        -> some View {
        modifier(ConfirmationMasquage(auteur: auteur, masquer: masquer))
    }
}
