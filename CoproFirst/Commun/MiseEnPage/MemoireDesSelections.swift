// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'élément ouvert de chaque liste d'une résidence (`ListeEtFiche`), par page ET par liste,
/// hors de l'écran qui la montre (#119, revu par la session iPad le 17/11/2026).
///
/// La sélection vit dans un `@State` de l'écran ; or `OngletsView` change de VUE quand la
/// présentation change (barre du bas, barre latérale, carnet) : au pli d'un iPhone pliable,
/// comme au passage plein écran ↔ Split View d'un iPad, l'écran se reconstruit, et la fiche
/// ouverte se perdait. Une liste qui se nomme (`ListeEtFiche(memoire:)`) la retrouve ici.
///
/// - **La clé est la page et la liste** : une page porte plusieurs listes, parfois du même
///   type d'élément (l'Espace CS : Courriels et Reporting choisissent des affaires) ; une
///   liste qui ne se nomme pas n'est pas gardée — mieux vaut rien que la fiche d'une autre.
/// - **Un `nil` voulu efface la case** : une liste vidée (changement d'onglet) ne rouvre pas
///   l'ancienne fiche au retour.
/// - **En mémoire** pour toute la session de la résidence ; **sur disque**, le marque-page
///   du pliable seulement (`disque`, tenu par `Parcours`), pour un élément qui sait se
///   réécrire en texte (`SelectionGardable`).
@MainActor
final class MemoireDesSelections {
    struct Cle: Hashable, Sendable {
        let page: String
        let liste: String
    }

    /// Le disque du marque-page : absent, rien ne s'y lit ni ne s'y écrit.
    struct Disque {
        let lire: @MainActor (Cle) -> String?
        let garder: @MainActor (String?, Cle) -> Void
    }

    private var cases: [Cle: AnyHashable] = [:]
    var disque: Disque?

    /// L'élément noté sous `cle`, de ce type ; à défaut, celui que le disque sait réécrire.
    func reprendre<Element: Hashable>(_ type: Element.Type, sous cle: Cle) -> Element? {
        if let enMemoire = cases[cle]?.base as? Element { return enMemoire }
        guard let gardable = type as? SelectionGardable.Type, let texte = disque?.lire(cle) else { return nil }
        return gardable.init(cleGardee: texte) as? Element
    }

    /// Note l'élément ouvert de la liste — `nil` efface la case, en mémoire comme sur disque.
    func noter<Element: Hashable>(_ element: Element?, sous cle: Cle) {
        cases[cle] = element.map(AnyHashable.init)
        disque?.garder((element as? SelectionGardable)?.cleGardee, cle)
    }

    /// Une autre résidence s'ouvre : rien de la précédente ne la suit.
    func oublier() { cases = [:] }
}

/// Un élément de liste qui se réécrit en texte, pour le marque-page sur disque : son
/// identifiant seul, jamais son contenu (un numéro d'affaire, pas son titre).
protocol SelectionGardable {
    var cleGardee: String { get }
    init?(cleGardee: String)
}

/// Les cases de la page affichée : la mémoire de la résidence et l'identifiant de la page.
struct SelectionsDeLaPage {
    let memoire: MemoireDesSelections
    let page: String

    func cle(_ liste: String) -> MemoireDesSelections.Cle { .init(page: page, liste: liste) }
}

private struct CleSelectionsDeLaPage: EnvironmentKey {
    static var defaultValue: SelectionsDeLaPage? { nil }
}

extension EnvironmentValues {
    /// Posée par `EcranDePage` ; absente (aperçus, feuilles), une liste ne garde rien.
    var selectionsDeLaPage: SelectionsDeLaPage? {
        get { self[CleSelectionsDeLaPage.self] }
        set { self[CleSelectionsDeLaPage.self] = newValue }
    }
}
