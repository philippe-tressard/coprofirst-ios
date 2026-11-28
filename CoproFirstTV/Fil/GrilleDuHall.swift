// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Une tuile de l'écran : un élément, ou un groupe que la maquette 5.2 réunit (#429).
enum TuileDuHall: Identifiable, Hashable, Sendable {
    case urgence(ElementDuHall)
    /// Les épinglés, ensemble : une tuile dorée qui les liste.
    case epingles([ElementDuHall])
    case sondage(SondageALaUne)
    case idee(IdeeALaUne)
    case annonce(AnnonceALaUne)
    /// Une carte du reste du Fil, dans le carrousel.
    case carte(ElementDuHall)

    var id: String {
        switch self {
        case .urgence(let element): "urgence.\(element.id)"
        case .epingles: "epingles"
        case .sondage(let sondage): "sondage.\(sondage.id)"
        case .idee(let idee): "idee.\(idee.id)"
        case .annonce(let annonce): "annonce.\(annonce.id)"
        case .carte(let element): "carte.\(element.id)"
        }
    }

    /// Sa part de la largeur de sa rangée : la petite annonce, avec sa photo, en prend deux.
    var poids: Double {
        if case .annonce = self { return 2 }
        return 1
    }
}

/// La disposition de l'écran, calculée d'une lecture — sans vue, donc testée seule.
///
/// Aucune case vide : sans urgence, les épinglés prennent toute la rangée du haut (et
/// inversement) ; une tuile de la communauté absente laisse sa place à ses voisines ; une
/// rangée sans tuile n'est pas posée.
struct GrilleDuHall: Equatable, Sendable {
    /// Les urgences, puis les épinglés réunis.
    let haut: [TuileDuHall]
    /// Le sondage, l'idée, la petite annonce : ce que le serveur met à la une.
    let milieu: [TuileDuHall]
    /// Le reste du Fil, dans l'ordre servi.
    let reste: [ElementDuHall]

    init(_ fil: FilDuHall) {
        let epingles = fil.du(.epingle)
        haut = fil.du(.urgent).map(TuileDuHall.urgence) + (epingles.isEmpty ? [] : [.epingles(epingles)])
        let communaute = fil.communaute
        milieu = [
            communaute.sondage.map(TuileDuHall.sondage),
            communaute.idee.map(TuileDuHall.idee),
            communaute.annonce.map(TuileDuHall.annonce),
        ].compactMap { $0 }
        reste = fil.du(.fil)
    }

    /// Les cartes du carrousel à l'écran : `places` au plus, à partir de `premiere`, en
    /// boucle — jamais deux fois la même quand le Fil en a moins que de places.
    func carrousel(depuis premiere: Int, places: Int) -> [ElementDuHall] {
        guard !reste.isEmpty, places > 0 else { return [] }
        let depart = ((premiere % reste.count) + reste.count) % reste.count
        return (0..<min(places, reste.count)).map { reste[(depart + $0) % reste.count] }
    }

    /// Le carrousel défile-t-il ? Seulement s'il a plus de cartes que de places.
    func defile(places: Int) -> Bool { reste.count > places }

    /// Les tuiles qui se mettent en avant, chacune à son tour : le haut, la communauté, puis
    /// la première carte du carrousel à l'écran.
    func tour(premiere: Int, places: Int) -> [TuileDuHall] {
        haut + milieu + carrousel(depuis: premiere, places: places).prefix(1).map(TuileDuHall.carte)
    }
}
