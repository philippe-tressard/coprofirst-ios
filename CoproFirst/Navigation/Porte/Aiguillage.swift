// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

/// Dans la résidence ouverte, où se pose un écran demandé : l'onglet de la barre qui le
/// porte, « Plus » s'il est au-delà des premiers, ou une feuille pour une affaire dont
/// l'onglet n'est pas dans la barre. Une page que le compte ne voit pas (réservée à un
/// rôle, `PagesOuvertes`) ne s'ouvre pas : le fil, à la place.
enum Aiguillage: Equatable {
    case onglet(String)
    case affaireDansLOnglet(onglet: String, id: Int)
    case affaireEnFeuille(id: Int)
    /// Le fil, puis l'élément de cette clé, dès le fil chargé (`Parcours.aOuvrir`).
    case elementDuFil(String)
    /// La feuille des notifications, par-dessus l'onglet en cours (#17).
    case cloche

    /// L'identifiant de l'onglet « Plus » de `OngletsView`.
    static let idPlus = "plus"

    /// - Parameters:
    ///   - pages: les pages de la barre, dans leur ordre (`Parcours.pagesDeLaBarre`).
    ///   - visibles: combien en tiennent avant « Plus » (`OngletsView.visibles`).
    static func aiguiller(_ ecran: Destination.Ecran, pages: [String], visibles: Int) -> Aiguillage {
        func place(_ id: String) -> String? {
            guard let rang = pages.firstIndex(of: id) else { return nil }
            return rang < visibles ? id : idPlus
        }
        switch ecran {
        case .page(let id):
            return .onglet(place(id) ?? OrdrePages.idFil)
        case .affaire(let id, _):
            let affaires = LienUniversel.idDeLaPage(route: LienUniversel.routeAffaires)
            if let affaires, place(affaires) == affaires {
                return .affaireDansLOnglet(onglet: affaires, id: id)
            }
            return .affaireEnFeuille(id: id)
        case .element(let cle):
            return .elementDuFil(cle)
        case .notifications:
            return .cloche
        case .accueil, .connexion, .navigateur:
            return .onglet(OrdrePages.idFil)
        }
    }
}
