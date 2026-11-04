// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

// MARK: - Liste

@Test func laListeNeMontreQueLesAffairesActives() {
    let affaires = ServiceSimule.affaires
    let liste = affaires.liste(filtres: .init(), options: [], trouvees: nil, avecArchives: false)
    #expect(!liste.isEmpty)
    #expect(liste.allSatisfy { !$0.archivee }, "les archivées vivent dans leur onglet")
    #expect(liste.count == affaires.filter { !$0.archivee }.count)
}

@Test func leSuiviNOffreQueLesEtatsPresentsEtReunitLesGroupes() {
    let actives = ServiceSimule.affaires.filter { !$0.archivee }
    let options = OptionDeSuivi.presentes(dans: actives)
    // en_ag, en_cours et chez_prestataire se réunissent sous « En cours » (GROUPES_SUIVI).
    #expect(options.map(\.code) == ["ouvert", "en_cours", "résolu", "annulé"])
    #expect(options.first { $0.code == "en_cours" }?.statuts == ["en_ag", "en_cours", "chez_prestataire"])
    #expect(!options.contains { $0.code == "publie" }, "une actualité n'a pas d'état de suivi")
}

@Test func leFiltreDeSuiviRetientLesStatutsDeSonOption() {
    let affaires = ServiceSimule.affaires
    let options = OptionDeSuivi.presentes(dans: affaires.filter { !$0.archivee })
    var filtres = FiltresAffaires()
    filtres.suivi = "en_cours"
    let retenues = affaires.liste(filtres: filtres, options: options, trouvees: nil, avecArchives: false)
    #expect(Set(retenues.map(\.statut)) == ["en_ag", "en_cours", "chez_prestataire"])
}

@Test func laNatureEtLaPorteeFiltrentCommeLeSite() {
    let affaires = ServiceSimule.affaires
    var filtres = FiltresAffaires(nature: "actualite")
    let actualites = affaires.liste(filtres: filtres, options: [], trouvees: nil, avecArchives: false)
    #expect(!actualites.isEmpty && actualites.allSatisfy { $0.estActualite })
    filtres = FiltresAffaires(meConcerne: true)
    let miennes = affaires.liste(filtres: filtres, options: [], trouvees: nil, avecArchives: false)
    // `selonPortee` : seule une affaire DITE étrangère sort — `nil` reste.
    #expect(miennes.allSatisfy { $0.meConcerne != false })
    #expect(miennes.contains { $0.meConcerne == nil })
}

@Test func laRechercheGardeLOrdreDuServeurEtProposeLesArchives() {
    let affaires = ServiceSimule.affaires
    let trouvees = [35, 22, 41]  // 22 est archivée
    let sans = affaires.liste(filtres: .init(), options: [], trouvees: trouvees, avecArchives: false)
    #expect(sans.map(\.id) == [35, 41], "l'ordre est la pertinence du serveur")
    let avec = affaires.liste(filtres: .init(), options: [], trouvees: trouvees, avecArchives: true)
    #expect(avec.map(\.id) == [35, 22, 41])
}

// MARK: - Archives et Kanban

@Test func lesArchivesSeRangentParAnneeSurTroisAns() throws {
    let calendrier = Chronologie.calendrier
    let jour = try #require(calendrier.date(from: DateComponents(year: 2026, month: 11, day: 4)))
    func archivee(_ id: Int, _ annee: Int, _ mois: Int) -> Affaire {
        let date = calendrier.date(from: DateComponents(year: annee, month: mois, day: 1)) ?? jour
        return Affaire(
            id: id, numero: "A-\(id)", titre: "", apercu: "", creeLe: date, misAJourLe: date, statut: "résolu",
            categorie: "panne", urgente: false, meConcerne: false, archivee: true, suiviKanban: false, natures: [],
            prestataire: nil, perimetres: [], lieu: nil, messages: nil)
    }
    let affaires = [archivee(1, 2025, 3), archivee(2, 2026, 2), archivee(3, 2026, 9), archivee(4, 2022, 1)]
    let groupes = affaires.archives(au: jour, calendrier: calendrier)
    #expect(groupes.map(\.annee) == [2026, 2025], "la plus récente d'abord ; 2022 sort des trois ans")
    #expect(groupes.first?.affaires.map(\.id) == [3, 2])
}

@Test func leKanbanNePrendQueLesAffairesSuiviesActivesEtRangees() {
    let kanban = ServiceSimule.affaires.auKanban
    #expect(kanban.allSatisfy { $0.suiviKanban && !$0.archivee && $0.colonne != nil })
    #expect(!kanban.contains { $0.statut == "publie" }, "un statut sans colonne sort du tableau")
}

@Test func lesColonnesEtLesStatutsSeRepondent() {
    // L'inverse est dérivé : chaque colonne atteinte pose un statut qui y ramène.
    for (colonne, statut) in TablesAffaires.statutParColonne {
        #expect(TablesAffaires.colonneParStatut[statut] == colonne)
    }
    // La colonne « fournisseur » est atteinte par chez_prestataire (#1092).
    #expect(TablesAffaires.statutParColonne["fournisseur"] == "chez_prestataire")
    #expect(Set(TablesAffaires.colonnesKanban.map(\.id)) == Set(TablesAffaires.colonneParStatut.values))
}

