// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

#if DEBUG
/// « Demandes de profil » simulées : lues du JSON de leur route (`FixturesDemandesProfil`)
/// par leurs types générés, comme le service réel. Un traitement retire la demande, comme le
/// serveur, et rend son annonce (`FixturesDemandesProfil.traitee`) ; une demande déjà
/// traitée est refusée avec sa phrase.
extension ServiceSimule: ServiceDemandesProfil {
    func demandesProfil(_ installation: Installation) async throws -> [DemandeProfil] {
        try await Task.sleep(for: .milliseconds(300))
        return try modifierSimule(depuis: FixturesDemandesProfil.lues) { $0 }
    }

    func traiterDemandeProfil(
        _ id: Int, approuver: Bool, motif: String?, dans installation: Installation
    ) async throws -> PhraseAvis {
        try await Task.sleep(for: .milliseconds(350))
        try modifierSimule(depuis: FixturesDemandesProfil.lues) { demandes in
            guard demandes.contains(where: { $0.id == id }) else {
                throw ErreurService.refus(.init(phrase: "Cette demande a déjà été traitée."))
            }
            demandes.removeAll { $0.id == id }
        }
        return try FixturesDemandesProfil.annonce(approuver: approuver)
    }
}
#endif
