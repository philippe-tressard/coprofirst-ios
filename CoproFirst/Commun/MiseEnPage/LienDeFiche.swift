// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le lien d'une rangée vers sa fiche, dans la liste d'une `ListeEtFiche` (#222) — à la
/// place d'un `NavigationLink`, à n'importe quelle profondeur de la liste : il CHOISIT
/// `valeur`, et `ListeEtFiche` décide où la fiche s'ouvre (poussée en classe compacte, à
/// côté de la liste en classe régulière). La rangée se souligne par `.rangeeChoisie`, que
/// l'appelant pose sur la carte entière.
///
/// `ligneDeListe` : une rangée de `List`, qui garde le chevron de l'iPhone — un bouton n'en
/// a pas, un `NavigationLink` si ; à côté de la liste, la rangée soulignée le remplace.
///
/// Hors d'une `ListeEtFiche` (aucun choix fourni), le lien redevient un
/// `NavigationLink(value:)` : la pile de la page doit alors savoir ouvrir `Valeur`.
struct LienDeFiche<Valeur: Hashable, Etiquette: View>: View {
    let valeur: Valeur
    var ligneDeListe = false
    @ViewBuilder let etiquette: () -> Etiquette
    @Environment(\.choixDeFiche) private var choix

    var body: some View {
        if let choix {
            Button {
                choix.choisir(AnyHashable(valeur))
            } label: {
                if ligneDeListe {
                    // La couleur du texte, pas la teinte d'un bouton : la rangée d'un lien.
                    HStack(spacing: 8) {
                        etiquette().foregroundStyle(.primary)
                        if choix.enPile {
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.forward")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                    }
                    .contentShape(.rect)
                } else {
                    etiquette()
                }
            }
        } else {
            NavigationLink(value: valeur, label: etiquette)
        }
    }
}

/// Ce qu'une `ListeEtFiche` donne à sa liste : choisir un élément, et savoir si sa fiche
/// sera poussée (`enPile`) ou montrée à côté.
struct ChoixDeFiche {
    let enPile: Bool
    let choisir: (AnyHashable) -> Void
}

private struct CleChoixDeFiche: EnvironmentKey {
    static var defaultValue: ChoixDeFiche? { nil }
}

extension EnvironmentValues {
    /// Fourni à la liste d'une `ListeEtFiche`, retiré de sa fiche : un `LienDeFiche` posé
    /// dans une fiche ne choisit pas pour la liste d'à côté.
    var choixDeFiche: ChoixDeFiche? {
        get { self[CleChoixDeFiche.self] }
        set { self[CleChoixDeFiche.self] = newValue }
    }
}
