// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce qui suit le cycle d'une résidence sur l'appareil : les notifications push (#17) et la
/// liaison avec l'Apple Watch (#226). UN point d'accroche : `Parcours` prévient ses abonnés,
/// aucun ne se branche sur la session à part — comme `AbonneSession` de CoproFirst-Android.
@MainActor
protocol AbonneSession: AnyObject {
    /// Une résidence s'ouvre, sa session en main (connexion, session gardée rouverte, reprise
    /// d'une consultation hors ligne). Jamais en consultation : rien ne partirait.
    func residenceOuverte(_ installation: Installation) async

    /// Elle se ferme : déconnexion, « Oublier toutes les résidences », session refusée par le
    /// serveur. Appelé AVANT la déconnexion, pour qu'un retrait parte encore authentifié ;
    /// sur une session refusée, l'appel au serveur échoue — l'abonné oublie sa part quand même.
    func residenceFermee(_ installation: Installation) async
}

/// Les abonnés de l'app, prévenus dans l'ordre. L'échec de l'un n'arrête ni les suivants ni
/// le geste de session : chacun tient déjà la cloche, ou le serveur, pour chemin de secours.
@MainActor
struct AbonnesSession {
    private(set) var liste: [any AbonneSession] = []

    /// Un abonné ne s'inscrit qu'une fois, même attaché deux fois.
    mutating func abonner(_ abonne: any AbonneSession) {
        guard !liste.contains(where: { $0 === abonne }) else { return }
        liste.append(abonne)
    }

    func ouverte(_ installation: Installation) async {
        for abonne in liste { await abonne.residenceOuverte(installation) }
    }

    func fermee(_ installation: Installation) async {
        for abonne in liste { await abonne.residenceFermee(installation) }
    }
}

extension Parcours {
    /// Inscrit un abonné ; une résidence déjà ouverte (hors consultation) le prévient aussitôt.
    func abonner(_ abonne: any AbonneSession) async {
        abonnes.abonner(abonne)
        if let ouverte, consultation == nil { await abonne.residenceOuverte(ouverte) }
    }
}
