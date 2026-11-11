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
    /// Écrit par le compte qui lit — `est_auteur`, tel que le SERVEUR le juge (contrat
    /// 1.26.0, #138) : sa bulle se range de son côté.
    let deMoi: Bool
    /// Le nom affiché de l'auteur, servi (`auteur_nom`, contrat 1.26.0, #138) : « Prénom
    /// NOM », la qualité d'un auteur détaché par la conservation, « Ancien résident ».
    /// `nil` d'une installation antérieure.
    let nom: String?
    /// « Un résident », « Le conseil syndical » — l'auteur détaché par la conservation
    /// (`auteur_qualite`, #2014) : ce que la bulle dit quand le nom n'est pas servi.
    let qualite: String?
    /// Une note du conseil : le serveur ne la sert qu'au conseil et à l'administration.
    let interne: Bool
    /// Les photos jointes (`/uploads/…`).
    let photos: [String]

    /// Ce que la bulle dit de son auteur : « Vous », le nom servi, la qualité servie, ou rien.
    var auteur: String? { deMoi ? "Vous" : nom?.nulSiVide ?? qualite }
}

extension MessageAffaire {
    /// `MessageRead` des tickets — le contrat le nomme par son module, un autre
    /// `MessageRead` (celui de la Communauté) existant à côté.
    typealias Servi = Components.Schemas.AppRoutersTicketsMessagesSchemasMessageRead

    /// Le fil servi, puis ce que son corps sert au-dessus du plancher (`auteur_nom`,
    /// `est_auteur`) — le MÊME branchement pour le service réel et l'API simulée.
    ///
    /// `moi` (l'identifiant du compte, `GET /auth/me`) ne sert qu'au REPLI d'une
    /// installation antérieure à 1.26.0, qui ne sert pas `est_auteur` : la comparaison à
    /// `auteur_id` d'avant, écrite ici seulement. Compte illisible : aucun message « à moi ».
    static func lus(_ servis: [Servi], corps: Data?, moi: Int?) -> [MessageAffaire] {
        let auDessus = Relecture.auDessusDuPlancher(parLigne: MessageAuDessusDuPlancher.self, corps: corps)
        return servis.map { message in
            let servi = auDessus[message.id]
            return MessageAffaire(
                id: message.id, contenu: message.contenu, date: message.creeLe,
                deMoi: servi?.estAuteur ?? (moi != nil && message.auteurId == moi), nom: servi?.auteurNom,
                qualite: message.auteurQualite, interne: message.interne,
                photos: (message.fichiersUrls ?? []).filter(Fichiers.estImage))
        }
    }
}

/// Ce que `MessageRead` des tickets sert au-dessus du plancher (contrat 1.26.0,
/// coprofirst#2680) : tout est facultatif.
struct MessageAuDessusDuPlancher: Decodable, Identifiable {
    let id: Int
    var auteurNom: String?
    var estAuteur: Bool?
}
