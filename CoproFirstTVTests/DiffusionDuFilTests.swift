// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import CoreImage
import Foundation
import Testing

@testable import CoproFirst

/// La diffusion du Fil (#429) : la relecture, le réseau qui manque, le retrait, le cycle de la
/// mise en avant, les photos, le QR code — sur le serveur simulé de l'écran.

@MainActor
private func diffusion(
    _ serveur: ServeurFilSimule, attendre: @escaping @Sendable (Duration) async throws -> Void = { _ in }
) -> DiffusionDuFil {
    DiffusionDuFil(residence: residenceDuHall(), jeton: "jeton-1", service: serveur, attendre: attendre)
}

private func reste(_ numeros: [Int]) -> FilDuHall {
    FilDuHall(elements: numeros.map { elementDuHall($0, .fil) })
}

/// Relu, le Fil garde la carte en tête du carrousel si elle y est encore ; sinon, la première.
@MainActor
@Test func laRelectureGardeLaCarteALEcran() async {
    let serveur = ServeurFilSimule(lecture: .success(reste([1, 2, 3, 4, 5, 6])))
    let modele = diffusion(serveur)
    await modele.relire()
    #expect(await serveur.jetonsPresentes == ["jeton-1"], "la lecture présente le jeton de l'écran")
    modele.cran()
    modele.cran()
    #expect(modele.carrousel.first?.titre == "Élément 3")
    await serveur.regler(lecture: .success(reste([9, 3, 4, 5, 6, 7])))
    await modele.relire()
    #expect(modele.carrousel.first?.titre == "Élément 3" && modele.premiere == 1)
    await serveur.regler(lecture: .success(reste([8, 9, 10, 11, 12])))
    await modele.relire()
    #expect(modele.carrousel.first?.titre == "Élément 8")
}

/// Hors ligne : la dernière lecture reste à l'écran. Jeton retiré (401) : l'écran le sait.
@MainActor
@Test func sansReseauLaDerniereLectureReste() async throws {
    let fil = try FilSimule.fil()
    let serveur = ServeurFilSimule(lecture: .success(fil))
    let modele = diffusion(serveur)
    await modele.relire()
    await serveur.regler(lecture: .failure(.horsLigne))
    await modele.relire()
    #expect(modele.fil == fil && modele.lue && !modele.retire)
    await serveur.regler(lecture: .failure(.sessionExpiree))
    await modele.relire()
    #expect(modele.retire)
}

/// Le carrousel ne bouge pas quand le Fil a moins de cartes que de places.
@MainActor
@Test func unCarrouselCourtNeDefilePas() async {
    let modele = diffusion(ServeurFilSimule(lecture: .success(reste([1, 2]))))
    await modele.relire()
    modele.cran()
    #expect(modele.premiere == 0 && modele.carrousel.map(\.titre) == ["Élément 1", "Élément 2"])
}

/// Le cycle : la boucle suit la cadence — chaque tuile du tour s'agrandit à son tour puis se
/// referme, le carrousel avance entre deux, le Fil se relit — et s'arrête au retrait.
@MainActor
@Test func laMiseEnAvantPasseDeTuileEnTuileEtSeReferme() async throws {
    let serveur = ServeurFilSimule(lecture: .success(try FilSimule.fil()))
    let horloge = HorlogeSimulee()
    let ouvertes = TuilesVues()
    let temoin = Temoin()
    let modele = DiffusionDuFil(
        residence: residenceDuHall(), jeton: "j", service: serveur,
        attendre: { duree in
            horloge.attendre(duree)
            await MainActor.run { ouvertes.noter(temoin.modele?.enAvant) }
            if horloge.attentes.count == 40 { await serveur.regler(lecture: .failure(.sessionExpiree)) }
        })
    temoin.modele = modele
    await modele.diffuser()
    #expect(modele.retire)
    let vues = ouvertes.distinctes
    #expect(
        Array(vues.prefix(5))
            == ["urgence.ticket_ouvert:41", "epingles", "sondage.12", "idee.3", "annonce.21"],
        "le haut, puis la communauté")
    #expect(vues.count > 5 && vues[5].hasPrefix("carte."), "puis la carte en tête du carrousel")
    #expect(ouvertes.fermetures > 0, "chaque mise en avant se referme")
    #expect(await serveur.lectures >= 3, "le Fil se relit toutes les \(RythmeTV.relectureDuFil)")
}

