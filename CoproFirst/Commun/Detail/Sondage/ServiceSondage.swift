// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce que la fiche d'un sondage demande à une installation (#38). Le fil et la
/// Communauté l'ouvrent : un composant commun, son service avec lui. Signaler un
/// commentaire : la lecture commune (`ServiceSignalements`).
protocol ServiceSondage: ServiceSignalements {
    /// GET /sondages/{id}, et GET /auth/me pour l'identifiant du compte.
    func sondage(_ id: Int, dans installation: Installation) async throws -> DetailSondage
    /// POST /sondages/{id}/voter (`VoteBody`) : l'option, la précision, le commentaire.
    func voter(_ vote: VoteSondage, au sondage: Int, dans installation: Installation) async throws
    /// POST /sondages/{id}/commenter.
    func commenterSondage(_ texte: String, au sondage: Int, dans installation: Installation) async throws
    /// DELETE /sondages/{id}/commentaires/{cid}.
    func supprimerCommentaireSondage(_ id: Int, du sondage: Int, dans installation: Installation) async throws
}

extension Parcours {
    /// Les deux réalisations s'y conforment (`SondageTests` le vérifie à la compilation).
    var serviceSondage: any ServiceSondage {
        // swiftlint:disable:next force_cast
        service as! any ServiceSondage
    }
}
