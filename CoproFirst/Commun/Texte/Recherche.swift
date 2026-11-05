// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// La recherche d'une liste (`contientTousLesMots` de `#lib/texte.ts`) : tous les mots
/// saisis, dans n'importe quel ordre, sans accents ni casse, sur ce que la ligne affiche.
enum Recherche {
    static func contientTousLesMots(_ champs: [String?], _ recherche: String) -> Bool {
        let mots = replier(recherche).split(whereSeparator: \.isWhitespace)
        guard !mots.isEmpty else { return true }
        let texte = replier(champs.compactMap { $0 }.joined(separator: " "))
        return mots.allSatisfy { texte.contains($0) }
    }

    static func replier(_ texte: String) -> String {
        texte.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
    }
}
