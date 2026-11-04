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
    #expect(etat.nonLues == 2)
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
