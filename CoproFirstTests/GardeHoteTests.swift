// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// La garde du mot de passe (#82) : un hôte jamais vu ne reçoit rien avant la
/// confirmation, et sans preuve, rien avant le second accord.
@MainActor
struct GardeHoteTests {
    let service = ServiceSimule(delai: .zero)
    let reglages: UserDefaults
    let connues: InstallationsConnues
    let garde: GardeHote

    init() throws {
        let suite = "garde-hote.\(UUID().uuidString)"
        reglages = try #require(UserDefaults(suiteName: suite))
        reglages.removePersistentDomain(forName: suite)
        connues = InstallationsConnues(reglages: reglages)
        let connues = connues
        garde = GardeHote(service: service, connues: { connues.liste })
    }

    private func installation(_ hote: String) throws -> Installation {
        var installation = ServiceSimule.residence
        installation.adresse = try adresse(hote)
        return installation
    }

    private func connecter(_ installation: Installation, _ origine: OrigineAdresse = .saisie) async throws -> Bool {
        try await garde.connecter(installation, origine: origine, email: "resident@exemple.fr", motDePasse: "secret")
    }

    @Test func unHoteInconnuNeRecoitAucuneRequeteDAuthentificationAvantLaConfirmation() async throws {
        let inconnue = try installation("tilleuls.exemple.fr")
        #expect(try await connecter(inconnue) == false, "la connexion s'arrête à la garde")
        #expect(service.adressesAyantRecuUnMotDePasse.isEmpty, "aucun mot de passe n'est parti")
        #expect(garde.aConfirmer == inconnue, "l'écran de confirmation s'ouvre")

        #expect(garde.confirmer() == false, "pas de confirmation avant la preuve lue")
        #expect(try await connecter(inconnue) == false)
        #expect(service.adressesAyantRecuUnMotDePasse.isEmpty)

        await garde.verifier()
        #expect(garde.preuve == .declaree)
        #expect(garde.confirmer())
        #expect(garde.aConfirmer == nil)
        #expect(try await connecter(inconnue))
        #expect(service.adressesAyantRecuUnMotDePasse == [inconnue.adresse], "un seul envoi, après l'accord")
    }

    @Test func renoncerNeConfirmeRien() async throws {
        let inconnue = try installation("tilleuls.exemple.fr")
        _ = try await connecter(inconnue)
        await garde.verifier()
        garde.renoncer()
        #expect(garde.aConfirmer == nil)
        #expect(try await connecter(inconnue) == false, "l'écran se rouvre")
        #expect(service.adressesAyantRecuUnMotDePasse.isEmpty)
    }

    @Test(arguments: [PreuveHote.absente, .sansLApp])
    func sansPreuveLaConnexionAttendUnSecondAccord(preuve: PreuveHote) async throws {
        let hote = preuve == .absente ? "imitation.exemple.fr" : "sans-app.exemple.fr"
        let suspecte = try installation(hote)
        _ = try await connecter(suspecte)
        await garde.verifier()
        #expect(garde.preuve == preuve, "l'écran avertit")
        #expect(garde.preuve?.reconnue == false)
        #expect(garde.confirmer() == false, "un seul accord ne suffit pas")
        #expect(try await connecter(suspecte) == false)
        #expect(service.adressesAyantRecuUnMotDePasse.isEmpty)

        #expect(garde.confirmer(secondAccord: true))
        #expect(try await connecter(suspecte))
        #expect(service.adressesAyantRecuUnMotDePasse == [suspecte.adresse])
    }

    @Test func uneResidenceConnueSaisieNeSeConfirmePas() async throws {
        let connue = try installation("tilleuls.exemple.fr")
        connues.retenir(connue)
        #expect(try await connecter(connue))
        #expect(garde.aConfirmer == nil)
        #expect(service.adressesAyantRecuUnMotDePasse == [connue.adresse])
    }

    @Test func unHoteVoisinDUneResidenceConnueSeConfirme() async throws {
        connues.retenir(try installation("tilleuls.exemple.fr"))
        #expect(try await connecter(try installation("tilleuls.exemple.fr:8443")) == false, "un autre port")
        #expect(try await connecter(try installation("ti1leuls.exemple.fr")) == false, "un « l » devenu « 1 »")
        #expect(service.adressesAyantRecuUnMotDePasse.isEmpty)
    }

    @Test func apresUnScanLaConfirmationEstToujoursDemandee() async throws {
        let connue = try installation("tilleuls.exemple.fr")
        connues.retenir(connue)
        #expect(try await connecter(connue, .scan) == false, "même une résidence connue")
        #expect(service.adressesAyantRecuUnMotDePasse.isEmpty)
    }

