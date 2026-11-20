// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce que la mesure d'audience demande à une installation (coprofirst#2726) : poster un
/// lot de pages vues, POST /telemetry/collect, en déclarant le canal de l'app et la classe de
/// l'appareil (#229). Réalisé par
/// `ServiceAPI` (client généré) et `ServiceSimule`.
protocol ServiceAudience: Sendable {
    /// Un lot de pages vues — au plus `LimitesAudience.evenementsParLot`, chacune de
    /// `LimitesAudience.page` caractères au plus : au-delà, le serveur refuse le lot entier.
    func envoyer(_ pages: [String], appareil: AppareilAudience, a installation: Installation) async throws
}

extension ServiceCoproFirst {
    var serviceAudience: (any ServiceAudience)? { self as? any ServiceAudience }
}
