// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Le Suivi des affaires par le client GÉNÉRÉ : la réponse est typée (`SuiviAffairesRead`).
extension ServiceAPI: ServiceReporting {
    func suiviAffaires(_ releve: ReleveSuivi, dans installation: Installation) async throws -> SuiviAffaires {
        let sortie = try await appeler {
            try await client(installation.adresse).getSuiviAffaires(query: .init(mode: releve.rawValue))
        }
        switch sortie {
        case .ok(let ok): return SuiviAffaires(try ok.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }
}

extension SuiviAffaires {
    init(_ lu: Components.Schemas.SuiviAffairesRead) {
        self.init(
            total: lu.total, anciennes: lu.anciennes, delaiJours: lu.delaiJours, fusionnees: lu.fusionnees ?? 0,
            parCategorie: lu.parCategorie.map(Repartition.init), parBatiment: lu.parBatiment.map(Repartition.init),
            affaires: lu.affaires.map(AffaireSuivie.init))
    }
}

extension Repartition {
    init(_ lu: Components.Schemas.BarreRead) {
        self.init(
            cle: lu.cle, libelle: lu.libelle, nombre: lu.nombre,
            tranches: lu.tranches.map {
                Tranche(cle: $0.cle, libelle: $0.libelle, nombre: $0.nombre, teinte: $0.teinte)
            })
    }
}

extension AffaireSuivie {
    init(_ lu: Components.Schemas.AffaireOuverteRead) {
        self.init(
            id: lu.id, numero: lu.numero, titre: lu.titre, statut: lu.statut, libelleCategorie: lu.libelleCategorie,
            ouverteLe: lu.ouverteLe, ageJours: lu.ageJours, anciennete: lu.anciennete, apercu: lu.apercu,
            apercuIA: lu.apercuIa, aEvolue: lu.aEvolue, motifEvolution: lu.motifEvolution, etatVisite: lu.etatVisite)
    }
}
