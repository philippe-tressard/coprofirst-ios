// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce que le bandeau d'une affaire et les entrées de son Historique demandent au
/// serveur, au-delà de « Répondre » (`ServiceCoproFirst.repondre`). Les deux services le
/// réalisent par extension, ici.
protocol ServiceGestesAffaire: Sendable {
    /// POST /tickets/{id}/evolutions : une Suite — un commentaire, ou un nouvel état.
    func ajouterSuite(_ suite: SaisieSuite, a affaire: Int, dans installation: Installation) async throws
    /// PATCH /tickets/{id} : « Modifier l'affaire » — les seuls champs changés.
    func enregistrer(_ edition: EditionAffaire, de affaire: Int, dans installation: Installation) async throws
    /// PATCH /tickets/{id} : une option de mise en avant, posée ou retirée.
    func regler(
        _ option: OptionAffaire, active: Bool, de affaire: Int, dans installation: Installation
    ) async throws
    /// PATCH /tickets/{id} `archive_manuel` : archiver, jamais supprimer.
    func archiverAffaire(_ affaire: Int, dans installation: Installation) async throws
    /// PATCH /tickets/{id}/evolutions/{evol_id} : « Modifier la suite », depuis
    /// l'Historique — les seuls champs changés (#91). Rend ce que l'affaire en a fait
    /// quand elle ne l'a pas suivie (#187), `nil` sinon.
    @discardableResult
    func corrigerSuite(
        _ correction: CorrectionSuite, _ suite: Int, de affaire: Int, dans installation: Installation
    ) async throws -> IssueCorrection?
    /// DELETE /tickets/{id}/evolutions/{evol_id} : effacer une entrée de l'Historique.
    func supprimerSuite(_ suite: Int, de affaire: Int, dans installation: Installation) async throws
    /// PATCH /tickets/{id}/messages/{msg_id} : SON message corrigé (#211) — le serveur
    /// réécrit aussi son miroir de l'Historique.
    func corrigerMessage(_ contenuHTML: String, _ message: Int, de affaire: Int, dans installation: Installation)
        async throws
    /// DELETE /tickets/{id}/messages/{msg_id} : SON message retiré, et son miroir avec lui.
    func supprimerMessage(_ message: Int, de affaire: Int, dans installation: Installation) async throws
    /// GET /tickets/{id}/agenda : le rendez-vous que le serveur compose (contrat 2.15.0,
    /// porte `VersionContrat.agenda`, #435) — sous la règle de lecture de l'affaire.
    func rendezVous(de affaire: Int, dans installation: Installation) async throws -> RendezVousAffaire
}

extension ServiceCoproFirst {
    /// `nil` pour un service qui ne le réalise pas : le bandeau le dit au lieu de se taire.
    var gestesAffaire: (any ServiceGestesAffaire)? { self as? any ServiceGestesAffaire }
}
