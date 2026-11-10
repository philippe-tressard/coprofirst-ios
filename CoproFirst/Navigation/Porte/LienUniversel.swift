// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// L'adresse d'un lien du site → la destination qu'elle désigne (#18).
///
/// Les chemins sont ceux que l'installation déclare dans son
/// `/.well-known/apple-app-site-association` (coprofirst#2459), eux-mêmes confrontés
/// aux modèles de courriel par `test_apple_app_site_association.py` de coprofirst :
/// `/`, `/tickets[/<id>]`, `/actualites[/…]`, `/auth/connexion`, et deux liens à jeton.
/// Une page du menu se reconnaît par sa route, lue dans la table GÉNÉRÉE
/// (`PagesParDefaut`) — jamais une liste de chemins écrite ici.
///
/// La même lecture vaut pour toute adresse reçue (`onOpenURL`) : lien universel
/// aujourd'hui, bandeau d'app de Safari demain. Elle ne fait confiance à rien : seul
/// HTTPS passe, l'hôte est normalisé, et un hôte inconnu suit la découverte, avec
/// confirmation (#82) — `Parcours.suivre`.
enum LienUniversel {
    /// La route de la vue Affaires sur le site — celle d'une affaire est `/tickets/<id>`.
    static let routeAffaires = "/tickets"

    /// La page du menu qu'ouvre cette route du site, d'après la table générée.
    static func idDeLaPage(route: String) -> String? {
        PagesParDefaut.toutes.first { $0.route == route }?.id
    }

    static func destination(_ url: URL) -> Destination? {
        guard url.scheme?.lowercased() == "https",
            let composants = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let hote = composants.host, !hote.isEmpty,
            let adresse = AdresseInstallation.normaliser(hote + (composants.port.map { ":\($0)" } ?? ""))
        else { return nil }
        return Destination(adresse: adresse, ecran: ecran(composants, url: url))
    }

    private static func ecran(_ composants: URLComponents, url: URL) -> Destination.Ecran {
        let segments = composants.path.split(separator: "/").map(String.init)
        switch segments.first {
        case nil:
            return .accueil
        case "tickets" where segments.count == 2:
            guard let id = Int(segments[1]) else { break }
            return .affaire(id: id, message: ancre("msg-", composants.fragment))
        // « Les actualités sont des affaires » (coprofirst, 23/09/2026) : le site renvoie
        // `/actualites` et `/actualites#pub-N` vers la vue Affaires. Une publication N
        // n'est pas reprise ici (elle demande GET /publications/{id}, réponse non typée).
        case "actualites":
            return page(route: routeAffaires) ?? .accueil
        case "auth" where segments == ["auth", "connexion"]:
            return .connexion
        default:
            break
        }
        return page(route: "/" + segments.joined(separator: "/")) ?? .navigateur(url)
    }

    private static func page(route: String) -> Destination.Ecran? {
        idDeLaPage(route: route).map { .page($0) }
    }

    /// `msg-45` → 45 ; toute autre ancre → rien.
    private static func ancre(_ prefixe: String, _ fragment: String?) -> Int? {
        guard let fragment, fragment.hasPrefix(prefixe) else { return nil }
        return Int(fragment.dropFirst(prefixe.count))
    }
}
