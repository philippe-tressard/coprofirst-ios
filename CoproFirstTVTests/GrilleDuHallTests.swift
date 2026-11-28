// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// La disposition du Fil en tuiles (#429) : chaque élément à la place de son registre SERVI,
/// aucune case vide, le carrousel en boucle sans doublon.

func elementDuHall(
    _ numero: Int, _ registre: RegistreDuFil, type: String = "ticket_ouvert", photos: Int = 0
) -> ElementDuHall {
    ElementDuHall(
        id: "\(type):\(numero)", type: type, registre: registre, titre: "Élément \(numero)", detail: nil,
        date: .now, echeance: nil, lieu: nil, photos: photos, lien: "/fil/\(numero)")
}

let communauteComplete = CommunauteDuHall(
    sondage: SondageALaUne(id: 12, question: "Quel jour ?", votants: 29, lien: "/sondages/12"),
    idee: IdeeALaUne(id: 3, titre: "Un composteur", soutiens: 18, lien: "/sondages#idees"),
    annonce: AnnonceALaUne(
        id: 21, titre: "Lave-linge", prixCentimes: 18_000, negociable: true, photos: 0, lien: "/sondages#annonces"))

/// Le registre servi décide seul : un `ticket_ouvert` servi en `fil` reste au carrousel, et
/// l'ordre servi est gardé dans chaque registre.
@Test func chaqueElementVaALaPlaceDeSonRegistreServi() {
    let fil = FilDuHall(
        elements: [
            elementDuHall(1, .fil), elementDuHall(2, .urgent), elementDuHall(3, .epingle), elementDuHall(4, .fil),
            elementDuHall(5, .epingle), elementDuHall(6, .urgent),
        ],
        communaute: communauteComplete)
    let grille = GrilleDuHall(fil)
    #expect(grille.haut.map(\.id) == ["urgence.ticket_ouvert:2", "urgence.ticket_ouvert:6", "epingles"])
    guard case .epingles(let epingles) = grille.haut.last else {
        Issue.record("les épinglés forment la dernière tuile du haut")
        return
    }
    #expect(epingles.map(\.id) == ["ticket_ouvert:3", "ticket_ouvert:5"])
    #expect(grille.reste.map(\.id) == ["ticket_ouvert:1", "ticket_ouvert:4"], "l'ordre servi, rien de recomposé")
    #expect(grille.milieu.map(\.id) == ["sondage.12", "idee.3", "annonce.21"])
}

/// Sans urgence, les épinglés prennent toute la rangée du haut ; sans épinglé, les urgences ;
/// sans l'un ni l'autre, la rangée n'est pas posée.
@Test func uneRangeeSansUrgenceLaisseToutAuxEpingles() {
    let sansUrgence = GrilleDuHall(FilDuHall(elements: [elementDuHall(3, .epingle), elementDuHall(1, .fil)]))
    #expect(sansUrgence.haut.map(\.id) == ["epingles"])
    let sansEpingle = GrilleDuHall(FilDuHall(elements: [elementDuHall(2, .urgent)]))
    #expect(sansEpingle.haut.map(\.id) == ["urgence.ticket_ouvert:2"])
    #expect(GrilleDuHall(FilDuHall(elements: [elementDuHall(1, .fil)])).haut.isEmpty)
}

/// Une tuile de la communauté sans contenu est absente : ses voisines se partagent la rangée.
@Test func uneTuileDeLaCommunauteSansContenuEstAbsente() {
    var communaute = communauteComplete
    communaute.idee = nil
    let grille = GrilleDuHall(FilDuHall(communaute: communaute))
    #expect(grille.milieu.map(\.id) == ["sondage.12", "annonce.21"])
    #expect(grille.milieu.map(\.poids) == [1, 2], "la petite annonce, avec sa photo, en prend deux parts")
    #expect(GrilleDuHall(FilDuHall()).milieu.isEmpty)
}

/// Le carrousel : en boucle à partir de la carte en tête, jamais deux fois la même carte ; il
/// ne défile que s'il a plus de cartes que de places.
@Test func leCarrouselTourneDansLOrdreServiSansDoublon() {
    let reste = (1...6).map { elementDuHall($0, .fil) }
    let grille = GrilleDuHall(FilDuHall(elements: reste))
    #expect(grille.carrousel(depuis: 0, places: 4).map(\.titre) == ["Élément 1", "Élément 2", "Élément 3", "Élément 4"])
    #expect(grille.carrousel(depuis: 4, places: 4).map(\.titre) == ["Élément 5", "Élément 6", "Élément 1", "Élément 2"])
    #expect(grille.defile(places: 4))
    let court = GrilleDuHall(FilDuHall(elements: Array(reste.prefix(3))))
    #expect(court.carrousel(depuis: 2, places: 4).map(\.titre) == ["Élément 3", "Élément 1", "Élément 2"])
    #expect(!court.defile(places: 4), "trois cartes pour quatre places : rien ne bouge")
    #expect(GrilleDuHall(FilDuHall()).carrousel(depuis: 0, places: 4).isEmpty)
}

/// Le tour de la mise en avant : le haut, la communauté, puis la carte en tête du carrousel.
@Test func leTourPasseParChaqueRangee() {
    let fil = FilDuHall(
        elements: [elementDuHall(2, .urgent), elementDuHall(1, .fil), elementDuHall(4, .fil)],
        communaute: CommunauteDuHall(sondage: communauteComplete.sondage))
    #expect(
        GrilleDuHall(fil).tour(premiere: 1, places: 4).map(\.id)
            == ["urgence.ticket_ouvert:2", "sondage.12", "carte.ticket_ouvert:4"])
}

/// Le rythme : un cran à 13 s, une mise en avant à 20 s ouverte 10 s — le carrousel attend
/// qu'elle se referme —, une relecture à 60 s.
@Test func laCadenceOuvreFermeEtSuspendLeCarrousel() {
    var cadence = CadenceDuHall()
    var gestes: [(CadenceDuHall.Geste, Duration)] = []
    var instant = Duration.zero
    var ouvertures: [Duration] = []
    while instant < .seconds(75) {
        let (geste, attente) = cadence.prochain()
        instant += attente
        gestes.append((geste, instant))
        if geste == .ouvrir {
            cadence.ouverte()
            ouvertures.append(instant)
        }
    }
    let lus = gestes.map { "\($0.0)@\($0.1.components.seconds)" }
    #expect(Array(lus.prefix(6)) == ["cran@13", "ouvrir@20", "fermer@30", "cran@36", "cran@49", "ouvrir@50"])
    #expect(ouvertures.first == .seconds(20))
    #expect(zip(ouvertures, ouvertures.dropFirst()).allSatisfy { $1 - $0 == RythmeTV.miseEnAvant }, "toutes les 30 s")
    #expect(lus.contains("relire@60"))
    for (rang, ouverture) in ouvertures.enumerated() {
        let pendant = gestes.filter { $0.1 > ouverture && $0.1 < ouverture + RythmeTV.ouverture }
        #expect(!pendant.contains { $0.0 == .cran }, "aucun cran pendant la mise en avant \(rang + 1)")
    }
}

/// Sans tuile à montrer, l'ouverture ne s'arme pas : le carrousel continue.
@Test func uneOuvertureSansTuileNeSuspendRien() {
    var cadence = CadenceDuHall()
    _ = cadence.prochain()
    #expect(cadence.prochain().0 == .ouvrir)
    #expect(!cadence.miseEnAvantOuverte)
    #expect(cadence.prochain().0 == .cran)
}
