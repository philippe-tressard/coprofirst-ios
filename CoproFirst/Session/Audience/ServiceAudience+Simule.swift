// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

#if DEBUG
/// La mesure d'audience simulée : rien ne part ni ne se garde. Elle refuse comme le
/// serveur un lot hors de ses bornes (422), pour qu'un écart se voie aussi sans réseau.
extension ServiceSimule: ServiceAudience {
    func envoyer(_ pages: [String], appareil: AppareilAudience, a installation: Installation) async throws {
        guard pages.count <= LimitesAudience.evenementsParLot,
            pages.allSatisfy({ !$0.isEmpty && $0.count <= LimitesAudience.page })
        else { throw ErreurService.inattendue(422) }
    }
}
#endif
