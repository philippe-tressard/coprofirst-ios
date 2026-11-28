// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Ce que l'écran de hall lit du Fil de la résidence (#429), à la forme que le serveur servira
/// avec le jeton de l'écran : le Fil public du périmètre (coprofirst#3159) et la communauté à la
/// une (coprofirst#3160). Lu par tous au hall : ni auteur, ni contact, ni « me concerne ».
protocol ServiceFilDuHall: ServiceEcranTV {
    /// Le Fil public et la communauté à la une, en une lecture.
    func fil(_ adresse: URL, jeton: JetonMasque) async throws -> FilDuHall
    /// Une photo d'un élément servi, par son rang, avec le jeton.
    func photo(_ source: SourcePhoto, rang: Int, _ adresse: URL, jeton: JetonMasque) async throws -> Data
}

extension ServiceEcranTV {
    /// Le Fil, si ce service le sert. Aucune installation ne le sert encore (lot 2, derrière sa
    /// porte de version) : l'écran garde alors la diffusion des affiches.
    var filDuHall: (any ServiceFilDuHall)? { self as? any ServiceFilDuHall }
}

/// Le registre d'un élément, SERVI par le serveur à la règle du site (`front/src/lib/flux.ts`,
/// « les trois registres du fil ») : un élément urgent et épinglé n'est qu'urgent. L'écran le
/// lit, il ne le recompose jamais — ni des badges, ni de l'état.
enum RegistreDuFil: String, Hashable, Sendable {
    case urgent, epingle, fil
}

/// Un élément du Fil public.
struct ElementDuHall: Identifiable, Hashable, Sendable {
    /// `type:id`, comme le Fil de l'iPhone (`ElementDuFil.id`).
    let id: String
    /// La rubrique (`type`) : son libellé, sa teinte et son pictogramme (`NaturesDuFil`, généré).
    let type: String
    let registre: RegistreDuFil
    let titre: String
    /// Le détail servi, en HTML assaini ou en texte : `TexteDuSite.apercu` sur la tuile,
    /// `TexteRiche` dans la mise en avant.
    let detail: String?
    let date: Date
    /// Le délai servi (`meta.affaire.echeance.libelle` : « J-2 », « Jour J »), tel quel.
    let echeance: String?
    /// Le lieu servi ; `nil` pour le périmètre par défaut.
    let lieu: String?
    /// Le nombre de photos : chacune se lit par son rang, avec le jeton.
    let photos: Int
    /// Le chemin de l'élément sur le site, servi : son QR code.
    let lien: String

    var nature: NatureDuFil { NaturesDuFil.parType[type] ?? .inconnue }
}

/// Le sondage à la une : la question et le nombre de votants, jamais les votes d'une personne.
struct SondageALaUne: Hashable, Sendable {
    let id: Int
    let question: String
    let votants: Int
    let lien: String
}

/// L'idée à la une (la plus soutenue, choisie par le serveur).
struct IdeeALaUne: Hashable, Sendable {
    let id: Int
    let titre: String
    let soutiens: Int
    let lien: String
}

/// La petite annonce à la une, sans auteur ni contact.
struct AnnonceALaUne: Hashable, Sendable {
    let id: Int
    let titre: String
    /// En centimes ; `nil` pour un don ou une recherche.
    let prixCentimes: Int?
    let negociable: Bool
    let photos: Int
    let lien: String
}

/// La communauté à la une : chaque tuile est absente quand le serveur n'a rien à y mettre.
struct CommunauteDuHall: Hashable, Sendable {
    var sondage: SondageALaUne?
    var idee: IdeeALaUne?
    var annonce: AnnonceALaUne?

    static let vide = CommunauteDuHall()
}

/// D'où vient une photo : un élément du Fil, ou la petite annonce à la une.
enum SourcePhoto: Hashable, Sendable {
    case element(String)
    case annonce(Int)
}

/// Une lecture : les éléments dans l'ordre servi, et la communauté.
struct FilDuHall: Hashable, Sendable {
    var elements: [ElementDuHall] = []
    var communaute: CommunauteDuHall = .vide

    static let vide = FilDuHall()

    /// Les éléments d'un registre, dans l'ordre servi.
    func du(_ registre: RegistreDuFil) -> [ElementDuHall] { elements.filter { $0.registre == registre } }

    var estVide: Bool {
        elements.isEmpty && communaute.sondage == nil && communaute.idee == nil && communaute.annonce == nil
    }
}
