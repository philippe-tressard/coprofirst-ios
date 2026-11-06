// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// L'annuaire de la résidence (GET /admin/annuaire) : le conseil syndical et le
/// syndic — typé par le contrat 1.5.0 (`AnnuaireLu`) et branché par `Annuaire(_:)`.
struct Annuaire: Codable, Hashable, Sendable {
    var cs: ConseilSyndical
    var syndic: Syndic
    var whatsappUrl: String?

    struct ConseilSyndical: Codable, Hashable, Sendable {
        var agAnnee: Int?
        var agDate: String?
        var membres: [Membre]
    }

    struct Syndic: Codable, Hashable, Sendable {
        var nomSyndic: String?
        var adresse: String?
        var siteWeb: String?
        var membres: [Membre]
    }

    /// Une personne de l'annuaire : membre du conseil ou contact du syndic.
    struct Membre: Codable, Hashable, Sendable, Identifiable {
        let id: Int
        var genre: String?
        var prenom: String?
        var nom: String?
        var batimentNom: String?
        var estGestionnaireSite: Bool?
        var estPresident: Bool?
        var photoUrl: String?
        var fonction: String?
        var email: String?
        var telephone: String?
        var estPrincipal: Bool?

        /// La civilité, le prénom et le nom, tels que servis. La convention du site
        /// (« Prénom NOM », `nomAffiche`) vit dans son front : l'app attend que l'API
        /// serve le nom affiché (coprofirst#2505).
        var nomComplet: String {
            [genre, prenom, nom].compactMap { $0?.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }.joined(separator: " ")
        }

        var initiales: String {
            [prenom, nom].compactMap { $0?.first }.map(String.init).joined().uppercased()
        }

        /// Les numéros d'un contact : le champ en porte parfois plusieurs, séparés par
        /// des virgules ; un doublon ne s'affiche qu'une fois.
        var telephones: [String] {
            var vus: [String] = []
            for numero in (telephone ?? "").split(separator: ",") {
                let propre = numero.trimmingCharacters(in: .whitespaces)
                if !propre.isEmpty, !vus.contains(propre) { vus.append(propre) }
            }
            return vus
        }
    }

    /// Les membres du conseil par bâtiment, dans l'ordre où le serveur les sert — un
    /// seul groupe quand la résidence n'a qu'un bâtiment (le site ne groupe pas alors).
    var groupesCS: [(batiment: String?, membres: [Membre])] {
        var ordre: [String?] = []
        var parBatiment: [String?: [Membre]] = [:]
        for membre in cs.membres {
            if parBatiment[membre.batimentNom] == nil { ordre.append(membre.batimentNom) }
            parBatiment[membre.batimentNom, default: []].append(membre)
        }
        // « Sans bâtiment » en dernier, comme sur le site.
        return (ordre.filter { $0 != nil } + ordre.filter { $0 == nil }).map { ($0, parBatiment[$0] ?? []) }
    }
}

/// Ce que l'Annuaire demande à une installation — le service du menu, dans son
/// dossier (motif des sessions parallèles de #10).
protocol ServiceAnnuaire: Sendable {
    func annuaire(_ installation: Installation) async throws -> Annuaire
}

extension ServiceCoproFirst {
    var annuaire: (any ServiceAnnuaire)? { self as? any ServiceAnnuaire }
}

extension ServiceAPI: ServiceAnnuaire {
    func annuaire(_ installation: Installation) async throws -> Annuaire {
        let sortie = try await appeler { try await client(installation.adresse).getAdminAnnuaire() }
        switch sortie {
        // Typée par le contrat 1.5.0 (`AnnuaireLu`) : lue par son type généré.
        case .ok(let ok): return Annuaire(try ok.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }
}

extension ServiceSimule: ServiceAnnuaire {
    func annuaire(_ installation: Installation) async throws -> Annuaire {
        try await Task.sleep(for: .milliseconds(400))
        return Self.annuaire
    }

    /// Un annuaire inventé : des prénoms et des noms qui n'appartiennent à personne.
    static let annuaire = Annuaire(
        cs: .init(
            agAnnee: 2026, agDate: "2026-06-12",
            membres: [
                .init(
                    id: 1, genre: "Mme", prenom: "Alix", nom: "Exemple", batimentNom: "A", estGestionnaireSite: true,
                    estPresident: true),
                .init(id: 2, genre: "M.", prenom: "Basile", nom: "Fictif", batimentNom: "A"),
                .init(id: 3, genre: "Mme", prenom: "Céleste", nom: "Inventé", batimentNom: "B"),
                .init(id: 4, genre: "M.", prenom: "Désiré", nom: "Modèle", batimentNom: nil),
            ]),
        syndic: .init(
            nomSyndic: "Cabinet Exemple Gestion", adresse: "1 place de l'Exemple, 00000 Ville-Exemple",
            siteWeb: "https://syndic.exemple.fr",
            membres: [
                .init(
                    id: 10, genre: "Mme", prenom: "Elsa", nom: "Gestion", fonction: "Gestionnaire de copropriété",
                    email: "gestion@syndic.exemple.fr", telephone: "01 00 00 00 01, 06 00 00 00 02",
                    estPrincipal: true),
                .init(
                    id: 11, genre: "M.", prenom: "Firmin", nom: "Compta", fonction: "Comptabilité",
                    email: "compta@syndic.exemple.fr", telephone: "01 00 00 00 03"),
            ]),
        whatsappUrl: "https://chat.whatsapp.com/exemple")
}

extension Annuaire.Membre {
    init(
        id: Int, genre: String?, prenom: String?, nom: String?, batimentNom: String? = nil,
        estGestionnaireSite: Bool = false, estPresident: Bool = false, fonction: String? = nil,
        email: String? = nil, telephone: String? = nil, estPrincipal: Bool = false
    ) {
        self.init(
            id: id, genre: genre, prenom: prenom, nom: nom, batimentNom: batimentNom,
            estGestionnaireSite: estGestionnaireSite, estPresident: estPresident, photoUrl: nil, fonction: fonction,
            email: email, telephone: telephone, estPrincipal: estPrincipal)
    }
}

extension Annuaire {
    /// L'annuaire tel que le contrat le type (`AnnuaireLu`).
    init(_ lu: Components.Schemas.AnnuaireLu) {
        self.init(
            cs: ConseilSyndical(
                agAnnee: lu.cs.agAnnee, agDate: lu.cs.agDate,
                membres: lu.cs.membres.map {
                    Membre(
                        id: $0.id, genre: $0.genre, prenom: $0.prenom, nom: $0.nom, batimentNom: $0.batimentNom,
                        estGestionnaireSite: $0.estGestionnaireSite, estPresident: $0.estPresident,
                        photoUrl: $0.photoUrl)
                }),
            syndic: Syndic(
                nomSyndic: lu.syndic.nomSyndic, adresse: lu.syndic.adresse, siteWeb: lu.syndic.siteWeb,
                membres: lu.syndic.membres.map {
                    Membre(
                        id: $0.id, genre: $0.genre, prenom: $0.prenom, nom: $0.nom, photoUrl: $0.photoUrl,
                        fonction: $0.fonction, email: $0.email, telephone: $0.telephone, estPrincipal: $0.estPrincipal)
                }),
            whatsappUrl: lu.whatsappUrl)
    }
}
