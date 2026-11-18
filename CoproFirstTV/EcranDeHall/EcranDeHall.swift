// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

/// Les textes de l'écran de hall, écrits une fois : les vues et les tests les lisent ici.
enum EcranDeHall {
    static let titre = "CoproFirst"
    static let sousTitre = "Écran de hall"
    /// Avant l'entrée (#218, lot 2) : ce que l'écran fera, et ce qu'il attend.
    static let invitation = """
        Cet écran fera défiler les affiches de votre résidence. \
        Saisissez l'adresse de son site, ou essayez la démo.
        """
    /// Le libellé du champ, celui de l'iPhone (`ChampResidence`).
    static let libelleAdresse = "Votre résidence"
    static let exempleAdresse = "residence.example.com"
    static let continuer = "Continuer"
    static let changer = "Changer de résidence"
    /// La résidence reconnue, avant l'appairage (lot 3) : d'où il se règle.
    static let attente = """
        Cet écran s'appairera depuis l'Espace conseil syndical du site. \
        Il fera ensuite défiler les affiches de la résidence.
        """
}
