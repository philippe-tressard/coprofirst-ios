// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

#if DEBUG
/// Les avis sur l'installation simulée (#207) : le récapitulatif des fixtures
/// (`FixturesNotations`), puis changé par les gestes de CE service — comme le serveur :
/// un nouvel avis va à l'exercice courant, sur la ligne de son affaire, ou parmi les avis
/// sans affaire ; une affaire où le prestataire n'intervient pas exige la confirmation.
/// C'est le FAUX serveur : le regroupement et le compte, que l'app ne fait jamais,
/// vivent ici seulement.
struct AvisSimules {
    var recapitulatifs: [Int: [ExerciceAvis]] = [:]
    var affaires: [Int: [AffaireANoter]] = [:]
    /// Les prestataires dont un geste a changé les avis : leur moyenne se relit ici.
    var touches: Set<Int> = []
    var prochain = 100

    /// La note que le serveur écrit pour chaque état (`NOTE_DE_ETAT`).
    static let notes = ["mauvais": 1, "neutre": 3, "excellent": 5]
    static let refusAjout = "Ce prestataire n'est pas intervenant de cette affaire : confirmez, il y sera ajouté."
    static let auteur = "Conseil syndical"
}

extension ServiceSimule {
    func affairesANoter(de prestataire: Int, dans installation: Installation) async throws -> [AffaireANoter] {
        try await Task.sleep(for: .milliseconds(200))
        return try avisSimules { try $0.affaires(prestataire) }
    }

    func noter(_ envoi: EnvoiAvis, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(300))
        try avisSimules { simules in
            let avis = AvisPrestataire(
                id: simules.prochain, etat: envoi.etat, commentaire: envoi.commentaire, auteurNom: AvisSimules.auteur,
                creeLe: .now, peutModifier: true, contratId: envoi.contratId)
            simules.prochain += 1
            try simules.poser(avis, envoi: envoi, annee: nil)
        }
    }

    func corriger(_ avis: Int, _ envoi: EnvoiAvis, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(300))
        try avisSimules { simules in
            guard let (lu, annee) = simules.retirer(avis, de: envoi.prestataireId) else {
                throw ErreurService.refus(.init(phrase: "Notation introuvable"))
            }
            var corrige = lu
            (corrige.etat, corrige.commentaire) = (envoi.etat, envoi.commentaire)
            do { try simules.poser(corrige, envoi: envoi, annee: annee) } catch {
                try simules.poser(lu, envoi: EnvoiAvis(lu, prestataire: envoi.prestataireId), annee: annee)
                throw error
            }
        }
    }

    func retirer(_ avis: Int, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(250))
        try avisSimules { simules in
            let prestataire = simules.recapitulatifs.first { $0.value.contient(avis) }?.key
            guard let prestataire, simules.retirer(avis, de: prestataire) != nil else {
                throw ErreurService.refus(.init(phrase: "Notation introuvable"))
            }
        }
    }

    /// Les fiches simulées, leur moyenne relue des avis qu'un geste a changés.
    func avecMoyennesSimulees(_ fiches: [Prestataire]) throws -> [Prestataire] {
        try avisSimules { simules in
            fiches.map { fiche in
                guard simules.touches.contains(fiche.id) else { return fiche }
                var lue = fiche
                let notes = (simules.recapitulatifs[fiche.id] ?? []).flatMap { $0.lignes.flatMap(\.avis) }
                    .compactMap { AvisSimules.notes[$0.etat] }
                lue.nbNotations = notes.count
                lue.noteMoyenne = notes.isEmpty ? nil : Double(notes.reduce(0, +)) / Double(notes.count)
                return lue
            }
        }
    }

    func recapitulatifSimule(_ prestataire: Int) throws -> [ExerciceAvis] {
        try avisSimules { try $0.recapitulatif(prestataire) }
    }

    /// Le magasin, lu des fixtures au premier usage : un geste peut venir avant toute lecture.
    private func avisSimules<R>(_ geste: (inout AvisSimules) throws -> R) throws -> R {
        try modifierSimule(
            depuis: {
                var simules = AvisSimules()
                for prestataire in FixturesNotations.prestataires { _ = try simules.recapitulatif(prestataire) }
                return simules
            }, geste)
    }
}

private extension EnvoiAvis {
    /// L'avis tel qu'il était, pour le remettre en place après un refus.
    init(_ avis: AvisPrestataire, prestataire: Int) {
        self.init(
            prestataireId: prestataire, contratId: avis.contratId, etat: avis.etat, commentaire: avis.commentaire,
            affaire: avis.ticketId, confirmerAjout: false)
    }
}

