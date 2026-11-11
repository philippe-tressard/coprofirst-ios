// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// Vérifié à la compilation : `parcours.serviceNotifications`, `serviceFAQ` et
/// `serviceProfil` (des transtypages) ne peuvent pas échouer.
@Test func lesDeuxServicesServentNotificationsFAQEtProfil() {
    let notifications: [any ServiceNotifications] = [ServiceAPI(), ServiceSimule(delai: .zero)]
    let faq: [any ServiceFAQ] = [ServiceAPI(), ServiceSimule(delai: .zero)]
    let profil: [any ServiceProfil] = [ServiceAPI(), ServiceSimule(delai: .zero)]
    #expect(notifications.count + faq.count + profil.count == 6)
}

/// Un serveur qui refuse tout geste.
private struct Refus: ServiceNotifications {
    let liste: [NotificationRecue]
    func notifications(_ installation: Installation) async throws -> [NotificationRecue] { liste }
    func marquerLue(_ id: Int, dans installation: Installation) async throws { throw ErreurService.inattendue(500) }
    func toutMarquerLu(_ installation: Installation) async throws { throw ErreurService.inattendue(500) }
    func supprimerNotification(_ id: Int, dans installation: Installation) async throws {
        throw ErreurService.inattendue(500)
    }
    func supprimerNotifications(_ ids: Set<Int>, dans installation: Installation) async throws {
        throw ErreurService.inattendue(500)
    }
    func supprimerLues(_ installation: Installation) async throws { throw ErreurService.inattendue(500) }
}

private func alerte(_ id: Int, ilYA heures: Double, lue: Bool = false, maintenant: Date = .now) -> NotificationRecue {
    NotificationRecue(
        id: id, type: "t", titre: "Alerte \(id)", corps: "", lue: lue, urgente: false,
        creeLe: maintenant.addingTimeInterval(-heures * 3600))
}

@MainActor
@Test func aujourdhuiCeSontLesVingtQuatreDernieresHeures() async {
    let maintenant = Date(timeIntervalSince1970: 1_800_000_000)
    let etat = EtatNotifications()
    let service = Refus(liste: [
        alerte(1, ilYA: 1, maintenant: maintenant), alerte(2, ilYA: 23.9, maintenant: maintenant),
        alerte(3, ilYA: 24.1, maintenant: maintenant),
    ])
    await etat.charger(ServiceSimule.residence, avec: service)
    let sections = etat.sections(maintenant: maintenant)
    #expect(sections.aujourdhui.map(\.id) == [1, 2], "fenêtre glissante, comme le site")
    #expect(sections.anciennes.map(\.id) == [3])
}

@MainActor
@Test func unGesteRefuseRendLaListeEtLeCompteDeLaCloche() async {
    let residence = ServiceSimule.residence
    let etat = EtatNotifications()
    await etat.charger(residence, avec: Refus(liste: [alerte(1, ilYA: 1), alerte(2, ilYA: 2, lue: true)]))
    #expect(etat.nonLues == 1)
    #expect(CompteurNonLues.partage.nombre(residence) == 1, "la cloche lit le même compte")

    await etat.toutMarquerLu(residence, avec: Refus(liste: []))
    #expect(etat.nonLues == 1, "le serveur a refusé : rien n'est marqué lu")
    #expect(etat.echec != nil, "et une phrase le dit")
    await etat.supprimer(etat.liste[0], dans: residence, avec: Refus(liste: []))
    #expect(etat.liste.count == 2, "la notification revient")
}

@MainActor
@Test func marquerLuDansLApiSimuleeVideLaCloche() async {
    let residence = ServiceSimule.residence
    let service = ServiceSimule(delai: .zero)
    let etat = EtatNotifications()
    await etat.charger(residence, avec: service)
    #expect(etat.liste.count == 150, "le volume d'un compte réel")
    #expect(etat.nonLues == 12)
    await etat.toutMarquerLu(residence, avec: service)
    #expect(etat.nonLues == 0)
    #expect(CompteurNonLues.partage.nombre(residence) == 0)
    #expect(TextesNotifications.nonLues(1) == "1 non lue" && TextesNotifications.nonLues(3) == "3 non lues")
}

