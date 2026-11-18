// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import OpenAPIRuntime

/// Lire un refus du serveur (`RefusDuServeur`) dans la réponse du client généré.
extension ServiceAPI {
    /// La réponse non documentée d'un GESTE (écriture) : la phrase du serveur quand il
    /// en donne une, sinon le cas d'`ErreurService` que dit le statut. Une LECTURE
    /// refusée garde `ErreurService.depuisLecture` : « introuvable », sans la phrase.
    static func refus(_ statut: Int, _ reponse: UndocumentedPayload) async -> ErreurService {
        let corps: Data? =
            if let flux = reponse.body { try? await Data(collecting: flux, upTo: 64 * 1024) } else { nil }
        return ErreurService.depuisRefus(statut, corps: corps)
    }

    /// Un 422 que le contrat documente en erreur de validation (`HTTPValidationError`,
    /// une LISTE) mais que le serveur sert avec SA phrase (`{"detail": "…"}`) — « un
    /// interlocuteur sans téléphone », #55 : le client généré ne le décode pas, la phrase
    /// se lit dans son erreur. Rien pour toute autre erreur.
    static func refusSousValidation(_ erreur: any Error) async -> ErreurService? {
        guard let erreur = erreur as? ClientError, erreur.response?.status.code == 422,
            let flux = erreur.responseBody, let corps = try? await Data(collecting: flux, upTo: 64 * 1024),
            let phrase = RefusDuServeur.detail(corps)
        else { return nil }
        return .refus(RefusDuServeur(phrase: phrase))
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
