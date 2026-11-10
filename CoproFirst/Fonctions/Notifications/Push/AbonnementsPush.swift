// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Les abonnements de cet appareil : un identifiant ALÉATOIRE par résidence, tiré par
/// l'app à l'enregistrement (spec push §5). C'est tout ce que porte une notification
/// (`"a"`) : il ne signifie rien hors du téléphone, qui seul sait à quelle résidence il
/// répond. Gardés sur l'appareil, jamais ailleurs ; oubliés à la déconnexion.
@MainActor
final class AbonnementsPush {
    private let reglages: UserDefaults
    private static let cle = "push-abonnements"

    init(reglages: UserDefaults = .standard) {
        self.reglages = reglages
    }

    /// Hôte → abonnement.
    private var table: [String: String] {
        get { (reglages.dictionary(forKey: Self.cle) as? [String: String]) ?? [:] }
        set { reglages.set(newValue, forKey: Self.cle) }
    }

    /// L'abonnement de cette résidence, tiré au premier enregistrement.
    func abonnement(pour installation: Installation) -> String {
        if let connu = table[installation.hote] { return connu }
        let neuf = Self.tirer()
        table[installation.hote] = neuf
        return neuf
    }

    func existant(pour installation: Installation) -> String? { table[installation.hote] }

    /// L'hôte qui répond à cet abonnement — `nil` s'il n'est pas (ou plus) de cet appareil.
    func hote(de abonnement: String) -> String? {
        table.first { $0.value == abonnement }?.key
    }

    func oublier(_ installation: Installation) {
        table[installation.hote] = nil
    }

    /// 24 octets du générateur cryptographique du système, en base64 « URL » sans
    /// remplissage : 32 caractères de `[A-Za-z0-9_-]`, dans le motif du contrat
    /// (`AppareilEnregistre.abonnement`, 16 à 64 — `NotificationsPushTests` le relit).
    nonisolated static func tirer() -> String {
        var generateur = SystemRandomNumberGenerator()
        let octets = Data((0..<24).map { _ in UInt8.random(in: .min ... .max, using: &generateur) })
        return octets.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
