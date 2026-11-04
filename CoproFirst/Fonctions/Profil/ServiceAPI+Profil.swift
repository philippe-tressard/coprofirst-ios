// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Le profil par le client GÉNÉRÉ.
extension ServiceAPI: ServiceProfil {
    func compte(_ installation: Installation) async throws -> Compte {
        let sortie = try await appeler { try await client(installation.adresse).meAuthMeGet() }
        switch sortie {
        case .ok(let ok): return Compte(lu: try ok.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func modifierIdentite(_ saisie: SaisieIdentite, ancienne: String, dans installation: Installation)
        async throws -> Bool {
        let nouvelle = saisie.changeAdresse(ancienne)
        let corps = Components.Schemas.MeUpdate(
            email: nouvelle ? saisie.email.trimmingCharacters(in: .whitespaces) : nil,
            fonction: saisie.fonction.nulSiVide, motDePasseActuel: nouvelle ? saisie.motDePasseActuel : nil,
            nom: saisie.nom.trimmingCharacters(in: .whitespaces),
            prenom: saisie.prenom.trimmingCharacters(in: .whitespaces),
            societe: saisie.societe.nulSiVide, telephone: saisie.telephone.nulSiVide)
        try await modifier(corps, installation)
        return nouvelle
    }

    func changerMotDePasse(actuel: String, nouveau: String, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).changePasswordAuthChangePasswordPost(
                body: .json(.init(motDePasseActuel: actuel, nouveauMotDePasse: nouveau)))
        }
        switch sortie {
        case .noContent: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        // Le mot de passe actuel refusé, ou un nouveau trop faible : la phrase du serveur.
        case .undocumented(400, let charge):
            var octets: [UInt8] = []
            if let corps = charge.body {
                for try await morceau in corps where octets.count < 4_096 { octets += morceau }
            }
            throw RefusDuServeur(json: Data(octets)) ?? ErreurService.inattendue(400)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func enregistrerPreferences(_ json: String, restreindre: Bool, dans installation: Installation) async throws {
        try await modifier(
            .init(preferencesNotifications: json, restreindreAMesBatiments: restreindre), installation)
    }

    func refuserTelemetrie(_ refus: Bool, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).toggleOptOutTelemetrieAuthMeOptOutTelemetriePatch(
                body: .json(.init(optOutTelemetrie: refus)))
        }
        switch sortie {
        case .noContent: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    /// Le JSON servi, écrit tel quel dans un fichier à partager (`mes-donnees-telemetrie.json`).
    func exporterTelemetrie(_ installation: Installation) async throws -> URL {
        let sortie = try await appeler { try await client(installation.adresse).exportTelemetrieAuthMeTelemetrieGet() }
        switch sortie {
        case .ok(let ok):
            let encodeur = JSONEncoder()
            encodeur.outputFormatting = [.prettyPrinted, .sortedKeys]
            let fichier = FileManager.default.temporaryDirectory.appending(path: "mes-donnees-telemetrie.json")
            try encodeur.encode(try ok.body.json).write(to: fichier, options: [.atomic, .completeFileProtection])
            return fichier
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func effacerTelemetrie(_ installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).effacerTelemetrieAuthMeTelemetrieDelete()
        }
        switch sortie {
        case .noContent: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func demandesModification(_ installation: Installation) async throws -> [DemandeModification] {
        let sortie = try await appeler {
            try await client(installation.adresse).mesDemandesModifAuthMeDemandesModificationGet()
        }
        switch sortie {
        case .ok(let ok):
            return try ok.body.json.map {
                DemandeModification(
                    id: $0.id, etat: $0.statutDemande.rawValue, statutSouhaite: $0.statutSouhaite,
                    batimentSouhaite: $0.batimentNomSouhaite, motifRefus: $0.motifRefus, creeLe: $0.creeLe)
            }
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func demanderModification(statut: String?, batiment: Int?, motif: String, dans installation: Installation)
        async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).creerDemandeModifAuthMeDemandeModificationPost(
                body: .json(.init(batimentIdSouhaite: batiment, motif: motif.nulSiVide, statutSouhaite: statut)))
        }
        switch sortie {
        case .created: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    /// La réponse n'est pas typée dans le contrat : relue en miroir.
    func batiments(_ installation: Installation) async throws -> [BatimentResidence] {
        let sortie = try await appeler { try await client(installation.adresse).listBatimentsAuthBatimentsGet() }
        switch sortie {
        case .ok(let ok): return try Relecture.lire([BatimentResidence].self, depuis: try ok.body.json)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    private func modifier(_ corps: Components.Schemas.MeUpdate, _ installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).updateMeAuthMePatch(body: .json(corps))
        }
        switch sortie {
        case .ok: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }
}

extension Compte {
    init(lu moi: Components.Schemas.UserRead) {
        self.init(
            prenom: moi.prenom, nom: moi.nom, email: moi.email, telephone: moi.telephone, societe: moi.societe,
            fonction: moi.fonction, photo: moi.photoUrl, statut: moi.statut.rawValue,
            roles: (moi.roles ?? [moi.role.rawValue]), batimentNom: moi.batimentNom, actif: moi.actif,
            creeLe: moi.creeLe, derniereConnexion: moi.derniereConnexion, preferences: moi.preferencesNotifications,
            restreindreAMesBatiments: moi.restreindreAMesBatiments ?? false,
            refusTelemetrie: moi.optOutTelemetrie ?? false)
    }
}

/// Un refus que le serveur explique (`{"detail": "…"}`) : sa phrase, telle quelle.
struct RefusDuServeur: Error, Equatable {
    let phrase: String

    init?(json: Data) {
        struct Detail: Decodable { let detail: String }
        guard let detail = try? JSONDecoder().decode(Detail.self, from: json), !detail.detail.isEmpty else {
            return nil
        }
        phrase = detail.detail
    }

    init(phrase: String) { self.phrase = phrase }
}