/// Une tuile qui n'est plus servie se referme à la relecture.
@MainActor
@Test func uneTuileQuiNEstPlusServieSeReferme() async {
    let serveur = ServeurFilSimule(lecture: .success(FilDuHall(elements: [elementDuHall(2, .urgent)])))
    let modele = diffusion(serveur)
    await modele.relire()
    modele.ouvrir()
    #expect(modele.enAvant == "urgence.ticket_ouvert:2")
    await serveur.regler(lecture: .success(reste([1])))
    await modele.relire()
    #expect(modele.enAvant == nil && modele.tuileEnAvant == nil)
}

/// Les photos se lisent une fois avec le jeton ; celles d'un élément qui n'est plus servi
/// s'oublient à la relecture.
@MainActor
@Test func lesPhotosSeLisentUneFoisPuisSOublient() async {
    let serveur = ServeurFilSimule(lecture: .success(FilDuHall(elements: [elementDuHall(1, .fil, photos: 2)])))
    let modele = diffusion(serveur)
    await modele.relire()
    let source = SourcePhoto.element("ticket_ouvert:1")
    #expect(await modele.photosDe(source, nombre: 2).count == 2)
    _ = await modele.photosDe(source, nombre: 2)
    #expect(await serveur.photosLues == [source, source], "deux photos, lues une seule fois")
    await serveur.regler(lecture: .success(reste([5])))
    await modele.relire()
    _ = await modele.photosDe(source, nombre: 2)
    #expect(await serveur.photosLues.count == 4, "l'élément parti, sa copie aussi")
}

/// Le QR code porte l'adresse servie, sur le site de la résidence — relu par Core Image.
@MainActor
@Test func leQRCodePorteLAdresseDeLElement() throws {
    let modele = diffusion(ServeurFilSimule(lecture: .success(.vide)))
    let adresse = try #require(modele.adresse("/sondages/12"))
    #expect(adresse.absoluteString == "https://tilleuls.example.com/sondages/12")
    let image = try #require(CodeQR.image(adresse.absoluteString))
    let detecteur = try #require(
        CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]))
    let agrandie = CIImage(cgImage: image).transformed(by: CGAffineTransform(scaleX: 8, y: 8))
    let lus = detecteur.features(in: agrandie).compactMap { ($0 as? CIQRCodeFeature)?.messageString }
    #expect(lus == [adresse.absoluteString])
}

/// Le Fil simulé : les jeux de démo de l'iPhone, passés par les décisions du serveur — le
/// registre servi, ce qui n'est lu que par une partie des résidents laissé de côté, la
/// communauté à la une avec ses compteurs.
@Test func leFilSimuleSertLesJeuxDeDemoDeLIPhone() throws {
    let fil = try FilSimule.fil()
    #expect(fil.du(.urgent).map(\.id) == ["ticket_ouvert:41"])
    #expect(fil.du(.epingle).map(\.id) == ["publication:12", "point_conseil:2"])
    #expect(!fil.elements.contains { $0.id == "ticket_mis_a_jour:44" }, "lu par les copropriétaires seuls")
    #expect(fil.elements.first { $0.id == "ticket_ouvert:41" }?.photos == 4)
    #expect(fil.communaute.sondage?.votants == 29)
    #expect(fil.communaute.idee?.soutiens == 18)
    #expect(fil.communaute.annonce?.prixCentimes == 18_000)
    let sans = try FilSimule.fil(sans: [.urgence, .idee])
    #expect(sans.du(.urgent).isEmpty && sans.communaute.idee == nil && sans.communaute.sondage != nil)
}

/// La diffusion, lue depuis son attente.
@MainActor
private final class Temoin {
    var modele: DiffusionDuFil?
}

/// Les tuiles vues agrandies pendant la boucle, dans l'ordre.
private final class TuilesVues: @unchecked Sendable {
    private let verrou = NSLock()
    private var vues: [String?] = []

    func noter(_ tuile: String?) { verrou.withLock { vues.append(tuile) } }

    /// Chaque mise en avant une fois, dans l'ordre où elle s'est ouverte.
    var distinctes: [String] {
        verrou.withLock {
            zip([nil] + vues, vues).compactMap { avant, apres in apres != avant ? apres : nil }
        }
    }

    var fermetures: Int {
        verrou.withLock { zip(vues, vues.dropFirst()).filter { $0 != nil && $1 == nil }.count }
    }
}
