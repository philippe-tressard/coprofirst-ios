// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Le relais des notifications sur téléphone, vu de l'app (#283) : est-il ALLUMÉ, et à
/// partir de quelle version une résidence ne fait sonner que l'alerte d'une actualité
/// urgente (spec push de coprofirst §12, décision de Philippe du 18/11/2026).
///
/// 🔴 **Éteint par défaut**, comme le service `notifications_push` de chaque installation.
/// Une résidence ne dit pas à un résident si son service est allumé (GET /config/services
/// est réservé à l'administration) : l'interrupteur vit donc ici, et il s'allume dans une
/// version de l'app une fois que Philippe a allumé le service (coprofirst#2875). Pas avant,
/// sinon l'offre de la cloche promettrait une alerte qui n'arrive jamais.
/// `NotificationsPushTests` garde cet état : l'allumer, c'est modifier ce test en le disant.
struct RelaisPush: Sendable {
    /// Le relais sonne-t-il ? Éteint : ni offre, ni enregistrement. Le retrait à la
    /// déconnexion et la notification touchée restent actifs, pour un appareil
    /// enregistré par une version précédente.
    let allume: Bool
    /// Une résidence sous cette version, ou qui sert une version illisible, ne reçoit rien.
    let depuis: VersionContrat

    /// Seule l'alerte d'une actualité ⚡ urgente part vers un téléphone (coprofirst#2789, spec
    /// push §12) : le contrat 2.10.0, devenu le PLANCHER (#313) — la porte `alertesPoussees`
    /// s'est retirée (#254). Le contrat 2.10.0 arrive avec v3.119.0, mais le filtre seulement
    /// avec v3.120.0 : une v3.119.0 pousserait toute la cloche. Elle n'a servi qu'une heure,
    /// service coupé, et aucune installation connue ne la sert (mesuré le 19/11/2026, puis par
    /// la concordance quotidienne : toutes au moins en v3.120.0).
    static let courant = RelaisPush(allume: false, depuis: .plancher)

    /// L'appareil s'offre et s'enregistre auprès de cette résidence.
    func sert(_ installation: Installation?) -> Bool {
        guard allume, let contrat = installation?.contrat else { return false }
        return contrat >= depuis
    }
}
