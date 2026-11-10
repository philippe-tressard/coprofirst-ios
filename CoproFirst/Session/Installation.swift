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
    /// Qui est l'utilisateur ici, au dernier passage (GET /auth/me) — facultatif.
    var profil: ProfilResidence?
    /// Le contrat d'API qu'elle sert (`version_contrat`), tel que servi — absent d'une
    /// résidence retenue avant #70 : il se relit à la découverte suivante.
    var versionContrat: String?
    /// Une variante du logo pour le fond sombre (`site_logo_sombre` non vide, #70).
    var aUnLogoSombre: Bool?

    init(
        adresse: URL, nom: String, aUnLogo: Bool, codePalette: String? = nil,
        ordrePages: [String]? = nil, surchargesPages: [String: SurchargePage]? = nil,
        versionContrat: String? = nil, aUnLogoSombre: Bool? = nil
    ) {
        self.adresse = adresse
        self.nom = nom
        self.aUnLogo = aUnLogo
        self.codePalette = codePalette
        self.ordrePages = ordrePages
        self.surchargesPages = surchargesPages
        self.versionContrat = versionContrat
        self.aUnLogoSombre = aUnLogoSombre
    }

    var id: URL { adresse }
    var palette: Palette { .pour(code: codePalette) }
    /// La barre du bas de cette résidence, dans son ordre.
    var pages: [PageDeNavigation] {
        OrdrePages.ordonner(PagesParDefaut.toutes, ordre: ordrePages, surcharges: surchargesPages ?? [:])
    }
    var hote: String { adresse.host() ?? adresse.absoluteString }
    /// Le contrat servi, lu par ses nombres — `nil` s'il est absent ou illisible.
    var contrat: VersionContrat? { VersionContrat(versionContrat) }

    /// L'adresse du logo téléversé par la résidence pour ce fond — `nil` sans logo
    /// (l'app montre alors celui de CoproFirst, comme le site son logo neutre).
    ///
    /// Sur un fond sombre, la variante `sombre` n'est demandée qu'à une installation
    /// qui la sert (contrat ≥ 1.15.0) ET qui en a téléversé une (`site_logo_sombre`),
    /// comme `LogoResidence.svelte` : sinon le logo lui-même, à la même adresse
    /// qu'au clair — aucune requête de plus. Le serveur rendrait d'ailleurs le logo
    /// clair dans ces deux cas : une version antérieure ignore le paramètre, et la
    /// 1.15.0 sans variante sert le logo téléversé (`utils/logo.logo_png`).
    ///
    /// ⚠️ Le paramètre `variante` n'est pas dans le contrat du plancher (1.12.0) : le
    /// client généré ne peut pas l'écrire. L'adresse s'écrit donc ici, et ici seulement.
    func adresseLogo(sombre: Bool) -> URL? {
        guard aUnLogo else { return nil }
        let adresse = adresse.appending(path: "api/config/logo.png")
        guard sombre, aUnLogoSombre == true, let contrat, contrat >= .logoSombre else { return adresse }
        return adresse.appending(queryItems: [URLQueryItem(name: "variante", value: "sombre")])
    }
}

extension Installation {
    /// L'installation que décrit GET /config — `nil` si rien n'y nomme une résidence.
    init?(adresse: URL, config cles: [String: String]) {
        guard let nom = cles["site_nom"], !nom.isEmpty else { return nil }
        let prefixe = "page_config_"
        let surcharges = cles.reduce(into: [String: SurchargePage]()) { surcharges, cle in
            guard cle.key.hasPrefix(prefixe), let surcharge = SurchargePage(json: cle.value) else { return }
            surcharges[String(cle.key.dropFirst(prefixe.count))] = surcharge
        }
        self.init(
            adresse: adresse, nom: nom, aUnLogo: !(cles["site_logo"] ?? "").isEmpty,
            codePalette: cles["site_palette"], ordrePages: OrdrePages.lire(cles["pages_order"]),
            surchargesPages: surcharges, versionContrat: cles["version_contrat"],
            aUnLogoSombre: !(cles["site_logo_sombre"] ?? "").isEmpty)
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

    /// L'adresse telle qu'on la saisirait : l'hôte, et son port s'il en a un.
    static func enSaisie(_ adresse: URL) -> String {
        (adresse.host() ?? "") + (adresse.port.map { ":\($0)" } ?? "")
    }
}
