// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Ce que l'écran « À propos » lit de la résidence ouverte : la mention de son pied de page
/// (`CLES_PIED` de GET /config) et ses deux textes légaux (GET /config/legal), en HTML,
/// déjà remplis par le serveur avec l'identité de la copropriété.
struct AProposResidence: Hashable, Sendable {
    /// L'année de création que l'administration a réglée (« © 2025–2026 »), si elle l'a fait.
    var anneeDebut: Int?
    /// Le texte libre du pied de page, s'il y en a un.
    var texte: String?
    var mentionsLegales: String?
    var confidentialite: String?

    /// `mentionAnnee` du site : « © 2026 », ou « © 2025–2026 » quand la création est antérieure.
    static func mentionAnnee(debut: Int?, courante: Int) -> String {
        if let debut, debut < courante { return "© \(debut)–\(courante)" }
        return "© \(courante)"
    }

    /// Les deux réponses publiques, lues telles que le serveur les sert.
    init(config: [String: String], legal: [String: String]) {
        anneeDebut = config[TextesDuPied.cleAnneeDebut].flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        texte = config[TextesDuPied.cleTexte].flatMap { $0.trimmingCharacters(in: .whitespaces).nulSiVide }
        mentionsLegales = legal["mentions_legales"].flatMap(\.nulSiVide)
        confidentialite = legal["politique_confidentialite"].flatMap(\.nulSiVide)
    }
}

/// GET /config et GET /config/legal : deux routes publiques, lues ensemble.
protocol ServiceAPropos: Sendable {
    func aPropos(_ installation: Installation) async throws -> AProposResidence
}

extension Parcours {
    /// Les deux réalisations s'y conforment (`AProposTests` le vérifie).
    var serviceAPropos: any ServiceAPropos {
        // swiftlint:disable:next force_cast
        service as! any ServiceAPropos
    }
}

extension ServiceAPI: ServiceAPropos {
    func aPropos(_ installation: Installation) async throws -> AProposResidence {
        async let config = configPublique(installation)
        async let legal = textesLegaux(installation)
        return try await AProposResidence(config: config, legal: legal)
    }

    private func configPublique(_ installation: Installation) async throws -> [String: String] {
        let sortie = try await appeler { try await client(installation.adresse).getConfig() }
        switch sortie {
        case .ok(let ok): return try ok.body.json.additionalProperties
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    private func textesLegaux(_ installation: Installation) async throws -> [String: String] {
        let sortie = try await appeler { try await client(installation.adresse).getConfigLegal() }
        switch sortie {
        case .ok(let ok): return try ok.body.json.additionalProperties
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }
}

#if DEBUG
extension ServiceSimule: ServiceAPropos {
    func aPropos(_ installation: Installation) async throws -> AProposResidence {
        try await Task.sleep(for: .milliseconds(250))
        return AProposResidence(
            config: [TextesDuPied.cleAnneeDebut: "2025"],
            legal: [
                "mentions_legales": """
                    <h2>Éditeur</h2><p>Le site de la résidence est édité par le syndicat des \
                    copropriétaires de la résidence de démonstration.</p><h2>Hébergement</h2>\
                    <p>Serveur auto-hébergé dans la résidence.</p>
                    """,
                "politique_confidentialite": """
                    <h2>Responsable de traitement</h2><p>Le syndicat des copropriétaires, représenté \
                    par son syndic.</p><h2>Vos droits</h2><p>Accès, rectification, effacement : \
                    écrivez au conseil syndical.</p>
                    """,
            ])
    }
}
#endif