@Test func laFAQSeRegroupeDansLOrdreDuServeur() {
    let questions = [
        QuestionFAQ(id: 1, categorie: "Vie", question: "a", reponse: ""),
        QuestionFAQ(id: 2, categorie: "", question: "b", reponse: ""),
        QuestionFAQ(id: 3, categorie: "Vie", question: "c", reponse: ""),
        QuestionFAQ(id: 4, categorie: "Accès", question: "d", reponse: ""),
    ]
    let categories = CategorieFAQ.regrouper(questions)
    #expect(categories.map(\.nom) == ["Vie", "Général", "Accès"], "l'ordre d'arrivée, sans retri")
    #expect(categories[0].questions.map(\.id) == [1, 3])
}

@Test func lesPreferencesJamaisRegleesPrennentLeurDefaut() throws {
    let lecture = LecturePreferences(#"{"mon_batiment_mail": false, "cle_inconnue": 3}"#)
    #expect(lecture.valeurs["mon_batiment_mail"] == false, "la valeur réglée gagne")
    #expect(lecture.valeurs["autres_batiments_app"] == true, "le défaut de la cloche")
    #expect(lecture.heritees == ["autres_batiments_mail", "mon_batiment_app", "autres_batiments_app"])
    let relu = try #require(
        try JSONSerialization.jsonObject(with: Data(lecture.json.utf8)) as? [String: Bool])
    #expect(relu.count == 4, "les quatre clés partent, rien d'autre")
    #expect(LecturePreferences("pas du json").heritees.count == 4)
}

@Test func changerDAdresseDemandeLeMotDePasse() {
    var saisie = SaisieIdentite(prenom: "A", nom: "B", email: " Moi@Exemple.fr ")
    #expect(!saisie.changeAdresse("moi@exemple.fr"), "sans casse ni espaces : la même adresse")
    #expect(saisie.complete("moi@exemple.fr"))
    saisie.email = "autre@exemple.fr"
    #expect(!saisie.complete("moi@exemple.fr"), "une nouvelle adresse sans mot de passe")
    saisie.motDePasseActuel = "secret"
    #expect(saisie.complete("moi@exemple.fr"))
}

@Test func leThemeSuitLeChoixEtRetombeSurAutomatique() {
    #expect(ThemeChoisi.schema("clair") == .light)
    #expect(ThemeChoisi.schema("sombre") == .dark)
    #expect(ThemeChoisi.schema("auto") == nil)
    #expect(ThemeChoisi.schema("inconnu") == nil, "une valeur inconnue = Automatique")
}

/// Un serveur qui note chaque requête de suppression (#53).
private final class SuppressionsNotees: ServiceNotifications, @unchecked Sendable {
    let liste: [NotificationRecue]
    private(set) var requetes: [String] = []
    private let verrou = NSLock()

    init(liste: [NotificationRecue]) { self.liste = liste }

    private func noter(_ requete: String) { verrou.withLock { requetes.append(requete) } }

    func notifications(_ installation: Installation) async throws -> [NotificationRecue] { liste }
    func marquerLue(_ id: Int, dans installation: Installation) async throws {}
    func toutMarquerLu(_ installation: Installation) async throws {}
    func supprimerNotification(_ id: Int, dans installation: Installation) async throws { noter("DELETE \(id)") }
    func supprimerNotifications(_ ids: Set<Int>, dans installation: Installation) async throws {
        noter("selection \(ids.sorted())")
    }
    func supprimerLues(_ installation: Installation) async throws { noter("lues") }
}

