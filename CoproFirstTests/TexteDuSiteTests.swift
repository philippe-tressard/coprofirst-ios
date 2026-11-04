// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import SwiftUI
import Testing

@testable import CoproFirst

/// La porte du texte riche du site (#22) : jamais une balise à l'écran.

@Test func lApercuRetireLesBalisesEtDecodeLesEntites() {
    let html = "<p>Le sol est <strong>glissant</strong>&nbsp;: attention.</p><p>L&#39;eau &amp; le gaz</p>"
    #expect(TexteDuSite.apercu(html) == "Le sol est glissant\u{00A0}: attention. L'eau & le gaz")
}

@Test func lApercuMetLesParagraphesEtLesSautsEnEspaces() {
    #expect(TexteDuSite.apercu("<p>Un</p><p>Deux<br>Trois</p><ul><li>Quatre</li></ul>") == "Un Deux Trois • Quatre")
}

@Test func unTexteSimpleSansBaliseResteTelQuel() {
    #expect(TexteDuSite.apercu("Pierre & Marie, 3 < 4") == "Pierre & Marie, 3 < 4")
    #expect(String(TexteDuSite.riche("Ligne un\nLigne deux").characters) == "Ligne un\nLigne deux")
}

@Test func unHTMLVideNeDonneRien() {
    #expect(TexteDuSite.apercu("") == "")
    #expect(TexteDuSite.apercu("<p></p><p> </p>") == "")
    #expect(TexteDuSite.riche("<p><br></p>").characters.isEmpty)
}

/// Une charge hostile : rien ne s'exécute, rien ne se charge, aucun code n'apparaît.
@Test func uneChargeHostileSeReduitASonTexteSur() {
    let html = """
        <p>Bonjour</p><script>alert('x')</script><style>p{color:red}</style>\
        <img src="https://pirate.example/p.png" onerror="alert(1)"><iframe src="https://pirate.example"></iframe>\
        <p onclick="alert(2)">fin</p>
        """
    let apercu = TexteDuSite.apercu(html)
    #expect(apercu == "Bonjour fin")
    for interdit in ["alert", "script", "onerror", "pirate", "<", ">", "color"] {
        #expect(!apercu.contains(interdit), "« \(interdit) » ne doit pas passer")
    }
    let riche = TexteDuSite.riche(html)
    #expect(riche.runs.allSatisfy { $0.link == nil }, "aucun lien ne naît d'une image ou d'un cadre")
}

@Test func unLienJavascriptOuInconnuNEstPasTouchable() {
    for href in [
        "javascript:alert(1)", "JaVaScRiPt:alert(1)", "java\tscript:alert(1)", " javascript:alert(1)",
        "data:text/html,<b>x</b>", "file:///etc/passwd", "vbscript:x", "/relatif", "//hote/x", "tel:0102",
    ] {
        let riche = TexteDuSite.riche("<p><a href=\"\(href)\">clic</a></p>")
        #expect(riche.runs.allSatisfy { $0.link == nil }, "\(href) ne doit pas être touchable")
        #expect(String(riche.characters) == "clic", "le texte du lien reste")
    }
}

@Test func unLienWebOuCourrielEstTouchable() {
    let riche = TexteDuSite.riche(
        "<p>Voir <a href=\"https://exemple.fr/a?b=1&amp;c=2\">ici</a> ou "
            + "<a href=\"mailto:cs@exemple.fr\">écrire</a></p>")
    let liens = riche.runs.compactMap(\.link)
    #expect(liens.map(\.absoluteString) == ["https://exemple.fr/a?b=1&c=2", "mailto:cs@exemple.fr"])
}

@Test func leDetailGardeGrasItaliqueListesEtTitres() {
    let riche = TexteDuSite.riche(
        "<h2>Travaux</h2><p>Le <strong>lundi</strong> et le <em>mardi</em>.</p><ol><li>Un</li><li>Deux</li></ol>")
    #expect(String(riche.characters) == "Travaux\n\nLe lundi et le mardi.\n\n1. Un\n2. Deux")
    let gras = riche.runs.first { String(riche[$0.range].characters) == "lundi" }
    #expect(gras?.inlinePresentationIntent == .stronglyEmphasized)
    let italique = riche.runs.first { String(riche[$0.range].characters) == "mardi" }
    #expect(italique?.inlinePresentationIntent == .emphasized)
}

/// Hors de la liste blanche du site (`BalisesDuSite`, générée) : le texte, sans la forme.
@Test func uneBaliseHorsListeSeReduitASonTexte() {
    #expect(!BalisesDuSite.balises.contains("table"))
    #expect(TexteDuSite.apercu("<table><tr><td>a</td><td>b</td></tr></table>") == "a b")
    #expect(BalisesDuSite.schemasDeLien == ["http", "https", "mailto"])
}

@Test func lesEntitesNumeriquesEtInconnuesSontSures() {
    #expect(Entites.decoder("&#x2019;&#8364;&#0;&#xD800;") == "’€\u{FFFD}\u{FFFD}")
    #expect(Entites.decoder("&inconnue; & &amp") == "&inconnue; & &amp", "jamais avalée")
}

