// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Un morceau du HTML riche du site, tel que `LectureHTML` le découpe.
enum JetonHTML: Equatable {
    case texte(String)
    case ouvrante(nom: String, attributs: [String: String])
    case fermante(nom: String)
}

/// Le découpage du HTML riche du site, SANS WebKit (#22).
///
/// Ni `WKWebView`, ni `NSAttributedString(data:options:[.documentType: .html])` : ce
/// dernier passe par WebKit et peut charger des ressources distantes. Ce lecteur ne
/// charge rien, n'exécute rien : il découpe en texte et en balises, et c'est tout.
/// Il tolère le HTML abîmé — une balise coupée par une troncature du serveur
/// (`contenu[:300]`) est abandonnée, un `<` isolé (« a < b ») reste du texte.
enum LectureHTML {
    static func jetons(_ html: String) -> [JetonHTML] {
        var sortie: [JetonHTML] = []
        var texte = ""
        var i = html.startIndex
        func publierTexte() {
            if !texte.isEmpty { sortie.append(.texte(Entites.decoder(texte))) }
            texte = ""
        }
        while i < html.endIndex {
            guard html[i] == "<" else {
                texte.append(html[i])
                i = html.index(after: i)
                continue
            }
            let reste = html[html.index(after: i)...]
            if reste.hasPrefix("!--") {  // commentaire : sauté jusqu'à sa fin
                publierTexte()
                i = html.range(of: "-->", range: i..<html.endIndex)?.upperBound ?? html.endIndex
                continue
            }
            guard let premier = reste.first, premier.isLetter || premier == "/" || premier == "!" || premier == "?"
            else {
                texte.append("<")  // « a < b » : un chevron isolé est du texte
                i = html.index(after: i)
                continue
            }
            // Une balise coupée en fin de texte (troncature) : abandonnée.
            guard let fin = finDeBalise(html, depuis: reste.startIndex) else {
                publierTexte()
                return sortie
            }
            publierTexte()
            if let jeton = balise(String(html[reste.startIndex..<fin])) { sortie.append(jeton) }
            i = html.index(after: fin)
        }
        publierTexte()
        return sortie
    }

    /// Le `>` qui ferme la balise, hors des valeurs d'attribut entre guillemets.
    private static func finDeBalise(_ html: String, depuis debut: String.Index) -> String.Index? {
        var guillemet: Character?
        var i = debut
        while i < html.endIndex {
            let c = html[i]
            if let g = guillemet {
                if c == g { guillemet = nil }
            } else if c == "\"" || c == "'" {
                guillemet = c
            } else if c == ">" {
                return i
            }
            i = html.index(after: i)
        }
        return nil
    }

    /// `p class="x"`, `/p`, `br/` → un jeton ; `!DOCTYPE`, `?xml` → rien.
    private static func balise(_ interieur: String) -> JetonHTML? {
        if interieur.hasPrefix("!") || interieur.hasPrefix("?") { return nil }
        if interieur.hasPrefix("/") {
            let nom = interieur.dropFirst().prefix { $0.isLetter || $0.isNumber }.lowercased()
            return nom.isEmpty ? nil : .fermante(nom: nom)
        }
        let nom = interieur.prefix { $0.isLetter || $0.isNumber }.lowercased()
        guard !nom.isEmpty else { return nil }
        return .ouvrante(nom: nom, attributs: attributs(interieur.dropFirst(nom.count)))
    }

