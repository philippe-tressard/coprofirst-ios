// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import OpenAPIRuntime

/// Lire un refus du serveur (`RefusDuServeur`) dans la réponse du client généré :
/// `Self.refus(statut, reponse)` (`LitLesRefus`, partagé avec l'Apple TV).
extension ServiceAPI: LitLesRefus {
    /// Un 422 que le contrat documente en erreur de validation (`HTTPValidationError`,
    /// une LISTE) mais que le serveur sert avec SA phrase (`{"detail": "…"}`) — « un
    /// interlocuteur sans téléphone », #55 : le client généré ne le décode pas, la phrase
    /// se lit dans son erreur. Rien pour toute autre erreur.
    static func refusSousValidation(_ erreur: any Error) async -> ErreurService? {
        guard let erreur = erreur as? ClientError, erreur.response?.status.code == 422,
            let flux = erreur.responseBody, let corps = try? await Data(collecting: flux, upTo: RefusDuServeur.plafond),
            let phrase = RefusDuServeur.detail(corps)
        else { return nil }
        return .refus(RefusDuServeur(phrase: phrase))
    }
}
