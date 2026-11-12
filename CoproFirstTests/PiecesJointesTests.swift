// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// Les pièces jointes, rangées et nommées comme le site (`#lib/fichiers.ts`), puis ouvertes
/// en fichiers locaux. Avant ce lot, l'app jetait les documents : une affaire avec un devis
/// PDF ne le montrait nulle part.

@Test func lesDocumentsNeSontPlusJetes() {
    let pieces = PiecesJointes(urls: [
        "/uploads/a.jpg", "/uploads/devis.pdf", "/uploads/b.HEIC", "/uploads/c.avif", "/uploads/liste.xlsx",
    ])
    #expect(pieces.photos == ["/uploads/a.jpg", "/uploads/b.HEIC", "/uploads/c.avif"])
    #expect(pieces.documents == ["/uploads/devis.pdf", "/uploads/liste.xlsx"])
}

@Test func uneMemeAdresseServieDeuxFoisNeCompteQuUneFois() {
    // Le serveur peut servir une photo dans `photos_urls` ET dans `fichiers_urls`.
    let pieces = PiecesJointes(urls: ["/uploads/a.jpg", "", "/uploads/a.jpg", "/uploads/n.pdf", "/uploads/n.pdf"])
    #expect(pieces.photos == ["/uploads/a.jpg"])
    #expect(pieces.documents == ["/uploads/n.pdf"])
    #expect(PiecesJointes(urls: []).vide)
}

@Test func lesPiecesSeDisentAuLecteurDEcran() {
    #expect(PiecesJointes(urls: ["/a.jpg"]).enClair == "1 photo")
    #expect(PiecesJointes(urls: ["/a.jpg", "/b.png", "/c.pdf"]).enClair == "2 photos, 1 pièce jointe")
    #expect(PiecesJointes(urls: ["/c.pdf", "/d.docx"]).enClair == "2 pièces jointes")
    #expect(PiecesJointes.aucune.enClair == nil)
}

@Test func leNomMontreEstCeluiDuSite() {
    let televerse = "/uploads/tickets/0123456789abcdef0123456789abcdef_Devis%20plombier.pdf"
    #expect(Fichiers.nomAffiche(televerse) == "Devis plombier.pdf")
    #expect(Fichiers.nomSansExtension(televerse) == "Devis plombier")
    #expect(Fichiers.typeAffiche(televerse) == "PDF")
    // Un préfixe qui n'est pas hexadécimal, ou trop court, reste dans le nom.
    #expect(Fichiers.nomAffiche("/uploads/x/0123456789abcdef0123456789abcdeZ_a.pdf").hasPrefix("0123"))
    #expect(Fichiers.nomAffiche("/uploads/x/abc_a.pdf") == "abc_a.pdf")
    // Un nom qui n'est QUE le préfixe ne devient pas vide.
    #expect(Fichiers.nomAffiche("/uploads/0123456789abcdef0123456789abcdef_") == "0123456789abcdef0123456789abcdef_")
}

@Test(arguments: [
    ("/u/a.docx", "WORD"), ("/u/a.XLS", "EXCEL"), ("/u/a.pptx", "POWERPOINT"), ("/u/a.txt", "TEXTE"),
    ("/u/a.jpeg", "JPG"), ("/u/a.md", "MD"), ("/u/sans-extension", "FICHIER"), ("/u/.cache", "FICHIER"),
])
func leTypeMontreSuitLesFamillesDuSite(chemin: String, type: String) {
    #expect(Fichiers.typeAffiche(chemin) == type)
}

@Test func lesExtensionsDImageSontCellesDuSite() {
    // Générées depuis `EXTENSIONS_IMAGE` : `jpe?g` et `tiff?` y sont dépliés.
    #expect(FichiersDuSite.extensionsImage.isSuperset(of: ["jpg", "jpeg", "tif", "tiff", "heif", "avif"]))
    #expect(!Fichiers.estImage("/uploads/devis.pdf"))
    #expect(!Fichiers.estImage("/uploads/dossier.jpg/fichier"))
}

@Test func lesPiecesDUneCarteDuFilSeLisentDansSonMeta() throws {
    let meta = try #require(
        MetaDuFil(json: #"{"photos_urls": ["/u/1.jpg", "/u/2.jpg"], "fichiers_urls": ["/u/ordre.pdf"]}"#))
    #expect(meta.pieces.photos == ["/u/1.jpg", "/u/2.jpg"])
    #expect(meta.pieces.documents == ["/u/ordre.pdf"])
    // Un `meta` sans pièce n'en invente pas.
    #expect(try #require(MetaDuFil(json: #"{"affaire": {"natures": ["activite"]}}"#)).pieces.vide)
}

@Test func uneAffaireServieGardeSesDocuments() throws {
    let detail = try #require(try ServiceSimule.affaires(41, conseil: false))
    #expect(detail.pieces.photos.count == 4)
    #expect(detail.pieces.documents.map(Fichiers.nomSansExtension) == ["Devis plombier", "41-consignes"])
    #expect(detail.suites.contains { !$0.pieces.documents.isEmpty }, "une suite joint le devis")
    #expect(detail.messages.contains { !$0.pieces.photos.isEmpty }, "un message joint une photo")
}

@Test func unePieceOuverteSEcritSousSonNomLisible() async throws {
    let installation = Installation(
        adresse: try #require(URL(string: "https://pieces.exemple.fr")), nom: "Pièces", aUnLogo: false)
    let chemins = [ServiceSimule.devisSimule, "/uploads/tickets/41-1.jpg"]
    let lus = try await PiecesLocales.partagees.fichiers(chemins, dans: installation, service: ServiceSimule())
    #expect(lus.map(\.lastPathComponent) == ["Devis plombier.pdf", "41-1.jpg"], "dans l'ordre demandé")
    #expect(try Data(contentsOf: lus[0]).starts(with: Data("%PDF".utf8)))
    // Deux pièces de même nom, d'adresses différentes, ne s'écrasent pas.
    let autre = try await PiecesLocales.partagees.fichiers(
        ["/uploads/autre/0123456789abcdef0123456789abcdef_Devis%20plombier.pdf"], dans: installation,
        service: ServiceSimule())
    #expect(autre[0] != lus[0] && autre[0].lastPathComponent == lus[0].lastPathComponent)
}
