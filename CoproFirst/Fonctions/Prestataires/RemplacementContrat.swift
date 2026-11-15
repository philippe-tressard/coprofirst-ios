// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Le contrat à l'autre bout d'un remplacement (`ContratLie`, contrat 1.29.0,
/// coprofirst#2712) : un nom, une date, de quoi le nommer.
struct ContratLie: Hashable, Sendable {
    let id: Int
    var libelle: String
    var prestataireId: Int
    var prestataireNom: String
    var dateDebut: String
    var resilieLe: String?
}

/// La résiliation d'un contrat et son remplacement par un autre prestataire, tels que le
/// serveur les SERT (contrat 1.29.0, coprofirst#2712, #185) : la date, « la résiliation
/// est passée » et les deux bouts du remplacement — le sens inverse (`remplace`) est
/// déduit par l'API, l'app ne recalcule rien.
struct RemplacementContrat: Hashable, Sendable {
    var resilieLe: String?
    var resilie = false
    var remplacePar: ContratLie?
    var remplace: [ContratLie] = []

    /// Les pastilles de la carte, dans l'ordre du site (`CarteContrat.svelte`) : par qui
    /// et dès quand il est remplacé — à défaut, sa résiliation —, puis ceux qu'il remplace.
    var pastilles: [String] {
        var lues: [String] = []
        if let remplacePar {
            lues.append(TextesPrestataires.remplacePar(remplacePar.prestataireNom, des: remplacePar.dateDebut))
        } else if let resilieLe {
            lues.append(TextesPrestataires.resilie(resilieLe, passe: resilie))
        }
        lues += remplace.map { TextesPrestataires.remplace($0.prestataireNom, resilieAu: $0.resilieLe) }
        return lues
    }

    /// Une résiliation est datée : la carte ne dit plus « Sans échéance ».
    var estDatee: Bool { resilieLe != nil }
}

extension ContratLie {
    init(_ lu: Components.Schemas.ContratLie) {
        self.init(
            id: lu.id, libelle: lu.libelle, prestataireId: lu.prestataireId, prestataireNom: lu.prestataireNom,
            dateDebut: lu.dateDebut, resilieLe: lu.resilieLe)
    }
}

extension RemplacementContrat {
    init(_ lu: Components.Schemas.ContratRead) {
        self.init(
            resilieLe: lu.resilieLe, resilie: lu.resilie ?? false, remplacePar: lu.remplacePar.map(ContratLie.init),
            remplace: (lu.remplace ?? []).map(ContratLie.init))
    }
}

extension Contrat {
    /// Les contrats servis, par le type généré — le MÊME branchement pour le service réel
    /// et l'API simulée.
    static func lus(_ generes: [Components.Schemas.ContratRead]) -> [Contrat] {
        generes.map { lu in
            var contrat = Contrat(lu)
            contrat.remplacement = RemplacementContrat(lu)
            return contrat
        }
    }
}
