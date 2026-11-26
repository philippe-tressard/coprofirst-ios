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

    // L'appairage (lot 3) : le code, et où le saisir — les mots de l'onglet du conseil (#295).
    static let appairage = """
        Pour afficher les annonces de hall, un membre du conseil syndical saisit ce code \
        dans l'Espace CS, onglet « Écrans du hall » — sur le site ou dans l'app CoproFirst.
        """
    static let demande = "Demande d'un code…"
    static func valable(jusqua heure: String) -> String { "Code valable jusqu'à \(heure)." }
    static let expire = "Ce code a expiré."
    static let nouveauCode = "Afficher un nouveau code"

    // La diffusion (lot 3).
    static let aucuneTitre = "Aucune annonce en ce moment"
    static let aucuneMessage = "Les annonces de hall de la résidence s'afficheront ici."
    static let lecture = "Lecture des annonces…"
    static func position(_ rang: Int, sur total: Int) -> String { "Annonce \(rang + 1) sur \(total)" }

    // « Désappairer » (lot 5) : un geste local ; couper l'accès se fait dans l'Espace CS.
    // Le même dialogue offre « À propos » (#320) : aucun bouton à l'écran pendant la diffusion.
    static let desappairer = "Désappairer"
    static let gestesTitre = "Cet écran de hall"
    static let desappairerMessage = """
        « Désappairer » : l'écran oublie son accès et affiche un nouveau code. Pour couper \
        l'accès lui-même, un membre du conseil retire l'écran dans l'Espace CS, onglet \
        « Écrans du hall ».
        """

    // « À propos » (#320) : le code de l'app et sa licence, puis les composants tiers.
    static let aPropos = "À propos"
    static let composantsTiers = "Composants tiers"
    static func versionApp(_ version: String?) -> String {
        version.map { "\(sousTitre)\(Separateur.point)version \($0)" } ?? sousTitre
    }
}
