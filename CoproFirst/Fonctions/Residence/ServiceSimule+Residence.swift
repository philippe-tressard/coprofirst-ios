// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

#if DEBUG
/// « Ma résidence » dans l'API simulée : tout est inventé — aucune personne, aucune
/// adresse réelle. Le HTML est celui de l'éditeur du site, pour que la porte
/// `TexteDuSite` ait à travailler (#22).
extension ServiceSimule: ServiceResidence {
    func fiche(_ installation: Installation) async throws -> ContenuFiche {
        try await Task.sleep(for: .milliseconds(450))
        return Apercu.contenuFiche
    }

    func rapport(_ id: Int, nom: String, dans installation: Installation) async throws -> URL {
        try await document(id, nom: nom, dans: installation)
    }

    func carnet(perimetre: String?, dans installation: Installation) async throws -> ContenuCarnet {
        try await Task.sleep(for: .milliseconds(450))
        let entrees = Apercu.carnet.filter { perimetre == nil || perimetre == "bat_a" || $0.equipement != "ascenseur" }
        return ContenuCarnet(
            entrees: entrees,
            libellesEquipements: ["ascenseur": "Ascenseur", "chaufferie": "Chaufferie", "toiture": "Toiture"])
    }

    func accesReglement(_ installation: Installation) async throws -> Bool { true }

    func reglement(_ installation: Installation) async throws -> (EtatReglement, [QuestionReglement]) {
        try await Task.sleep(for: .milliseconds(450))
        let etat = EtatReglement(disponible: true, texteDisponible: true, lienReglement: nil)
        return (etat, verrouQuestions.withLock { questionsPosees } + [Apercu.question])
    }

    func poser(_ question: String, dans installation: Installation) async throws -> QuestionReglement {
        try await Task.sleep(for: .seconds(2))
        let modele = Apercu.question
        var reponse = QuestionReglement(
            id: Int.random(in: 1_000...9_999), question: question, reponse: modele.reponse,
            reponseSansRenvois: modele.reponseSansRenvois,
            verdictLibelle: modele.verdictLibelle, poseeLe: .now, texteEnVigueur: true, dansLaFAQ: false,
            extraits: modele.extraits, renvoisSansExtrait: modele.renvoisSansExtrait)
        reponse.selonReglement = modele.selonReglement
        reponse.reserves = modele.reserves
        reponse.provenance = modele.provenance
        reponse.modele = modele.modele
        verrouQuestions.withLock { questionsPosees.insert(reponse, at: 0) }
        return reponse
    }
}

/// Les questions posées pendant la séance simulée (un toucher les ajoute en tête).
nonisolated(unsafe) private var questionsPosees: [QuestionReglement] = []
private let verrouQuestions = NSLock()
#endif
