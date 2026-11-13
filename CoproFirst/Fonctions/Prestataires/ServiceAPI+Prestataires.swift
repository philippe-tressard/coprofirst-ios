// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// « Prestataires » par le client GÉNÉRÉ : toutes ces réponses sont typées.
extension ServiceAPI: ServicePrestataires {
    func prestataires(_ installation: Installation, archives: Bool) async throws -> [Prestataire] {
        let client = client(installation.adresse)
        if archives {
            let sortie = try await appeler { try await client.getPrestatairesArchives() }
            switch sortie {
            case .ok(let ok): return try ok.body.json.map(Prestataire.init)
            case .unprocessableContent: throw ErreurService.inattendue(422)
            case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
            }
        }
        let sortie = try await appeler { try await client.getPrestataires() }
        switch sortie {
        case .ok(let ok): return try ok.body.json.map(Prestataire.init)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func contrats(_ installation: Installation, archives: Bool) async throws -> [Contrat] {
        // Le corps est gardé : la résiliation et le remplacement se servent au-dessus du
        // plancher (contrat 1.29.0, #185), et le type généré les jetterait.
        let client = client(installation.adresse)
        if archives {
            let (sortie, corps) = try await appeler {
                try await CorpsServi.garder { try await client.getPrestatairesContratsArchives() }
            }
            switch sortie {
            case .ok(let ok): return Contrat.lus(try ok.body.json, corps: corps)
            case .unprocessableContent: throw ErreurService.inattendue(422)
            case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
            }
        }
        let (sortie, corps) = try await appeler {
            try await CorpsServi.garder { try await client.getPrestatairesContrats() }
        }
        switch sortie {
        case .ok(let ok): return Contrat.lus(try ok.body.json, corps: corps)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func avis(_ installation: Installation) async throws -> [AvisPrestataire] {
        switch try await appeler({ try await client(installation.adresse).getPrestatairesNotations() }) {
        case .ok(let ok): return try ok.body.json.map(AvisPrestataire.init)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func equipements(_ installation: Installation) async throws -> [Equipement] {
        switch try await appeler({ try await client(installation.adresse).getEquipements() }) {
        case .ok(let ok):
            return try ok.body.json.map { Equipement(code: $0.code, libelle: $0.libelle, ordre: $0.ordre) }
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func documents(contrat: Int, dans installation: Installation) async throws -> [DocumentContrat] {
        let sortie = try await appeler {
            try await client(installation.adresse).getDocuments(query: .init(contratId: contrat))
        }
        switch sortie {
        case .ok(let ok):
            return try ok.body.json.map { DocumentContrat(id: $0.id, titre: $0.titre, fichierNom: $0.fichierNom) }
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func compteurs(_ installation: Installation) async throws -> [Compteur] {
        let sortie = try await appeler {
            try await client(installation.adresse).getPrestatairesCompteursConfig()
        }
        switch sortie {
        case .ok(let ok):
            return try ok.body.json.map {
                Compteur(
                    id: $0.id, typeCompteur: $0.typeCompteur, libelle: $0.label, ordre: $0.ordre,
                    prestataireId: $0.prestataireId)
            }
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func releves(_ typeCompteur: String, dans installation: Installation) async throws -> [Releve] {
        let sortie = try await appeler {
            try await client(installation.adresse).getPrestatairesReleves(
                query: .init(typeCompteur: typeCompteur))
        }
        switch sortie {
        case .ok(let ok):
            return try ok.body.json.map {
                Releve(id: $0.id, dateReleve: $0.dateReleve, index: $0.index, note: $0.note, photoUrl: $0.photoUrl)
            }
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }
}

extension Prestataire {
    init(_ lu: Components.Schemas.PrestataireRead) {
        self.init(
            id: lu.id, nom: lu.nom, specialite: lu.specialite, type: lu.typePrestataire?.rawValue,
            telephone: lu.telephone, email: lu.email, adresse: lu.adresse, description: lu.description,
            contacts: (lu.contacts ?? []).map {
                ContactPrestataire(
                    prenom: $0.prenom, nom: $0.nom, fonction: $0.fonction, telephone: $0.telephone, email: $0.email,
                    nomServi: $0.nomAffiche)
            }, telephones: lu.telephones)
    }
}

extension Contrat {
    init(_ lu: Components.Schemas.ContratRead) {
        self.init(
            id: lu.id, prestataireId: lu.prestataireId, libelle: lu.libelle, typeEquipement: lu.typeEquipement,
            numeroContrat: lu.numeroContrat, dateDebut: lu.dateDebut, dureeValeur: lu.dureeInitialeValeur,
            dureeUnite: lu.dureeInitialeUnite, frequenceType: lu.frequenceType, frequenceValeur: lu.frequenceValeur,
            frequenceLibelle: lu.frequenceLibelle, prochaineVisite: lu.prochaineVisite, notes: lu.notes)
    }
}

extension AvisPrestataire {
    init(_ lu: Components.Schemas.NotationRead) {
        self.init(
            id: lu.id, prestataireId: lu.prestataireId, note: lu.note, commentaire: lu.commentaire,
            auteurNom: lu.auteurNom, creeLe: lu.creeLe)
    }
}
