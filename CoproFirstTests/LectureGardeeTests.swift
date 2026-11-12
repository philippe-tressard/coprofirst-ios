// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

// Le magasin des lectures gardées (#101) : ce qui reste sur l'appareil pour consulter
// sans réseau. Ses exigences sont de sécurité : protection `.complete`, hors des
// sauvegardes, un dossier par résidence, sept jours au plus, rien sans session gardée.

/// Une horloge que le test avance.
final class HorlogeDeTest: @unchecked Sendable {
    private let verrou = NSLock()
    private var instant = Date(timeIntervalSince1970: 1_794_317_520)

    var maintenant: Date { verrou.withLock { instant } }
    func avancer(_ secondes: TimeInterval) { verrou.withLock { instant += secondes } }
}

/// Ce que le magasin a écrit, fichier par fichier.
final class EcrituresDeTest: @unchecked Sendable {
    private let verrou = NSLock()
    private var recues: [String] = []

    var noms: [String] { verrou.withLock { recues } }
    func noter(_ nom: String) { verrou.withLock { recues.append(nom) } }
}

/// Un magasin dans un dossier jetable, à l'horloge du test.
struct MagasinDeTest {
    let racine = FileManager.default.temporaryDirectory.appending(path: "lectures-\(UUID().uuidString)")
    let horloge = HorlogeDeTest()
    let ecritures = EcrituresDeTest()

    func magasin(sessionGardee: Bool = true) -> LecturesGardees {
        LecturesGardees(
            racine: racine, horloge: { [horloge] in horloge.maintenant }, sessionGardee: { _ in sessionGardee },
            ecrire: { [ecritures, racine] donnees, dossier, nom in
                ecritures.noter(nom)
                // LA porte des fichiers de l'app, comme le magasin réel.
                _ = try Fichiers.ecrire(donnees, sous: [dossier], nom: nom, racine: racine)
            })
    }

    /// Les lectures du magasin, quel que soit l'hôte (l'index des dates n'en est pas une).
    var fichiers: [URL] { tousLesFichiers.filter { $0.lastPathComponent != "dates" } }

    var tousLesFichiers: [URL] {
        let parcours = FileManager.default.enumerator(at: racine, includingPropertiesForKeys: [.isRegularFileKey])
        return (parcours?.allObjects as? [URL] ?? []).filter {
            (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }
    }

    func nettoyer() { try? FileManager.default.removeItem(at: racine) }
}

private let jour: TimeInterval = 86_400

@Suite struct LectureGardeeTests {
    @Test func uneLectureGardeeSeRelitAvecSonTypeEtSaDate() throws {
        let banc = MagasinDeTest()
        defer { banc.nettoyer() }
        let magasin = banc.magasin()
        magasin.garder(Data("le fil".utf8), type: "application/json", cle: "get_flux /flux", de: "a.exemple")
        let lue = try #require(magasin.lire("get_flux /flux", de: "a.exemple"))
        #expect(lue.corps == Data("le fil".utf8))
        #expect(lue.type == "application/json")
        #expect(lue.date == banc.horloge.maintenant)
        #expect(magasin.lire("get_tickets /tickets", de: "a.exemple") == nil, "une autre clé ne rend rien")
    }

    @Test func chaqueResidenceASonDossier() {
        let banc = MagasinDeTest()
        defer { banc.nettoyer() }
        let magasin = banc.magasin()
        magasin.garder(Data("A".utf8), type: nil, cle: "get_flux /flux", de: "a.exemple")
        magasin.garder(Data("B".utf8), type: nil, cle: "get_flux /flux", de: "b.exemple")
        #expect(magasin.lire("get_flux /flux", de: "a.exemple")?.corps == Data("A".utf8))
        #expect(magasin.lire("get_flux /flux", de: "b.exemple")?.corps == Data("B".utf8))
        #expect(magasin.dossier("a.exemple") != magasin.dossier("b.exemple"))
        #expect(!magasin.dossier("a.exemple").path.contains("a.exemple"), "aucun nom d'hôte dans un chemin")

        magasin.effacer("a.exemple")
        #expect(magasin.lire("get_flux /flux", de: "a.exemple") == nil, "effacée")
        #expect(!FileManager.default.fileExists(atPath: magasin.dossier("a.exemple").path), "le dossier entier")
        #expect(magasin.lire("get_flux /flux", de: "b.exemple")?.corps == Data("B".utf8), "l'autre résidence reste")
    }

