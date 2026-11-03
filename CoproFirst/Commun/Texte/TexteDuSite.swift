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
/// - `riche` : le texte riche natif d'un détail (`AttributedString`), limité à la
///   liste blanche du site (`BalisesDuSite`, générée) ; le reste se réduit à son texte.
///
/// Rien ne se charge : une image devient son texte de remplacement. Un lien n'est
/// touchable que s'il est absolu et de schéma `BalisesDuSite.schemasDeLien`.
enum TexteDuSite {
    static func apercu(_ html: String) -> String {
        let texte = String(Rendu(html, riche: false).resultat.characters)
        return texte.split(whereSeparator: { $0 == "\n" || $0 == " " }).joined(separator: " ")
    }

    static func riche(_ html: String) -> AttributedString {
        Rendu(html, riche: true).resultat
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

/// Le parcours des jetons : un état de mise en forme, une sortie qui s'allonge.
private struct Rendu {
    /// Leur CONTENU n'est pas du texte : il disparaît avec la balise.
    static let contenusIgnores: Set<String> = [
        "script", "style", "template", "noscript", "iframe", "object", "embed", "svg", "math",
        "head", "title", "textarea", "select",
    ]
    /// Les blocs : un saut de paragraphe avant et après.
    static let paragraphes: Set<String> = [
        "p", "blockquote", "pre", "ul", "ol", "h1", "h2", "h3", "h4", "h5", "h6", "hr", "details",
    ]
    /// Un simple retour à la ligne.
    static let lignes: Set<String> = ["li", "div", "summary"]

    private(set) var resultat = AttributedString()
    private let riche: Bool
    private var ouvertes: [(nom: String, lien: URL?)] = []
    private var listes: [(ordonnee: Bool, rang: Int)] = []
    private var sauts = 0  // retours à la ligne dus avant le prochain texte
    private var espace = false  // un blanc dû avant le prochain texte
    private var ignore: String?  // la balise dont on saute le contenu

    init(_ html: String, riche: Bool) {
        self.riche = riche
        // Un texte sans balise est du texte simple : ses retours à la ligne comptent.
        guard html.contains("<") else {
            resultat = AttributedString(Entites.decoder(html).trimmingCharacters(in: .whitespacesAndNewlines))
            return
        }
        for jeton in LectureHTML.jetons(html) { lire(jeton) }
    }

    private mutating func lire(_ jeton: JetonHTML) {
        if let ignore {
            if case .fermante(let nom) = jeton, nom == ignore { self.ignore = nil }
            return
        }
        switch jeton {
        case .texte(let texte): ecrire(texte)
        case .ouvrante(let nom, let attributs): ouvrir(nom, attributs)
        case .fermante(let nom): fermer(nom)
        }
    }

    private mutating func ouvrir(_ nom: String, _ attributs: [String: String]) {
        guard admise(nom) else { return }
        switch nom {
        case "br": sauterLigne(1, force: true)
        case "img": if let alt = attributs["alt"], !alt.isEmpty { ecrire(alt) }
        case "hr": sauterLigne(2)
        case "ul", "ol":
            sauterLigne(listes.isEmpty ? 2 : 1)
            listes.append((nom == "ol", 0))
        case "li": ouvrirElementDeListe()
        default:
            if Self.paragraphes.contains(nom) { sauterLigne(2) }
            if Self.lignes.contains(nom) { sauterLigne(1) }
            ouvertes.append((nom, nom == "a" ? attributs["href"].flatMap(TexteDuSite.lienSur) : nil))
        }
    }

    /// Une balise de la liste blanche ; sinon, son contenu sauté (`script`…) ou réduit
    /// à son texte, sans coller les mots.
    private mutating func admise(_ nom: String) -> Bool {
        if Self.contenusIgnores.contains(nom) {
            ignore = nom
            return false
        }
        if !BalisesDuSite.balises.contains(nom) {
            espace = true
            return false
        }
        return true
    }

    /// « • » ou « 2. », décalé selon la profondeur de la liste.
    private mutating func ouvrirElementDeListe() {
        sauterLigne(1)
        if !listes.isEmpty { listes[listes.count - 1].rang += 1 }
        let puce = listes.last.map { $0.ordonnee ? "\($0.rang). " : "• " } ?? "• "
        ecrire(String(repeating: "    ", count: max(listes.count - 1, 0)) + puce, brut: true)
    }

    private mutating func fermer(_ nom: String) {
        guard BalisesDuSite.balises.contains(nom) else {
            espace = true
            return
        }
        if nom == "ul" || nom == "ol" {
            if !listes.isEmpty { listes.removeLast() }
            sauterLigne(listes.isEmpty ? 2 : 1)
            return
        }
        if let rang = ouvertes.lastIndex(where: { $0.nom == nom }) { ouvertes.removeSubrange(rang...) }
        if Self.paragraphes.contains(nom) { sauterLigne(2) }
        if Self.lignes.contains(nom) { sauterLigne(1) }
    }

    private mutating func sauterLigne(_ n: Int, force: Bool = false) {
        guard !resultat.characters.isEmpty else { return }
        sauts = force ? sauts + n : max(sauts, n)
        espace = false
    }

    /// Le texte, blancs réduits (sauf dans `pre`), précédé de ce qui est dû.
    private mutating func ecrire(_ brut: String, brut estBrut: Bool = false) {
        let dansPre = ouvertes.contains { $0.nom == "pre" }
        let blanc: (Character) -> Bool = { $0 == " " || $0.isNewline || $0 == "\t" }
        var texte = brut
        var finBlanc = false
        if !estBrut && !dansPre {
            if texte.first.map(blanc) ?? false { espace = true }
            finBlanc = texte.last.map(blanc) ?? false
            texte = texte.split(whereSeparator: blanc).joined(separator: " ")
            if texte.isEmpty { return }
        }
        var prefixe = ""
        if !resultat.characters.isEmpty {
            if sauts > 0 {
                prefixe = String(repeating: "\n", count: min(sauts, 2))
            } else if espace, let dernier = resultat.characters.last, !dernier.isWhitespace {
                prefixe = " "
            }
        }
        sauts = 0
        espace = false
        resultat += AttributedString(prefixe)
        resultat += AttributedString(texte, attributes: riche ? mise() : AttributeContainer())
        espace = finBlanc
    }

    /// La mise en forme des balises ouvertes : gras, italique, code, liens, titres.
    static let intentions: [String: InlinePresentationIntent] = [
        "strong": .stronglyEmphasized, "b": .stronglyEmphasized, "summary": .stronglyEmphasized,
        "em": .emphasized, "i": .emphasized, "blockquote": .emphasized,
        "s": .strikethrough, "code": .code, "pre": .code,
    ]
    static let titres: [String: Font] = [
        "h1": .title3.weight(.semibold), "h2": .title3.weight(.semibold),
        "h3": .headline, "h4": .headline, "h5": .headline, "h6": .headline,
    ]

    private func mise() -> AttributeContainer {
        var mise = AttributeContainer()
        var intention: InlinePresentationIntent = []
        for (nom, lien) in ouvertes {
            if let ajout = Self.intentions[nom] { intention.insert(ajout) }
            if let titre = Self.titres[nom] { mise.font = titre }
            if nom == "u" { mise.underlineStyle = .single }
            if let lien {
                mise.link = lien
                mise.underlineStyle = .single
            }
        }
        if !intention.isEmpty { mise.inlinePresentationIntent = intention }
        return mise
    }
}
