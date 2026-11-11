// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

extension Lancement {
    /// Le centre de notifications d'iOS ; en Debug, sous l'API simulée, le centre simulé
    /// (`LancementSimule.push`) — un build Release ne le compile pas (#84).
    @MainActor
    static func push(_ arguments: [String]) -> NotificationsPush {
        #if DEBUG
        if let push = LancementSimule.push(arguments) { return push }
        #endif
        return NotificationsPush(centre: CentreSysteme())
    }
}

#if DEBUG
extension LancementSimule {
    /// Aucune alerte système : l'autorisation est dite par `-push non-demandee|refusee`,
    /// accordée sinon — les écrans et captures des autres lots ne voient pas l'offre.
    @MainActor
    static func push(_ arguments: [String]) -> NotificationsPush? {
        guard arguments.contains("-api-simulee") else { return nil }
        let etat: AutorisationPush =
            switch argument("-push", arguments) {
            case "non-demandee": .nonDemandee
            case "refusee": .refusee
            default: .accordee
            }
        let suite = "fr.coprofirst.app.simulee.push"
        let reglages = UserDefaults(suiteName: suite) ?? .standard
        reglages.removePersistentDomain(forName: suite)
        return NotificationsPush(centre: CentreSimule(etat), reglages: reglages)
    }

    /// `-push-touchee` : une notification de la résidence inventée, touchée — comme si
    /// l'appareil y était enregistré d'un passage précédent.
    @MainActor
    static func toucherNotification(_ arguments: [String], _ push: NotificationsPush) {
        guard arguments.contains("-api-simulee"), arguments.contains("-push-touchee") else { return }
        push.touchee(abonnement: push.abonnements.abonnement(pour: ServiceSimule.residence))
    }
}
#endif