@MainActor
@Test func uneSelectionPartEnUneSeuleRequete() async {
    let residence = ServiceSimule.residence
    let liste = (1...10).map { alerte($0, ilYA: Double($0), lue: $0 > 3) }
    let service = SuppressionsNotees(liste: liste)
    let etat = EtatNotifications()
    await etat.charger(residence, avec: service)

    #expect(await etat.supprimer([1, 2, 7, 9], dans: residence, avec: service))
    #expect(service.requetes == ["selection [1, 2, 7, 9]"], "une requête, jamais une par notification")
    #expect(etat.liste.map(\.id) == [3, 4, 5, 6, 8, 10])
    #expect(etat.nonLues == 1)
    #expect(CompteurNonLues.partage.nombre(residence) == 1, "la cloche suit")
}

/// « Supprimer les lues », le geste direct du site (#53) : sa route, UNE requête, et il
/// ne reste que les non lues. Sans notification lue, rien ne part.
@MainActor
@Test func supprimerLesLuesPartParSaRouteEnUneRequete() async {
    let residence = ServiceSimule.residence
    let liste = (1...6).map { alerte($0, ilYA: Double($0), lue: $0 > 2) }
    let service = SuppressionsNotees(liste: liste)
    let etat = EtatNotifications()
    await etat.charger(residence, avec: service)
    #expect(etat.lues == 4)

    #expect(await etat.supprimerLues(residence, avec: service))
    #expect(service.requetes == ["lues"], "la route des lues, une fois — ni sélection, ni un DELETE par alerte")
    #expect(etat.liste.map(\.id) == [1, 2], "il ne reste que les non lues")
    #expect(etat.lues == 0 && etat.nonLues == 2)
    #expect(CompteurNonLues.partage.nombre(residence) == 2, "la cloche ne bouge pas")

    #expect(!(await etat.supprimerLues(residence, avec: service)), "plus aucune lue : rien à faire")
    #expect(service.requetes == ["lues"], "et aucune requête de plus")
}

/// Une seule porte vers la route des lues : une sélection, même quand ce sont toutes les
/// lues de la liste, part comme une sélection — celles choisies, et elles seules.
@MainActor
@Test func uneSelectionEgaleAuxLuesResteUneSelection() async {
    let residence = ServiceSimule.residence
    let liste = (1...6).map { alerte($0, ilYA: Double($0), lue: $0 > 2) }
    let service = SuppressionsNotees(liste: liste)
    let etat = EtatNotifications()
    await etat.charger(residence, avec: service)

    #expect(await etat.supprimer([3, 4, 5, 6], dans: residence, avec: service))
    #expect(service.requetes == ["selection [3, 4, 5, 6]"])
    #expect(etat.liste.map(\.id) == [1, 2])
}

@MainActor
@Test func supprimerLesLuesRefuseRendLaListe() async {
    let residence = ServiceSimule.residence
    let liste = [alerte(1, ilYA: 1), alerte(2, ilYA: 2, lue: true), alerte(3, ilYA: 3, lue: true)]
    let etat = EtatNotifications()
    await etat.charger(residence, avec: Refus(liste: liste))
    #expect(!(await etat.supprimerLues(residence, avec: Refus(liste: liste))))
    #expect(etat.liste.map(\.id) == [1, 2, 3], "les lues reviennent, à leur place")
    #expect(etat.lues == 2)
    #expect(etat.echec != nil, "et la phrase du serveur le dit")
}

@MainActor
@Test func supprimerLesLuesDansLApiSimuleeSeRelit() async {
    let residence = ServiceSimule.residence
    let service = ServiceSimule(delai: .zero)
    let etat = EtatNotifications()
    await etat.charger(residence, avec: service)
    #expect(etat.lues == 138)
    #expect(await etat.supprimerLues(residence, avec: service))
    await etat.charger(residence, avec: service)
    #expect(etat.liste.count == 12 && etat.lues == 0, "le serveur n'a gardé que les non lues")
}

