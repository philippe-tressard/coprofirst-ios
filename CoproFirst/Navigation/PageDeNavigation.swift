// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Une entrée de navigation du site (table générée : PagesParDefaut.swift).
struct PageDeNavigation: Hashable, Sendable, Identifiable {
    let id: String
    let route: String
    var libelle: String
    let titre: String
    let icone: String
}

/// La barre du bas : les pages dans l'ORDRE RÉGLÉ PAR L'ADMINISTRATION
/// (`pages_order` de GET /config), libellées par `page_config_<id>` — jamais un
/// ordre écrit dans l'app. Sans réglage, l'ordre par défaut du site.
enum OrdrePages {
    /// Le tableau de bord du site devient le fil de l'app.
    static let idFil = "tableau-de-bord"
    static let libelleFil = "Fil"

    static func ordonner(
        _ pages: [PageDeNavigation], ordre: [String]?, libelles: [String: String]
    ) -> [PageDeNavigation] {
        var restantes = pages
        var rangees: [PageDeNavigation] = []
        // Comme le site (`ordonnerPages`) : un id répété ou inconnu ne rend rien de plus.
        for id in ordre ?? [] {
            if let i = restantes.firstIndex(where: { $0.id == id }) {
                rangees.append(restantes.remove(at: i))
            }
        }
        return (rangees + restantes).map { page in
            var page = page
            page.libelle = page.id == idFil ? libelleFil : (libelles[page.id] ?? page.libelle)
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

    /// Le libellé de menu d'une surcharge `page_config_<id>` (JSON), s'il y en a un.
    static func libelle(surcharge: String) -> String? {
        guard let donnees = surcharge.data(using: .utf8),
            let objet = try? JSONSerialization.jsonObject(with: donnees) as? [String: Any],
            let libelle = objet["navLabel"] as? String, !libelle.isEmpty
        else { return nil }
        return libelle
    }
}
