// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// La liaison iPhone ↔ montre (#226). ÉTEINTE dans ce lot : la montre ne se relie pas, ne
/// garde rien, n'appelle rien — elle dit seulement de l'ouvrir par l'iPhone. Elle s'allume
/// avec le lot de la liaison, quand le plancher sert les routes `/montres` (contrat 2.4.0,
/// coprofirst#2771) : l'iPhone émet le jeton de montre et le transmet par WatchConnectivity.
/// Comme `LiaisonMontre.ACTIF` de la montre Wear OS.
enum LiaisonMontre {
    static let active = false
}

/// Ce que la montre montre en s'ouvrant.
enum EtatMontre: Equatable {
    /// Jamais reliée, ou liaison éteinte.
    case nonReliee
    /// Reliée par l'iPhone : le nom de la résidence (en tête de la cloche) et d'où lire ses
    /// alertes. Le nom vient de l'iPhone à l'appairage, jamais du jeton.
    case reliee(residence: String, source: SourceDeLaCloche)

    /// L'état au lancement. Liaison éteinte : « non reliée ». En Debug, `-api-simulee` relie
    /// la montre à une résidence inventée (`ClocheSimulee`) : aucune requête ne part.
    static func auLancement(_ arguments: [String]) -> EtatMontre {
        #if DEBUG
        if arguments.contains("-api-simulee") {
            return .reliee(residence: ClocheSimulee.residence, source: .simulee(ClocheSimulee.reglage(arguments)))
        }
        #endif
        return .nonReliee
    }
}
