// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import OpenAPIRuntime

/// Un refus du serveur, dit avec SA phrase (`{"detail": "…"}`) — comme le site
/// l'affiche (#41). Il voyage dans `ErreurService.refus` : un écran qui montre
/// `ErreurService.depuis(error).phrase` montre la phrase du serveur, sans rien de plus.
/// Sa lecture dans une réponse refusée : `ErreurService.depuisRefus`, ci-dessous, et pour
/// l'iPhone `ServiceAPI+Refus.swift`. Ce fichier-ci est compilé aussi par l'Apple TV
/// (`project.yml`, cible `CoproFirstTV`), qui lit ainsi les refus de son appairage.
struct RefusDuServeur: Equatable, Sendable {
    let phrase: String
}

extension RefusDuServeur {
    /// La plus longue phrase de refus qu'un corps porte : au-delà, ce n'en est pas une.
    static let plafond = 64 * 1024

    /// Le `detail` d'un corps de refus, s'il est une phrase (une erreur de validation
    /// sert une liste : elle ne s'affiche pas).
    static func detail(_ corps: Data) -> String? {
        struct Detail: Decodable { let detail: String }
        guard let lu = try? JSONDecoder().decode(Detail.self, from: corps) else { return nil }
        let phrase = lu.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        return phrase.isEmpty ? nil : phrase
    }
}

extension ErreurService {
    /// Le refus d'un geste, lu dans son statut et son corps (`{"detail": "…"}`).
    static func depuisRefus(_ statut: Int, corps: Data?) -> ErreurService {
        if statut == 401 { return .sessionExpiree }
        guard let phrase = corps.flatMap(RefusDuServeur.detail) else { return .depuisLecture(statut) }
        return .refus(RefusDuServeur(phrase: phrase))
    }
}

/// Un service qui lit les refus du client GÉNÉRÉ : `ServiceAPI` (l'iPhone) et le service de
/// l'écran de hall (l'Apple TV). Une seule écriture, adoptée par les deux.
protocol LitLesRefus {}

extension LitLesRefus {
    /// La réponse non documentée d'un GESTE (écriture) : la phrase du serveur quand il
    /// en donne une, sinon le cas d'`ErreurService` que dit le statut. Une LECTURE
    /// refusée garde `ErreurService.depuisLecture` : « introuvable », sans la phrase.
    static func refus(_ statut: Int, _ reponse: UndocumentedPayload) async -> ErreurService {
        let corps: Data? =
            if let flux = reponse.body { try? await Data(collecting: flux, upTo: RefusDuServeur.plafond) } else { nil }
        return ErreurService.depuisRefus(statut, corps: corps)
    }
}
