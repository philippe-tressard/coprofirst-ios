// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'Espace conseil syndical (page `espace-cs` du site, #15) : le cadre commun des pages
/// à onglets (`CadreAOnglets`) et la table de ses onglets (`OngletsEspaceCS`).
///
/// Réservé au conseil et à l'administration : la barre ne l'offre qu'à eux
/// (`PagesOuvertes`), et l'écran le redit s'il est atteint autrement — le serveur, lui,
/// refuse chaque route à qui n'en est pas.
struct EspaceCSView: View {
    let contexte: ContexteDeMenu

    init(contexte: ContexteDeMenu) { self.contexte = contexte }

    var body: some View {
        // Le libellé du menu (« Espace CS »), et non le titre de la page (« Espace Conseil
        // Syndical (CS) ») : un grand titre ne passe pas à la ligne, il se tronquerait.
        // Écart de rendu assumé avec le site (standards/11 §14) ; le descriptif dit le reste.
        CadreAOnglets(
            contexte: contexte,
            page: PageAOnglets(
                id: "espace-cs", ecrans: OngletsEspaceCS.ecrans, descriptifs: TablesEspaceCS.descriptifs,
                reserve: TextesEspaceCS.reserve))
    }
}

extension EspaceCSView: EcranDeMenu {}

/// Les mots du cadre et ce que les onglets partagent.
enum TextesEspaceCS {
    static let reserve = "Cet espace est réservé au conseil syndical."
    static let serviceAbsent = "Cet onglet n'est pas disponible avec cette résidence."
    static let approuver = "Approuver"
    static let rejeter = "Rejeter"
    static let modifier = "Modifier"
    static let supprimer = "Supprimer"
    static let annuler = "Annuler"
}
