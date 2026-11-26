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
    /// colonne de fiche n'a pas de barre à elle. `ficheACote` dit laquelle.
    @MainActor
    func attendreDetailAffaire(_ numero: String) -> Bool {
        let numeroLu =
            ficheACote
            ? descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == 'affaire.numero' AND label == %@", numero)).firstMatch
            : navigationBars[numero]
        guard numeroLu.apparait() else { return false }
        return elementAcces("affaire.lien").apparait()
    }

    /// ✏️ du bandeau, JUSQU'À la feuille « Modifier » lue (son « Enregistrer ») — le seul
    /// toucher de `affaire.modifier`, que `scripts/touchers_onglets.py` tient. Nu, un toucher
    /// perdu sous charge laissait le détail sans feuille, et le test rougissait 30 s plus loin
    /// sur sa première ligne (main 1c47c05, échantillon iPad du 25/11, #400). Ouvrir une
    /// feuille est idempotent : la reprise est déclarée au résumé, et ne part que si la feuille
    /// n'est toujours pas là (`toucher(_:jusqua:)`).
    @MainActor
    func ouvrirModificationAffaire(file: StaticString = #filePath, line: UInt = #line) {
        toucher(elementAcces("affaire.modifier"), jusqua: buttons["modifier.enregistrer"], file: file, line: line)
    }
}

extension XCUIApplication {
    /// Une fiche s'ouvre-t-elle à côté de sa liste ? Comme l'app le décide : la fenêtre en
    /// classe régulière ET plus large que haute (`FicheParDessus`) — en portrait, l'iPad
    /// pousse la fiche par-dessus la liste, comme l'iPhone. Jamais l'appareil.
    @MainActor
    var ficheACote: Bool {
        let fenetre = windows.firstMatch
        return fenetre.horizontalSizeClass == .regular && fenetre.frame.width > fenetre.frame.height
    }
}
