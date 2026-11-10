// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Une réponse du fil d'une idée, d'une annonce, ou un commentaire de sondage
/// (`ReponseCommunauteRead`, typé dans le contrat). Texte brut, jamais du HTML.
/// Deux lecteurs — la Communauté et la fiche d'un sondage (#38) : il vit ici.
struct ReponseCommunaute: Codable, Hashable, Sendable, Identifiable {
    let id: Int
    let auteurId: Int?
    let contenu: String
    let creeLe: Date
    let auteurNom: String?
    let auteurBatiment: String?
    let auteurRole: String?
    let estCs: Bool?
    /// La conclusion de `peut_commenter`, SERVIE (coprofirst#2506) : l'auteur, le conseil
    /// syndical, l'administration. Absent : « non » — l'app ne la recalcule pas.
    var peutSupprimer = false
}

extension ReponseCommunaute {
    init(_ lue: Components.Schemas.ReponseCommunauteRead) {
        self.init(
            id: lue.id, auteurId: lue.auteurId, contenu: lue.contenu, creeLe: lue.creeLe, auteurNom: lue.auteurNom,
            auteurBatiment: lue.auteurBatiment, auteurRole: lue.auteurRole, estCs: lue.estCs,
            peutSupprimer: lue.peutSupprimer ?? false)
    }
}
