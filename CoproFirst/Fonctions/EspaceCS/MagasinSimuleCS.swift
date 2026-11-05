// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce qu'un onglet de l'Espace CS garde en mémoire sur l'installation simulée : une
/// boîte par service simulé ET par type de contenu — deux tests ne se marchent pas
/// dessus, deux onglets non plus. Une extension de `ServiceSimule` ne peut pas ranger
/// de propriété : chaque onglet y prend la sienne par `MagasinSimuleCS.de(self) { … }`.
final class MagasinSimuleCS<Contenu>: @unchecked Sendable {
    private var contenu: Contenu
    private let verrou = NSLock()

    init(_ initial: Contenu) { contenu = initial }

    var valeur: Contenu { verrou.withLock { contenu } }

    @discardableResult
    func modifier<R>(_ geste: (inout Contenu) throws -> R) rethrows -> R {
        try verrou.withLock { try geste(&contenu) }
    }

    static func de(_ service: ServiceSimule, initial: () -> Contenu) -> MagasinSimuleCS<Contenu> {
        RegistreMagasinsCS.boite(service, cle: String(reflecting: Contenu.self)) { MagasinSimuleCS(initial()) }
    }
}

/// Le registre des boîtes. Le service est retenu avec elles : un identifiant libéré
/// puis réemployé rendrait la boîte d'un autre.
private enum RegistreMagasinsCS {
    private static let verrou = NSLock()
    nonisolated(unsafe) private static var boites: [String: (ServiceSimule, AnyObject)] = [:]

    static func boite<B: AnyObject>(_ service: ServiceSimule, cle: String, neuve: () -> B) -> B {
        verrou.withLock {
            let cle = "\(ObjectIdentifier(service).hashValue)|\(cle)"
            if let existante = boites[cle]?.1 as? B { return existante }
            let boite = neuve()
            boites[cle] = (service, boite)
            return boite
        }
    }
}
