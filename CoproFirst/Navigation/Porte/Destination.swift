// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Où mène un lien (#18) ou le toucher d'une notification (#17) : une résidence, par
/// son adresse, et un écran. **Une seule porte** l'ouvre, `Parcours.suivre(_:)` — ni le
/// lien ni la notification ne naviguent eux-mêmes.
struct Destination: Hashable, Sendable {
    /// L'adresse de la résidence, réduite à `https://<hôte>` (`AdresseInstallation`).
    var adresse: URL
    var ecran: Ecran

    enum Ecran: Hashable, Sendable {
        /// La résidence, à son premier écran (le fil).
        case accueil
        /// Une page du menu, par son identifiant (`pages.ts`, `PagesParDefaut`).
        case page(String)
        /// Une affaire ; `message` : celui qu'un lien vise (`#msg-45`) — lu, pas encore
        /// montré (le détail ne défile pas jusqu'à un message).
        case affaire(id: Int, message: Int?)
        /// Un élément du fil, par sa clé `type:id` (`ElementDuFil.id`, `cleFluxItem` du
        /// site) : il s'ouvre depuis le fil, comme au toucher de sa carte (#17).
        case element(String)
        /// La cloche : la liste des alertes, lue par GET /notifications. Une notification
        /// push ne dit rien de plus — ni quelle alerte, ni de quoi (spec push §5, #17).
        case notifications
        /// L'écran de connexion de la résidence.
        case connexion
        /// Une page que l'app ne porte pas (lien à jeton : vérifier une adresse,
        /// choisir un mot de passe) : elle s'ouvre dans Safari, DANS l'app — jamais par
        /// `openURL`, qui renverrait le lien à l'app elle-même.
        case navigateur(URL)
    }
}

/// Une page du site montrée dans Safari, au-dessus de l'app (`PageWebView`).
struct PageWeb: Identifiable, Hashable, Sendable {
    let url: URL
    var id: URL { url }
}

/// Ce que la porte retient entre deux écrans — un seul état, lu par la racine,
/// l'espace de la résidence et l'écran des affaires.
struct EtatPorte: Equatable {
    /// Le lien vers une résidence qu'il faut d'abord ouvrir (Face ID ou mot de passe) :
    /// son écran suit l'ouverture (`Parcours.ouvrir`).
    var enAttente: Destination?
    /// L'affaire que l'onglet des affaires poussera dans sa pile (`AffairesView`).
    var affaireDansLOnglet: Int?
    /// L'affaire montrée en feuille, quand l'onglet des affaires n'est pas dans la barre.
    var affaireEnFeuille: AffaireEnFeuille?
    var pageWeb: PageWeb?
}

struct AffaireEnFeuille: Identifiable, Hashable, Sendable {
    let id: Int
}
