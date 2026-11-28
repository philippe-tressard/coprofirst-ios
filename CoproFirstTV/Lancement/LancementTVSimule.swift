// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import SwiftUI

#if DEBUG
/// L'écran de hall sans serveur, pour les captures et les essais au simulateur (#320) :
/// `-api-simulee -hall appairage|diffusion|vide|fil|fil-vide` — le code d'appairage qui attend
/// le conseil, trois affiches qui défilent, ou aucune ; le Fil en tuiles (#429, `FilSimule`), ou
/// un Fil vide. Le Fil se règle : `-fil-sans urgence,annonce…` (`FilSimule.Manque`), `-fil-plein`
/// (trois urgences, cinq épinglés),
/// `-mise-en-avant <tuile>` (une tuile tenue agrandie : `urgence.ticket_ouvert:41`, `epingles`…),
/// `-mouvement-reduit`, `-grand-texte`. `-a-propos` ouvre « À propos » à l'entrée et à
/// l'appairage (`BoutonAProposTV`), `-composant <nom>` y ouvre les textes d'un paquet ;
/// `-theme clair|sombre` impose le thème. Debug seul (#84) ; hors de ces arguments, l'app
/// parle aux vraies installations, et rien n'est gardé au Trousseau.
enum LancementTVSimule {
    /// Une résidence inventée, à la palette « prune » ; celle des tests aussi.
    static let residence = Installation(
        adresse: URL(string: "https://tilleuls.example.com")!, nom: "Les Tilleuls", aUnLogo: false,
        codePalette: "prune", versionContrat: VersionContrat.plancher.description)

    @MainActor
    static func hall(_ arguments: [String]) -> HallTV? {
        guard arguments.contains("-api-simulee") else { return nil }
        let serveur = ServeurEcranSimule(lecture: .success(etape(arguments) == "vide" ? [] : affiches))
        let memoire = MemoireEcran(coffre: CoffreEnMemoire())
        let entree = EntreeTV()
        switch etape(arguments) {
        case "appairage": entree.reprendre(residence)
        case "diffusion", "vide", "fil", "fil-vide": memoire.ranger(.init(residence: residence, jeton: "jeton-simule"))
        default: break
        }
        let service: any ServiceEcranTV
        switch etape(arguments) {
        case "fil":
            let plein = arguments.contains("-fil-plein")
            let lecture = Result { try FilSimule.fil(sans: manques(arguments), plein: plein) }
                .mapError { _ in ErreurService.inattendue(500) }
            service = ServeurFilSimule(ecran: serveur, lecture: lecture)
        case "fil-vide": service = ServeurFilSimule(ecran: serveur, lecture: .success(.vide))
        default: service = serveur
        }
        return HallTV(entree: entree, service: service, memoire: memoire)
    }

    static func reglages(_ arguments: [String]) -> ReglagesDuHall {
        ReglagesDuHall(
            tenue: valeur("-mise-en-avant", arguments), mouvementReduit: arguments.contains("-mouvement-reduit"),
            grandTexte: arguments.contains("-grand-texte"))
    }

    private static func manques(_ arguments: [String]) -> Set<FilSimule.Manque> {
        let noms = (valeur("-fil-sans", arguments) ?? "").split(separator: ",")
        return Set(noms.compactMap { FilSimule.Manque(rawValue: String($0)) })
    }

    static func theme(_ arguments: [String]) -> ColorScheme? {
        switch valeur("-theme", arguments) {
        case "clair": .light
        case "sombre": .dark
        default: nil
        }
    }

    static func aPropos(_ arguments: [String]) -> Bool {
        arguments.contains("-a-propos") || composant(arguments) != nil
    }

    static func composant(_ arguments: [String]) -> String? { valeur("-composant", arguments) }

    private static func etape(_ arguments: [String]) -> String? { valeur("-hall", arguments) }

    private static func valeur(_ cle: String, _ arguments: [String]) -> String? {
        arguments.firstIndex(of: cle).flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
    }

    /// Des affiches de hall telles qu'un conseil les écrit.
    static let affiches = [
        AfficheHall(
            id: 1, titre: "Coupure d'eau jeudi matin",
            message: """
                <p>Le remplacement d'une vanne au sous-sol coupe l'eau froide de <strong>9 h à 12 h</strong>, \
                dans les trois bâtiments.</p><p>Pensez à faire une réserve la veille.</p>
                """,
            images: 0, creeLe: .now),
        AfficheHall(
            id: 2, titre: "Assemblée générale le 15 janvier",
            message: """
                <p>L'assemblée générale se tient à 18 h 30, salle polyvalente. La convocation et \
                l'ordre du jour sont dans l'app, rubrique Documents.</p>
                """,
            images: 0, creeLe: .now),
        AfficheHall(
            id: 3, titre: "Encombrants : mardi 9 décembre",
            message: "<p>Déposez-les la veille au soir, devant le local à vélos.</p>",
            images: 0, creeLe: .now),
    ]
}

/// Un serveur d'écran simulé : les réponses d'interrogation se servent dans l'ordre, les
/// affiches et les images se règlent par test ou par `LancementTVSimule`. Aucun réseau.
actor ServeurEcranSimule: ServiceEcranTV {
    init(lecture: Result<[AfficheHall], ErreurService> = .success([])) { self.lecture = lecture }

    var demande: Result<DemandeAppairageTV, ErreurService> = .success(
        DemandeAppairageTV(codeAppareil: "secret", codeCourt: "BCDF-GHJK", expireDans: 600, intervalle: 5))
    var interrogations: [ReponseAppairage] = []
    private(set) var interrogees = 0
    var lecture: Result<[AfficheHall], ErreurService>
    private(set) var lectures = 0
    private(set) var jetonsPresentes: [JetonMasque] = []
    var imagesEnEchec: Set<Int> = []

    func regler(interrogations: [ReponseAppairage]) { self.interrogations = interrogations }
    func regler(demande: Result<DemandeAppairageTV, ErreurService>) { self.demande = demande }
    func regler(lecture: Result<[AfficheHall], ErreurService>) { self.lecture = lecture }
    func regler(imagesEnEchec: Set<Int>) { self.imagesEnEchec = imagesEnEchec }

    func demander(_ adresse: URL) async throws -> DemandeAppairageTV { try demande.get() }

    func interroger(_ codeAppareil: String, _ adresse: URL) async throws -> ReponseAppairage {
        interrogees += 1
        return interrogations.isEmpty ? .enAttente : interrogations.removeFirst()
    }

    func affiches(_ adresse: URL, jeton: JetonMasque) async throws -> [AfficheHall] {
        lectures += 1
        jetonsPresentes.append(jeton)
        return try lecture.get()
    }

    func image(_ affiche: Int, rang: Int, _ adresse: URL, jeton: JetonMasque) async throws -> Data {
        if imagesEnEchec.contains(rang) { throw ErreurService.injoignable }
        return Data([UInt8(affiche), UInt8(rang)])
    }
}
#endif
