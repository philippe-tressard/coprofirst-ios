// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

// Entrer sans réseau, en sortir (#101) : le parcours ouvre la dernière lecture quand la
// reprise échoue FAUTE DE RÉSEAU, Face ID passé — jamais autrement ; il reprend la
// session au retour du réseau ; un refus du serveur ramène à la connexion.

/// Un habitué dont la session est gardée, sur l'API simulée privée de réseau.
@MainActor
private func habitue(_ lecture: LectureDisponible) -> (Parcours, ServiceSimule) {
    let suite = "fr.coprofirst.tests.hors-ligne.\(UUID().uuidString)"
    let reglages = UserDefaults(suiteName: suite) ?? .standard
    reglages.removePersistentDomain(forName: suite)
    let simule = ServiceSimule(delai: .zero)
    simule.garder(ServiceSimule.residence)
    simule.horsLigneSimule = true
    simule.lectureSimulee = lecture
    let connues = InstallationsConnues(reglages: reglages, coffre: CoffreEnMemoire())
    let parcours = Parcours(service: simule, connues: connues)
    return (parcours, simule)
}

/// L'échec de la reprise, tel que l'écran le reçoit.
@MainActor
private func echecDeLaReprise(_ parcours: Parcours) async -> any Error {
    do {
        try await parcours.service.reprendre(ServiceSimule.residence)
        return ErreurService.inattendue(0)
    } catch {
        return error
    }
}

@MainActor @Suite struct EntreeHorsLigneTests {
    private let residence = ServiceSimule.residence

    @Test func sansReseauLaDerniereLectureSOuvreEnConsultation() async {
        let (parcours, _) = habitue(.gardee(ServiceSimule.lectureDuTicket))
        let echec = await echecDeLaReprise(parcours)
        #expect(ErreurService.depuis(echec) == .horsLigne)

        #expect(parcours.entrerHorsLigne(residence, apres: echec) == .ouverte)
        #expect(parcours.ouverte == residence)
        #expect(parcours.consultation == ConsultationHorsLigne(aJourAu: ServiceSimule.lectureDuTicket))
        #expect(parcours.consultation?.phrase == "Hors ligne — à jour au 10/11/2026 à 14:32")
    }

    @Test func unServeurInjoignableOuvreAussiLaDerniereLecture() {
        let (parcours, _) = habitue(.gardee(ServiceSimule.lectureDuTicket))
        #expect(parcours.entrerHorsLigne(residence, apres: ErreurService.injoignable) == .ouverte)
        #expect(parcours.consultation != nil)
    }

    @Test func faceIDAnnuleNOuvreRien() async {
        let (parcours, simule) = habitue(.gardee(ServiceSimule.lectureDuTicket))
        simule.refuserFaceID = true
        let echec = await echecDeLaReprise(parcours)
        #expect(ErreurService.depuis(echec) == .sessionExpiree, "l'échec d'un Face ID annulé")

        #expect(parcours.entrerHorsLigne(residence, apres: echec) == .impossible)
        #expect(parcours.ouverte == nil)
        #expect(parcours.consultation == nil)
    }

    @Test func unRefusDuServeurNOuvreRien() {
        let (parcours, _) = habitue(.gardee(ServiceSimule.lectureDuTicket))
        for refus in [ErreurService.sessionExpiree, .identifiantsRefuses, .inattendue(500), .tropDEssais] {
            #expect(parcours.entrerHorsLigne(residence, apres: refus) == .impossible)
        }
        #expect(parcours.ouverte == nil)
    }

    @Test func sansLectureGardeeRienNeSOuvre() {
        let (parcours, _) = habitue(.aucune)
        #expect(parcours.entrerHorsLigne(residence, apres: ErreurService.horsLigne) == .impossible)
        #expect(parcours.ouverte == nil)
    }

    @Test func uneLecturePerimeeSeDitEtNOuvreRien() {
        let (parcours, _) = habitue(.perimee)
        #expect(parcours.entrerHorsLigne(residence, apres: ErreurService.horsLigne) == .perimee)
        #expect(parcours.ouverte == nil)
        #expect(TextesHorsLigne.perimee.contains("7 jours"), "la durée dite est celle de la constante")
        #expect(parcours.entrerHorsLigne(residence, apres: ErreurService.horsLigne) == .impossible, "effacée")
    }

    // MARK: - Le retour du réseau

    @Test func tantQueLeReseauManqueLaConsultationContinue() async {
        let (parcours, _) = habitue(.gardee(ServiceSimule.lectureDuTicket))
        _ = parcours.entrerHorsLigne(residence, apres: ErreurService.horsLigne)
        await parcours.reprendreEnLigne()
        #expect(parcours.consultation != nil)
        #expect(parcours.ouverte == residence)
    }

    @Test func auRetourDuReseauLaSessionReprendEtLaConsultationFinit() async {
        let (parcours, simule) = habitue(.gardee(ServiceSimule.lectureDuTicket))
        _ = parcours.entrerHorsLigne(residence, apres: ErreurService.horsLigne)
        simule.horsLigneSimule = false
        await parcours.reprendreEnLigne()
        #expect(parcours.consultation == nil, "les gestes reviennent")
        #expect(parcours.ouverte == residence, "sans quitter la résidence")
    }

    @Test func unCompteRevoqueRevientALaConnexionSansRienGarder() async {
        let (parcours, simule) = habitue(.gardee(ServiceSimule.lectureDuTicket))
        _ = parcours.entrerHorsLigne(residence, apres: ErreurService.horsLigne)
        simule.horsLigneSimule = false
        simule.repriseRefusee = true
        await parcours.reprendreEnLigne()
        #expect(parcours.ouverte == nil)
        #expect(parcours.consultation == nil)
        #expect(parcours.avis == ErreurService.sessionExpiree.phrase)
        #expect(!simule.aUneSessionGardee(residence), "le jeton")
        #expect(simule.lectureSimulee == .aucune, "et la lecture")
    }

    // MARK: - Sortir

    @Test func seDeconnecterEnConsultationEffaceLaLectureEtSortDeLaConsultation() async {
        let (parcours, simule) = habitue(.gardee(ServiceSimule.lectureDuTicket))
        _ = parcours.entrerHorsLigne(residence, apres: ErreurService.horsLigne)
        await parcours.deconnecter(residence)
        #expect(parcours.ouverte == nil)
        #expect(parcours.consultation == nil)
        #expect(simule.lectureSimulee == .aucune)
        #expect(parcours.entrerHorsLigne(residence, apres: ErreurService.horsLigne) == .impossible, "plus rien")
    }

    @Test func changerDeResidenceSortDeLaConsultation() {
        let (parcours, _) = habitue(.gardee(ServiceSimule.lectureDuTicket))
        _ = parcours.entrerHorsLigne(residence, apres: ErreurService.horsLigne)
        parcours.changer(pour: nil)
        #expect(parcours.consultation == nil)
    }

    @Test func ouvrirEnLigneNEstPasUneConsultation() {
        let (parcours, _) = habitue(.gardee(ServiceSimule.lectureDuTicket))
        parcours.ouvrir(residence)
        #expect(parcours.consultation == nil)
    }
}
