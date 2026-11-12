// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

#if DEBUG
/// La consultation hors ligne de l'API simulée (#101) : rien n'est écrit sur le disque —
/// ses lectures inventées tiennent lieu de lecture gardée, comme son `gardees` tient lieu
/// de Trousseau. Le magasin réel s'éprouve par `ServiceAPI` (`LectureGardeeTests`).
extension ServiceSimule: ServiceHorsLigne {
    /// La date de la lecture « gardée » sous `-hors-ligne gardee` : le 10/11/2026 à 14:32,
    /// heure de Paris — l'exemple du ticket.
    static let lectureDuTicket = Date(timeIntervalSince1970: 1_794_317_520)

    func consulterHorsLigne(_ installation: Installation) -> LectureDisponible {
        let lecture = lectureSimulee
        // Périmée : effacée en la disant, une seule fois — comme le magasin.
        if lecture == .perimee { lectureSimulee = .aucune }
        return lecture
    }

    func reprendreEnLigne(_ installation: Installation) async throws {
        if horsLigneSimule { throw ErreurService.horsLigne }
        if repriseRefusee {
            _ = await deconnecter(installation)
            throw ErreurService.sessionExpiree
        }
    }

    func purgerLesLectures(sauf gardees: [Installation]) {}

    func fichierGarde(_ chemin: String, dans installation: Installation) async throws -> Data {
        try await fichierProtege(chemin, dans: installation)
    }
}
#endif
