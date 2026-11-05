// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Ce qu'un onglet de l'Espace CS reçoit du cadre (`EspaceCSView`).
struct ContexteOngletCS {
    let installation: Installation
    /// Le service de la session : chaque onglet y cherche SON protocole
    /// (`service as? any ServiceComptesCS`), déclaré dans son dossier.
    let service: any ServiceCoproFirst
    let droits: DroitsOnglet
    /// La phrase brève qui suit un geste (`avisEphemere`, posé par le cadre).
    let avis: Binding<String?>
    /// Augmente à chaque « tirer pour actualiser » : un onglet relit par `.task(id:)`.
    let actualisation: Int
}

/// Un onglet de l'Espace CS : une vue qui se construit depuis son contexte.
///
/// Elle rend son CONTENU (le cadre porte le défilement, la barre d'onglets et le
/// descriptif) et peut poser ses propres boutons de barre d'outils (`.toolbar`).
@MainActor
protocol OngletEspaceCS: View {
    init(contexte: ContexteOngletCS)
}

/// La table des onglets : l'identifiant d'un onglet du site (`pages-roles.ts`) → sa vue.
///
/// ⚠️ UNE LIGNE PAR ONGLET, séparée des autres par une ligne vide : deux sessions y
/// ajoutent chacune la leur sans conflit. L'ORDRE et l'ouverture ne se décident pas ici
/// (`OngletsDuSite.ouverts(page: "espace-cs", …)`, généré) ; un onglet absent de la
/// table s'affiche « Bientôt ».
@MainActor
enum OngletsEspaceCS {
    static let ecrans: [String: any OngletEspaceCS.Type] = [
        "validations": OngletComptesCS.self,

        "badges": OngletBadgesCS.self,

        // #15 — "reporting"

        // #15 — "annonces-hall"

        "annuaire": OngletAnnuaireCS.self,

        // #15 — "courriels"
    ]

    /// La vue de l'onglet, ou « Bientôt » tant qu'aucune n'est inscrite.
    static func ecran(_ onglet: OngletDuSite, _ contexte: ContexteOngletCS) -> AnyView {
        guard let type = ecrans[onglet.id] else { return AnyView(OngletBientot(onglet: onglet)) }
        return AnyView(type.init(contexte: contexte))
    }
}

/// Un onglet du site que l'app ne porte pas encore : il le dit, sans écran vide.
private struct OngletBientot: View {
    let onglet: OngletDuSite

    var body: some View {
        ContentUnavailableView(
            "Bientôt", systemImage: "hourglass",
            description: Text("« \(onglet.libelle) » arrive dans une prochaine version de l'app."))
    }
}
