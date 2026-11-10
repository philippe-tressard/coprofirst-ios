// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import SwiftUI

/// LA PORTE du texte riche du site (#22) : descriptions d'affaires, textes du fil,
/// suites, sondages arrivent en HTML (l'éditeur du site). Aucun écran ne les montre
/// tels quels — `Text(html)` afficherait les balises —, et aucun ne les convertit
/// ailleurs qu'ici.
///
/// - `apercu` : le texte simple d'une carte (balises retirées, entités décodées,
///   paragraphes en espaces) ; la vue tronque ensuite.
/// - `blocs` : le texte riche d'un détail, bloc par bloc — un paragraphe, ou un
///   élément de liste avec son marqueur (« • », « 2. ») et son niveau ; `TexteRiche`
///   les met en page, retrait suspendu compris (#25). Limité à la liste blanche du
///   site (`BalisesDuSite`, générée) ; le reste se réduit à son texte.
/// - `riche` : les mêmes blocs en un seul `AttributedString` (marqueurs en tête de
///   ligne), pour un texte qui ne peut être qu'un `Text`.
///
/// Rien ne se charge : une image devient son texte de remplacement. Un lien n'est
/// touchable que s'il est absolu et de schéma `BalisesDuSite.schemasDeLien`.
enum TexteDuSite {
    static func apercu(_ html: String) -> String {
        let texte = String(assembler(RenduHTML(html, riche: false).blocs).characters)
        return texte.split(whereSeparator: { $0 == "\n" || $0 == " " }).joined(separator: " ")
    }

    static func blocs(_ html: String) -> [BlocDuSite] {
        RenduHTML(html, riche: true).blocs
    }

    static func riche(_ html: String) -> AttributedString {
        assembler(blocs(html))
    }

    /// Les blocs bout à bout : un saut de ligne entre deux, deux avant un paragraphe.
    static func assembler(_ blocs: [BlocDuSite]) -> AttributedString {
        var sortie = AttributedString()
        for (rang, bloc) in blocs.enumerated() {
            if rang > 0 { sortie += AttributedString(bloc.ecart ? "\n\n" : "\n") }
            let retrait = String(repeating: "    ", count: max(bloc.niveau - 1, 0))
            if let marqueur = bloc.marqueur { sortie += AttributedString(retrait + marqueur + " ") }
            sortie += bloc.texte
        }
        return sortie
    }

    /// Le sens inverse : un texte SAISI dans l'app, écrit comme l'éditeur du site l'écrit
    /// — des paragraphes, des retours à la ligne, aucun caractère lu comme une balise.
    /// Une description, une réponse, une suite : la même écriture partout.
    static func html(saisi texte: String) -> String {
        texte
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { "<p>\($0.replacingOccurrences(of: "\n", with: "<br>"))</p>" }
            .joined()
    }

    /// Le texte à RÉÉCRIRE d'un HTML du site — seulement si le réenregistrer ne perd
    /// rien : `html(saisi:)` doit en refaire exactement le même HTML. Une mise en forme
    /// que l'app ne sait pas écrire (gras, liste, lien, espace insécable) rend `nil` :
    /// l'écran la montre sans la toucher, plutôt que de l'effacer en silence.
    /// Un texte sans balise (saisi avant l'éditeur) se réécrit tel quel.
    static func saisi(html: String) -> String? {
        let texte = String(assembler(RenduHTML(html, riche: false).blocs).characters)
        if self.html(saisi: texte) == html.replacingOccurrences(of: "<br/>", with: "<br>") { return texte }
        let brut = !html.contains("<") && !html.contains("&")
        return brut && texte == html.trimmingCharacters(in: .whitespacesAndNewlines) ? texte : nil
    }

    /// Un lien sûr : absolu, d'un schéma de la liste blanche, sans caractère de
    /// contrôle (`java\tscript:` ne passe pas) — sinon `nil`, et le texte reste inerte.
    static func lienSur(_ href: String) -> URL? {
        let propre = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !propre.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }),
            let url = URL(string: propre), let schema = url.scheme?.lowercased(),
            BalisesDuSite.schemasDeLien.contains(schema)
        else { return nil }
        if schema != "mailto", url.host()?.isEmpty ?? true { return nil }
        return url
    }
}

/// Un bloc du texte riche : un paragraphe (`niveau` 0), ou une ligne d'un élément de
/// liste — sa première porte le `marqueur`, les suivantes (un second `<p>` dans le
/// même `<li>`) n'en ont pas et s'alignent sur le texte.
struct BlocDuSite: Hashable, Sendable {
    /// La profondeur de liste : 0 hors liste, 1 pour une liste, 2 pour une sous-liste…
    var niveau: Int
    /// « • » ou « 2. » ; `nil` pour un paragraphe ou la suite d'un élément.
    var marqueur: String?
    var texte: AttributedString
    /// Un écart de paragraphe le précède (sinon un simple saut de ligne).
    var ecart: Bool
}
