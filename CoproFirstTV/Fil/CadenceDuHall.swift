// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

/// Le rythme du Fil en tuiles (#429), sans horloge : à chaque appel, le prochain geste et
/// l'attente avant lui. La diffusion attend, fait le geste, redemande.
///
/// - Le carrousel avance d'un cran toutes les `RythmeTV.cran`, mais pas pendant une mise en
///   avant : la carte agrandie retournera à sa place, qui n'a pas bougé.
/// - Une mise en avant s'ouvre toutes les `RythmeTV.miseEnAvant` (la première aux deux tiers),
///   et se referme `RythmeTV.ouverture` plus tard — si elle s'est ouverte (`ouverte()`).
/// - Le Fil se relit toutes les `RythmeTV.relectureDuFil`.
struct CadenceDuHall: Equatable {
    enum Geste: Equatable { case relire, fermer, ouvrir, cran }

    private var cran = RythmeTV.cran
    private var ouverture = RythmeTV.miseEnAvant - RythmeTV.ouverture
    private var relecture = RythmeTV.relectureDuFil
    /// Armée par `ouverte()`, le temps d'une mise en avant.
    private var fermeture: Duration?

    var miseEnAvantOuverte: Bool { fermeture != nil }

    /// Le prochain geste et l'attente avant lui ; les échéances qui courent avancent d'autant.
    /// À égalité, la relecture passe d'abord, puis la fermeture, l'ouverture, le cran.
    mutating func prochain() -> (Geste, Duration) {
        var candidats: [(Geste, Duration)] = [(.relire, relecture)]
        if let fermeture { candidats.append((.fermer, fermeture)) }
        candidats.append((.ouvrir, ouverture))
        if fermeture == nil { candidats.append((.cran, cran)) }
        // `min` rend le premier des minimums : l'ordre ci-dessus départage.
        let (geste, attente) = candidats.min { $0.1 < $1.1 } ?? (.relire, relecture)
        relecture -= attente
        ouverture -= attente
        if fermeture == nil { cran -= attente } else { fermeture? -= attente }
        switch geste {
        case .relire: relecture = RythmeTV.relectureDuFil
        case .fermer: fermeture = nil
        case .ouvrir: ouverture = RythmeTV.miseEnAvant
        case .cran: cran = RythmeTV.cran
        }
        return (geste, attente)
    }

    /// Une tuile s'est agrandie : sa fermeture est due dans `RythmeTV.ouverture`. Sans tuile à
    /// montrer, l'ouverture ne s'arme pas, et le carrousel continue.
    mutating func ouverte() { fermeture = RythmeTV.ouverture }
}