// MARK: - Droits

@Test func modererEstLeConseilOuLAdministration() {
    let resident = DroitsAffaires(profil: .init(statut: "copropriétaire_résident", roles: ["résident"]))
    let conseil = DroitsAffaires(profil: .init(statut: "copropriétaire_résident", roles: ["conseil_syndical"]))
    let admin = DroitsAffaires(profil: .init(statut: nil, roles: ["admin"]))
    #expect(!resident.moderateur)
    #expect(conseil.moderateur && admin.moderateur)
    #expect(!DroitsAffaires(profil: nil).moderateur, "sans profil, rien n'est offert")
}

@Test func leKanbanEstFermeAuxLocatairesEtAuProfilInconnu() {
    func ouvre(_ profil: ProfilResidence?) -> Bool {
        DroitsAffaires(profil: profil).onglets.contains { $0.id == "kanban" }
    }
    #expect(!ouvre(.init(statut: "locataire", roles: ["résident"])))
    #expect(ouvre(.init(statut: "copropriétaire_bailleur", roles: [])))
    #expect(!ouvre(nil), "profil non lu : l'onglet réservé reste caché")
    #expect(DroitsAffaires(profil: nil).onglets.map(\.id) == ["liste", "archives"])
}

@Test func lesCategoriesReserveesNeSontOffertesQuAuConseil() {
    let resident = DroitsAffaires(profil: .init(statut: "locataire", roles: ["résident"]))
    let conseil = DroitsAffaires(profil: .init(statut: nil, roles: ["conseil_syndical"]))
    #expect(!resident.categories.contains { $0.reserveCS })
    #expect(conseil.categories.count == TablesAffaires.categories.count)
    #expect(conseil.categories.first?.code == "actualite", "« Actualité » en tête")
}

// MARK: - Création

@Test func laDescriptionPartEnParagraphesSansBaliseSaisie() {
    let saisie = SaisieAffaire(
        categorie: "panne", titre: "  Fuite  ", description: "Ligne 1\nligne 2\n\n<b>a & b</b>", urgente: false)
    #expect(saisie.descriptionHTML == "<p>Ligne 1<br>ligne 2</p><p>&lt;b&gt;a &amp; b&lt;/b&gt;</p>")
    #expect(saisie.complete)
    #expect(!SaisieAffaire(categorie: "panne", titre: " ", description: "x", urgente: false).complete)
}

@Test func lePerimetreParDefautEstLaPremiereRacineGlobale() {
    #expect(ServiceSimule.perimetres.parDefaut?.code == "copropriete")
}

// MARK: - Gestes, sur l'installation simulée

@MainActor
@Test func archiverEnvoieLaffaireAuxArchives() async throws {
    let etat = EtatAffaires()
    let service = ServiceSimule(delai: .zero)
    await etat.charger(ServiceSimule.residence, avec: service)
    let affaire = try #require(etat.liste.first { $0.id == 35 })
    await etat.archiver(affaire, dans: ServiceSimule.residence, avec: service)
    #expect(!etat.liste.contains { $0.id == 35 })
    #expect(etat.archives.flatMap(\.affaires).contains { $0.id == 35 })
    #expect(etat.avis == nil)
}

@MainActor
@Test func deplacerChangeLaColonneEtRetombeSurUneOptionPresente() async throws {
    let etat = EtatAffaires()
    let service = ServiceSimule(delai: .zero)
    await etat.charger(ServiceSimule.residence, avec: service)
    let ouvertes = etat.affaires.filter { $0.statut == "ouvert" && !$0.archivee }
    etat.filtres.suivi = "ouvert"
    for affaire in ouvertes {
        await etat.deplacer(affaire, vers: "en_ag", dans: ServiceSimule.residence, avec: service)
    }
    #expect(etat.affaires.filter { ouvertes.map(\.id).contains($0.id) }.allSatisfy { $0.colonne == "ag" })
    #expect(etat.filtres.suivi == nil, "plus aucune affaire ouverte : on retombe sur « Toutes »")
}

@MainActor
@Test func unServiceSansLeMenuSeDitAuLieuDeSeTaire() async {
    let etat = EtatAffaires()
    await etat.charger(ServiceSimule.residence, avec: nil)
    #expect(etat.phase == .erreur(.serviceAbsent))
}

@MainActor
@Test func uneResidenceConnueNApparaitQuUneFois() throws {
    let suite = "tests.\(UUID().uuidString)"
    let reglages = try #require(UserDefaults(suiteName: suite))
    defer { reglages.removePersistentDomain(forName: suite) }
    let connues = InstallationsConnues(reglages: reglages)
    let residence = ServiceSimule.residence
    connues.retenir(residence)
    connues.retenir(Installation(adresse: URL(string: "https://autre.exemple.fr")!, nom: "Autre", aUnLogo: false))
    connues.retenir(residence)
    #expect(connues.liste.map(\.nom) == [residence.nom, "Autre"])
    #expect(InstallationsConnues(reglages: reglages).liste.count == 2, "relue au lancement suivant")
}
