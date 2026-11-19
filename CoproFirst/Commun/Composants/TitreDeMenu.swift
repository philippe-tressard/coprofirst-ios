// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

extension View {
    /// Le titre d'un écran de menu : grand titre (serif, `ApparenceNavigation`) aux
    /// tailles ordinaires, titre en ligne aux tailles d'accessibilité — un grand titre
    /// y coupe ses mots et mange la moitié de l'écran (#33, #41). Une fiche ouverte à
    /// côté (iPad, #222) : la barre court sur la page ET la fiche, un titre en ligne s'y
    /// centrerait sur leur séparation — il se pose en tête, en grand (`.inlineLarge`).
    func titreDeMenu() -> some View { modifier(TitreDeMenu()) }
}

struct TitreDeMenu: ViewModifier {
    @Environment(\.dynamicTypeSize) private var tailleTexte
    @Environment(\.colonneDeFiche) private var colonne

    /// UN modificateur, jamais un `if` sur la colonne : deux branches donnent à la page deux
    /// identités — la colonne qui s'ouvre la recréait, sa liste refermait la colonne en
    /// disparaissant, et l'ordre apparition/disparition décidait d'une boucle sans fin (fil
    /// principal occupé, échantillon iPad de la CI, #279).
    func body(content: Content) -> some View {
        let mode = TitreDeMenu.mode(colonneOuverte: colonne?.ouverte == true, taille: tailleTexte)
        content.toolbarTitleDisplayMode(mode.barre)
    }

    /// `ToolbarTitleDisplayMode` ne se compare pas : le choix se dit ici, et se teste.
    enum Mode: Equatable {
        case grand, enLigne, enTete

        var barre: ToolbarTitleDisplayMode {
            switch self {
            case .grand: .large
            case .enLigne: .inline
            case .enTete: .inlineLarge
            }
        }
    }

    static func mode(colonneOuverte: Bool, taille: DynamicTypeSize) -> Mode {
        if colonneOuverte { return .enTete }
        return taille.isAccessibilitySize ? .enLigne : .grand
    }
}

extension TitreDeMenu {
    /// L'action d'une page de menu (créer…) va à droite quand le titre se pose en tête :
    /// iOS 26 retire de la barre les éléments de gauche d'un titre `.inlineLarge`, sans menu
    /// pour les retrouver — « Nouvelle affaire » et « Créer » disparaissaient sur iPad (#223).
    static func actionADroite(colonneOuverte: Bool, taille: DynamicTypeSize) -> Bool {
        mode(colonneOuverte: colonneOuverte, taille: taille) == .enTete
    }
}

/// L'action d'une page de menu, posée dans sa barre : à gauche d'ordinaire, à droite quand
/// une fiche est ouverte à côté (`TitreDeMenu.actionADroite`), comme « Nouvelle note » de Notes.
struct ActionDeMenu<Contenu: View>: ToolbarContent {
    @ViewBuilder let contenu: () -> Contenu
    @Environment(\.colonneDeFiche) private var colonne
    @Environment(\.dynamicTypeSize) private var taille

    var body: some ToolbarContent {
        let aDroite = TitreDeMenu.actionADroite(colonneOuverte: colonne?.ouverte == true, taille: taille)
        ToolbarItem(placement: aDroite ? .topBarTrailing : .topBarLeading) { contenu() }
    }
}