/// La confirmation nomme ce qui part, avec les mots du site (`SUPPRESSION(quoi)`).
@Test func laConfirmationDitCeQuiPart() {
    #expect(TextesNotifications.supprimerLues == "Supprimer les lues")
    #expect(SuppressionDemandee.lues(138).quoi == "Les 138 notifications lues")
    #expect(SuppressionDemandee.lues(1).quoi == "La notification lue")
    #expect(SuppressionDemandee.lues(2).message == "Les 2 notifications lues\n\nCette action est irréversible.")
    #expect(SuppressionDemandee.lues(2).libelle == "Supprimer")
    #expect(SuppressionDemandee.selection([1, 2, 3]).quoi == "Ces 3 notifications")
    #expect(SuppressionDemandee.selection([1, 2, 3]).libelle == "Supprimer (3)")
    #expect(SuppressionDemandee.une(alerte(1, ilYA: 1)).quoi == "Cette notification")
}

@MainActor
@Test func uneSuppressionGroupeeRefuseeRendToutesLesLignes() async {
    let residence = ServiceSimule.residence
    let liste = (1...4).map { alerte($0, ilYA: Double($0)) }
    let etat = EtatNotifications()
    await etat.charger(residence, avec: Refus(liste: liste))
    #expect(!(await etat.supprimer([1, 3], dans: residence, avec: Refus(liste: liste))))
    #expect(etat.liste.map(\.id) == [1, 2, 3, 4], "elles reviennent, à leur place")
    #expect(etat.echec != nil, "et la phrase du serveur le dit")
}

@MainActor
@Test func laSuppressionGroupeeDeLApiSimuleeSeRelit() async {
    let residence = ServiceSimule.residence
    let service = ServiceSimule(delai: .zero)
    let etat = EtatNotifications()
    await etat.charger(residence, avec: service)
    let lues = Set(etat.liste.filter(\.lue).map(\.id))
    #expect(await etat.supprimer(lues, dans: residence, avec: service))
    await etat.charger(residence, avec: service)
    #expect(etat.liste.count == 12 && etat.liste.allSatisfy { !$0.lue }, "il ne reste que les non lues")
    #expect(TextesNotifications.supprimerSelection(0) == "Supprimer")
    #expect(TextesNotifications.supprimerSelection(3) == "Supprimer (3)")
}

// MARK: - Une sélection au-delà de la borne du contrat (#118)

/// Un serveur à la borne du contrat : il refuse (422) la requête qui la dépasse, comme
/// le vrai (`SuppressionNotifications.ids`, `maxItems`), note les identifiants de chaque
/// requête reçue, et peut perdre le réseau à la requête d'un rang donné (1 : la première).
private final class ServeurBorne: ServiceNotifications, @unchecked Sendable {
    let liste: [NotificationRecue]
    let enPanne: Int?
    private(set) var recues: [Set<Int>] = []
    private let verrou = NSLock()

    init(liste: [NotificationRecue], enPanne: Int? = nil) {
        self.liste = liste
        self.enPanne = enPanne
    }

    func notifications(_ installation: Installation) async throws -> [NotificationRecue] { liste }
    func marquerLue(_ id: Int, dans installation: Installation) async throws {}
    func toutMarquerLu(_ installation: Installation) async throws {}
    func supprimerNotification(_ id: Int, dans installation: Installation) async throws {}
    func supprimerNotifications(_ ids: Set<Int>, dans installation: Installation) async throws {
        let rang = verrou.withLock { recues.append(ids); return recues.count }
        guard (1...LimitesNotifications.selectionParRequete).contains(ids.count) else {
            throw ErreurService.inattendue(422)
        }
        if rang == enPanne { throw ErreurService.horsLigne }
    }
    func supprimerLues(_ installation: Installation) async throws {}
}

/// La borne n'est pas recopiée : elle est celle du contrat dont le client se génère.
@Test func laBorneDUneSelectionEstCelleDuContrat() throws {
    let contrat = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Paquets/ClientAPI/Sources/ClientAPI/openapi.json")
    let schema = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: contrat)) as? [String: Any])
    let schemas = try #require((schema["components"] as? [String: Any])?["schemas"] as? [String: Any])
    let corps = try #require(schemas["SuppressionNotifications"] as? [String: Any])
    let ids = try #require((corps["properties"] as? [String: Any])?["ids"] as? [String: Any])
    #expect(ids["maxItems"] as? Int == LimitesNotifications.selectionParRequete)
    #expect(LimitesNotifications.selectionParRequete >= 1, "une borne nulle ne ferait partir aucune requête")
}

