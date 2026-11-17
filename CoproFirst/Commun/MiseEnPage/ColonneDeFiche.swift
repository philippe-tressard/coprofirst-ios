// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La colonne où s'affiche la fiche d'une `ListeEtFiche`, en classe régulière (#222).
///
/// Elle est FOURNIE par l'environnement (`\.colonneDeFiche`) par celui qui tient la page —
/// `PageEtColonneDeFiche`, dans le détail de la barre latérale — et non dessinée par la
/// liste : une pile IMBRIQUÉE dans celle de la page lui prenait son titre et ses boutons.
/// Ici, la page et la fiche sont deux piles SŒURS ; la page garde sa barre. Dans une
/// colonne de `NavigationSplitView`, des piles sœurs partagent pourtant LA barre de la
/// colonne (constaté le 16/11/2026) : la fiche n'y pose rien. Ce qu'elle mettrait en barre
/// se pose dans SA colonne (`\.dansLaColonneDeFiche` : le bandeau d'une affaire, son
/// numéro dans l'en-tête).
///
/// Une seule liste l'occupe à la fois (`jeton`) : la liste qui apparaît l'ouvre, celle qui
/// disparaît (page poussée, autre onglet, Kanban) la ferme — sans fermer celle d'une autre.
/// Une page sans liste ne l'ouvre jamais : elle garde toute la largeur.
@MainActor @Observable
final class ColonneDeFiche {
    /// La fiche à montrer : son identité (la pile repart à chaque autre élément) et sa vue.
    struct Contenu {
        let id: AnyHashable?
        let vue: AnyView
    }

    private(set) var partage = Partage.parDefaut
    private(set) var contenu: Contenu?
    private var occupant: UUID?

    /// Une liste occupe la colonne.
    var ouverte: Bool { occupant != nil }

    func ouvrir(par jeton: UUID, partage: Partage) {
        occupant = jeton
        self.partage = partage
    }

    func montrer(_ contenu: Contenu, par jeton: UUID) {
        guard occupant == jeton else { return }
        self.contenu = contenu
    }

    /// Sans effet si une autre liste l'occupe déjà : sa disparition arrive parfois après
    /// l'apparition de la suivante.
    func fermer(par jeton: UUID) {
        guard occupant == jeton else { return }
        occupant = nil
        contenu = nil
    }
}

private struct CleColonneDeFiche: EnvironmentKey {
    static var defaultValue: ColonneDeFiche? { nil }
}

private struct CleDansLaColonneDeFiche: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// La colonne de fiche que fournit la page (`EcranDePage`) ; absente, une `ListeEtFiche`
    /// en classe régulière dessine liste et fiche côte à côte elle-même.
    var colonneDeFiche: ColonneDeFiche? {
        get { self[CleColonneDeFiche.self] }
        set { self[CleColonneDeFiche.self] = newValue }
    }

    /// Vrai dans la colonne de fiche seulement : une fiche y pose dans son contenu ce
    /// qu'elle mettrait ailleurs en barre de navigation ou en barre du bas.
    var dansLaColonneDeFiche: Bool {
        get { self[CleDansLaColonneDeFiche.self] }
        set { self[CleDansLaColonneDeFiche.self] = newValue }
    }
}

/// Une page et sa colonne de fiche : la page dans sa pile, à gauche, à la largeur de liste
/// que demande la `ListeEtFiche` qui l'occupe ; la fiche dans SA pile, à droite. Colonne
/// fermée, la page prend toute la largeur.
struct PageEtColonneDeFiche<Page: View>: View {
    let page: Page
    @State private var colonne = ColonneDeFiche()
    @Environment(\.horizontalSizeClass) private var classe
    @Environment(\.palette) private var palette

    init(@ViewBuilder page: () -> Page) {
        self.page = page()
    }

    var body: some View {
        GeometryReader { cadre in
            HStack(spacing: 0) {
                page
                    .frame(width: colonne.ouverte ? colonne.partage.largeurDeLaListe(dans: cadre.size.width) : nil)
                    .frame(maxWidth: colonne.ouverte ? nil : .infinity)
                if colonne.ouverte, classe == .regular {
                    Divider().ignoresSafeArea()
                    NavigationStack {
                        colonne.contenu?.vue ?? AnyView(FicheVide())
                    }
                    .environment(\.dansLaColonneDeFiche, true)
                    .id(colonne.contenu?.id)
                    .frame(maxWidth: .infinity)
                    .background(palette.bg)
                }
            }
        }
        .environment(\.colonneDeFiche, colonne)
    }
}
