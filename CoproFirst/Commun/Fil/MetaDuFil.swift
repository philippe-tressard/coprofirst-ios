// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import OpenAPIRuntime

/// Ce que l'app relit de `meta.affaire` d'un élément du fil — la ligne de pastilles
/// d'une affaire (`flux/commun.pastilles_affaire`) : ses dates et son délai (`EcheanceDuFil`,
/// #75), ses natures (`NatureDeLaCarte`, #78) — et les pièces jointes de l'élément. `meta` est un dictionnaire libre du contrat,
/// donc relu (`Relecture`) ; une lecture, deux usages.
struct MetaDuFil: Decodable {
    let affaire: AffaireServie?
    /// Les pièces jointes de l'élément (`meta.photos_urls`, `meta.fichiers_urls`), que la
    /// carte signale (`VignettePieces`) et que le résumé montre (`PiecesJointesView`).
    let photosUrls: [String]?
    let fichiersUrls: [String]?

    var pieces: PiecesJointes { PiecesJointes(urls: (photosUrls ?? []) + (fichiersUrls ?? [])) }

    struct AffaireServie: Decodable {
        let debut: String?
        let fin: String?
        let echeance: EcheanceServie?
        /// Les natures que le serveur DÉRIVE (`utils/nature_affaire`) — jamais redérivées ici.
        let natures: [String]?
    }

    struct EcheanceServie: Decodable {
        let etat: String
        let libelle: String?
        let plusieursJours: Bool?
    }

    /// `nil` si `meta` est absent ou illisible.
    init?(meta: OpenAPIObjectContainer?) {
        guard let meta else { return nil }
        // `Relecture` relit une liste d'objets libres : un seul, ici.
        guard let lu = (try? Relecture.lire([MetaDuFil].self, depuis: [meta]))?.first else { return nil }
        self = lu
    }

    /// Le même `meta`, en JSON — l'API simulée le sert ainsi, à la forme du serveur.
    init?(json: String) {
        guard let lu = try? Relecture.lire(MetaDuFil.self, json: Data(json.utf8)) else { return nil }
        self = lu
    }
}
