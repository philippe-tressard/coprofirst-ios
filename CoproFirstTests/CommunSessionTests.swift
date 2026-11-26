// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import OpenAPIRuntime
import Testing

@testable import CoproFirst

// Les gestes communs du dialogue avec l'API (#41) : relire une réponse non typée,
// dire la phrase du serveur quand il refuse.

// MARK: - Relecture

/// Une réponse NON TYPÉE arrive en `OpenAPIValueContainer` : ses dates y sont des
/// chaînes, que `Relecture` lit comme le client (sans fuseau = UTC). Une sortie TYPÉE ne
/// compile pas dans `Relecture.lire(_:depuis:)` (bogue du 06/11/2026).
@Test func uneReponseNonTypeeSeRelitAvecSesDatesSansFuseau() throws {
    struct Delegation: Decodable {
        let id: Int
        let creeLe: Date
        let estActive: Bool
    }
    let json = #"{"id": 3, "cree_le": "2026-11-04T08:30:00", "est_active": true}"#
    let brut = try JSONDecoder().decode(OpenAPIValueContainer.self, from: Data(json.utf8))
    let lue = try Relecture.lire(Delegation.self, depuis: brut)
    #expect(lue.id == 3 && lue.estActive)
    #expect(lue.creeLe == ISO8601DateFormatter().date(from: "2026-11-04T08:30:00Z"), "sans fuseau = UTC")
}

@Test func desOctetsSeRelisentCommeUneValeurDuClient() throws {
    // `/lots/mes-lots` est typée depuis le contrat 1.5.0 : un modèle local en tient lieu.
    struct Lot: Decodable {
        let numero: String
        let batimentNom: String?
        let typeLien: String?
    }
    let json = #"[{"numero": "12", "id": 4, "batiment_nom": "A", "type_lien": "locataire"}]"#
    let lots = try Relecture.lire([Lot].self, json: Data(json.utf8))
    #expect(lots.first?.batimentNom == "A" && lots.first?.typeLien == "locataire")
}

// MARK: - Phrase du serveur

/// `ServiceAPI.refus` lit le corps de la réponse, puis s'en remet à ceci.
private func refus(_ statut: Int, _ corps: String?) -> ErreurService {
    ErreurService.depuisRefus(statut, corps: corps.map { Data($0.utf8) })
}

@Test func unRefusDitLaPhraseDuServeur() {
    let erreur = refus(403, #"{"detail": "Réservé au conseil syndical"}"#)
    #expect(erreur == .refus(.init(phrase: "Réservé au conseil syndical")))
    #expect(erreur.phrase == "Réservé au conseil syndical")
    #expect(ErreurService.depuis(erreur).phraseDuServeur == "Réservé au conseil syndical")
}

/// Le 403 d'un compte au mot de passe temporaire (#377) : un `detail` OBJET, dont le message
/// est la phrase et le code celui que publie le serveur (`TablesProfil.motifMotDePasseAChanger`).
@Test func unRefusStructureDitSonMessageEtGardeSonCode() {
    let corps = #"{"detail": {"code": "mot_de_passe_a_changer", "message": "Votre mot de passe est temporaire."}}"#
    let erreur = refus(403, corps)
    #expect(erreur.phrase == "Votre mot de passe est temporaire.")
    guard case .refus(let lu) = erreur else { Issue.record("un refus attendu"); return }
    #expect(lu.code == TablesProfil.motifMotDePasseAChanger)
    #expect(refus(403, #"{"detail": {"code": "x"}}"#) == .depuisLecture(403), "sans message : rien à dire")
}

@Test func leMotDePasseTemporaireSeLitEtTombeQuandIlEstChoisi() async throws {
    let service = ServiceSimule(delai: .zero)
    service.profilSimule.motDePasseAChanger = true
    try await service.changerMotDePasse(actuel: "temporaire1", nouveau: "choisi-2026", dans: ServiceSimule.residence)
    #expect(try await service.profil(ServiceSimule.residence).motDePasseAChanger == false)
}

@Test func sansPhraseLeStatutDecide() {
    #expect(refus(401, #"{"detail": "x"}"#) == .sessionExpiree, "401 : la session")
    #expect(refus(403, nil) == .introuvable)
    #expect(refus(404, #"{"detail": "  "}"#) == .introuvable, "une phrase vide n'en est pas une")
    // Une erreur de validation sert une liste : elle ne s'affiche pas.
    #expect(refus(400, #"{"detail": [{"msg": "x"}]}"#) == .inattendue(400))
    #expect(refus(500, "<html>") == .inattendue(500))
}

@Test func laPhraseDuServeurPasseDevantCelleDeLEcran() {
    let erreur = ErreurService.refus(.init(phrase: "Export déjà en cours"))
    #expect(ErreurService.phrase(erreur, sinon: "Erreur lors de l'export.") == "Export déjà en cours")
    let horsLigne = ErreurService.phrase(ErreurService.horsLigne, sinon: "Erreur lors de l'export.")
    #expect(horsLigne == "Erreur lors de l'export.", "sans phrase du serveur, celle de l'écran")
    #expect(ErreurService.horsLigne.phraseDuServeur == nil)
}