/// Une troncature du serveur (`contenu[:300]`) peut couper une balise en deux.
@Test func uneBaliseCoupeeEnFinDeTexteDisparait() {
    #expect(TexteDuSite.apercu("<p>Le plombier passe <strong>dem") == "Le plombier passe dem")
    #expect(TexteDuSite.apercu("<p>Le plombier passe <a href=\"https://exe") == "Le plombier passe")
}

@Test func unTresLongTexteSeConvertitEnEntier() {
    let paragraphe = "<p>Un paragraphe <strong>riche</strong> de la résidence.</p>"
    let html = String(repeating: paragraphe, count: 2_000)
    let apercu = TexteDuSite.apercu(html)
    #expect(!apercu.contains("<"))
    #expect(apercu.components(separatedBy: "riche").count == 2_001)
}

/// Le rendu en très grand texte : le texte riche suit Dynamic Type, sans rien perdre.
@MainActor
@Test func leDetailSeRendEnTresGrandTexte() throws {
    let texte = Text(TexteDuSite.riche("<p>Le <strong>lundi</strong>, <a href=\"https://exemple.fr\">voir</a>.</p>"))
        .frame(width: 320)
        .environment(\.dynamicTypeSize, .accessibility5)
    let normal = Text(TexteDuSite.riche("<p>Le <strong>lundi</strong>, <a href=\"https://exemple.fr\">voir</a>.</p>"))
        .frame(width: 320)
    let grand = try #require(ImageRenderer(content: texte).uiImage)
    let petit = try #require(ImageRenderer(content: normal).uiImage)
    #expect(grand.size.height > petit.size.height * 1.5, "le texte grandit avec Dynamic Type")
}

// MARK: - Les listes de l'éditeur du site (#25)

/// La forme exacte de l'éditeur du site (Tiptap) : chaque élément est `<li><p>…</p></li>`.
@Test func leMarqueurEtLeTexteRestentSurLaMemeLigne() {
    let html = """
        <p>Constat :</p><ol><li><p>le portillon ne s'ouvre pas ;</p></li>\
        <li><p>le badge clignote rouge.</p></li></ol>
        """
    let blocs = TexteDuSite.blocs(html)
    #expect(blocs.map(\.marqueur) == [nil, "1.", "2."])
    #expect(
        blocs.map { String($0.texte.characters) } == [
            "Constat :", "le portillon ne s'ouvre pas ;", "le badge clignote rouge.",
        ])
    #expect(blocs.map(\.ecart) == [false, true, false])
    #expect(
        String(TexteDuSite.riche(html).characters)
            == "Constat :\n\n1. le portillon ne s'ouvre pas ;\n2. le badge clignote rouge.")
    #expect(TexteDuSite.apercu(html) == "Constat : 1. le portillon ne s'ouvre pas ; 2. le badge clignote rouge.")
}

/// Deux `<p>` dans un même élément : le second passe à la ligne, sans marqueur, au même niveau.
@Test func unSecondParagrapheDansUnElementSAligneSurLeTexte() {
    let blocs = TexteDuSite.blocs("<ul><li><p>Premier</p><p>suite du premier</p></li><li><p>Second</p></li></ul>")
    #expect(blocs.map(\.marqueur) == ["•", nil, "•"])
    #expect(blocs.map(\.niveau) == [1, 1, 1])
    #expect(blocs.map(\.ecart) == [false, false, false])
}

/// Une sous-liste vit dans le `<li>`, après son `<p>` : un niveau de plus.
@Test func uneSousListeEstUnNiveauPlusLoin() {
    let blocs = TexteDuSite.blocs(
        "<ol><li><p>Bâtiment A</p><ul><li><p>hall</p></li><li><p>cave</p></li></ul></li><li><p>Bâtiment B</p></li></ol>"
    )
    #expect(blocs.map(\.marqueur) == ["1.", "•", "•", "2."])
    #expect(blocs.map(\.niveau) == [1, 2, 2, 1])
}

/// Un `<li>` sans `<p>` (HTML écrit à la main, ancien contenu) se lit pareil.
@Test func unElementSansParagrapheGardeSonMarqueur() {
    #expect(TexteDuSite.blocs("<ul><li>un</li><li><strong>deux</strong></li></ul>").map(\.marqueur) == ["•", "•"])
    #expect(String(TexteDuSite.riche("<ul><li>un</li><li>deux</li></ul>").characters) == "• un\n• deux")
}

/// Le retrait suspendu : en très grand texte, l'élément long passe sur plusieurs lignes
/// sans que son marqueur reste seul en tête.
@MainActor
@Test func unElementLongSeRendSousSonMarqueur() throws {
    let html = "<ol><li><p>" + String(repeating: "le portillon ne s'ouvre pas ; ", count: 6) + "</p></li></ol>"
    let vue = TexteRiche(html: html).frame(width: 320).environment(\.dynamicTypeSize, .accessibility3)
    let image = try #require(ImageRenderer(content: vue).uiImage)
    #expect(image.size.height > 100, "plusieurs lignes, rendues ensemble")
    #expect(TexteRiche(html: html).blocs.count == 1, "un seul bloc : le marqueur et tout le texte")
}