    @Test func apresUnLienLaConfirmationEstToujoursDemandee() async throws {
        let connue = try installation("tilleuls.exemple.fr")
        connues.retenir(connue)
        #expect(try await connecter(connue, .lien) == false, "même une résidence connue (#18)")
        #expect(service.adressesAyantRecuUnMotDePasse.isEmpty)
    }

    @Test func laDemonstrationEcriteDansLAppNeSeConfirmePas() throws {
        let demo = try adresse(ContenuVitrine.adresseDemo)
        #expect(garde.exigeConfirmation(demo, origine: .saisie) == false)
        #expect(garde.exigeConfirmation(demo, origine: .scan), "scannée, elle se confirme comme les autres")
    }
}

// MARK: - La preuve servie

private func adresse(_ saisie: String) throws -> URL {
    try #require(AdresseInstallation.normaliser(saisie))
}

private func aasa(_ json: String, statut: Int = 200) -> PreuveHote {
    PreuveAASA.juger(statut: statut, donnees: Data(json.utf8))
}

@Test func laPreuveServieParLesInstallationsDeclareLApp() {
    // La forme servie par coprofirst#2459 (démo, 10/11/2026).
    #expect(
        aasa(#"{"applinks":{"details":[{"appIDs":["GUX8KASNTG.fr.coprofirst.app"],"components":[]}]}}"#) == .declaree)
    #expect(aasa(#"{"applinks":{"details":[{"appID":"GUX8KASNTG.fr.coprofirst.app","paths":["*"]}]}}"#) == .declaree)
    #expect(aasa(#"{"webcredentials":{"apps":["GUX8KASNTG.fr.coprofirst.app"]}}"#) == .declaree)
}

@Test func unFichierQuiNeDeclarePasLAppAvertit() {
    #expect(aasa(#"{"applinks":{"details":[{"appIDs":["ABCDE12345.fr.coprofirst.app"]}]}}"#) == .sansLApp)
    #expect(aasa(#"{"applinks":{"details":[{"appIDs":["GUX8KASNTG.fr.coprofirst.autre"]}]}}"#) == .sansLApp)
    #expect(aasa(#"{"applinks":{"details":[]}}"#) == .sansLApp)
    #expect(aasa("{}") == .sansLApp)
}

@Test func unFichierAbsentOuIllisibleAvertit() {
    let valide = #"{"applinks":{"details":[{"appIDs":["GUX8KASNTG.fr.coprofirst.app"]}]}}"#
    #expect(aasa(valide, statut: 404) == .absente)
    #expect(aasa(valide, statut: 301) == .absente, "une redirection n'est pas suivie")
    #expect(aasa("<html>Résidence</html>") == .absente)
    #expect(aasa("[]") == .absente)
    let enorme = "{\"x\":\"" + String(repeating: "a", count: PreuveAASA.plafond) + "\"," + valide.dropFirst()
    #expect(aasa(enorme) == .absente, "au-delà de 128 Kio, Apple l'ignore")
}

@Test func laPreuveSeLitALAdresseDeLHote() throws {
    #expect(
        PreuveAASA.adresse(de: try adresse("residence.exemple.fr:8443")).absoluteString
            == "https://residence.exemple.fr:8443/.well-known/apple-app-site-association")
}

@Test func lIdentifiantDeLaPreuveEstCeluiDeLApp() throws {
    let identifiant = try #require(Bundle.main.bundleIdentifier)
    #expect(PreuveAASA.identifiantApp == "GUX8KASNTG." + identifiant)
}

// MARK: - L'hôte affiché

@Test func lHoteSAfficheEnEntierPortCompris() throws {
    #expect(ConfirmationHote.hote(try adresse("tilleuls.exemple.fr")) == "tilleuls.exemple.fr")
    #expect(ConfirmationHote.hote(try adresse("https://tilleuls.exemple.fr:8443/x")) == "tilleuls.exemple.fr:8443")
}

@Test func unHoteInternationalNeSeDeguisePas() {
    // « і » cyrillique à la place du « i » latin : refusé, ou montré sous sa forme encodée.
    guard let adresse = AdresseInstallation.normaliser("t\u{0456}lleuls.exemple.fr") else { return }
    let affiche = ConfirmationHote.hote(adresse)
    let ascii = affiche.allSatisfy { $0.isASCII }
    #expect(ascii, "« \(affiche) » imite un hôte latin")
    #expect(affiche != "tilleuls.exemple.fr")
}
