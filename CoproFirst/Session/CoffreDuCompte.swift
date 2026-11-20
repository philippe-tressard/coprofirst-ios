// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Security

/// Ce que l'app retient d'un COMPTE, résidence par résidence — le profil (statut,
/// rôles, logement) et le courriel de la dernière connexion : jamais dans les
/// réglages, que la sauvegarde de l'appareil emporte en clair (#84).
protocol CoffreDuCompte {
    func lire(_ cle: String) -> Data?
    /// `false` : le coffre a refusé — l'appelant ne doit rien effacer d'autre.
    @discardableResult func ranger(_ donnees: Data, _ cle: String) -> Bool
    func effacer(_ cle: String)
}

/// Le coffre de l'app : le Trousseau de l'appareil, jamais synchronisé (`ThisDeviceOnly`),
/// lisible après le premier déverrouillage, SANS invite — l'arrivée en a besoin avant toute
/// requête (#84). Sans biométrie, il est compilé aussi par l'Apple TV, qui y garde son
/// appairage (#218), et par l'Apple Watch, qui y garde sa liaison sous son propre service
/// (#226) ; la session de l'iPhone, protégée par Face ID, est `Trousseau`.
struct CoffreTrousseau: CoffreDuCompte {
    /// Le service du compte retenu ; un autre usage nomme le sien.
    static let serviceCompte = "fr.coprofirst.app.compte"
    let service: String

    init(service: String = Self.serviceCompte) {
        self.service = service
    }

    func lire(_ cle: String) -> Data? {
        var requete = Self.requete(cle, service: service)
        requete[kSecReturnData as String] = true
        requete[kSecMatchLimit as String] = kSecMatchLimitOne
        var resultat: CFTypeRef?
        guard SecItemCopyMatching(requete as CFDictionary, &resultat) == errSecSuccess else { return nil }
        return resultat as? Data
    }

    /// Range la valeur ; `false` si le Trousseau l'a refusée (un build sans signature).
    @discardableResult
    func ranger(_ donnees: Data, _ cle: String) -> Bool {
        effacer(cle)
        var requete = Self.requete(cle, service: service)
        requete[kSecValueData as String] = donnees
        requete[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(requete as CFDictionary, nil) == errSecSuccess
    }

    func effacer(_ cle: String) {
        SecItemDelete(Self.requete(cle, service: service) as CFDictionary)
    }

    /// La requête d'un élément du Trousseau de l'app : un mot de passe générique, rangé par
    /// service et par clé. `Trousseau` (la session) l'emploie aussi.
    static func requete(_ cle: String, service: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: cle,
        ]
    }
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
