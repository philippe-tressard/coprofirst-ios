// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import SwiftUI

/// Le parcours des jetons de `LectureHTML` : un état de mise en forme, des blocs qui
/// s'ajoutent. Appelé par `TexteDuSite` seul.
///
/// Les listes suivent la forme de l'éditeur du site (Tiptap) : chaque élément est
/// `<li><p>texte</p></li>`, une sous-liste vit dans le `<li>` après son `<p>`. Le
/// premier `<p>` d'un `<li>` ne coupe rien : le marqueur et le texte restent sur la
/// même ligne (#25). Un second `<p>` du même `<li>` ouvre une ligne sans marqueur.
struct RenduHTML {
    /// Leur CONTENU n'est pas du texte : il disparaît avec la balise.
    static let contenusIgnores: Set<String> = [
        "script", "style", "template", "noscript", "iframe", "object", "embed", "svg", "math",
        "head", "title", "textarea", "select",
    ]
    /// Les blocs : un écart de paragraphe avant et après (une ligne dans une liste).
    static let paragraphes: Set<String> = [
        "p", "blockquote", "pre", "h1", "h2", "h3", "h4", "h5", "h6", "hr", "details",
    ]
    /// Un simple retour à la ligne.
    static let lignes: Set<String> = ["div", "summary"]

    private(set) var blocs: [BlocDuSite] = []
    private let riche: Bool
    private var courant: BlocDuSite?
    private var ouvertes: [(nom: String, lien: URL?)] = []
    private var listes: [(ordonnee: Bool, rang: Int)] = []
    private var coupure = 0  // 1 : ligne, 2 : paragraphe, dû avant le prochain texte
    private var marqueur: String?  // le marqueur d'un `<li>` qui n'a pas encore de texte
    private var espace = false  // un blanc dû avant le prochain texte
    private var ignore: String?  // la balise dont on saute le contenu

    init(_ html: String, riche: Bool) {
        self.riche = riche
        // Un texte sans balise est du texte simple : ses retours à la ligne comptent.
        guard html.contains("<") else {
            let texte = Entites.decoder(html).trimmingCharacters(in: .whitespacesAndNewlines)
            if !texte.isEmpty { blocs = [BlocDuSite(niveau: 0, texte: AttributedString(texte), ecart: false)] }
            return
        }
        for jeton in LectureHTML.jetons(html) { lire(jeton) }
        fermerBloc()
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
        case "br": retourALaLigne()
        case "img": if let alt = attributs["alt"], !alt.isEmpty { ecrire(alt) }
        case "hr": couper(2)
        case "ul", "ol":
            couper(listes.isEmpty ? 2 : 1)
            listes.append((nom == "ol", 0))
        case "li": ouvrirElementDeListe()
        default:
            // Le premier `<p>` d'un `<li>` : le marqueur attend son texte, rien ne coupe.
            if marqueur == nil { couperAutourDe(nom) }
            ouvertes.append((nom, nom == "a" ? attributs["href"].flatMap(TexteDuSite.lienSur) : nil))
        }
    }

    /// Un bloc coupe avant et après lui : un paragraphe (une ligne dans une liste), ou une ligne.
    private mutating func couperAutourDe(_ nom: String) {
        if Self.paragraphes.contains(nom) { couper(listes.isEmpty ? 2 : 1) }
        if Self.lignes.contains(nom) { couper(1) }
    }

    private mutating func fermer(_ nom: String) {
        guard BalisesDuSite.balises.contains(nom) else {
            espace = true
            return
        }
        switch nom {
        case "ul", "ol":
            if !listes.isEmpty { listes.removeLast() }
            couper(listes.isEmpty ? 2 : 1)
        case "li":
            marqueur = nil
            couper(1)
        default:
            if let rang = ouvertes.lastIndex(where: { $0.nom == nom }) { ouvertes.removeSubrange(rang...) }
            couperAutourDe(nom)
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

    /// « • » ou « 2. » : il attend le premier texte de l'élément, sur la même ligne.
    private mutating func ouvrirElementDeListe() {
        couper(1)
        if !listes.isEmpty { listes[listes.count - 1].rang += 1 }
        marqueur = listes.last.map { $0.ordonnee ? "\($0.rang)." : "•" } ?? "•"
    }

    private mutating func couper(_ n: Int) {
        fermerBloc()
        coupure = max(coupure, n)
        espace = false
    }

    private mutating func fermerBloc() {
        if let bloc = courant, !bloc.texte.characters.isEmpty { blocs.append(bloc) }
        courant = nil
    }

    /// `<br>` : un retour dans le bloc, jamais en tête.
    private mutating func retourALaLigne() {
        guard courant != nil else { return }
        courant?.texte += AttributedString("\n")
        espace = false
    }

    /// Le texte, blancs réduits (sauf dans `pre`), dans le bloc courant ou un neuf.
    private mutating func ecrire(_ brut: String) {
        let blanc: (Character) -> Bool = { $0 == " " || $0.isNewline || $0 == "\t" }
        var texte = brut
        var finBlanc = false
        if !ouvertes.contains(where: { $0.nom == "pre" }) {
            if texte.first.map(blanc) ?? false { espace = true }
            finBlanc = texte.last.map(blanc) ?? false
            texte = texte.split(whereSeparator: blanc).joined(separator: " ")
            if texte.isEmpty { return }
        }
        if courant == nil {
            courant = BlocDuSite(
                niveau: listes.count, marqueur: listes.isEmpty ? nil : marqueur, texte: AttributedString(),
                ecart: coupure >= 2 && !blocs.isEmpty)
            marqueur = nil
            coupure = 0
            espace = false
        } else if espace, let dernier = courant?.texte.characters.last, !dernier.isWhitespace {
            courant?.texte += AttributedString(" ")
        }
        let morceau = AttributedString(texte, attributes: riche ? mise() : AttributeContainer())
        courant?.texte += morceau
        espace = finBlanc
    }

    static let intentions: [String: InlinePresentationIntent] = [
        "strong": .stronglyEmphasized, "b": .stronglyEmphasized, "summary": .stronglyEmphasized,
        "em": .emphasized, "i": .emphasized, "blockquote": .emphasized,
        "s": .strikethrough, "code": .code, "pre": .code,
    ]
    static let titres: [String: Font] = [
        "h1": .title3.weight(.semibold), "h2": .title3.weight(.semibold),
        "h3": .headline, "h4": .headline, "h5": .headline, "h6": .headline,
    ]

    /// La mise en forme des balises ouvertes : gras, italique, code, liens, titres.
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
