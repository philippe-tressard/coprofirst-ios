// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce que la montre montre en s'ouvrant.
enum EtatMontre: Equatable {
    /// Jamais reliée, liaison échue ou éteinte, jeton refusé : la montre attend l'iPhone.
    case nonReliee
    /// Reliée par l'iPhone : le nom de la résidence (en tête de la cloche) et d'où lire ses
    /// alertes. Le nom vient de l'iPhone à la liaison, jamais du jeton.
    case reliee(residence: String, source: SourceDeLaCloche)

    /// L'état que donne le coffre : la liaison qui vaut encore (`Liaisons.valide`).
    static func depuis(
        _ coffre: any CoffreLiaison, active: Bool = LiaisonMontre.active, maintenant: Date = .now
    ) -> EtatMontre {
        guard active, let liaison = Liaisons.valide(coffre, maintenant: maintenant) else { return .nonReliee }
        return .reliee(residence: liaison.residence, source: .jeton(liaison))
    }

    #if DEBUG
    /// En Debug, `-api-simulee` relie la montre à une résidence inventée (`ClocheSimulee`) :
    /// aucune requête ne part.
    static func simule(_ arguments: [String]) -> EtatMontre? {
        guard arguments.contains("-api-simulee") else { return nil }
        return .reliee(residence: ClocheSimulee.residence, source: .simulee(ClocheSimulee.reglage(arguments)))
    }
    #endif
}
