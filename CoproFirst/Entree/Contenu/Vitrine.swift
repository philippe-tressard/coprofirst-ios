// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Observation

/// La vitrine lit le contenu de coprofirst.fr (#51) : une seule source pour le site et
/// l'app. Au lancement, la dernière lecture gardée en cache, à défaut la copie
/// embarquée (`ContenuEmbarque`, générée) ; puis une lecture du site, une fois par
/// lancement réussie, qui remplace l'une et l'autre si elle donne des pages complètes.
///
/// Ce n'est pas l'API de CoproFirst (client généré) : un fichier statique du site, lu
/// sans cookie ni jeton (session éphémère), dont l'app n'affiche que le texte.
@MainActor @Observable
final class Vitrine {
    /// Lire une adresse : `URLSession` en vrai, un double dans les tests.
    typealias Lecteur = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    static let adresse = URL(string: "https://coprofirst.fr/contenu.json")
    /// Au-delà, ce n'est pas le contenu de l'accueil (16 Ko le 08/11/2026).
    static let tailleMax = 1_000_000

    private(set) var pages: PagesVitrine
    @ObservationIgnored private let lecteur: Lecteur?
    @ObservationIgnored private let cache: URL?
    @ObservationIgnored private var lue = false

    /// `lecteur` nil : aucune lecture du réseau (API simulée, tests) ; `cache` nil : ni
    /// lecture ni écriture du cache.
    init(lecteur: Lecteur?, cache: URL?) {
        self.lecteur = lecteur
        self.cache = cache
        let gardee = cache.flatMap { try? Data(contentsOf: $0) }.flatMap(PagesVitrine.lire)
        pages = gardee ?? Self.embarquee
    }

    /// La vitrine de l'app : le site, en session éphémère, et le cache de l'appareil.
    static func enLigne() -> Vitrine {
        let session = URLSession(configuration: .ephemeral)
        let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("contenu-vitrine.json")
        return Vitrine(lecteur: { try await session.data(for: $0) }, cache: cache)
    }

    /// Ce que `ContenuVitrineTests` garantit lisible et complet.
    static let embarquee: PagesVitrine = {
        guard let pages = PagesVitrine.lire(Data(ContenuEmbarque.json.utf8)) else {
            preconditionFailure("copie embarquée de contenu.json illisible — ContenuVitrineTests la refuse")
        }
        return pages
    }()

    /// Lit le site, si ce lancement ne l'a pas déjà fait avec succès. Un échec (hors
    /// ligne, réponse refusée, contenu incomplet) ne change rien à l'écran.
    func actualiser() async {
        guard !lue, let lecteur, let adresse = Self.adresse else { return }
        let requete = URLRequest(url: adresse, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        guard let reponse = try? await lecteur(requete),
            (reponse.1 as? HTTPURLResponse)?.statusCode == 200, reponse.0.count <= Self.tailleMax,
            let lues = PagesVitrine.lire(reponse.0)
        else { return }
        let donnees = reponse.0
        lue = true
        if lues != pages { pages = lues }
        if let cache { try? donnees.write(to: cache, options: .atomic) }
    }
}
