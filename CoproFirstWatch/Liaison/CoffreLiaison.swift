// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// La liaison que l'iPhone a donnée : la résidence et son jeton de montre (coprofirst#2771).
struct LiaisonGardee: Codable, Hashable, Sendable, CustomStringConvertible, CustomDebugStringConvertible,
    CustomReflectable
{
    let adresse: URL
    let residence: String
    let jeton: String
    let expireLe: Date

    var description: String { "LiaisonGardee(\(adresse.absoluteString), \(residence), jeton masqué, \(expireLe))" }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [], displayStyle: .struct) }
}

/// Où la montre garde sa liaison : une seule, celle de la dernière résidence ouverte sur
/// l'iPhone.
protocol CoffreLiaison: Sendable {
    func lire() -> LiaisonGardee?
    func garder(_ liaison: LiaisonGardee)
    func effacer()
}

/// Ce que la montre fait d'un message de l'iPhone (`MessageLiaison`, déjà vérifié à sa
/// lecture : https, champs complets) : elle garde la liaison, ou l'efface si elle vise la même
/// résidence — l'effacement d'une résidence quittée avant n'efface pas la suivante.
enum Liaisons {
    static func recevoir(_ message: MessageLiaison, _ coffre: any CoffreLiaison) {
        switch message {
        case .liaison(let adresse, let residence, let jeton, let expireLe):
            coffre.garder(LiaisonGardee(adresse: adresse, residence: residence, jeton: jeton, expireLe: expireLe))
        case .effacement(let adresse):
            if coffre.lire()?.adresse == adresse { coffre.effacer() }
        }
    }

    /// La liaison qui vaut encore : un jeton échu ne lit plus rien, la montre attend l'iPhone.
    static func valide(_ coffre: any CoffreLiaison, maintenant: Date = .now) -> LiaisonGardee? {
        coffre.lire().flatMap { $0.expireLe > maintenant ? $0 : nil }
    }
}

/// Au Trousseau de la montre, sans invite — le coffre de l'app (`CoffreTrousseau`, partagé
/// avec l'iPhone et l'Apple TV), sous le service de la liaison —, jamais synchronisé. Une
/// entrée illisible se lit comme une montre pas reliée.
struct LiaisonAuTrousseau: CoffreLiaison {
    private static let coffre = CoffreTrousseau(service: "fr.coprofirst.app.montre.liaison")
    private static let cle = "liaison"

    func lire() -> LiaisonGardee? {
        Self.coffre.lire(Self.cle).flatMap { try? JSONDecoder().decode(LiaisonGardee.self, from: $0) }
    }

    func garder(_ liaison: LiaisonGardee) {
        guard let donnees = try? JSONEncoder().encode(liaison) else { return }
        Self.coffre.ranger(donnees, Self.cle)
    }

    func effacer() {
        Self.coffre.effacer(Self.cle)
    }
}

/// En mémoire : les tests, et le simulateur sans signature (où le Trousseau refuse).
final class LiaisonEnMemoire: CoffreLiaison, @unchecked Sendable {
    private var liaison: LiaisonGardee?
    private let verrou = NSLock()

    init(_ liaison: LiaisonGardee? = nil) {
        self.liaison = liaison
    }

    func lire() -> LiaisonGardee? { verrou.withLock { liaison } }
    func garder(_ liaison: LiaisonGardee) { verrou.withLock { self.liaison = liaison } }
    func effacer() { verrou.withLock { liaison = nil } }
}
