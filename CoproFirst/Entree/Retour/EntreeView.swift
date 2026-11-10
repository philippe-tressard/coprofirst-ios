// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le premier écran de la pile d'entrée. L'accueil (vitrine, démo) n'est montré
/// qu'à un appareil qui n'a encore ouvert aucune résidence ; ensuite, l'app rouvre
/// la dernière : Face ID si sa session est gardée, sinon la connexion pré-remplie.
struct EntreeView: View {
    @Environment(Parcours.self) private var parcours

    var body: some View {
        if let derniere = parcours.connues.derniere {
            if parcours.service.aUneSessionGardee(derniere) {
                RetourView(installation: derniere)
                    .id(derniere.adresse)
            } else {
                ConnexionView(preremplissage: .init(installation: derniere, parMotDePasse: true))
                    .id(derniere.adresse)
            }
        } else {
            AccueilView()
        }
    }
}
