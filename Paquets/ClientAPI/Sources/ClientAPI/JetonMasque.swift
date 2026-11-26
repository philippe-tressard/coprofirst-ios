// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// UN jeton — d'appareil APNs, d'écran de hall, de montre — tel que l'app le porte : il ne
/// s'écrit JAMAIS, ni dans un journal, ni dans un message d'erreur, ni par `dump` (#342). Sa
/// description, son reflet et son `dump` disent `‹jeton masqué›` ; le texte en clair ne se lit
/// que par `enClair`, au seul endroit où il part (l'en-tête de `JetonAppareil`, un corps de
/// requête, le message vers la montre).
///
/// L'UNIQUE enveloppe : un type qui porte un jeton le garde dans un `JetonMasque`, et n'a plus
/// rien à réécrire — son propre reflet affiche celui-ci (`scripts/verifier-jetons.py` refuse un
/// jeton en `String` dans le code de l'app, et un `customMirror` ailleurs qu'ici).
///
/// Encodé, c'est le texte seul : ce qui est déjà rangé au Trousseau se relit à l'identique.
public struct JetonMasque: Hashable, Sendable, Codable, ExpressibleByStringLiteral {
    public static let masque = "‹jeton masqué›"

    /// Le jeton en clair : à lire au seul moment où il part.
    public let enClair: String

    public init(_ enClair: String) { self.enClair = enClair }
    public init(stringLiteral enClair: String) { self.enClair = enClair }

    public init(from decoder: any Decoder) throws {
        enClair = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var conteneur = encoder.singleValueContainer()
        try conteneur.encode(enClair)
    }
}

extension JetonMasque: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public var description: String { Self.masque }
    public var debugDescription: String { Self.masque }
    public var customMirror: Mirror { Mirror(self, children: [], displayStyle: .struct) }
}
