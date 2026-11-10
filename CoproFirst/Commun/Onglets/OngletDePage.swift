// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Ce qu'un onglet d'une page à onglets reçoit du cadre (`CadreAOnglets`).
struct ContexteOnglet {
    let installation: Installation
    /// Le service de la session : chaque onglet y cherche SON protocole
    /// (`service as? any ServiceComptesCS`), déclaré dans son dossier.
    let service: any ServiceCoproFirst
    let droits: DroitsOnglet
    /// La phrase brève qui suit un geste (`avisEphemere`, posé par le cadre) :
    /// `avis.dire(…)`, jamais lue par l'onglet.
    let avis: AvisDuGeste
    /// Augmente à chaque « tirer pour actualiser » : un onglet relit par `.task(id:)`.
    let actualisation: Int
}

/// Un onglet d'une page à onglets (Espace CS, Paramétrage) : une vue qui se construit
/// depuis son contexte.
///
/// Elle rend son CONTENU (le cadre porte le défilement, la barre d'onglets et le
/// descriptif) et peut poser ses propres boutons de barre d'outils (`.toolbar`).
@MainActor
protocol OngletDePage: View {
    init(contexte: ContexteOnglet)
}

/// Un onglet du site que l'app ne porte pas encore : il le dit, sans écran vide.
struct OngletBientot: View {
    let onglet: OngletDuSite

    var body: some View {
        ContentUnavailableView(
            "Bientôt", systemImage: "hourglass",
            description: Text("« \(onglet.libelle) » arrive dans une prochaine version de l'app."))
    }
}
