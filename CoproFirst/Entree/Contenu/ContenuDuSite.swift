// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Le contenu de l'accueil de coprofirst.fr, tel que le site le publie (`contenu.json`,
/// coprofirst-site#42 ; règles : docstring de `scripts/contenu-accueil.py` du site).
/// Un champ inconnu s'ignore ; un `format` plus récent que `formatConnu` se refuse.
struct ContenuDuSite: Decodable, Equatable, Sendable {
    static let formatConnu = 1

    let format: Int
    let sections: [BlocDeContenu]

    enum Refus: Error, Equatable {
        case formatInconnu(Int)
    }

    static func lire(_ donnees: Data) throws -> ContenuDuSite {
        let contenu = try JSONDecoder().decode(ContenuDuSite.self, from: donnees)
        guard contenu.format <= formatConnu else { throw Refus.formatInconnu(contenu.format) }
        return contenu
    }

    func section(_ id: String) -> BlocDeContenu? { sections.first { $0.id == id } }
}

/// Une section ou l'un de ses éléments : les deux ont la même forme. L'app n'en lit
/// que le texte — ni `liens`, ni `images`, ni `adresse` (aucune adresse venue du
/// réseau n'est ouverte ni contactée par l'app).
struct BlocDeContenu: Decodable, Equatable, Sendable {
    let id: String
    let titre: String?
    let textes: [String]
    let elements: [BlocDeContenu]

    private enum CodingKeys: String, CodingKey { case id, titre, textes, elements }

    init(from decoder: any Decoder) throws {
        let valeurs = try decoder.container(keyedBy: CodingKeys.self)
        id = try valeurs.decode(String.self, forKey: .id)
        titre = try valeurs.decodeIfPresent(String.self, forKey: .titre)
        // Un champ vide est omis par le site.
        textes = try valeurs.decodeIfPresent([String].self, forKey: .textes) ?? []
        elements = try valeurs.decodeIfPresent([BlocDeContenu].self, forKey: .elements) ?? []
    }

    func element(_ id: String) -> BlocDeContenu? { elements.first { $0.id == id } }
}

/// La première phrase d'un paragraphe : le site écrit un chapeau de plusieurs phrases,
/// la vitrine de l'app n'en montre que la première (la « version A », raccourcie).
/// Une phrase finit sur `.`, `!`, `?` ou `…` suivis d'une espace et d'une majuscule —
/// « Où en est ma demande ? » n'est donc pas coupé.
func premierePhrase(_ texte: String) -> String {
    guard let fin = texte.firstMatch(of: /[.!?…](?=\s+\p{Lu})/) else { return texte }
    return String(texte[..<fin.range.upperBound])
}
