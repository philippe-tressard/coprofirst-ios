// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import LocalAuthentication
import Security

/// Ce qui garde une session au Trousseau : l'écran d'activation le dit (#84).
enum ProtectionSession: Equatable, Sendable {
    /// La biométrie de l'appareil (« Face ID », « Touch ID »…) : elle seule rouvre.
    case biometrie(String)
    /// Sans biométrie inscrite : le verrouillage de l'appareil — qui connaît le code rouvre.
    case codeAppareil
    /// Ni code ni biométrie : l'appareil déverrouillé suffit, rien d'autre ne protège.
    case aucune
}

/// Le jeton de rafraîchissement de chaque installation, au Trousseau de l'appareil.
///
/// Protégé par la biométrie quand l'appareil en a une (`biometryCurrentSet` : un
/// visage ajouté ensuite l'invalide) ; sinon par le code de l'appareil ; sans code,
/// lisible appareil déverrouillé — et `enregistrer` dit lequel, pour que l'écran le dise.
/// Jamais synchronisé (`ThisDeviceOnly`), jamais dans les réglages ni sur le disque.
enum Trousseau {
    private static let service = "fr.coprofirst.app.session"

    /// Garde le jeton et rend ce qui le protège — `nil` s'il n'a pas pu être gardé.
    @discardableResult
    static func enregistrer(_ jeton: String, pour hote: String) -> ProtectionSession? {
        supprimer(pour: hote)
        var requete = base(hote)
        requete[kSecValueData as String] = Data(jeton.utf8)
        var erreur: Unmanaged<CFError>?
        if let nom = Biometrie.actuelle.nom,
            let controle = SecAccessControlCreateWithFlags(
                nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .biometryCurrentSet, &erreur)
        {
            requete[kSecAttrAccessControl as String] = controle
            if SecItemAdd(requete as CFDictionary, nil) == errSecSuccess { return .biometrie(nom) }
            requete.removeValue(forKey: kSecAttrAccessControl as String)
        }
        // Sans biométrie inscrite : le code de l'appareil, s'il en a un.
        requete[kSecAttrAccessible as String] = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        if SecItemAdd(requete as CFDictionary, nil) == errSecSuccess { return .codeAppareil }
        // Ni code ni biométrie (simulateur) : la protection de l'appareil seule.
        requete[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(requete as CFDictionary, nil) == errSecSuccess ? .aucune : nil
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

    // MARK: - Le compte, sans biométrie (#84)

    /// Ce que l'app retient d'un compte (profil, courriel) : lisible après le premier
    /// déverrouillage, sans invite — l'arrivée en a besoin avant toute requête.
    private static let serviceCompte = "fr.coprofirst.app.compte"

    static func lireCompte(_ cle: String) -> Data? {
        var requete = base(cle, domaine: serviceCompte)
        requete[kSecReturnData as String] = true
        requete[kSecMatchLimit as String] = kSecMatchLimitOne
        var resultat: CFTypeRef?
        guard SecItemCopyMatching(requete as CFDictionary, &resultat) == errSecSuccess else { return nil }
        return resultat as? Data
    }

    static func rangerCompte(_ donnees: Data, _ cle: String) {
        effacerCompte(cle)
        var requete = base(cle, domaine: serviceCompte)
        requete[kSecValueData as String] = donnees
        requete[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(requete as CFDictionary, nil)
    }

    static func effacerCompte(_ cle: String) {
        SecItemDelete(base(cle, domaine: serviceCompte) as CFDictionary)
    }

    private static func base(_ cle: String, domaine: String = service) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: domaine,
            kSecAttrAccount as String: cle,
        ]
    }
}
