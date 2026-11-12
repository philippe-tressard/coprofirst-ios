// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Observation

/// Les constantes de l'aperçu servi, communes à toutes ses entrées.
enum ApercuSaisie {
    /// ~150 ms après le dernier changement de la saisie (`DELAI_APERCU_MS` du site,
    /// arbitré le 11/11/2026, coprofirst#2633) : une rafale de frappe fait UNE demande.
    static let delai: Duration = .milliseconds(150)
}

/// L'aperçu SERVI d'une saisie non enregistrée (#129, #130, #135) : un formulaire ne
/// compose pas une règle d'affichage sur ce qu'on saisit, il la DEMANDE au serveur, qui
/// applique celle de l'objet enregistré — « qui la lira » (`POST /lectures/apercu`), le
/// lieu choisi (`POST /perimetres/libelle`), « Prénom NOM » (`POST /noms/affiche`).
///
/// Le mécanisme est écrit ICI, une fois (`#lib/apercu-serveur` en est le pendant sur le
/// site) ; un écran l'emploie par `ApercuServi`, jamais en recopiant le délai. Les
/// conditions arbitrées le 11/11/2026 :
/// - **le délai** (`ApercuSaisie.delai`) : une saisie neuve annule la demande de la
///   précédente, qui n'est pas encore partie ;
/// - **une réponse périmée est ignorée** : rangée sous SA saisie, elle ne se montre que
///   si cette saisie est encore la courante — une réponse tardive pour un état quitté ne
///   remplace pas la valeur ;
/// - **la dernière valeur reste** pendant l'attente, sans clignoter : `valeur` ne repasse
///   jamais par `nil` ;
/// - **hors ligne**, rien ne part, la dernière valeur servie reste, et la saisie n'est
///   jamais bloquée — un échec se tait de même ;
/// - **une valeur déjà servie** — avec l'objet (`connue`), ou plus tôt dans la saisie —
///   ne se redemande pas, et une demande en route pour la même saisie ne repart pas.
@MainActor @Observable
final class EtatApercu<Entree: Hashable & Sendable, Sortie: Equatable & Sendable> {
    /// Ce que l'écran montre : la sortie de la saisie courante, ou la dernière montrée.
    private(set) var valeur: Sortie?
    @ObservationIgnored private var courante: Entree?
    @ObservationIgnored private var servies: [Entree: Sortie] = [:]
    @ObservationIgnored private var enCours: Entree?
    @ObservationIgnored private var demande: Task<Void, Never>?
    /// Le numéro de la dernière demande : une demande remplacée ne touche plus à rien.
    @ObservationIgnored private var jeton = 0
    @ObservationIgnored private let pause: @Sendable () async throws -> Void

    /// `connue` : la sortie servie AVEC l'objet pour sa saisie d'ouverture — elle se
    /// montre d'emblée et ne se redemande pas. `pause` : le délai ; un test le remplace.
    init(
        connue: (Entree, Sortie)? = nil,
        pause: @escaping @Sendable () async throws -> Void = { try await Task.sleep(for: ApercuSaisie.delai) }
    ) {
        self.pause = pause
        if let (entree, sortie) = connue {
            servies[entree] = sortie
            courante = entree
            valeur = sortie
        }
    }

    /// La saisie est maintenant `entree`. `enLigne` : un appel au serveur peut partir.
    func saisie(_ entree: Entree, enLigne: Bool, demander: @escaping @Sendable (Entree) async throws -> Sortie) {
        courante = entree
        if let servie = servies[entree] {
            abandonner()
            montrer(servie)
            return
        }
        if enCours == entree { return }
        abandonner()
        guard enLigne else { return }
        jeton &+= 1
        let numero = jeton
        enCours = entree
        demande = Task { [pause] in
            do {
                try await pause()
                try Task.checkCancellation()
                let sortie = try await demander(entree)
                self.recevoir(sortie, pour: entree, numero: numero)
            } catch {
                // Annulée, hors ligne ou refusée : la dernière valeur reste, rien n'est bloqué.
                if self.jeton == numero { self.enCours = nil }
            }
        }
    }

    /// La demande en route ne sert plus (saisie changée, écran fermé).
    func abandonner() {
        demande?.cancel()
        demande = nil
        enCours = nil
    }

    /// Attend la fin de la demande en route — pour les tests.
    func demandeEnCours() async {
        await demande?.value
    }

    private func recevoir(_ sortie: Sortie, pour entree: Entree, numero: Int) {
        // La réponse vaut pour SA saisie, même périmée : revenir à cette saisie la montrera
        // sans redemander.
        servies[entree] = sortie
        if jeton == numero { enCours = nil }
        guard entree == courante else { return }
        montrer(sortie)
    }

    private func montrer(_ sortie: Sortie) {
        if valeur != sortie { valeur = sortie }
    }
}
