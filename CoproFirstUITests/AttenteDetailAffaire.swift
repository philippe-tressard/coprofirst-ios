// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Le point d'attente commun des tests du détail d'une affaire (#98) : on attend le
/// détail CHARGÉ, jamais une durée, puis le reste se lit par `.exists`. Chaque attente
/// a le plafond de toutes (`Attente.plafond`).
extension XCUIApplication {
    /// Le détail de l'affaire `numero` est chargé : son numéro (le squelette porte
    /// « A-0000 ») ET son bandeau, posé dans la même vue — 🔗 est offert à tout lecteur
    /// (`GesteAffaire.offerts`). Après, chaque icône du bandeau, chaque message et chaque
    /// suite se lit par `.exists` : rien n'arrive plus tard.
    ///
    /// Le numéro est au titre de la barre quand la fiche est poussée (iPhone) ; dans
    /// l'en-tête (`affaire.numero`) quand elle est à côté de sa liste (iPad, #222) — la
    /// colonne de fiche n'a pas de barre à elle. La classe de taille de la fenêtre dit
    /// laquelle, comme l'app la lit (`ListeEtFiche`) — jamais l'appareil.
    @MainActor
    func attendreDetailAffaire(_ numero: String) -> Bool {
        let numeroLu =
            windows.firstMatch.horizontalSizeClass == .regular
            ? descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == 'affaire.numero' AND label == %@", numero)).firstMatch
            : navigationBars[numero]
        guard numeroLu.apparait() else { return false }
        return elementAcces("affaire.lien").apparait()
    }
}
