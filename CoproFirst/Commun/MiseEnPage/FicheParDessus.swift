// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'iPad en PORTRAIT : la barre latérale et la page, deux colonnes et pas trois — une
/// `ListeEtFiche` y ouvre sa fiche par-dessus sa liste, comme sur l'iPhone. Barre, liste et
/// fiche côte à côte n'y laissaient à chacune qu'un tiers d'écran, illisible. En paysage,
/// rien ne change : liste et fiche côte à côte (#222).
///
/// Un signal à la seule `ListeEtFiche`, pas une classe de taille compacte imposée à la
/// page : celle-ci gagnait les feuilles et les contrôles du système (le menu « Ajouter un
/// prestataire » ne s'ouvrait plus), qui restent ceux de l'iPad.
enum FicheParDessus {
    /// Plus haute que large : le portrait se lit sur la fenêtre, jamais sur l'appareil. Une
    /// fenêtre pas encore mesurée (`.zero`) garde liste et fiche côte à côte.
    static func enPortrait(_ fenetre: CGSize) -> Bool {
        fenetre.height > fenetre.width
    }

    /// La fenêtre ENTIÈRE, marges sûres rendues : le clavier d'une feuille en est une, et
    /// sa hauteur retranchée faisait passer un iPad en portrait pour un paysage — la page
    /// repassait côte à côte, la fiche poussée disparaissait sous la saisie.
    static func fenetre(_ cadre: GeometryProxy) -> CGSize {
        fenetre(cadre.size, marges: cadre.safeAreaInsets)
    }

    static func fenetre(_ taille: CGSize, marges: EdgeInsets) -> CGSize {
        CGSize(
            width: taille.width + marges.leading + marges.trailing,
            height: taille.height + marges.top + marges.bottom)
    }
}

private struct CleFicheParDessus: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Vrai dans la page de la barre latérale en portrait (`FicheParDessus`) : une
    /// `ListeEtFiche` y pousse sa fiche, même en classe régulière.
    var ficheParDessus: Bool {
        get { self[CleFicheParDessus.self] }
        set { self[CleFicheParDessus.self] = newValue }
    }
}
