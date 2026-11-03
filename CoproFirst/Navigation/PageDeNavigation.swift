// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Une entrée de navigation du site (table générée : PagesParDefaut.swift).
struct PageDeNavigation: Hashable, Sendable, Identifiable {
    let id: String
    let route: String
    var libelle: String
    var titre: String
    let icone: String
}

/// Ce que l'administration a écrit pour une page (`page_config_<id>`, du JSON) :
/// son libellé de menu et son titre, s'ils diffèrent du site par défaut.
struct SurchargePage: Codable, Hashable, Sendable {
    var navLabel: String?
    var titre: String?

    init(navLabel: String? = nil, titre: String? = nil) {
        self.navLabel = navLabel
        self.titre = titre
    }

    init?(json: String) {
        guard let donnees = json.data(using: .utf8),
            let objet = try? JSONSerialization.jsonObject(with: donnees) as? [String: Any]
        else { return nil }
        let texte = { (cle: String) in (objet[cle] as? String).flatMap { $0.isEmpty ? nil : $0 } }
        self.init(navLabel: texte("navLabel"), titre: texte("titre"))
    }
}

/// Le libellé d'une page dans la barre du bas — écrit ICI, et nulle part ailleurs.
///
/// La barre n'a la place que d'un mot : chaque page y a un libellé COURT. Mais si
/// l'administration a renommé la page (`page_config_<id>` qui diffère de `pages.ts`),
/// c'est son nom qui s'affiche — jamais un raccourci qui le contredirait. Le titre
/// de l'écran, lui, reste le titre de la page (« Mes lots & accès »).
enum LibellesBarre {
    static let courts: [String: String] = [
        OrdrePages.idFil: OrdrePages.libelleFil,
        "residence": "Résidence",
        "mes-demandes": "Affaires",
        "mon-lot": "Accès",
    ]

    /// `defaut` : la page telle que `pages.ts` la décrit, avant toute surcharge.
    static func libelle(_ defaut: PageDeNavigation, surcharge: SurchargePage?) -> String {
        if let menu = surcharge?.navLabel, menu != defaut.libelle { return menu }
        if let titre = surcharge?.titre, titre != defaut.titre { return titre }
        return courts[defaut.id] ?? defaut.libelle
    }
}

/// La barre du bas : les pages dans l'ORDRE RÉGLÉ PAR L'ADMINISTRATION
/// (`pages_order` de GET /config), libellées par `page_config_<id>` — jamais un
/// ordre écrit dans l'app. Sans réglage, l'ordre par défaut du site.
enum OrdrePages {
    /// Le tableau de bord du site devient le fil de l'app.
    static let idFil = "tableau-de-bord"
    static let libelleFil = "Fil"

    static func ordonner(
        _ pages: [PageDeNavigation], ordre: [String]?, surcharges: [String: SurchargePage]
    ) -> [PageDeNavigation] {
        var restantes = pages
        var rangees: [PageDeNavigation] = []
        // Comme le site (`ordonnerPages`) : un id répété ou inconnu ne rend rien de plus.
        for id in ordre ?? [] {
            if let i = restantes.firstIndex(where: { $0.id == id }) {
                rangees.append(restantes.remove(at: i))
            }
        }
        return (rangees + restantes).map { defaut in
            var page = defaut
            let surcharge = surcharges[defaut.id]
            page.libelle = LibellesBarre.libelle(defaut, surcharge: surcharge)
            page.titre = surcharge?.titre ?? defaut.titre
            return page
        }
    }

    /// `pages_order` : un tableau JSON d'identifiants (ou, à défaut, une liste à virgules).
    static func lire(_ valeur: String?) -> [String]? {
        guard let valeur, !valeur.isEmpty else { return nil }
        if let donnees = valeur.data(using: .utf8),
            let ids = try? JSONDecoder().decode([String].self, from: donnees)
        {
            return ids
        }
        return valeur.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
