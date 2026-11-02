// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import LocalAuthentication
import Security

/// Le jeton de rafraîchissement de chaque installation, au Trousseau de l'appareil.
///
/// Protégé par la biométrie quand l'appareil en a une (`biometryCurrentSet` : un
/// visage ajouté ensuite l'invalide) ; sinon, lisible seulement appareil déverrouillé.
/// Jamais synchronisé (`ThisDeviceOnly`), jamais dans les réglages ni sur le disque.
enum Trousseau {
    private static let service = "fr.coprofirst.app.session"

    static func enregistrer(_ jeton: String, pour hote: String) {
        supprimer(pour: hote)
        var requete = base(hote)
        requete[kSecValueData as String] = Data(jeton.utf8)
        var erreur: Unmanaged<CFError>?
        if let controle = SecAccessControlCreateWithFlags(
            nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .biometryCurrentSet, &erreur)
        {
            requete[kSecAttrAccessControl as String] = controle
            if SecItemAdd(requete as CFDictionary, nil) == errSecSuccess { return }
            requete.removeValue(forKey: kSecAttrAccessControl as String)
        }
        // Pas de code ni de biométrie (simulateur) : la protection de l'appareil seule.
        requete[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(requete as CFDictionary, nil)
    }

    /// Lit le jeton ; le système demande Face ID s'il le protège.
    static func lire(pour hote: String, raison: String) -> String? {
        let contexte = LAContext()
        contexte.localizedReason = raison
        var requete = base(hote)
        requete[kSecReturnData as String] = true
        requete[kSecMatchLimit as String] = kSecMatchLimitOne
        requete[kSecUseAuthenticationContext as String] = contexte
        var resultat: CFTypeRef?
        guard SecItemCopyMatching(requete as CFDictionary, &resultat) == errSecSuccess,
            let donnees = resultat as? Data
        else { return nil }
        return String(data: donnees, encoding: .utf8)
    }

    /// Présent, sans le lire (aucune invite Face ID).
    static func contient(pour hote: String) -> Bool {
        var requete = base(hote)
        let contexte = LAContext()
        contexte.interactionNotAllowed = true
        requete[kSecUseAuthenticationContext as String] = contexte
        let statut = SecItemCopyMatching(requete as CFDictionary, nil)
        return statut == errSecSuccess || statut == errSecInteractionNotAllowed
    }

    static func supprimer(pour hote: String) {
        SecItemDelete(base(hote) as CFDictionary)
    }

    private static func base(_ hote: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: hote,
        ]
    }
}
