// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Observation
import WatchConnectivity

/// La liaison de la montre, tenue pour l'app (#226) : elle écoute l'iPhone par
/// WatchConnectivity, garde ce qu'il donne (`CoffreLiaison`) et dit l'état à montrer. Un jeton
/// refusé par le serveur efface la liaison : la montre attend l'iPhone. Liaison éteinte
/// (`LiaisonMontre.active`), WatchConnectivity ne s'active pas.
@MainActor @Observable
final class LiaisonDeLaMontre: NSObject, WCSessionDelegate {
    private(set) var etat: EtatMontre
    @ObservationIgnored private let coffre: any CoffreLiaison
    @ObservationIgnored private let active: Bool
    /// En Debug, sous l'API simulée : l'état ne vient pas du coffre.
    @ObservationIgnored private var simulee = false

    init(coffre: any CoffreLiaison, active: Bool = LiaisonMontre.active) {
        self.coffre = coffre
        self.active = active
        etat = EtatMontre.depuis(coffre, active: active)
    }

    /// L'app : le Trousseau de la montre, et l'écoute de l'iPhone ; en Debug, `-api-simulee`
    /// relie à une résidence inventée sans rien écouter.
    static func auLancement(_ arguments: [String]) -> LiaisonDeLaMontre {
        #if DEBUG
        if let simule = EtatMontre.simule(arguments) {
            let liaison = LiaisonDeLaMontre(coffre: LiaisonEnMemoire())
            liaison.simulee = true
            liaison.etat = simule
            return liaison
        }
        #endif
        let liaison = LiaisonDeLaMontre(coffre: LiaisonAuTrousseau())
        liaison.ecouter()
        return liaison
    }

    func ecouter() {
        guard active, WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Un message de l'iPhone, déjà lu (`MessageLiaison`).
    func recevoir(_ message: MessageLiaison) {
        guard active else { return }
        Liaisons.recevoir(message, coffre)
        relire()
    }

    /// Le serveur ne reconnaît plus le jeton : la liaison s'oublie.
    func jetonRefuse() {
        if !simulee { coffre.effacer() }
        etat = .nonReliee
    }

    /// Au retour au premier plan : une liaison échue entre-temps ne lit plus rien.
    func relire() {
        guard !simulee else { return }
        let neuf = EtatMontre.depuis(coffre, active: active)
        if neuf != etat { etat = neuf }
    }

    nonisolated func session(
        _ session: WCSession, activationDidCompleteWith etat: WCSessionActivationState, error: (any Error)?
    ) {}

    /// Le message est lu AVANT de quitter le fil de WatchConnectivity : seul un message
    /// complet passe, et rien de ce qui n'est pas lu ne s'en va.
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let message = MessageLiaison(userInfo) else { return }
        Task { @MainActor in self.recevoir(message) }
    }
}
