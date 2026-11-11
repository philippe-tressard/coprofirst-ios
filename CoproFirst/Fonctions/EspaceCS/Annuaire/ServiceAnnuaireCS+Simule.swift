// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

#if DEBUG
/// L'annuaire du conseil simulé, lu du JSON de ses routes (`FixturesAnnuaireCS`) comme
/// le service réel le lit. Un enregistrement numérote les fiches neuves et rend la
/// composition retenue, comme le serveur.
extension ServiceSimule: ServiceAnnuaireCS {
    func conseil(_ installation: Installation) async throws -> ConseilCS {
        try await Task.sleep(for: .milliseconds(300))
        return try annuaireCS { $0.conseil }
    }

    func enregistrer(_ conseil: ConseilCS, dans installation: Installation) async throws -> ConseilCS {
        try await Task.sleep(for: .milliseconds(350))
        return try annuaireCS { annuaire in
            var conseil = conseil
            for i in conseil.membres.indices where conseil.membres[i].id == nil {
                conseil.membres[i].id = annuaire.prochainId()
            }
            annuaire.conseil = conseil
            return conseil
        }
    }

    func syndic(_ installation: Installation) async throws -> SyndicCS {
        try await Task.sleep(for: .milliseconds(300))
        return try annuaireCS { $0.syndic }
    }

    func enregistrer(_ syndic: SyndicCS, dans installation: Installation) async throws -> SyndicCS {
        try await Task.sleep(for: .milliseconds(350))
        return try annuaireCS { annuaire in
            var syndic = syndic
            for i in syndic.membres.indices {
                if syndic.membres[i].id == nil { syndic.membres[i].id = annuaire.prochainId() }
                // Ce que le serveur sert en retour : les numéros, un par un.
                syndic.membres[i].telephones = (syndic.membres[i].telephone ?? "").split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
            }
            // Le contrat fait foi : un nom saisi ne remplace pas celui du contrat.
            if annuaire.syndic.nomDuContrat { syndic.nomSyndic = annuaire.syndic.nomSyndic }
            syndic.nomSyndicSource = annuaire.syndic.nomSyndicSource
            annuaire.syndic = syndic
            return syndic
        }
    }

    func rapprochement(nom: String, localiser: Bool, dans installation: Installation) async throws -> Rapprochement {
        try await Task.sleep(for: .milliseconds(150))
        var trouve = try FixturesAnnuaireCS.rapprochementLu(nom)
        if !localiser { trouve = Rapprochement(userId: trouve.userId) }
        return trouve
    }

    /// L'annuaire de CE service simulé, lu des fixtures au premier usage.
    private func annuaireCS<R>(_ geste: (inout AnnuaireCSSimule) throws -> R) throws -> R {
        try modifierSimule(depuis: AnnuaireCSSimule.init, geste)
    }
}

/// L'annuaire du conseil simulé, et le dernier numéro donné à une fiche.
struct AnnuaireCSSimule: Sendable {
    private var dernierId = 40
    var conseil: ConseilCS
    var syndic: SyndicCS

    init() throws {
        conseil = try FixturesAnnuaireCS.conseilLu()
        syndic = try FixturesAnnuaireCS.syndicLu()
    }

    mutating func prochainId() -> Int {
        dernierId += 1
        return dernierId
    }
}
#endif