@Test func uneSelectionSeDecoupeSansRienPerdreNiRedire() {
    #expect(EtatNotifications.lots([], de: 2).isEmpty)
    #expect(EtatNotifications.lots([5, 1, 4, 2, 3], de: 2) == [[1, 2], [3, 4], [5]])
    #expect(EtatNotifications.lots([1, 2], de: 2) == [[1, 2]], "à la borne : un seul lot")
    let limite = LimitesNotifications.selectionParRequete
    #expect(EtatNotifications.lots(Set(1...limite)).count == 1)
    #expect(EtatNotifications.lots(Set(1...(limite + 1))).map(\.count) == [limite, 1])
}

/// Le cas du ticket : plus d'identifiants qu'une requête n'en accepte. Autant de requêtes
/// qu'il en faut, aucune au-delà de la borne, chaque identifiant envoyé une seule fois.
@MainActor
@Test func uneSelectionAuDelaDeLaBornePartEnRequetesSuccessives() async {
    let residence = ServiceSimule.residence
    let limite = LimitesNotifications.selectionParRequete
    let choisies = Set(1...(2 * limite + 1))
    let liste = (1...(2 * limite + 4)).map { alerte($0, ilYA: Double($0), lue: $0 > 2) }
    let service = ServeurBorne(liste: liste)
    let etat = EtatNotifications()
    await etat.charger(residence, avec: service)

    #expect(await etat.supprimer(choisies, dans: residence, avec: service))
    #expect(service.recues.map(\.count) == [limite, limite, 1], "trois requêtes, aucune au-delà de la borne")
    #expect(service.recues.reduce(0) { $0 + $1.count } == choisies.count, "aucun identifiant envoyé deux fois")
    #expect(service.recues.reduce(into: Set<Int>()) { $0.formUnion($1) } == choisies, "et aucun oublié")
    #expect(etat.liste.map(\.id) == [2 * limite + 2, 2 * limite + 3, 2 * limite + 4], "les autres restent")
    #expect(etat.echec == nil && etat.phraseEchec == nil, "aucune erreur à l'écran")
    #expect(CompteurNonLues.partage.nombre(residence) == 0, "la cloche suit")
}

/// Une requête échoue en route : ce que le serveur a supprimé a disparu, le reste demeure
/// à sa place, la requête suivante ne part pas, et la phrase dit combien et pourquoi.
@MainActor
@Test func uneSuppressionInterrompueNeRendQueCeQuiReste() async {
    let residence = ServiceSimule.residence
    let limite = LimitesNotifications.selectionParRequete
    let choisies = Set(1...(2 * limite + 1))
    let liste = (1...(2 * limite + 4)).map { alerte($0, ilYA: Double($0), lue: $0 > 2) }
    let service = ServeurBorne(liste: liste, enPanne: 2)
    let etat = EtatNotifications()
    await etat.charger(residence, avec: service)

    #expect(!(await etat.supprimer(choisies, dans: residence, avec: service)), "tout n'est pas supprimé")
    #expect(service.recues.count == 2, "la troisième requête ne part pas")
    #expect(
        etat.liste.map(\.id) == Array((limite + 1)...(2 * limite + 4)), "le premier lot a disparu, le reste demeure")
    #expect(etat.interrompue?.parties == Set(1...limite))
    #expect(etat.echec == .horsLigne, "la cause reste lisible")
    #expect(
        etat.phraseEchec
            == "\(limite) notifications sur \(2 * limite + 1) ont été supprimées ; "
            + "les \(limite + 1) autres sont toujours là. " + ErreurService.horsLigne.phrase)
    #expect(etat.nonLues == 0 && CompteurNonLues.partage.nombre(residence) == 0, "les deux non lues sont parties")

    // On réessaie ce qui reste : le réseau est revenu, la phrase s'efface.
    let restantes = choisies.subtracting(Set(1...limite))
    #expect(await etat.supprimer(restantes, dans: residence, avec: service))
    #expect(service.recues.dropFirst(2).map(\.count) == [limite, 1])
    #expect(etat.liste.map(\.id) == [2 * limite + 2, 2 * limite + 3, 2 * limite + 4])
    #expect(etat.phraseEchec == nil && etat.interrompue == nil)
}

