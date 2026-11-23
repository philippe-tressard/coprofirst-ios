// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// ⌘F au clavier matériel de l'iPad (#223) : il ouvre la recherche de l'écran courant,
/// là où elle existe (`ChampRecherche`, `.barreDeRecherche`).
///
/// ⌘F est la commande « Rechercher » du système : un bouton de vue (`keyboardShortcut`)
/// ne la reçoit pas, quand ⌘⇧F, lui, passe (mesuré au simulateur iPad le 22/11/2026). On
/// répond donc à son ACTION, `find:`, au délégué de l'app (`DelegueApp.find`), qui ouvre la
/// dernière recherche montée. Au simulateur, la frappe n'y arrive pas à coup sûr après une
/// relance de l'app par XCUITest : le geste se contrôle sur un iPad, clavier branché (#223).
extension View {
    /// Cette recherche répond à ⌘F tant qu'elle est la dernière apparue à l'écran.
    func rechercheAuClavier(_ ouvrir: @escaping @MainActor () -> Void) -> some View {
        modifier(RechercheAuClavier(ouvrir: ouvrir))
    }
}

private struct RechercheAuClavier: ViewModifier {
    let ouvrir: @MainActor () -> Void
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear { RecherchesMontees.partagees.monter(id, ouvrir: ouvrir) }
            .onDisappear { RecherchesMontees.partagees.demonter(id) }
    }
}

/// Les recherches à l'écran, dans l'ordre où elles sont apparues. Deux peuvent l'être à la
/// fois — la feuille « Noter » au-dessus de Prestataires, qui garde la sienne : ⌘F va à la
/// dernière apparue, celle que l'on voit, puis de nouveau à la page quand la feuille se
/// referme.
@MainActor
final class RecherchesMontees {
    static let partagees = RecherchesMontees()
    private var pile: [(id: UUID, ouvrir: @MainActor () -> Void)] = []

    func monter(_ id: UUID, ouvrir: @escaping @MainActor () -> Void) {
        pile.removeAll { $0.id == id }
        pile.append((id, ouvrir))
    }

    func demonter(_ id: UUID) { pile.removeAll { $0.id == id } }

    /// Ouvre la dernière recherche montée ; `false` s'il n'y en a aucune à l'écran.
    @discardableResult
    func ouvrirLaDerniere() -> Bool {
        guard let derniere = pile.last else { return false }
        derniere.ouvrir()
        return true
    }
}
