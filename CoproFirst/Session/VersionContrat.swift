// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// La version du contrat d'API qu'une installation sert (`version_contrat` de
/// GET /config) : l'app adapte ses gestes à une installation plus ancienne.
///
/// 🔴 Elle se compare par ses NOMBRES, jamais comme une chaîne : « 1.9.0 » < « 1.15.0 »,
/// que l'ordre des caractères inverserait. C'est la seule comparaison de versions de
/// contrat de l'app — un geste qui dépend d'une version s'écrit
/// `installation.contrat >= .logoSombre`, jamais avec la chaîne servie.
struct VersionContrat: Comparable, Hashable, Sendable, CustomStringConvertible {
    /// Majeure, mineure, correctif — trois nombres, un absent valant 0 (« 1.15 » = « 1.15.0 »).
    let nombres: [Int]

    init(_ majeure: Int, _ mineure: Int, _ correctif: Int = 0) {
        nombres = [majeure, mineure, correctif]
    }

    /// « 1.15.0 » → 1.15.0 ; une valeur illisible (vide, « 1.x », « v1.2 ») → `nil` :
    /// l'app ne devine pas une version, elle garde alors les gestes du plancher.
    init?(_ texte: String?) {
        guard let texte else { return nil }
        let parties = texte.trimmingCharacters(in: .whitespaces).split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(parties.count) else { return nil }
        var lus: [Int] = []
        for partie in parties {
            guard !partie.isEmpty, partie.allSatisfy({ $0.isASCII && $0.isNumber }), let nombre = Int(partie) else {
                return nil
            }
            lus.append(nombre)
        }
        nombres = lus + Array(repeating: 0, count: 3 - lus.count)
    }

    static func < (gauche: VersionContrat, droite: VersionContrat) -> Bool {
        gauche.nombres.lexicographicallyPrecedes(droite.nombres)
    }

    var description: String { nombres.map(String.init).joined(separator: ".") }

    /// GET /config/logo.png?variante=sombre — la variante du logo pour un fond sombre
    /// (coprofirst v3.77.0, #70).
    static let logoSombre = VersionContrat(1, 15, 0)
}