    /// `href="…" title='…' disabled` → leurs valeurs, entités décodées ; noms en minuscules.
    private static func attributs(_ texte: Substring) -> [String: String] {
        var sortie: [String: String] = [:]
        var i = texte.startIndex
        func sauterBlancs() {
            while i < texte.endIndex, texte[i].isWhitespace || texte[i] == "/" { i = texte.index(after: i) }
        }
        while true {
            sauterBlancs()
            guard i < texte.endIndex else { return sortie }
            let debutNom = i
            while i < texte.endIndex, !texte[i].isWhitespace, texte[i] != "=", texte[i] != "/" {
                i = texte.index(after: i)
            }
            let nom = texte[debutNom..<i].lowercased()
            while i < texte.endIndex, texte[i].isWhitespace { i = texte.index(after: i) }
            var valeur = ""
            if i < texte.endIndex, texte[i] == "=" {
                i = texte.index(after: i)
                valeur = valeurDAttribut(texte, &i)
            }
            if !nom.isEmpty, sortie[nom] == nil { sortie[nom] = Entites.decoder(valeur) }
        }
    }

    /// La valeur qui suit `=` : entre guillemets doubles ou simples, ou jusqu'au blanc.
    private static func valeurDAttribut(_ texte: Substring, _ i: inout Substring.Index) -> String {
        while i < texte.endIndex, texte[i].isWhitespace { i = texte.index(after: i) }
        guard i < texte.endIndex else { return "" }
        let guillemet: Character? = texte[i] == "\"" || texte[i] == "'" ? texte[i] : nil
        if guillemet != nil { i = texte.index(after: i) }
        let debut = i
        while i < texte.endIndex, guillemet.map({ texte[i] != $0 }) ?? !texte[i].isWhitespace {
            i = texte.index(after: i)
        }
        let valeur = String(texte[debut..<i])
        if guillemet != nil, i < texte.endIndex { i = texte.index(after: i) }
        return valeur
    }
}

/// Les entités HTML : numériques (`&#39;`, `&#x2019;`) et les nommées qu'un éditeur
/// écrit. Une entité inconnue ou mal formée reste telle quelle — jamais avalée.
enum Entites {
    static let nommees: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}",
        "laquo": "«", "raquo": "»", "hellip": "…", "rsquo": "’", "lsquo": "‘", "ldquo": "“",
        "rdquo": "”", "ndash": "–", "mdash": "—", "euro": "€", "deg": "°", "middot": "·",
        "times": "×", "copy": "©", "reg": "®", "trade": "™", "sup2": "²", "sup3": "³",
        "eacute": "é", "egrave": "è", "ecirc": "ê", "euml": "ë", "agrave": "à", "acirc": "â",
        "ccedil": "ç", "icirc": "î", "iuml": "ï", "ocirc": "ô", "ugrave": "ù", "ucirc": "û",
        "uuml": "ü", "oelig": "œ", "aelig": "æ", "Eacute": "É", "Egrave": "È", "Ecirc": "Ê",
        "Agrave": "À", "Ccedil": "Ç", "OElig": "Œ", "shy": "",
    ]

    static func decoder(_ texte: String) -> String {
        guard texte.contains("&") else { return texte }
        var sortie = ""
        var i = texte.startIndex
        while i < texte.endIndex {
            guard texte[i] == "&",
                let pointVirgule = texte[i...].prefix(12).firstIndex(of: ";"),
                let valeur = valeur(String(texte[texte.index(after: i)..<pointVirgule]))
            else {
                sortie.append(texte[i])
                i = texte.index(after: i)
                continue
            }
            sortie += valeur
            i = texte.index(after: pointVirgule)
        }
        return sortie
    }

    private static func valeur(_ nom: String) -> String? {
        guard nom.hasPrefix("#") else { return nommees[nom] }
        let chiffres = nom.dropFirst()
        let code: UInt32?
        if chiffres.first == "x" || chiffres.first == "X" {
            code = UInt32(chiffres.dropFirst(), radix: 16)
        } else {
            code = UInt32(chiffres, radix: 10)
        }
        guard let code else { return nil }
        // Le nul, les substituts et les codes hors Unicode deviennent U+FFFD, comme un navigateur.
        guard code != 0, let scalaire = Unicode.Scalar(code) else { return "\u{FFFD}" }
        return String(Character(scalaire))
    }
}