    @Test func chaqueFichierEstProtegeEtLeMagasinHorsDesSauvegardes() throws {
        let banc = MagasinDeTest()
        defer { banc.nettoyer() }
        let magasin = banc.magasin()
        magasin.garder(Data("le fil".utf8), type: nil, cle: "get_flux /flux", de: "a.exemple")
        magasin.garder(Data("les affaires".utf8), type: nil, cle: "get_tickets /tickets", de: "a.exemple")

        // Chaque écriture passe par LA porte des fichiers, sous la protection complète.
        #expect(banc.ecritures.noms.count == 4, "deux lectures, et l'index des dates à chaque fois")
        #expect(Fichiers.protection.contains(.completeFileProtection))
        #expect(Fichiers.protection.contains(.atomic))

        // Ce que le disque en DIT : hors des sauvegardes, la racine comme le dossier de l'hôte.
        for dossier in [banc.racine, magasin.dossier("a.exemple")] {
            let valeurs = try dossier.resourceValues(forKeys: [.isExcludedFromBackupKey])
            #expect(valeurs.isExcludedFromBackup == true, "\(dossier.lastPathComponent) exclu des sauvegardes")
        }
        let fichiers = banc.tousLesFichiers
        #expect(fichiers.count == 3, "deux lectures et l'index")
        // Le simulateur ne chiffre pas, mais il rend la classe demandée quand il la connaît :
        // jamais une classe plus faible que `.complete`.
        for fichier in fichiers {
            let classe = try FileManager.default.attributesOfItem(atPath: fichier.path)[.protectionKey]
            if let classe = classe as? FileProtectionType { #expect(classe == .complete) }
        }
    }

    @Test func sansProtectionPossibleRienNEstEcrit() {
        let banc = MagasinDeTest()
        defer { banc.nettoyer() }
        let magasin = LecturesGardees(
            racine: banc.racine, sessionGardee: { _ in true },
            ecrire: { _, _, _ in throw CocoaError(.fileWriteNoPermission) })
        magasin.garder(Data("le fil".utf8), type: nil, cle: "get_flux /flux", de: "a.exemple")
        #expect(banc.tousLesFichiers.isEmpty)
        #expect(magasin.consulter("a.exemple") == .aucune)
    }

    @Test func sansSessionGardeeRienNEstGarde() {
        let banc = MagasinDeTest()
        defer { banc.nettoyer() }
        let magasin = banc.magasin(sessionGardee: false)
        magasin.garder(Data("le fil".utf8), type: nil, cle: "get_flux /flux", de: "a.exemple")
        #expect(banc.tousLesFichiers.isEmpty, "sans Face ID pour la rouvrir, la lecture ne servirait à rien")
        #expect(!FileManager.default.fileExists(atPath: banc.racine.path))
    }

    @Test func leMagasinDeLAppNEstNiTemporaireNiDansLesCaches() {
        let racine = LecturesGardees.racineAppareil.path
        #expect(racine.contains("/Library/Application Support/"))
        #expect(!racine.hasPrefix(FileManager.default.temporaryDirectory.path))
        #expect(!racine.contains("/Caches/"))
    }

    // MARK: - Sept jours

    @Test func laDureeMaximaleEstDeSeptJours() {
        #expect(LectureGardee.joursMax == 7, "la proposition du ticket — à confirmer par Philippe")
        #expect(LectureGardee.dureeMax == 7 * jour)
    }

    @Test func uneLectureDeMoinsDeSeptJoursOuvreLaConsultation() {
        let banc = MagasinDeTest()
        defer { banc.nettoyer() }
        let magasin = banc.magasin()
        let gardeeLe = banc.horloge.maintenant
        magasin.garder(Data("le fil".utf8), type: nil, cle: "get_flux /flux", de: "a.exemple")
        banc.horloge.avancer(7 * jour - 1)
        #expect(!magasin.enConsultation("a.exemple"))
        #expect(magasin.consulter("a.exemple") == .gardee(gardeeLe), "la date de la dernière lecture fraîche")
        #expect(magasin.enConsultation("a.exemple"))
        #expect(magasin.lire("get_flux /flux", de: "a.exemple") != nil)
    }

    @Test func auDelaDeSeptJoursLaLectureEstEffaceeEtDite() {
        let banc = MagasinDeTest()
        defer { banc.nettoyer() }
        let magasin = banc.magasin()
        magasin.garder(Data("le fil".utf8), type: nil, cle: "get_flux /flux", de: "a.exemple")
        banc.horloge.avancer(7 * jour + 1)
        #expect(magasin.consulter("a.exemple") == .perimee)
        #expect(!magasin.enConsultation("a.exemple"), "rien ne s'ouvre")
        #expect(banc.tousLesFichiers.isEmpty, "effacée du disque, index compris")
        #expect(magasin.consulter("a.exemple") == .aucune, "dite une fois")
    }

    @Test func uneLectureFraicheNeSauvePasUneLectureTropAncienne() {
        let banc = MagasinDeTest()
        defer { banc.nettoyer() }
        let magasin = banc.magasin()
        magasin.garder(Data("une affaire".utf8), type: nil, cle: "get_tickets_ticket_id /tickets/41", de: "a.exemple")
        banc.horloge.avancer(7 * jour + 1)
        magasin.garder(Data("le fil".utf8), type: nil, cle: "get_flux /flux", de: "a.exemple")
        #expect(magasin.consulter("a.exemple") == .gardee(banc.horloge.maintenant))
        #expect(magasin.lire("get_flux /flux", de: "a.exemple") != nil)
        #expect(magasin.lire("get_tickets_ticket_id /tickets/41", de: "a.exemple") == nil, "trop ancienne")
        #expect(banc.fichiers.count == 1, "et effacée du disque")
    }

    // MARK: - Purger, retirer

    @Test func auLancementRienNeResteDUneResidenceSansSessionNiDUneLecturePerimee() {
        let banc = MagasinDeTest()
        defer { banc.nettoyer() }
        let magasin = banc.magasin()
        magasin.garder(Data("ancienne".utf8), type: nil, cle: "get_tickets /tickets", de: "a.exemple")
        banc.horloge.avancer(7 * jour + 1)
        magasin.garder(Data("fraîche".utf8), type: nil, cle: "get_flux /flux", de: "a.exemple")
        magasin.garder(Data("orpheline".utf8), type: nil, cle: "get_flux /flux", de: "b.exemple")

        magasin.purger(sauf: ["a.exemple"])
        #expect(banc.fichiers.count == 1, "il ne reste que la lecture fraîche de la résidence connectée")
        #expect(magasin.lire("get_flux /flux", de: "a.exemple")?.corps == Data("fraîche".utf8))
        #expect(!FileManager.default.fileExists(atPath: magasin.dossier("b.exemple").path))
    }

    @Test func uneLectureQueLeServeurNeSertPlusSeRetireSeule() {
        let banc = MagasinDeTest()
        defer { banc.nettoyer() }
        let magasin = banc.magasin()
        magasin.garder(Data("une affaire".utf8), type: nil, cle: "get_tickets_ticket_id /tickets/41", de: "a.exemple")
        magasin.garder(Data("le fil".utf8), type: nil, cle: "get_flux /flux", de: "a.exemple")
        magasin.retirer("get_tickets_ticket_id /tickets/41", de: "a.exemple")
        #expect(magasin.lire("get_tickets_ticket_id /tickets/41", de: "a.exemple") == nil)
        #expect(magasin.lire("get_flux /flux", de: "a.exemple") != nil)
    }

    @Test func effacerSortAussiDeLaConsultation() {
        let banc = MagasinDeTest()
        defer { banc.nettoyer() }
        let magasin = banc.magasin()
        magasin.garder(Data("le fil".utf8), type: nil, cle: "get_flux /flux", de: "a.exemple")
        _ = magasin.consulter("a.exemple")
        magasin.effacer("a.exemple")
        #expect(!magasin.enConsultation("a.exemple"))
        #expect(magasin.consulter("a.exemple") == .aucune)
    }
}
