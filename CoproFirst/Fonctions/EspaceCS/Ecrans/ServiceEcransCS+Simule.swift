// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

#if DEBUG
/// Des écrans inventés, pour les aperçus, les tests et les captures : aucune requête. La
/// liste de départ est le JSON de la route (`FixturesEcransCS`) ; les gestes changent la
/// liste de CE service. Seul `FixturesEcransCS.codeAffiche` désigne une demande en attente.
extension ServiceSimule: ServiceEcransCS {
    func ecrans(dans installation: Installation) async throws -> [EcranDuHall] {
        try await Task.sleep(for: .milliseconds(300))
        return try modifierSimule(depuis: FixturesEcransCS.ecransLus) { $0 }
    }

    func appairer(_ saisie: SaisieAppairage, dans installation: Installation) async throws -> EcranAppaire {
        try await Task.sleep(for: .milliseconds(400))
        let attendu = SaisieAppairage(code: FixturesEcransCS.codeAffiche).lettres
        guard saisie.lettres == attendu, let code = saisie.perimetres.codes.first else {
            throw ErreurService.refus(.init(phrase: FixturesEcransCS.codeInconnu))
        }
        let noeuds = try await perimetres(installation)
        let libelle = noeuds.first { $0.code == code && !$0.parDefaut }?.libelle ?? ""
        // Ce que le serveur ferait quand l'écran vient chercher son accès : il naît.
        try modifierSimule(depuis: FixturesEcransCS.ecransLus) { liste in
            let neuf = EcranDuHall(
                id: (liste.map(\.id).max() ?? 0) + 1, nom: saisie.nomSaisi, perimetre: code,
                perimetreLibelle: libelle, creeLe: .now, vuLe: nil,
                expireLe: .now.addingTimeInterval(30 * 86_400), echu: false)
            liste.append(neuf)
            liste.sort { ($0.nom, $0.id) < ($1.nom, $1.id) }
        }
        return EcranAppaire(nom: saisie.nomSaisi, perimetreLibelle: libelle)
    }

    func retirerEcran(_ id: Int, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(250))
        try modifierSimule(depuis: FixturesEcransCS.ecransLus) { $0.removeAll { $0.id == id } }
    }
}
#endif
