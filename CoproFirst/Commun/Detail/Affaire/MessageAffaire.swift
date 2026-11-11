// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Un message du fil d'une affaire (`TicketMessage` : GET et POST /tickets/{id}/messages).
///
/// ⚠️ À ne pas confondre avec une suite de l'Historique (`SuiteAffaire`, `TicketEvolution`) :
/// deux tables, deux fils, comme sur le site (`FilMessagesTicket.svelte`). « Répondre »
/// écrit ici ; le serveur double la réponse d'une suite « reponse » dans l'Historique.
struct MessageAffaire: Identifiable, Hashable, Sendable {
    let id: Int
    /// Le texte riche du site (HTML de l'éditeur).
    let contenu: String
    let date: Date
    /// Écrit par le compte qui lit : l'identifiant servi (`auteur_id`) contre celui du
    /// compte (`GET /auth/me`). Compte illisible : aucun message n'est « à moi ».
    let deMoi: Bool
    /// « Un résident », « Le conseil syndical » — l'auteur détaché par la conservation
    /// (`auteur_qualite`, #2014). Le contrat ne sert aucun autre nom d'auteur.
    let qualite: String?
    /// Une note du conseil : le serveur ne la sert qu'au conseil et à l'administration.
    let interne: Bool
    /// Ce qu'il joint (`fichiers_urls`) : photos et documents.
    let pieces: PiecesJointes

    /// Ce que la bulle dit de son auteur : « Vous », la qualité servie, ou rien.
    var auteur: String? { deMoi ? "Vous" : qualite }
}

extension MessageAffaire {
    /// `MessageRead` des tickets — le contrat le nomme par son module, un autre
    /// `MessageRead` (celui de la Communauté) existant à côté.
    typealias Servi = Components.Schemas.AppRoutersTicketsMessagesSchemasMessageRead

    init(_ message: Servi, moi: Int?) {
        self.init(
            id: message.id, contenu: message.contenu, date: message.creeLe,
            deMoi: moi != nil && message.auteurId == moi, qualite: message.auteurQualite,
            interne: message.interne, pieces: PiecesJointes(urls: message.fichiersUrls ?? []))
    }
}
