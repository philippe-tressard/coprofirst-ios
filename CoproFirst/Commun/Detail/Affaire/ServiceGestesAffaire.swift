// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce que le bandeau d'une affaire demande au serveur, au-delà de « Répondre »
/// (`ServiceCoproFirst.repondre`). Les deux services le réalisent par extension, ici.
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
}

extension ServiceCoproFirst {
    /// `nil` pour un service qui ne le réalise pas : le bandeau le dit au lieu de se taire.
    var gestesAffaire: (any ServiceGestesAffaire)? { self as? any ServiceGestesAffaire }
}
