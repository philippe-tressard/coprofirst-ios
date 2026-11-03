// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

@Test func lesRolesSAnnoncentCommeLEnTeteDuSite() {
    let conseil = ProfilResidence(
        statut: "copropriétaire_résident", roles: ["résident", "propriétaire", "conseil_syndical", "conseil_syndical"],
        libelleLogement: nil)
    #expect(conseil.rolesAffiches == ["Copropriétaire résident", "Conseil syndical"], "statut, puis CS, sans doublon")
    let locataire = ProfilResidence(statut: "locataire", roles: ["résident"], libelleLogement: nil)
    #expect(locataire.rolesAffiches == ["Locataire"], "résident n'ajoute rien au statut")
    let admin = ProfilResidence(statut: "statut_inconnu", roles: ["admin", "conseil_syndical"], libelleLogement: nil)
    #expect(
        admin.rolesAffiches == ["Conseil syndical", "Admin"],
        "un statut inconnu ne s'annonce pas ; l'ordre est celui du site")
}

private struct Ouvert {
    let parcours: Parcours
    let service: ServiceSimule
}

@MainActor
private func parcoursOuvert() throws -> Ouvert {
    let suite = "tests.\(UUID().uuidString)"
    let reglages = try #require(UserDefaults(suiteName: suite))
    let service = ServiceSimule(delai: .milliseconds(1))
    let parcours = Parcours(service: service, connues: InstallationsConnues(reglages: reglages))
    parcours.ouvrir(ServiceSimule.residence, premiereConnexion: true)
    return Ouvert(parcours: parcours, service: service)
}

@MainActor
@Test func apresLaDeconnexionFaceIDNeRouvreRienEtLeFilNEstPlusLisible() async throws {
    let ouvert = try parcoursOuvert()
    let (parcours, service) = (ouvert.parcours, ouvert.service)
    let residence = ServiceSimule.residence
    #expect(await service.activerFaceID(residence))
    #expect(service.aUneSessionGardee(residence))
    _ = try await service.fil(residence)

    await parcours.deconnecter(residence)

    #expect(!service.aUneSessionGardee(residence), "plus de session gardée : Face ID ne rouvre rien")
    await #expect(throws: ErreurService.sessionExpiree) { try await service.fil(residence) }
    await #expect(throws: ErreurService.sessionExpiree) { try await service.reprendre(residence) }
    #expect(parcours.ouverte == nil)
    #expect(
        parcours.chemin == [.connexion(.init(installation: residence))], "retour à la connexion, adresse pré-remplie")
    #expect(!parcours.connues.faceIDProposee(residence), "Face ID sera reproposé")
    #expect(parcours.connues.liste.contains(residence), "la résidence reste connue")
}

@MainActor
@Test func oublierToutesLesResidencesRendUneAppNeuve() async throws {
    let ouvert = try parcoursOuvert()
    let (parcours, service) = (ouvert.parcours, ouvert.service)
    parcours.connues.retenir(ServiceSimule.demo)
    await parcours.oublierTout()
    #expect(parcours.connues.liste.isEmpty)
    #expect(parcours.ouverte == nil && parcours.reconnue == nil && parcours.chemin.isEmpty, "retour à l'accueil")
    await #expect(throws: ErreurService.sessionExpiree) { try await service.fil(ServiceSimule.residence) }
}

@MainActor
@Test func leProfilConnuSurvitAUneNouvelleDecouverte() throws {
    let parcours = try parcoursOuvert().parcours
    let profil = ProfilResidence(statut: "locataire", roles: [], libelleLogement: "Bât. A")
    parcours.connues.noter(profil, pour: ServiceSimule.residence)
    parcours.connues.retenir(ServiceSimule.residence)  // une découverte ne sert pas le profil
    #expect(parcours.ouverteAJour?.profil == profil)
}
