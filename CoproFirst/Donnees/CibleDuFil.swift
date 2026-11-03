// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce qu'ouvre un toucher sur une carte du fil — TOUJOURS quelque chose.
///
/// La règle est celle du site (`typeLink`, `front/src/lib/flux.ts`) : une affaire
/// (et une actualité, qui EST une affaire de catégorie Actualité) s'ouvre sur son
/// détail ; un sondage sur le sondage ; un document qui a une page, sur son
/// fichier ; tout le reste — ou ce qui n'a pas de page sur le site — sur un résumé.
enum CibleDuFil: Hashable, Sendable {
    case affaire(id: Int)
    case sondage(id: Int)
    case document(id: Int, nom: String?)
    /// `lien` : la page du site, s'il en a une (« Voir sur le site »).
    case resume(lien: String?)

    static let typesAffaire: Set<String> = ["ticket_ouvert", "ticket_resolu", "ticket_mis_a_jour", "publication"]

    /// Ce que \`meta\` d'un élément du fil désigne (\`routers/flux/*.py\` de coprofirst).
    struct Meta: Hashable, Sendable {
        var ticketId: Int?
        var sondageId: Int?
        var documentId: Int?
        var fichierNom: String?
    }

    static func pour(type: String, meta: Meta, lien: String?) -> CibleDuFil {
        if typesAffaire.contains(type), let id = meta.ticketId { return .affaire(id: id) }
        if type == "sondage_ouvert" || type == "sondage_clos", let id = meta.sondageId { return .sondage(id: id) }
        // Un document SANS lien n'a pas de page sur le site (catégorie non exposée) :
        // le site n'en montre rien de plus, l'app non plus.
        if type == "document", let id = meta.documentId, lien != nil { return .document(id: id, nom: meta.fichierNom) }
        return .resume(lien: lien)
    }

    /// La flèche de la carte, comme `typeVoirLabel` du site.
    var libelle: String {
        switch self {
        case .affaire: "Voir le détail"
        case .sondage: "Voir le sondage"
        case .document: "Ouvrir le document"
        case .resume: "Voir le résumé"
        }
    }
}
