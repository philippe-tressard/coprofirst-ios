// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La table des onglets de l'Espace CS : l'identifiant d'un onglet du site
/// (`pages-roles.ts`) → sa vue, que le cadre commun ouvre (`CadreAOnglets`).
///
/// ⚠️ UNE LIGNE PAR ONGLET, séparée des autres par une ligne vide : deux sessions y
/// ajoutent chacune la leur sans conflit. L'ORDRE et l'ouverture ne se décident pas ici
/// (`OngletsDuSite.ouverts(page: "espace-cs", …)`, généré) ; un onglet absent de la
/// table s'affiche « Bientôt ».
///
/// Ajouter un onglet : son dossier, sa vue conforme à `OngletDePage`, une ligne ici.
@MainActor
enum OngletsEspaceCS {
    static let ecrans: [String: any OngletDePage.Type] = [
        "validations": OngletComptesCS.self,

        "badges": OngletBadgesCS.self,

        "reporting": OngletReporting.self,

        "annonces-hall": OngletAnnoncesHall.self,

        "annuaire": OngletAnnuaireCS.self,

        "courriels": OngletCourriels.self,
    ]
}
