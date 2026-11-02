// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Une installation de CoproFirst : une résidence, à son adresse. Aucun annuaire ne
/// les liste — l'app ne connaît que celles que l'utilisateur a saisies ou scannées.
struct Installation: Codable, Hashable, Sendable, Identifiable {
    /// L'adresse du site, réduite à `https://<hôte>`.
    let adresse: URL
    /// Le nom de la résidence (`site_nom` de GET /config).
    var nom: String
    /// Un logo téléversé par la résidence (`site_logo` non vide).
    var aUnLogo: Bool

    var id: URL { adresse }
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
