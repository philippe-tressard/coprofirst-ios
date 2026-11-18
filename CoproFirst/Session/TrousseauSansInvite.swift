// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Security

/// Une valeur au Trousseau de l'appareil, SANS invite : lisible après le premier
/// déverrouillage (`AfterFirstUnlockThisDeviceOnly`), jamais synchronisée, jamais sauvegardée
/// ailleurs. Le compte retenu de l'iPhone (#84) et la liaison de la montre (#226) — un seul
/// code, compilé nommément par la cible montre (`project.yml`).
enum TrousseauSansInvite {
    static func lire(_ cle: String, service: String) -> Data? {
        var requete = requete(cle, service: service)
        requete[kSecReturnData as String] = true
        requete[kSecMatchLimit as String] = kSecMatchLimitOne
        var resultat: CFTypeRef?
        guard SecItemCopyMatching(requete as CFDictionary, &resultat) == errSecSuccess else { return nil }
        return resultat as? Data
    }

    /// Range la valeur ; `false` si le Trousseau l'a refusée.
    @discardableResult
    static func ranger(_ donnees: Data, _ cle: String, service: String) -> Bool {
        effacer(cle, service: service)
        var requete = requete(cle, service: service)
        requete[kSecValueData as String] = donnees
        requete[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(requete as CFDictionary, nil) == errSecSuccess
    }

    static func effacer(_ cle: String, service: String) {
        SecItemDelete(requete(cle, service: service) as CFDictionary)
    }

    /// La requête de base d'une entrée : un mot de passe générique, par service et par clé.
    static func requete(_ cle: String, service: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: cle,
        ]
    }
}
