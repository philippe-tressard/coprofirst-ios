// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// Les réglages (`UserDefaults`, emportés en clair par la sauvegarde de l'appareil) ne
/// gardent que la résidence : ni nom, ni rôle, ni logement, ni courriel (#84).

/// Tout ce que la suite de réglages contient, en un texte où chercher.
private func contenu(_ suite: String) -> String {
    let domaine = UserDefaults.standard.persistentDomain(forName: suite) ?? [:]
    return domaine.map { cle, valeur in
        let texte = (valeur as? Data).flatMap { String(data: $0, encoding: .utf8) } ?? "\(valeur)"
        return "\(cle)=\(texte)"
    }.joined(separator: "\n")
}

@MainActor
@Test func apresUneConnexionLesReglagesNeGardentNiNomNiRole() async throws {
    let suite = "tests.\(UUID().uuidString)"
    let reglages = try #require(UserDefaults(suiteName: suite))
    defer { reglages.removePersistentDomain(forName: suite) }
    let service = ServiceSimule(delai: .milliseconds(1))
    let coffre = CoffreEnMemoire()
    let parcours = Parcours(service: service, connues: InstallationsConnues(reglages: reglages, coffre: coffre))
    let residence = ServiceSimule.residence

    // Le parcours de `ConnexionView.seConnecter`, puis la relecture du profil (GET /auth/me).
    try await service.connecter(residence, email: "resident@exemple.fr", motDePasse: "secret")
    parcours.connues.retenirIdentifiant("resident@exemple.fr", pour: residence)
    parcours.ouvrir(residence, premiereConnexion: true)
    await parcours.rafraichirProfil()
    let profil = try #require(parcours.ouverteAJour?.profil, "le profil est bien connu de l'app")

    let ecrit = contenu(suite)
    #expect(ecrit.contains(residence.nom), "la résidence, elle, est retenue")
    for trace in profil.roles + [profil.statut, profil.libelleLogement, "resident@exemple.fr"].compactMap({ $0 }) {
        #expect(!ecrit.contains(trace), "« \(trace) » ne doit pas être dans les réglages")
    }
    #expect(!ecrit.contains("profil"), "aucun profil sérialisé")

    // Relu au lancement suivant, depuis le coffre.
    let relance = InstallationsConnues(reglages: reglages, coffre: coffre)
    #expect(relance.liste.first?.profil == profil)
    #expect(relance.identifiant(residence) == "resident@exemple.fr")
}

/// Ce qu'une version antérieure a écrit en clair passe au coffre, puis s'efface.
@MainActor
@Test func leProfilEtLeCourrielDejaEcritsMigrentAuCoffre() throws {
    let suite = "tests.\(UUID().uuidString)"
    let reglages = try #require(UserDefaults(suiteName: suite))
    defer { reglages.removePersistentDomain(forName: suite) }
    var ancienne = ServiceSimule.residence
    let profil = ProfilResidence(statut: "locataire", roles: ["résident"], libelleLogement: "Bât. B, T2")
    ancienne.profil = profil
    reglages.set(try JSONEncoder().encode([ancienne]), forKey: "installations-connues")
    reglages.set("ancien@exemple.fr", forKey: "identifiant." + ancienne.hote)

    let coffre = CoffreEnMemoire()
    let connues = InstallationsConnues(reglages: reglages, coffre: coffre)

    #expect(connues.liste.first?.profil == profil, "le profil reste connu")
    #expect(connues.identifiant(ancienne) == "ancien@exemple.fr", "le courriel reste pré-rempli")
    let ecrit = contenu(suite)
    #expect(!ecrit.contains("locataire") && !ecrit.contains("Bât. B"), "le profil a quitté les réglages")
    #expect(!ecrit.contains("ancien@exemple.fr"), "le courriel a quitté les réglages")
    #expect(ecrit.contains(ancienne.nom), "la résidence reste")
}

/// Le coffre de l'app est le Trousseau : une valeur rangée se relit, puis s'efface.
@Test func leCoffreDuTrousseauRangeRelitEtEfface() {
    let coffre = CoffreTrousseau()
    let cle = "tests.\(UUID().uuidString)"
    defer { coffre.effacer(cle) }
    coffre.ranger(Data("valeur".utf8), cle)
    #expect(coffre.lire(cle) == Data("valeur".utf8))
    coffre.effacer(cle)
    #expect(coffre.lire(cle) == nil)
}

/// L'activation dit ce qui protège la session : Face ID, ou le verrouillage de
/// l'appareil — jamais l'un pour l'autre.
@Test func lActivationDitCeQuiProtegeLaSession() {
    let faceID = FaceIDFeuille.dire(.biometrie("Face ID"), nom: "Les Tilleuls")
    #expect(faceID.titre == "Protégée par Face ID" && faceID.rassurant)
    let code = FaceIDFeuille.dire(.codeAppareil, nom: "Les Tilleuls")
    #expect(code.titre == "Protégée par le verrouillage de l'appareil" && !code.rassurant)
    #expect(!code.titre.contains("Face ID"))
    let rien = FaceIDFeuille.dire(.aucune, nom: "Les Tilleuls")
    #expect(!rien.rassurant && !rien.titre.contains("Protégée"))
}
