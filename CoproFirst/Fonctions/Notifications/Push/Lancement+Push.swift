// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

extension Lancement {
    /// Le centre d'iOS ; sous `-api-simulee`, le centre simulé — aucune alerte système,
    /// l'autorisation dite par `-push non-demandee|refusee`, accordée sinon : les écrans
    /// et captures des autres lots ne voient pas l'offre de la cloche.
    @MainActor
    static func push(_ arguments: [String]) -> NotificationsPush {
        guard arguments.contains("-api-simulee") else { return NotificationsPush(centre: CentreSysteme()) }
        let etat: AutorisationPush =
            switch arguments.firstIndex(of: "-push").flatMap({ arguments.dropFirst($0 + 1).first }) {
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
    static func toucherSimule(_ arguments: [String], _ push: NotificationsPush) {
        guard arguments.contains("-api-simulee"), arguments.contains("-push-touchee") else { return }
        push.touchee(abonnement: push.abonnements.abonnement(pour: ServiceSimule.residence))
    }
}
