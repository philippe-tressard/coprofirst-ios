// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Une installation de CoproFirst : une résidence, à son adresse. Aucun annuaire ne
/// les liste — l'app ne connaît que celles que l'utilisateur a saisies ou scannées.
struct Installation: Codable, Hashable, Sendable, Identifiable {
    /// L'adresse du site, réduite à `https://<hôte>`.
    var adresse: URL
    /// Le nom de la résidence (`site_nom` de GET /config).
    var nom: String
    /// Un logo téléversé par la résidence (`site_logo` non vide).
    var aUnLogo: Bool
    /// Le code de sa palette (`site_palette`), absent avant les versions qui le servent.
    var codePalette: String?
    /// L'ordre de navigation réglé par l'administration (`pages_order`).
    var ordrePages: [String]?
    /// Ce que l'administration a écrit pour chaque page (`page_config_<id>`).
    /// Facultatif : une résidence retenue par une version antérieure se relit encore.
    var surchargesPages: [String: SurchargePage]?

    init(
        adresse: URL, nom: String, aUnLogo: Bool, codePalette: String? = nil,
        ordrePages: [String]? = nil, surchargesPages: [String: SurchargePage]? = nil
    ) {
        self.adresse = adresse
        self.nom = nom
        self.aUnLogo = aUnLogo
        self.codePalette = codePalette
        self.ordrePages = ordrePages
        self.surchargesPages = surchargesPages
    }

    var id: URL { adresse }
    var palette: Palette { .pour(code: codePalette) }
    /// La barre du bas de cette résidence, dans son ordre.
    var pages: [PageDeNavigation] {
        OrdrePages.ordonner(PagesParDefaut.toutes, ordre: ordrePages, surcharges: surchargesPages ?? [:])
    }
    var hote: String { adresse.host() ?? adresse.absoluteString }
    var adresseLogo: URL? {
        aUnLogo ? adresse.appending(path: "api/config/logo.png") : nil
    }
}

/// L'adresse saisie ou scannée, ramenée à `https://<hôte>` — ou rien.
enum AdresseInstallation {
    static func normaliser(_ saisie: String) -> URL? {
        var texte = saisie.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !texte.isEmpty, !texte.contains(" ") else { return nil }
        if texte.hasPrefix("http://") {
            // Jamais en clair : l'app parle HTTPS, comme les installations.
            texte = String(texte.dropFirst("http://".count))
        }
        if !texte.hasPrefix("https://") {
            texte = "https://" + texte
        }
        guard let composants = URLComponents(string: texte),
            let hote = composants.host, hote.contains("."), !hote.hasPrefix("."), !hote.hasSuffix(".")
        else { return nil }
        var propre = URLComponents()
        propre.scheme = "https"
        propre.host = hote
        propre.port = composants.port
        return propre.url
    }
}
