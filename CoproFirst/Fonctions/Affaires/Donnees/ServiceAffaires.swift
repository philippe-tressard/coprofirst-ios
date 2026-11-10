// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce que le menu Affaires demande à une installation. Le menu le déclare dans son
/// dossier : les deux services (`ServiceAPI`, `ServiceSimule`) le réalisent par une
/// extension ici même, sans toucher au protocole commun (#10, sessions parallèles).
protocol ServiceAffaires: ServicePerimetres {
    /// GET /tickets : les affaires lisibles par l'utilisateur connecté.
    func affaires(_ installation: Installation) async throws -> [Affaire]
    /// GET /tickets/recherche : les identifiants trouvés, dans l'ordre de pertinence.
    func rechercher(_ terme: String, dans installation: Installation) async throws -> [Int]
    /// GET /lots/mes-perimetres : y a-t-il de quoi filtrer « ce qui me concerne » ?
    func offrirMeConcerne(_ installation: Installation) async -> Bool
    /// GET /tickets/referentiels : les sections que la saisie Essentielle montre, par catégorie.
    func sectionsEssentielles(_ installation: Installation) async throws -> SectionsEssentielles
    /// POST /tickets.
    func creer(_ saisie: SaisieAffaire, dans installation: Installation) async throws -> Affaire
    /// GET /tickets/{id}/fusion : combien d'affaires pourraient y être fusionnées.
    func candidatesALaFusion(_ affaire: Affaire, dans installation: Installation) async throws -> Int
    /// POST /tickets/{id}/evolutions : une Suite d'état sans texte, qui n'avertit
    /// personne (`notifier: false`) — le glissement au Kanban du site.
    func deplacer(_ affaire: Affaire, vers statut: String, dans installation: Installation) async throws
    /// PATCH /tickets/{id} `archive_manuel` : archiver, jamais supprimer.
    func archiver(_ affaire: Affaire, dans installation: Installation) async throws -> Affaire
}

extension ServiceCoproFirst {
    /// Le service du menu Affaires, tiré du service de la session — `nil` pour un
    /// service qui ne le réalise pas (l'écran le dit au lieu de se taire).
    var menuAffaires: (any ServiceAffaires)? { self as? any ServiceAffaires }
}

/// Ce que « Nouvelle affaire » envoie.
struct SaisieAffaire: Hashable, Sendable {
    var categorie: String
    var titre: String
    var description: String
    var urgente: Bool
    var perimetre: String?

    /// La description saisie, en HTML de l'éditeur du site (`TexteDuSite.html(saisi:)`).
    var descriptionHTML: String { TexteDuSite.html(saisi: description) }

    /// Prête à partir : un titre et une description (sections requises du site).
    var complete: Bool {
        !titre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
