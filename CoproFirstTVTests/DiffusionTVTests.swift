// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// La diffusion de l'écran de hall (#218, lot 3) : le défilement, la relecture, le retrait,
/// les images — et l'appairage gardé d'un lancement à l'autre.
private func affiche(_ id: Int, images: Int = 0) -> AfficheHall {
    AfficheHall(id: id, titre: "Affiche \(id)", message: "<p>Message \(id)</p>", images: images, creeLe: .now)
}

@MainActor
private func diffusion(
    _ serveur: ServeurEcranSimule, attendre: @escaping @Sendable (Duration) async throws -> Void = { _ in }
) -> DiffusionTV {
    DiffusionTV(residence: residenceDuHall(), jeton: "jeton-1", service: serveur, attendre: attendre)
}

@MainActor
@Test func lesAffichesDefilentEtReviennentALaPremiere() async {
    let serveur = ServeurEcranSimule()
    await serveur.regler(lecture: .success([affiche(1), affiche(2), affiche(3)]))
    let modele = diffusion(serveur)
    await modele.relire()
    #expect(modele.lue && modele.affiche?.id == 1)
    #expect(await serveur.jetonsPresentes == ["jeton-1"], "la lecture présente le jeton de l'écran")
    modele.suivante()
    modele.suivante()
    #expect(modele.affiche?.id == 3)
    modele.suivante()
    #expect(modele.affiche?.id == 1, "après la dernière, la première")
}

/// Relue, la liste garde l'affiche à l'écran si elle y est encore ; sinon, la première.
@MainActor
@Test func uneRelectureGardeLAfficheALEcran() async {
    let serveur = ServeurEcranSimule()
    await serveur.regler(lecture: .success([affiche(1), affiche(2), affiche(3)]))
    let modele = diffusion(serveur)
    await modele.relire()
    modele.suivante()
    await serveur.regler(lecture: .success([affiche(4), affiche(2)]))
    await modele.relire()
    #expect(modele.affiche?.id == 2 && modele.rang == 1)
    await serveur.regler(lecture: .success([affiche(5)]))
    await modele.relire()
    #expect(modele.affiche?.id == 5)
}

/// Hors ligne : la dernière liste reste. Jeton retiré (401) : l'écran le sait.
@MainActor
@Test func horsLigneLaListeResteEtUnJetonRetireSeVoit() async {
    let serveur = ServeurEcranSimule()
    await serveur.regler(lecture: .success([affiche(1)]))
    let modele = diffusion(serveur)
    await modele.relire()
    await serveur.regler(lecture: .failure(.horsLigne))
    await modele.relire()
    #expect(modele.affiches.map(\.id) == [1] && !modele.retire)
    await serveur.regler(lecture: .failure(.sessionExpiree))
    await modele.relire()
    #expect(modele.retire)
}

/// La boucle : une lecture, puis une affiche toutes les `parAffiche`, une relecture toutes
/// les `relecture` ; elle s'arrête au retrait.
@MainActor
@Test func laBoucleRelitAuRythmeEtSArreteAuRetrait() async {
    let serveur = ServeurEcranSimule()
    await serveur.regler(lecture: .success([affiche(1), affiche(2)]))
    let tours = max(1, Int(RythmeTV.relecture / RythmeTV.parAffiche))
    let compteur = HorlogeSimulee()
    let modele = DiffusionTV(
        residence: residenceDuHall(), jeton: "j", service: serveur,
        attendre: { duree in
            compteur.attendre(duree)
            if compteur.attentes.count == tours * 2 { await serveur.regler(lecture: .failure(.sessionExpiree)) }
        })
    await modele.diffuser()
    #expect(modele.retire)
    #expect(compteur.attentes.allSatisfy { $0 == RythmeTV.parAffiche })
    #expect(await serveur.lectures == 3, "au départ, après \(tours) affiches, puis après \(tours * 2)")
}

/// Une image illisible est sautée, et l'affiche se relira : rien n'est gardé d'incomplet.
@MainActor
@Test func lesImagesSeLisentUneFoisEtUnEchecNeSeGardePas() async {
    let serveur = ServeurEcranSimule()
    let modele = diffusion(serveur)
    await serveur.regler(imagesEnEchec: [1])
    let premiere = await modele.imagesDe(affiche(7, images: 2))
    #expect(premiere == [Data([7, 0])])
    await serveur.regler(imagesEnEchec: [])
    #expect(await modele.imagesDe(affiche(7, images: 2)) == [Data([7, 0]), Data([7, 1])])
}

/// L'appairage se garde au coffre : rallumé, l'écran diffuse ; retiré, il l'oublie et
/// redemande un code pour la même résidence.
@MainActor
@Test func lAppairageSeGardeEtUnRetraitLOublie() {
    let coffre = CoffreEnMemoire()
    let hall = HallTV(entree: EntreeTV(), service: ServeurEcranSimule(), memoire: MemoireEcran(coffre: coffre))
    #expect(hall.etape == .entree)
    hall.appairer(residenceDuHall(), jeton: "jeton-1")
    let garde = MemoireEcran.Appairage(residence: residenceDuHall(), jeton: "jeton-1")
    #expect(hall.etape == .diffusion(garde))

    let rallume = HallTV(entree: EntreeTV(), service: ServeurEcranSimule(), memoire: MemoireEcran(coffre: coffre))
    #expect(rallume.etape == .diffusion(garde), "rallumée, l'Apple TV reprend sans personne")

    rallume.retirer()
    #expect(rallume.etape == .appairage(residenceDuHall()))
    #expect(MemoireEcran(coffre: coffre).lire() == nil, "le jeton retiré ne se garde pas")
}
