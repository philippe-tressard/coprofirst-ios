// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import WatchConnectivity

/// Le chemin de l'iPhone vers la montre. Un protocole : son seul transport réel est
/// WatchConnectivity (`CanalWatchConnectivity`) ; les tests et l'API simulée le simulent.
@MainActor
protocol CanalMontre: AnyObject {
    /// Une Apple Watch jumelée porte l'app CoproFirst.
    func montreJointe() async -> Bool

    func transmettre(_ message: MessageLiaison) async
}

/// WatchConnectivity, du côté de l'iPhone. Un message part par `transferUserInfo` : il attend
/// que la montre soit joignable et arrive dans l'ordre (la liaison, puis son effacement). Un
/// effacement ANNULE d'abord les liaisons pas encore remises : un jeton retiré ne part pas.
@MainActor
final class CanalWatchConnectivity: NSObject, CanalMontre, WCSessionDelegate {
    private var enAttente: [CheckedContinuation<Void, Never>] = []

    func montreJointe() async -> Bool {
        guard WCSession.isSupported() else { return false }
        await activer()
        return WCSession.default.isPaired && WCSession.default.isWatchAppInstalled
    }

    func transmettre(_ message: MessageLiaison) async {
        guard WCSession.isSupported() else { return }
        await activer()
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        if case .effacement = message {
            for transfert in session.outstandingUserInfoTransfers { transfert.cancel() }
        }
        session.transferUserInfo(message.donnees)
    }

    /// La session s'active une fois ; un appel pendant l'activation attend sa fin.
    private func activer() async {
        let session = WCSession.default
        guard session.activationState != .activated else { return }
        await withCheckedContinuation { suite in
            enAttente.append(suite)
            guard enAttente.count == 1 else { return }
            session.delegate = self
            session.activate()
        }
    }

    private func activationTerminee() {
        let suites = enAttente
        enAttente = []
        for suite in suites { suite.resume() }
    }

    nonisolated func session(
        _ session: WCSession, activationDidCompleteWith etat: WCSessionActivationState, error: (any Error)?
    ) {
        Task { @MainActor in self.activationTerminee() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Une autre montre a été choisie : la session se réactive pour elle.
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
