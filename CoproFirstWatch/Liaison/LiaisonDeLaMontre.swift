// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Observation
import WatchConnectivity

/// La liaison de la montre, tenue pour l'app (#226) : elle écoute l'iPhone par
/// WatchConnectivity, garde ce qu'il donne (`CoffreLiaison`) et dit l'état à montrer. Un jeton
/// refusé par le serveur efface la liaison : la montre attend l'iPhone. Liaison éteinte
/// (`LiaisonMontre.active`), WatchConnectivity ne s'active pas.
///
/// Elle tient aussi ce qui suit la liaison (#226, lot 3) : la dernière cloche gardée pour le
/// hors ligne (`GardeDeLaCloche`), effacée quand la montre n'est plus reliée, et le résumé du
/// widget (`Surfaces`).
@MainActor @Observable
final class LiaisonDeLaMontre: NSObject, WCSessionDelegate {
    private(set) var etat: EtatMontre
    @ObservationIgnored private let coffre: any CoffreLiaison
    @ObservationIgnored private let active: Bool
    @ObservationIgnored let garde: any GardeDeLaCloche
    @ObservationIgnored private let surfaces: Surfaces
    /// En Debug, sous l'API simulée : l'état ne vient pas du coffre.
    @ObservationIgnored private var simulee = false

    init(
        coffre: any CoffreLiaison, garde: any GardeDeLaCloche = GardeEnMemoire(),
        surfaces: Surfaces = Surfaces(ecrire: { _ in true }, recharger: {}), active: Bool = LiaisonMontre.active
    ) {
        self.coffre = coffre
        self.garde = garde
        self.surfaces = surfaces
        self.active = active
        etat = EtatMontre.depuis(coffre, active: active)
    }

    /// L'app : le Trousseau de la montre, et l'écoute de l'iPhone ; en Debug, `-api-simulee`
    /// relie à une résidence inventée sans rien écouter.
    static func auLancement(_ arguments: [String]) -> LiaisonDeLaMontre {
        #if DEBUG
        if let simule = EtatMontre.simule(arguments) {
            let liaison = LiaisonDeLaMontre(coffre: LiaisonEnMemoire(), garde: ClocheSimulee.garde(arguments))
            liaison.simulee = true
            liaison.etat = simule
            return liaison
        }
        #endif
        let garde: any GardeDeLaCloche = GardeSurDisque.parDefaut ?? GardeEnMemoire()
        let liaison = LiaisonDeLaMontre(coffre: LiaisonAuTrousseau(), garde: garde, surfaces: Surfaces())
        // Une liaison échue ou retirée app fermée : rien de gardé, et le widget ne redit pas un
        // ancien compte.
        if liaison.etat == .nonReliee { liaison.oublierLaCloche() }
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
        poser(.nonReliee)
    }

    /// Au retour au premier plan : une liaison échue entre-temps ne lit plus rien.
    func relire() {
        guard !simulee else { return }
        poser(EtatMontre.depuis(coffre, active: active))
    }

    /// Le lecteur d'une cloche reliée : il garde, publie au widget, et rend la liaison au refus.
    func lecteur(_ source: SourceDeLaCloche) -> LecteurCloche {
        LecteurCloche(
            source: source, garde: garde, publier: { [surfaces] in surfaces.publier($0) },
            auRefus: { [weak self] in self?.jetonRefuse() })
    }

    /// Le rafraîchissement d'arrière-plan (`DelegueMontre`) : la cloche se relit, le widget suit.
    func rafraichir() async {
        relire()
        guard case .reliee(_, let source) = etat else { return }
        await lecteur(source).lire()
    }

    private func poser(_ neuf: EtatMontre) {
        guard neuf != etat else { return }
        etat = neuf
        if neuf == .nonReliee { oublierLaCloche() }
    }

    /// Plus reliée : rien de la cloche ne reste au poignet, et le widget le dit.
    func oublierLaCloche() {
        garde.effacer()
        surfaces.publier(.nonReliee)
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
