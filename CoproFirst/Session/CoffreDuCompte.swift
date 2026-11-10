// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce que l'app retient d'un COMPTE, résidence par résidence — le profil (statut,
/// rôles, logement) et le courriel de la dernière connexion : jamais dans les
/// réglages, que la sauvegarde de l'appareil emporte en clair (#84).
protocol CoffreDuCompte {
    func lire(_ cle: String) -> Data?
    /// `false` : le coffre a refusé — l'appelant ne doit rien effacer d'autre.
    @discardableResult func ranger(_ donnees: Data, _ cle: String) -> Bool
    func effacer(_ cle: String)
}

/// Le coffre de l'app : le Trousseau de l'appareil, jamais synchronisé.
struct CoffreTrousseau: CoffreDuCompte {
    func lire(_ cle: String) -> Data? { Trousseau.lireCompte(cle) }
    func ranger(_ donnees: Data, _ cle: String) -> Bool { Trousseau.rangerCompte(donnees, cle) }
    func effacer(_ cle: String) { Trousseau.effacerCompte(cle) }
}

/// Un coffre qui s'oublie avec le processus : la simulation et les tests, que le
/// Trousseau du simulateur ne doit pas relier d'un lancement à l'autre.
final class CoffreEnMemoire: CoffreDuCompte {
    private var contenu: [String: Data] = [:]

    func lire(_ cle: String) -> Data? { contenu[cle] }
    func ranger(_ donnees: Data, _ cle: String) -> Bool {
        contenu[cle] = donnees
        return true
    }
    func effacer(_ cle: String) { contenu[cle] = nil }
}
