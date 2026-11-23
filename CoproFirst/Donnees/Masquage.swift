// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Un résident dont on masque ce qu'il publie, pour soi seul (`MasquageRead`,
/// coprofirst#2861). Rien n'est supprimé, et il n'en est pas averti ; le filtre est au
/// SERVEUR (idées, annonces, sondages, réponses, commentaires, suites et messages
/// d'affaire) — l'app ne le refait pas.
struct Masquage: Identifiable, Hashable, Sendable {
    let auteurId: Int
    /// Le nom tel que l'affichent ses publications.
    let auteur: String
    let creeLe: Date

    var id: Int { auteurId }
}

extension Masquage {
    init(_ lu: Components.Schemas.MasquageRead) {
        self.init(auteurId: lu.auteurId, auteur: lu.auteur, creeLe: lu.creeLe)
    }
}

/// L'auteur qu'un geste propose de masquer : son identifiant et son nom, tel qu'affiché
/// là où le geste s'offre. Le geste ne s'offre que là où le nom s'affiche — ce qui ne
/// dit pas son auteur (une idée, un sondage) ne se masque pas (#286).
struct AuteurAMasquer: Identifiable, Hashable, Sendable {
    let id: Int
    let nom: String

    /// `nil` sans identifiant ni nom servis, ou pour soi : le geste ne s'offre pas.
    init?(id: Int?, nom: String?, moi: Int?) {
        guard let id, let nom, !nom.isEmpty, id != moi else { return nil }
        self.id = id
        self.nom = nom
    }
}

/// GET, POST /masquages et DELETE /masquages/{auteur_id} — au plancher depuis v3.121.2 (#313),
/// offerts à une installation qui dit son contrat (`installation.sert(.plancher)`). Trois lecteurs :
/// la Communauté, une affaire, le Profil. Le serveur refuse en 422, avec sa phrase, ce qui
/// ne se masque pas (soi-même, le conseil syndical, l'administration, un modérateur qui
/// masquerait) : l'app ne redit pas la règle.
protocol ServiceMasquages: Sendable {
    func masques(dans installation: Installation) async throws -> [Masquage]
    func masquer(_ auteur: AuteurAMasquer, dans installation: Installation) async throws
    func demasquer(_ auteurId: Int, dans installation: Installation) async throws
}

extension ServiceCoproFirst {
    /// Les deux réalisations s'y conforment (`ModerationTests` le vérifie à la compilation).
    var masquages: (any ServiceMasquages)? { self as? any ServiceMasquages }
}

extension ServiceAPI: ServiceMasquages {
    func masques(dans installation: Installation) async throws -> [Masquage] {
        let sortie = try await appeler { try await client(installation.adresse).getMasquages() }
        switch sortie {
        case .ok(let reponse): return try reponse.body.json.map(Masquage.init)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func masquer(_ auteur: AuteurAMasquer, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).postMasquages(body: .json(.init(auteurId: auteur.id)))
        }
        switch sortie {
        case .created: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func demasquer(_ auteurId: Int, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).deleteMasquagesAuteurId(path: .init(auteurId: auteurId))
        }
        switch sortie {
        case .noContent: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }
}

#if DEBUG
extension ServiceSimule: ServiceMasquages {
    func masques(dans installation: Installation) async throws -> [Masquage] {
        try await Task.sleep(for: .milliseconds(250))
        return try modifierSimule(depuis: FixturesMasquages.lus) { $0 }
    }

    /// Idempotent, comme le serveur (201 sur un masque déjà posé). L'API simulée ne filtre
    /// pas ce qu'elle sert : le filtre est au serveur, et rien ici ne le recopie.
    func masquer(_ auteur: AuteurAMasquer, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(250))
        try modifierSimule(depuis: FixturesMasquages.lus) { masques in
            guard !masques.contains(where: { $0.auteurId == auteur.id }) else { return }
            masques.append(Masquage(auteurId: auteur.id, auteur: auteur.nom, creeLe: .now))
        }
    }

    func demasquer(_ auteurId: Int, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(250))
        try modifierSimule(depuis: FixturesMasquages.lus) { $0.removeAll { $0.auteurId == auteurId } }
    }
}

/// GET /masquages, tel que le serveur le sert au compte simulé : une personne masquée.
/// `scripts/verifier-fixtures.py` le juge contre le schéma du serveur. Tout est inventé.
enum FixturesMasquages {
    typealias Reponse = FixturesAcces.Reponse

    static let masquages = #"""
        [
          {"auteur_id": 31, "auteur": "Dominique EXEMPLE", "cree_le": "2026-11-12T18:30:00"}
        ]
        """#

    /// Chaque réponse et le schéma de sa route, pour le juge (`scripts/verifier-fixtures.py`).
    static let parSchema: [Reponse] = [Reponse(nom: "masquages", schema: "MasquageRead", json: masquages)]

    static func lus() throws -> [Masquage] {
        try Relecture.generee([Components.Schemas.MasquageRead].self, json: masquages).map(Masquage.init)
    }
}
#endif
