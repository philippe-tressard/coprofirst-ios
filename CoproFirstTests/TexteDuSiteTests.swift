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
