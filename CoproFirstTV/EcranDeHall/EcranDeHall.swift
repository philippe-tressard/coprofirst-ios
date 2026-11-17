// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

/// Les textes de l'écran de hall, écrits une fois : la vue et les tests les lisent ici.
enum EcranDeHall {
    static let titre = "CoproFirst"
    static let sousTitre = "Écran de hall"
    /// Avant l'appairage (lot 3, #218) : ce que l'écran fera, et d'où il se règle.
    static let attente = """
        Cet écran fera défiler les affiches de votre résidence. \
        Il s'appairera depuis l'Espace conseil syndical du site.
        """
}
