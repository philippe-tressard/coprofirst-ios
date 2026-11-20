// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Comment se présente la navigation de la résidence ouverte — choisi sur la classe de
/// taille HORIZONTALE, jamais sur l'appareil (#221) : un iPad en Split View étroit est
/// compact, un iPhone pliable déplié est régulier (#119). Le même état (`Parcours.onglet`)
/// sert toutes les présentations ; seul `OngletsView` choisit laquelle s'affiche.
enum PresentationNavigation: Equatable, Sendable {
    /// La barre du bas : quatre pages, puis « Plus » (`BarreDuBas`).
    case barreDuBas
    /// La barre latérale : toutes les pages, Profil et À propos (`BarreLaterale`).
    case barreLaterale
    /// Le carnet de l'iPhone pliable ouvert (#119) : les mêmes entrées que la barre
    /// latérale, en intercalaires sur la tranche droite (`Carnet`).
    case carnet

    /// La classe de taille d'abord : un iPhone pliable déplié en Split View étroit reste
    /// compact. En classe régulière, la charnière ouverte (`Posture`) fait le carnet ; sans
    /// charnière (iPad), la barre latérale.
    static func pour(_ classe: UserInterfaceSizeClass?, posture: Posture = .sansPli) -> Self {
        guard classe == .regular else { return .barreDuBas }
        return posture.ouverte ? .carnet : .barreLaterale
    }

    /// Combien de pages se montrent avant « Plus » — où la porte d'un lien peut se poser.
    var visibles: Int {
        switch self {
        case .barreDuBas: 4
        case .barreLaterale, .carnet: .max
        }
    }

    /// Ce qui est ouvert : l'onglet retenu, et la page ouverte DANS « Plus » s'il l'est.
    struct Place: Equatable, Sendable {
        var onglet: String
        var dansPlus: String?
    }

    /// La même page, d'une présentation à l'autre (rotation, Split View, pliage) : la page
    /// ouverte reste ouverte. Dans « Plus », elle s'y rouvre ; « Plus » seul, sans page
    /// ouverte, devient la première page qu'il portait — la barre latérale et le carnet
    /// n'ont pas de liste « Plus ». Une page que la barre du bas n'a pas où poser (pas de
    /// « Plus ») : le fil.
    static func traduire(_ place: Place, vers cible: Self, pages: [String]) -> Place {
        switch cible {
        case .barreLaterale, .carnet:
            guard place.onglet == Aiguillage.idPlus else { return Place(onglet: place.onglet) }
            let premiere = pages.dropFirst(barreDuBas.visibles).first ?? EntreeFixe.profil.rawValue
            return Place(onglet: place.dansPlus ?? premiere)
        case .barreDuBas:
            if let rang = pages.firstIndex(of: place.onglet), rang < cible.visibles {
                return Place(onglet: place.onglet)
            }
            if place.onglet == Aiguillage.idPlus { return place }
            guard pages.count > cible.visibles else { return Place(onglet: OrdrePages.idFil) }
            let connue = pages.contains(place.onglet) || EntreeFixe(rawValue: place.onglet) != nil
            return Place(onglet: Aiguillage.idPlus, dansPlus: connue ? place.onglet : nil)
        }
    }
}

/// Les entrées qui ne sont pas des pages du site (pages.ts : `href` nul pour le profil ;
/// le pied de page pour « À propos ») : en fin de « Plus », et en bas de la barre latérale.
/// Leurs identifiants partagent l'espace de `Parcours.onglet` avec ceux des pages.
enum EntreeFixe: String, CaseIterable, Identifiable, Sendable {
    case profil
    case aPropos = "a-propos"

    var id: String { rawValue }

    var libelle: String {
        switch self {
        case .profil: "Profil"
        case .aPropos: "À propos"
        }
    }

    var symbole: String {
        switch self {
        case .profil: "person.crop.circle"
        case .aPropos: "info.circle"
        }
    }

    @MainActor @ViewBuilder
    func ecran(_ installation: Installation) -> some View {
        switch self {
        case .profil: ProfilView().pageVue(CheminDuSite.profil).bandeauInstallation()
        // Le pied de page du site : ©, mentions légales, confidentialité, logiciel libre.
        case .aPropos: AProposView(installation: installation).bandeauInstallation()
        }
    }
}

/// Une page de la barre : sa pile de navigation, et l'écran que le registre des menus
/// inscrit pour elle (`RegistreDesMenus`) — « Bientôt » sinon. Un onglet de la barre du
/// bas, ou le détail de la barre latérale.
struct EcranDePage: View {
    let page: PageDeNavigation
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @State private var chemin = NavigationPath()

    var body: some View {
        NavigationStack(path: $chemin) {
            RegistreDesMenus.ecran(ContexteDeMenu(page: page, installation: installation, chemin: $chemin))
        }
        // L'élément ouvert de ses listes survit au changement de présentation (#119).
        .environment(\.selectionsDeLaPage, SelectionsDeLaPage(memoire: parcours.selections, page: page.id))
    }
}
