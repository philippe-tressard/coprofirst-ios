// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Un refus du serveur, dit avec SA phrase (`{"detail": "…"}`) — comme le site
/// l'affiche (#41). Il voyage dans `ErreurService.refus` : un écran qui montre
/// `ErreurService.depuis(error).phrase` montre la phrase du serveur, sans rien de plus.
/// Sa lecture dans une réponse refusée : `ServiceAPI+Refus.swift`. Ce fichier-ci est
/// compilé aussi par l'Apple TV (`project.yml`, cible `CoproFirstTV`).
struct RefusDuServeur: Equatable, Sendable {
    let phrase: String
}

extension RefusDuServeur {
    /// Le `detail` d'un corps de refus, s'il est une phrase (une erreur de validation
    /// sert une liste : elle ne s'affiche pas).
    static func detail(_ corps: Data) -> String? {
        struct Detail: Decodable { let detail: String }
        guard let lu = try? JSONDecoder().decode(Detail.self, from: corps) else { return nil }
        let phrase = lu.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        return phrase.isEmpty ? nil : phrase
    }
}