private extension [ExerciceAvis] {
    func contient(_ avis: Int) -> Bool { contains { $0.lignes.contains { $0.avis.contains { $0.id == avis } } } }
}

extension AvisSimules {
    mutating func recapitulatif(_ prestataire: Int) throws -> [ExerciceAvis] {
        if let lu = recapitulatifs[prestataire] { return lu }
        let lu = try FixturesNotations.lus(prestataire)
        recapitulatifs[prestataire] = lu
        return lu
    }

    mutating func affaires(_ prestataire: Int) throws -> [AffaireANoter] {
        if let lues = affaires[prestataire] { return lues }
        let lues = try FixturesNotations.affairesLues(prestataire)
        affaires[prestataire] = lues
        return lues
    }

    /// Range l'avis : dans l'exercice `annee` (l'exercice courant pour un nouvel avis), sur
    /// la ligne de son affaire — ajoutée, et le prestataire avec, si l'ajout est confirmé.
    mutating func poser(_ avis: AvisPrestataire, envoi: EnvoiAvis, annee: Int?) throws {
        let prestataire = envoi.prestataireId
        var exercices = try recapitulatif(prestataire)
        var affairesDuPrestataire = try affaires(prestataire)
        var avis = avis
        avis.ticketId = envoi.affaire
        let courante = annee ?? Calendar.current.component(.year, from: .now)
        var indice = exercices.firstIndex { $0.annee == courante }
        if indice == nil {
            exercices.insert(
                ExerciceAvis(
                    annee: courante, libelle: "\(courante)", nbInterventions: 0, nbNotees: 0, compte: [:], lignes: []),
                at: 0)
            indice = 0
        }
        guard let indice else { return }
        if let affaire = envoi.affaire {
            // Comme le serveur : une affaire inconnue est introuvable, jamais un avis général.
            guard let choisie = affairesDuPrestataire.firstIndex(where: { $0.id == affaire }) else {
                throw ErreurService.refus(.init(phrase: "Affaire introuvable"))
            }
            if !affairesDuPrestataire[choisie].intervient {
                guard envoi.confirmerAjout else { throw ErreurService.refus(.init(phrase: Self.refusAjout)) }
                affairesDuPrestataire[choisie].intervient = true
            }
            let cle = "t\(affaire)"
            if !exercices[indice].lignes.contains(where: { $0.id == cle }) {
                let ajoutee = affairesDuPrestataire[choisie]
                exercices[indice].lignes.insert(
                    LigneIntervention(id: cle, date: .now, numero: ajoutee.numero, titre: ajoutee.titre, avis: []),
                    at: 0)
            }
            exercices[indice].lignes[exercices[indice].lignes.firstIndex { $0.id == cle } ?? 0].avis.append(avis)
        } else {
            avis.ticketId = nil
            if let generaux = exercices[indice].lignes.firstIndex(where: { $0.id == "generaux" }) {
                exercices[indice].lignes[generaux].avis.append(avis)
            } else {
                exercices[indice].lignes.append(
                    LigneIntervention(id: "generaux", titre: TextesAvisPrestataire.sansAffaire, avis: [avis]))
            }
        }
        exercices[indice].recompter()
        (recapitulatifs[prestataire], affaires[prestataire]) = (exercices, affairesDuPrestataire)
        touches.insert(prestataire)
    }

    /// Retire l'avis ; rend ce qu'il était et l'année de son exercice.
    mutating func retirer(_ avis: Int, de prestataire: Int) -> (AvisPrestataire, Int)? {
        guard var exercices = recapitulatifs[prestataire] else { return nil }
        for exercice in exercices.indices {
            for ligne in exercices[exercice].lignes.indices {
                guard let rang = exercices[exercice].lignes[ligne].avis.firstIndex(where: { $0.id == avis }) else {
                    continue
                }
                let lu = exercices[exercice].lignes[ligne].avis.remove(at: rang)
                exercices[exercice].lignes.removeAll { $0.id == "generaux" && $0.avis.isEmpty }
                exercices[exercice].recompter()
                recapitulatifs[prestataire] = exercices
                touches.insert(prestataire)
                return (lu, exercices[exercice].annee)
            }
        }
        return nil
    }
}

private extension ExerciceAvis {
    /// Ce que le serveur compte : les interventions, les notées, chaque état.
    mutating func recompter() {
        let interventions = lignes.filter { $0.id != "generaux" }
        nbInterventions = interventions.count
        nbNotees = interventions.filter { !$0.avis.isEmpty }.count
        compte = Dictionary(lignes.flatMap(\.avis).map { ($0.etat, 1) }, uniquingKeysWith: +)
    }
}
#endif
