// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce qu'une personne SERVIE porte au-dessus du plancher (contrat 1.25.0,
/// coprofirst#2633) : son nom affiché, « Prénom NOM » (lot 4, #135), et, pour le compte
/// connecté, s'il modère (lot 5, #136). Relu dans le corps d'une route TYPÉE par
/// `Relecture.auDessusDuPlancher` : tout est facultatif. Absent — une installation
/// antérieure — l'écran garde son repli, écrit une fois : `FormatsDuSite.nom(affiche:…)`
/// pour un nom, `DroitsOnglet` pour la modération.
struct PersonneServie: Decodable, Identifiable {
    let id: Int
    /// `nom_affiche` : un compte (`UserRead`, `UtilisateurAdminRead`), un locataire trouvé.
    var nomAffiche: String?
    /// `nom_aide_affiche` : la personne aidée déclarée à l'inscription — `''` sans elle.
    var nomAideAffiche: String?
    /// `locataire_nom_affiche` : le locataire d'un bail (`BailOut`).
    var locataireNomAffiche: String?
    /// `bailleur_nom_affiche` : le bailleur, sur le bail du locataire (`BailLocataireOut`).
    var bailleurNomAffiche: String?
    /// `est_moderateur` : conseil syndical ou administration, au prédicat qui ouvre les
    /// routes `require_cs_or_admin` — il dit le compte CONNECTÉ (`/auth/me`).
    var estModerateur: Bool?
}

extension PersonneServie {
    /// Les personnes d'une LISTE servie, par identifiant — vide d'une installation antérieure.
    static func parLigne(_ corps: Data?) -> [Int: PersonneServie] {
        Relecture.auDessusDuPlancher(parLigne: Self.self, corps: corps)
    }

    /// La personne d'une réponse servie seule (`/auth/me`, un bail) — `nil` si rien n'est lisible.
    static func lue(_ corps: Data?) -> PersonneServie? {
        Relecture.auDessusDuPlancher(Self.self, corps: corps)
    }
}
