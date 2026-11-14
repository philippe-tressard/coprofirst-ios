// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce que la mesure d'audience demande à une installation (coprofirst#2726) : poster un
/// lot de pages vues, POST /telemetry/collect, en déclarant le canal de l'app. Réalisé par
/// `ServiceAPI` (client généré) et `ServiceSimule`.
protocol ServiceAudience: Sendable {
    /// Un lot de pages vues — au plus `LimitesAudience.evenementsParLot`, chacune de
    /// `LimitesAudience.page` caractères au plus : au-delà, le serveur refuse le lot entier.
    func envoyer(_ pages: [String], a installation: Installation) async throws
}

extension ServiceCoproFirst {
    var serviceAudience: (any ServiceAudience)? { self as? any ServiceAudience }
}

/// Le canal que l'app déclare dans son lot (`canal` de `LotAudience`, contrat 1.31.0) :
/// le serveur range ses vues sous « App iPhone ». Au-dessus du plancher : ajouté au corps
/// généré par `CorpsEnvoye.completer`, jamais écrit dans un corps fait à la main.
struct CanalAudience: Encodable, Sendable {
    let canal: String

    /// `ios` : une valeur de la liste du serveur (`utils/canaux_audience` de coprofirst) —
    /// une autre serait refusée (422).
    static let app = CanalAudience(canal: "ios")
}
