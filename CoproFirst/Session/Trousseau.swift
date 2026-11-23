// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
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
/// Jamais synchronisé (`ThisDeviceOnly`), jamais dans les réglages ni sur le disque ; masqué
/// dans toute trace (`JetonMasque`, #342) entre le cookie et le Trousseau.
enum Trousseau {
    private static let service = "fr.coprofirst.app.session"

    /// Garde le jeton et rend ce qui le protège — `nil` s'il n'a pas pu être gardé.
    @discardableResult
    static func enregistrer(_ jeton: JetonMasque, pour hote: String) -> ProtectionSession? {
        supprimer(pour: hote)
        var requete = CoffreTrousseau.requete(hote, service: service)
        requete[kSecValueData as String] = Data(jeton.enClair.utf8)
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
    static func lire(pour hote: String, raison: String) -> JetonMasque? {
        let contexte = LAContext()
        contexte.localizedReason = raison
        var requete = CoffreTrousseau.requete(hote, service: service)
        requete[kSecReturnData as String] = true
        requete[kSecMatchLimit as String] = kSecMatchLimitOne
        requete[kSecUseAuthenticationContext as String] = contexte
        var resultat: CFTypeRef?
        guard SecItemCopyMatching(requete as CFDictionary, &resultat) == errSecSuccess,
            let donnees = resultat as? Data
        else { return nil }
        return String(data: donnees, encoding: .utf8).map { JetonMasque($0) }
    }

    /// Présent, sans le lire (aucune invite Face ID).
    static func contient(pour hote: String) -> Bool {
        var requete = CoffreTrousseau.requete(hote, service: service)
        let contexte = LAContext()
        contexte.interactionNotAllowed = true
        requete[kSecUseAuthenticationContext as String] = contexte
        let statut = SecItemCopyMatching(requete as CFDictionary, nil)
        return statut == errSecSuccess || statut == errSecInteractionNotAllowed
    }

    static func supprimer(pour hote: String) {
        SecItemDelete(CoffreTrousseau.requete(hote, service: service) as CFDictionary)
    }
}
