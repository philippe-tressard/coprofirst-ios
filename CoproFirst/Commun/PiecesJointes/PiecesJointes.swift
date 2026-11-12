// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Les pièces jointes d'un élément — affaire, suite, message, carte du fil, annonce —,
/// rangées comme le site les range (`separerFichiers`, `#lib/fichiers.ts`) : les photos
/// d'un côté, les documents de l'autre, dans l'ordre servi, sans doublon.
///
/// Le serveur sert des listes d'URL (`photos_urls`, `fichiers_urls`) où une photo peut
/// se trouver dans l'une ou l'autre : seule l'extension décide (`Fichiers.estImage`).
/// Avant ce type, l'app ne gardait que les images et jetait les documents.
struct PiecesJointes: Hashable, Sendable {
    private(set) var photos: [String] = []
    private(set) var documents: [String] = []

    static let aucune = PiecesJointes()

    init() {}

    /// Toutes les URL servies, photos et documents mêlés.
    init(urls: [String]) {
        var vues = Set<String>()
        for url in urls where !url.isEmpty && vues.insert(url).inserted {
            if Fichiers.estImage(url) { photos.append(url) } else { documents.append(url) }
        }
    }

    var vide: Bool { photos.isEmpty && documents.isEmpty }

    /// « 2 photos, 1 pièce jointe » — ce que dit la vignette d'une carte au lecteur d'écran.
    var enClair: String? {
        var morceaux: [String] = []
        if !photos.isEmpty { morceaux.append(photos.count > 1 ? "\(photos.count) photos" : "1 photo") }
        if !documents.isEmpty {
            morceaux.append(documents.count > 1 ? "\(documents.count) pièces jointes" : "1 pièce jointe")
        }
        return morceaux.isEmpty ? nil : morceaux.joined(separator: ", ")
    }
}
