// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// Le lot 3 de #226 : la dernière cloche gardée pour le hors ligne, et le résumé du widget.
@MainActor
struct HorsLigneEtWidgetTests {
    private let adresse = URL(string: "https://tilleuls.example.com")!

    private func alerte(_ id: Int, lue: Bool = false, urgente: Bool = false) -> NotificationRecue {
        NotificationRecue(
            id: id, type: "ticket_update", titre: "Alerte \(id)", corps: "<p>Texte</p>", lue: lue, urgente: urgente,
            creeLe: Date(timeIntervalSince1970: 1_800_000_000))
    }

    // MARK: - La garde

    @Test func uneClocheGardeeNeSeMontreQuePourSaResidenceEtSeptJours() {
        let maintenant = Date(timeIntervalSince1970: 1_900_000_000)
        let garde = GardeEnMemoire(ClocheGardee(adresse: adresse, alertes: [alerte(1)], aJourAu: maintenant - 3_600))
        #expect(garde.consultable(pour: adresse, maintenant: maintenant) != nil)
        #expect(garde.consultable(pour: URL(string: "https://glycines.example.com")!, maintenant: maintenant) == nil)
        let tard = maintenant + LectureGardee.dureeMax
        #expect(garde.consultable(pour: adresse, maintenant: tard) == nil, "plus de sept jours : effacée")
        #expect(garde.lire() == nil, "et rien n'en reste")
    }

    @Test func laGardeSurDisqueRelitCeQuElleAEcritPuisEfface() throws {
        let dossier = FileManager.default.temporaryDirectory.appending(path: "garde-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dossier) }
        let garde = GardeSurDisque(dossier: dossier)
        let cloche = ClocheGardee(adresse: adresse, alertes: [alerte(1), alerte(2, lue: true)], aJourAu: .now)
        garde.garder(cloche)
        #expect(garde.lire() == cloche)
        let exclu = try dossier.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup
        #expect(exclu == true, "hors des sauvegardes")
        garde.effacer()
        #expect(garde.lire() == nil)
    }

    @Test func sansReseauLaClocheGardeeSeMontreDatee() async {
        let gardee = ClocheGardee(
            adresse: ClocheSimulee.adresse, alertes: [alerte(1, urgente: true)], aJourAu: .now - 600)
        var publies: [ResumeCloche] = []
        let lecteur = LecteurCloche(
            source: .simulee(.horsLigne), garde: GardeEnMemoire(gardee), publier: { publies.append($0) })
        await lecteur.lire()
        #expect(lecteur.lecture == .horsLigne(Cloche(gardee.alertes), aJourAu: gardee.aJourAu))
        #expect(publies == [.compte(nonLues: 1, urgentes: 1)], "le widget compte la cloche gardée")
    }

    @Test func sansReseauNiGardeLaResidenceSeDitInjoignable() async {
        var publies: [ResumeCloche] = []
        let lecteur = LecteurCloche(
            source: .simulee(.horsLigne), garde: GardeEnMemoire(), publier: { publies.append($0) })
        await lecteur.lire()
        #expect(lecteur.lecture == .injoignable)
        #expect(publies == [.injoignable])
    }

    @Test func enLigneLaClocheSeGardeEtUnRefusLEfface() async {
        let garde = GardeEnMemoire()
        let lecteur = LecteurCloche(source: .simulee(.boite(nombre: 4)), garde: garde)
        await lecteur.lire()
        #expect(garde.lire()?.alertes.count == 4)
        #expect(garde.lire()?.adresse == ClocheSimulee.adresse)
        var rendue = false
        let refuse = LecteurCloche(source: .simulee(.refusee), garde: garde, auRefus: { rendue = true })
        await refuse.lire()
        #expect(rendue)
        #expect(garde.lire() == nil, "un jeton refusé ne laisse rien au poignet")
    }

    @Test func laMontreQuiNEstPlusRelieeOublieSaCloche() {
        var publies: [ResumeCloche] = []
        let garde = GardeEnMemoire(ClocheGardee(adresse: adresse, alertes: [alerte(1)], aJourAu: .now))
        let montre = LiaisonDeLaMontre(
            coffre: LiaisonEnMemoire(), garde: garde,
            surfaces: Surfaces(ecrire: { publies.append($0); return true }, recharger: {}), active: true)
        montre.recevoir(
            .liaison(adresse: adresse, residence: "R", jeton: "j", expireLe: .now.addingTimeInterval(86_400)))
        montre.jetonRefuse()
        #expect(garde.lire() == nil)
        #expect(publies == [.nonReliee])
    }

    // MARK: - Le résumé du widget

    @Test func laPhraseDuWidgetNeDitQueDesNombres() {
        #expect(ResumeCloche.compte(nonLues: 0, urgentes: 0).phrase == TextesMontre.aucuneAlerte)
        #expect(ResumeCloche.compte(nonLues: 1, urgentes: 0).phrase == "1 nouvelle alerte")
        #expect(ResumeCloche.compte(nonLues: 2, urgentes: 1).phrase == "2 nouvelles alertes ·\u{00A0}dont 1 urgente")
        #expect(ResumeCloche.compte(nonLues: 3, urgentes: 2).phrase == "3 nouvelles alertes ·\u{00A0}dont 2 urgentes")
        #expect(ResumeCloche.nonReliee.phrase == TextesMontre.nonReliee)
        #expect(ResumeCloche.injoignable.phrase == TextesMontre.injoignable)
    }

    @Test func lePointNeSAllumeQuAuNonLu() {
        #expect(ResumeCloche.compte(nonLues: 1, urgentes: 0).pointNonLu)
        #expect(!ResumeCloche.compte(nonLues: 0, urgentes: 0).pointNonLu)
        #expect(!ResumeCloche.nonReliee.pointNonLu)
        #expect(!ResumeCloche.injoignable.pointNonLu)
    }

    @Test func leResumePasseParLeDossierDuGroupe() throws {
        let dossier = FileManager.default.temporaryDirectory.appending(path: "groupe-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dossier) }
        #expect(PartageDuResume.lire(dossier) == .nonReliee, "rien d'écrit : non reliée")
        #expect(PartageDuResume.ecrire(.compte(nonLues: 2, urgentes: 1), dossier))
        #expect(PartageDuResume.lire(dossier) == .compte(nonLues: 2, urgentes: 1))
        #expect(!PartageDuResume.ecrire(.injoignable, nil), "sans conteneur de groupe, rien ne s'écrit")
    }

    @Test func leWidgetNeSeRechargeQueSiLeResumeChange() {
        var recharges = 0
        let surfaces = Surfaces(ecrire: { _ in true }, recharger: { recharges += 1 })
        surfaces.publier(.compte(nonLues: 1, urgentes: 0))
        surfaces.publier(.compte(nonLues: 1, urgentes: 0))
        surfaces.publier(.injoignable)
        #expect(recharges == 2)
    }
}
