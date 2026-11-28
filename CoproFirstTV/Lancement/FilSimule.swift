// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

#if DEBUG
/// Le Fil public que le serveur simulé sert à l'écran de hall (#429), en attendant
/// coprofirst#3159 et #3160 : les jeux de démo de l'iPhone — le Fil (`Apercu.fil`), les idées
/// et annonces (`FixturesCommunaute`), les sondages (`FixturesSondage`) —, passés par ce que
/// le SERVEUR décidera : quels éléments un hall peut montrer, leur registre, ce qui est à la une.
/// Ces décisions sont écrites ici comme ses réponses, jamais recalculées par l'écran.
enum FilSimule {
    /// Ce que le serveur servirait au hall de la démo, dans l'ordre du Fil, et le registre de
    /// chacun. « Ramonage » (`ticket_mis_a_jour:44`), lu par les seuls copropriétaires, n'est pas
    /// servi : le hall est lu par tous.
    static let servis: [String: RegistreDuFil] = [
        "ticket_ouvert:41": .urgent,
        "publication:12": .epingle,
        "point_conseil:2": .epingle,
        "sondage_ouvert:3": .fil,
        "document:7": .fil,
        "ticket_mis_a_jour:38": .fil,
        "ticket_mis_a_jour:45": .fil,
        "ticket_resolu:31": .fil,
    ]

    /// Ce que le serveur met à la une de la communauté : un sondage ouvert, l'idée la plus
    /// soutenue, une annonce en cours.
    static let sondageALaUne = 12
    static let ideeALaUne = 3
    static let annonceALaUne = 21

    /// Ce qui manque à une démo réglée (`-fil-sans urgence,annonce…`) : une rangée sans urgence,
    /// une tuile de la communauté absente.
    enum Manque: String, CaseIterable { case urgence, epingles, sondage, idee, annonce }

    static func fil(sans manques: Set<Manque> = []) throws -> FilDuHall {
        var elements = Apercu.fil.compactMap(servi)
        if manques.contains(.urgence) { elements.removeAll { $0.registre == .urgent } }
        if manques.contains(.epingles) { elements.removeAll { $0.registre == .epingle } }
        let communaute = try CommunauteDuHall(
            sondage: manques.contains(.sondage) ? nil : sondage(),
            idee: manques.contains(.idee) ? nil : idee(),
            annonce: manques.contains(.annonce) ? nil : annonce())
        return FilDuHall(elements: elements, communaute: communaute)
    }

    /// Un élément du Fil tel que la route publique le servirait : sans « me concerne », sans
    /// lecture, son registre et son lien.
    private static func servi(_ element: ElementDuFil) -> ElementDuHall? {
        guard let registre = servis[element.id] else { return nil }
        return ElementDuHall(
            id: element.id, type: element.type, registre: registre, titre: element.titre, detail: element.detail,
            date: element.date, echeance: element.echeance?.libelle, lieu: element.lieu,
            photos: element.pieces.photos.count, lien: lien(element.cible))
    }

    /// Le chemin du site de l'élément, tel que le serveur le servirait — depuis les routes
    /// GÉNÉRÉES des pages (`PagesParDefaut`).
    private static func lien(_ cible: CibleDuFil) -> String {
        switch cible {
        case .affaire(let id): "\(route("mes-demandes"))/\(id)"
        case .sondage(let id): "\(route("communaute"))/\(id)"
        case .document: route("residence")
        case .resume(let lien): lien ?? route("tableau-de-bord")
        }
    }

    private static func route(_ page: String) -> String {
        PagesParDefaut.toutes.first { $0.id == page }?.route ?? "/"
    }

    /// Le serveur simulé compte un votant par vote d'option.
    private static func sondage() throws -> SondageALaUne? {
        let fiches = try Relecture.generee([Components.Schemas.SondageDetail].self, json: FixturesSondage.fiches)
        return fiches.first { $0.id == sondageALaUne }.map { fiche in
            SondageALaUne(
                id: fiche.id, question: fiche.question,
                votants: (fiche.options ?? []).reduce(0) { $0 + ($1.nbVotes ?? 0) },
                lien: "\(route("communaute"))/\(fiche.id)")
        }
    }

    private static func idee() throws -> IdeeALaUne? {
        let idees = try Relecture.generee([Components.Schemas.IdeeRead].self, json: FixturesCommunaute.idees)
        return idees.first { $0.id == ideeALaUne }.map {
            IdeeALaUne(id: $0.id, titre: $0.titre, soutiens: $0.nbVotes ?? 0, lien: "\(route("communaute"))#idees")
        }
    }

    /// Ni auteur, ni courriel, ni contact : la route publique ne les sert pas.
    private static func annonce() throws -> AnnonceALaUne? {
        let annonces = try Relecture.generee([Components.Schemas.AnnonceRead].self, json: FixturesCommunaute.annonces)
        return annonces.first { $0.id == annonceALaUne }.map {
            AnnonceALaUne(
                id: $0.id, titre: $0.titre, prixCentimes: $0.prixCentimes, negociable: $0.negotiable ?? false,
                photos: $0.photos?.count ?? 0, lien: "\(route("communaute"))#annonces")
        }
    }
}

/// Le serveur de l'écran simulé, qui sert AUSSI le Fil : les affiches, l'appairage et le
/// jeton restent ceux de `ServeurEcranSimule`. Aucun réseau ; les photos sont dessinées.
actor ServeurFilSimule: ServiceFilDuHall {
    let ecran: ServeurEcranSimule
    private var lecture: Result<FilDuHall, ErreurService>
    private(set) var lectures = 0
    private(set) var jetonsPresentes: [JetonMasque] = []
    private(set) var photosLues: [SourcePhoto] = []

    init(ecran: ServeurEcranSimule = ServeurEcranSimule(), lecture: Result<FilDuHall, ErreurService>) {
        self.ecran = ecran
        self.lecture = lecture
    }

    func regler(lecture: Result<FilDuHall, ErreurService>) { self.lecture = lecture }

    func fil(_ adresse: URL, jeton: JetonMasque) async throws -> FilDuHall {
        lectures += 1
        jetonsPresentes.append(jeton)
        return try lecture.get()
    }

    func photo(_ source: SourcePhoto, rang: Int, _ adresse: URL, jeton: JetonMasque) async throws -> Data {
        photosLues.append(source)
        return PhotoDessinee.jpeg("\(source)-\(rang)")
    }

    func demander(_ adresse: URL) async throws -> DemandeAppairageTV { try await ecran.demander(adresse) }

    func interroger(_ codeAppareil: String, _ adresse: URL) async throws -> ReponseAppairage {
        try await ecran.interroger(codeAppareil, adresse)
    }

    func affiches(_ adresse: URL, jeton: JetonMasque) async throws -> [AfficheHall] {
        try await ecran.affiches(adresse, jeton: jeton)
    }

    func image(_ affiche: Int, rang: Int, _ adresse: URL, jeton: JetonMasque) async throws -> Data {
        try await ecran.image(affiche, rang: rang, adresse, jeton: jeton)
    }
}
#endif
