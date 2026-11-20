// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

extension Lancement {
    /// La liaison avec l'Apple Watch (#226), abonnée au parcours : WatchConnectivity ; en
    /// Debug, sous l'API simulée, un canal sans montre (`CanalSimule`) — aucun jeton inventé ne
    /// part vers une vraie montre jumelée. Un build Release ne le compile pas (#84).
    @MainActor
    static func relierLaMontre(_ parcours: Parcours, _ arguments: [String]) async {
        guard let service = parcours.service.serviceMontres else { return }
        var canal: @MainActor () -> any CanalMontre = { CanalWatchConnectivity() }
        #if DEBUG
        if arguments.contains("-api-simulee") { canal = { CanalSimule() } }
        #endif
        await parcours.abonner(LiaisonsMontre(canal: canal, service: service))
    }
}

#if DEBUG
/// Un canal sans vraie montre : il dit si une montre est jointe et garde ce qu'il transmet —
/// lu par les tests.
@MainActor
final class CanalSimule: CanalMontre {
    var jointe: Bool
    private(set) var transmis: [MessageLiaison] = []

    init(jointe: Bool = false) {
        self.jointe = jointe
    }

    func montreJointe() async -> Bool { jointe }

    func transmettre(_ message: MessageLiaison) async {
        transmis.append(message)
    }
}
#endif