/// L'échec dès la première requête reste le refus ordinaire : tout revient, la phrase est
/// celle de la cause — pas « 0 notification sur … ».
@MainActor
@Test func unEchecDesLaPremiereRequeteRendToutesLesLignes() async {
    let residence = ServiceSimule.residence
    let limite = LimitesNotifications.selectionParRequete
    let liste = (1...(limite + 2)).map { alerte($0, ilYA: Double($0)) }
    let service = ServeurBorne(liste: liste, enPanne: 1)
    let etat = EtatNotifications()
    await etat.charger(residence, avec: service)

    #expect(!(await etat.supprimer(Set(1...(limite + 1)), dans: residence, avec: service)))
    #expect(service.recues.count == 1, "la seconde requête ne part pas")
    #expect(etat.liste.map(\.id) == Array(1...(limite + 2)), "elles reviennent toutes, à leur place")
    #expect(etat.interrompue == nil && etat.phraseEchec == ErreurService.horsLigne.phrase)
}

@Test func laPhraseDUneSuppressionInterrompueDitCeQuiEstPartiEtCeQuiReste() {
    #expect(
        TextesNotifications.suppressionInterrompue(500, sur: 1200)
            == "500 notifications sur 1200 ont été supprimées ; les 700 autres sont toujours là.")
    #expect(
        TextesNotifications.suppressionInterrompue(500, sur: 501)
            == "500 notifications sur 501 ont été supprimées ; la dernière est toujours là.")
    #expect(
        TextesNotifications.suppressionInterrompue(1, sur: 3)
            == "1 notification sur 3 a été supprimée ; les 2 autres sont toujours là.")
}

/// L'API simulée refuse, comme le serveur, la requête qui dépasse la borne — sans le
/// découpage, la grande sélection y échouerait donc — et la sélection s'y supprime entière.
@MainActor
@Test func uneGrandeSelectionSeSupprimeDansLApiSimulee() async throws {
    let residence = ServiceSimule.residence
    let limite = LimitesNotifications.selectionParRequete
    let service = ServiceSimule(delai: .zero)
    service.reglerNotifications(nombre: limite + 20)
    let etat = EtatNotifications()
    await etat.charger(residence, avec: service)
    let toutes = Set(etat.liste.map(\.id))
    #expect(toutes.count == limite + 20, "plus qu'une requête n'en supprime")

    await #expect(throws: ErreurService.inattendue(422)) {
        try await service.supprimerNotifications(toutes, dans: residence)
    }
    let apresLeRefus = try await service.notifications(residence)
    #expect(apresLeRefus.count == limite + 20, "un 422 ne supprime rien")

    #expect(await etat.supprimer(toutes, dans: residence, avec: service))
    await etat.charger(residence, avec: service)
    #expect(etat.liste.isEmpty && etat.phraseEchec == nil, "le serveur n'a plus rien")
}

/// Le réseau tombe à la deuxième requête : ce que l'écran garde est ce que le serveur a gardé.
@MainActor
@Test func uneSuppressionInterrompueDansLApiSimuleeLaisseLaListeVraie() async throws {
    let residence = ServiceSimule.residence
    let limite = LimitesNotifications.selectionParRequete
    let service = ServiceSimule(delai: .zero)
    service.reglerNotifications(nombre: limite + 20, suppressionEnPanne: 2)
    let etat = EtatNotifications()
    await etat.charger(residence, avec: service)

    #expect(!(await etat.supprimer(Set(etat.liste.map(\.id)), dans: residence, avec: service)))
    #expect(etat.liste.count == 20 && etat.interrompue?.parties.count == limite)
    let gardees = try await service.notifications(residence)
    #expect(etat.liste == gardees, "l'écran et le serveur disent la même liste")
}
