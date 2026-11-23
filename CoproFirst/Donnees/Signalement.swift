// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Ce qu'on signale au conseil syndical : `cible_type` et `cible_id` de POST /signalements
/// (`SignalementCreate`). Le type est celui que le site envoie (`signaler('commentaire', id)`).
struct CibleSignalement: Hashable, Sendable {
    let type: String
    let id: Int
}

extension CibleSignalement {
    /// Au plancher depuis v3.121.2 (#313 ; servi avant derrière une porte, coprofirst#2861,
    /// #286) : une affaire, une suite qui porte un texte, la réponse de l'assistant à une
    /// question au règlement — les types que le site envoie (`CibleSignalement` de
    /// `communaute.ts`). Un contenu que le lecteur ne voit pas répond 404.
    static func affaire(_ id: Int) -> Self { .init(type: "affaire", id: id) }
    static func suite(_ id: Int) -> Self { .init(type: "suite", id: id) }
    static func questionReglement(_ id: Int) -> Self { .init(type: "question_reglement", id: id) }
}

/// POST /signalements : un motif, au conseil syndical. La Communauté et la fiche d'un
/// sondage (#38) en héritent par leur protocole, comme `ServicePerimetres` ; une affaire et
/// le Règlement le lisent par `service.signalements` (#286).
protocol ServiceSignalements: Sendable {
    func signalerAuConseil(_ cible: CibleSignalement, motif: String, dans installation: Installation) async throws
}

extension ServiceCoproFirst {
    var signalements: (any ServiceSignalements)? { self as? any ServiceSignalements }
}

extension ServiceAPI: ServiceSignalements {
    func signalerAuConseil(_ cible: CibleSignalement, motif: String, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).postSignalements(
                body: .json(.init(cibleId: cible.id, cibleType: cible.type, motif: motif)))
        }
        switch sortie {
        case .created: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }
}

#if DEBUG
extension ServiceSimule: ServiceSignalements {
    func signalerAuConseil(_ cible: CibleSignalement, motif: String, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(250))
    }
}
#endif
