// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'aperçu servi d'une saisie, à l'écran : `contenu` reçoit la valeur que le serveur a
/// rendue pour la saisie courante — ou la dernière, tant qu'il n'a pas répondu ; `nil`
/// avant sa première réponse. Le mécanisme (délai, réponse périmée, hors ligne, pas de
/// redemande) est `EtatApercu` ; cette vue n'y ajoute que trois choses, écrites une fois :
/// - **la porte du serveur** : le service et la résidence ouverte du `Parcours` — un écran
///   ne dit que QUELLE question poser (`demander`) ;
/// - **hors ligne** (#101) : ni en consultation, ni sans réseau (`Reseau`) — l'aperçu ne
///   part pas, et repart de lui-même quand le réseau revient ;
/// - **le fondu** : un changement de valeur se fond, court, en sortie douce ; rien ne bouge
///   pendant l'attente, et rien du tout sous « Réduire les animations ».
///
/// Le contenu RÉSERVE sa place (la ligne est là avant la première réponse) : rien ne
/// bouge sous le pouce quand la valeur arrive.
struct ApercuServi<Entree: Hashable & Sendable, Sortie: Equatable & Sendable, Contenu: View>: View {
    typealias Demande = @Sendable (any ServiceApercus, Installation, Entree) async throws -> Sortie

    let entree: Entree
    let demander: Demande
    @ViewBuilder let contenu: (Sortie?) -> Contenu
    @State private var etat: EtatApercu<Entree, Sortie>
    @Environment(Parcours.self) private var parcours: Parcours?
    @Environment(Reseau.self) private var reseau: Reseau?
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit

    /// `connue` : la valeur servie AVEC l'objet, et la saisie qu'elle nomme (le prénom et
    /// le nom enregistrés) — elle se montre d'emblée et ne se redemande pas.
    init(
        _ entree: Entree, connue: (Entree, Sortie)? = nil, demander: @escaping Demande,
        @ViewBuilder contenu: @escaping (Sortie?) -> Contenu
    ) {
        self.entree = entree
        self.demander = demander
        self.contenu = contenu
        _etat = State(initialValue: EtatApercu(connue: connue))
    }

    /// Un appel peut partir : ni consultation hors ligne, ni réseau absent.
    private var enLigne: Bool { parcours?.consultation == nil && reseau?.enLigne != false }

    private struct Declencheur: Equatable {
        let entree: Entree
        let enLigne: Bool
    }

    var body: some View {
        contenu(etat.valeur)
            .animation(mouvementReduit ? nil : .easeOut(duration: 0.15), value: etat.valeur)
            .onChange(of: Declencheur(entree: entree, enLigne: enLigne), initial: true) { _, declencheur in
                guard let service = parcours?.service.apercus, let installation = parcours?.ouverte else { return }
                let demander = demander
                etat.saisie(declencheur.entree, enLigne: declencheur.enLigne) {
                    try await demander(service, installation, $0)
                }
            }
    }
}
