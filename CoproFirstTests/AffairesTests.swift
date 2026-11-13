// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import Testing

@testable import CoproFirst

// MARK: - Liste

@Test func laListeNeMontreQueLesAffairesActives() {
    let affaires = Apercu.affaires
    let liste = affaires.liste(filtres: .init(), options: [], trouvees: nil, avecArchives: false)
    #expect(!liste.isEmpty)
    #expect(liste.allSatisfy { !$0.archivee }, "les archivées vivent dans leur onglet")
    #expect(liste.count == affaires.filter { !$0.archivee }.count)
}

@Test func leSuiviNOffreQueLesEtatsPresentsEtReunitLesGroupes() throws {
    let actives = Apercu.affaires.filter { !$0.archivee }
    let options = OptionDeSuivi.presentes(dans: actives, servis: try FixturesReferentielsAffaires.lus().statuts)
    // en_ag, en_cours et chez_prestataire se réunissent sous « En cours » (GROUPES_SUIVI).
    #expect(options.map(\.code) == ["ouvert", "en_cours", "résolu", "annulé"])
    #expect(options.first { $0.code == "en_cours" }?.statuts == ["en_ag", "en_cours", "chez_prestataire"])
    #expect(!options.contains { $0.code == "publie" }, "une actualité n'a pas d'état de suivi")
}

@Test func leFiltreDeSuiviRetientLesStatutsDeSonOption() throws {
    let affaires = Apercu.affaires
    let options = OptionDeSuivi.presentes(
        dans: affaires.filter { !$0.archivee }, servis: try FixturesReferentielsAffaires.lus().statuts)
    var filtres = FiltresAffaires()
    filtres.suivi = "en_cours"
    let retenues = affaires.liste(filtres: filtres, options: options, trouvees: nil, avecArchives: false)
    #expect(Set(retenues.map(\.statut)) == ["en_ag", "en_cours", "chez_prestataire"])
}

@Test func laNatureEtLaPorteeFiltrentCommeLeSite() {
    let affaires = Apercu.affaires
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
    let affaires = Apercu.affaires
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
            statutLibelle: "Résolu", close: true, categorie: "panne", categorieLibelle: "Panne", urgente: false,
            meConcerne: false,
            archivee: true, suiviKanban: false, natures: [], prestataires: [], perimetres: [], lieu: nil,
            messages: nil, colonne: "termine", peutDeplacer: false, peutArchiver: false)
    }
    let affaires = [archivee(1, 2025, 3), archivee(2, 2026, 2), archivee(3, 2026, 9), archivee(4, 2022, 1)]
    let groupes = affaires.archives(au: jour, calendrier: calendrier)
    #expect(groupes.map(\.annee) == [2026, 2025], "la plus récente d'abord ; 2022 sort des trois ans")
    #expect(groupes.first?.affaires.map(\.id) == [3, 2])
}

@Test func leKanbanNePrendQueLesAffairesSuiviesActivesEtRangees() {
    let kanban = Apercu.affaires.auKanban
    #expect(kanban.allSatisfy { $0.suiviKanban && !$0.archivee && $0.colonne != nil })
    #expect(!kanban.contains { $0.statut == "publie" }, "un statut sans colonne sort du tableau")
}

/// L'état qu'une colonne pose se lit dans les référentiels SERVIS (`GET /tickets/referentiels`,
/// #83) : plus aucune table colonne ⇄ statut dans l'app. Remplace le test de la table générée
/// `colonneParStatut`, qui décrivait le recalcul retiré.
@Test func chaqueColonneServiePoseUnEtatServiQuiYRamene() throws {
    let servis = try FixturesReferentielsAffaires.lus()
    #expect(servis.colonnes.map(\.id) == ["ag", "cs", "syndic", "fournisseur", "termine", "annule"])
    for colonne in servis.colonnes {
        let statut = try #require(servis.statut(pourColonne: colonne.id), "\(colonne.id) : aucun état n'y mène")
        #expect(statut.colonne == colonne.id)
    }
    // La colonne « fournisseur » est atteinte par chez_prestataire (#1092).
    #expect(servis.statut(pourColonne: "fournisseur")?.code == "chez_prestataire")
    #expect(servis.statut(pourColonne: "termine")?.clos == true, "« Terminé » clôt : le serveur le dit")
    #expect(servis.statut(pourColonne: "inconnue") == nil)
    // Une colonne neuve, que le site ne teinte pas encore, garde un trait neutre.
    #expect(ColonneKanban(id: "neuve", libelle: "Neuve", libelleCourt: "N").teinte == \Palette.border)
}

/// `Apercu.affaires` écrit en données ce que le serveur sert (colonne, clôture, libellé) :
/// il doit dire la même chose que les référentiels simulés, sans quoi la démo mentirait.
@Test func lApercuEstServiCommeLesReferentielsSimules() throws {
    let servis = try FixturesReferentielsAffaires.lus()
    for affaire in Apercu.affaires {
        let statut = try #require(servis.statuts.first { $0.code == affaire.statut }, "\(affaire.statut) : inconnu")
        #expect(affaire.colonne == statut.colonne, "A-\(affaire.id) : colonne")
        #expect(affaire.close == statut.clos, "A-\(affaire.id) : clôture")
        #expect(affaire.categorieLibelle == servis.categorie(affaire.categorie)?.libelle, "A-\(affaire.id) : libellé")
        #expect(affaire.statutLibelle == statut.libelle, "A-\(affaire.id) : libellé de l'état servi (#105)")
    }
}

/// La colonne, le libellé de la catégorie, le lieu et les gestes se LISENT dans
/// `TicketRead` : un serveur qui range « ouvert » ailleurs que l'ancienne table est suivi.
@Test func colonneLibelleLieuEtGestesSontLusDansLAffaireServie() async throws {
    let json = #"""
        [{"id": 9, "numero": "TK-9", "titre": "Essai", "description": "", "categorie": "panne", "statut": "ouvert",
          "suivi_actualite_libelle": "", "frequence_libelle": "",
          "priorite": "normale", "cree_le": "2026-11-02T09:00:00", "urgente": false,
          "categorie_libelle": "Panne (servie)", "statut_libelle": "Ouvert", "close": false,
          "colonne_kanban": "ag", "nouveau": false, "nom_proprietaire": "Camille Essai",
          "perimetre_libelle": "Bât. 2 › Toit", "peut_deplacer_au_kanban": true, "peut_archiver": true},
         {"id": 10, "numero": "TK-10", "titre": "Essai", "description": "", "categorie": "panne", "statut": "ouvert",
          "suivi_actualite_libelle": "", "frequence_libelle": "",
          "priorite": "normale", "cree_le": "2026-11-02T09:00:00", "urgente": false, "categorie_libelle": "Panne",
          "statut_libelle": "Ouvert", "close": false, "colonne_kanban": null, "nouveau": false,
          "nom_proprietaire": "Camille Essai", "perimetre_libelle": ""}]
        """#
    let lues = try await client(servant: json).getTickets().ok.body.json.map { Affaire(ticket: $0) }
    let servie = try #require(lues.first)
    #expect(servie.colonne == "ag", "la colonne servie, pas celle d'une table")
    #expect(servie.categorieLibelle == "Panne (servie)")
    #expect(servie.lieu == "Bât. 2 › Toit")
    #expect(servie.peutDeplacer && servie.peutArchiver)
    let muette = try #require(lues.last)
    #expect(muette.colonne == nil, "hors tableau : le serveur le dit")
    #expect(muette.lieu == nil, "périmètre par défaut : le serveur le tait")
    #expect(!muette.peutDeplacer && !muette.peutArchiver, "un geste non servi n'est pas offert")
}

// MARK: - Droits

/// « Est du conseil », pour la saisie, se LIT (#105) : c'est le compte à qui le serveur permet
/// une catégorie qu'il réserve (`reservee` ET `permise`). Remplace
/// `modererEstLeConseilOuLAdministration`, qui éprouvait le prédicat retiré
/// (`DroitsAffaires.moderateur`, déduit des rôles du profil).
@Test func poserLesReserveesSeLitDansLesCategoriesServies() throws {
    #expect(try FixturesReferentielsAffaires.lus(moderateur: true).poseLesReservees)
    #expect(try !FixturesReferentielsAffaires.lus(moderateur: false).poseLesReservees)
    #expect(!ReferentielsAffaires.vides.poseLesReservees, "rien de servi : rien n'est offert")
    // Le cas fautif : un serveur qui ouvre une catégorie réservée à un compte que ses rôles
    // ne disent pas du conseil. Seul ce qu'il sert compte — aucun profil n'entre ici.
    func servie(reservee: Bool, permise: Bool) -> ReferentielsAffaires {
        let entretien = ReferentielsAffaires.Categorie(
            code: "entretien", libelle: "Entretien", emoji: "", reservee: reservee, permise: permise)
        return ReferentielsAffaires(colonnes: [], statuts: [], categories: [entretien])
    }
    #expect(servie(reservee: true, permise: true).poseLesReservees)
    #expect(!servie(reservee: true, permise: false).poseLesReservees)
    #expect(!servie(reservee: false, permise: true).poseLesReservees, "une catégorie ouverte à tous ne dit rien")
}

@Test func leKanbanEstFermeAuxLocatairesEtAuProfilInconnu() {
    // Les listes d'onglets sont calculées HORS de la macro, puis comparées. Sous Xcode
    // 26.6 (CI), `#expect(!ouvre(x))` (fonction locale niée) échouait avec un résultat
    // « <not evaluated> », vert sous Xcode 27.2 : cause non établie. Une liste comparée
    // dit, en cas d'échec, quels onglets étaient réellement ouverts.
    let locataire = DroitsAffaires(profil: .init(statut: "locataire", roles: ["résident"])).onglets.map(\.id)
    let bailleur = DroitsAffaires(profil: .init(statut: "copropriétaire_bailleur", roles: [])).onglets.map(\.id)
    let inconnu = DroitsAffaires(profil: nil).onglets.map(\.id)
    #expect(locataire == ["liste", "archives"])
    #expect(bailleur == ["liste", "kanban", "archives"])
    #expect(inconnu == ["liste", "archives"], "profil non lu : l'onglet réservé reste caché")
}

/// Les catégories offertes se LISENT (`permise`, #105) : plus de règle « réservée au conseil »
/// recalculée ici. Les référentiels simulés servent un résident comme le vrai serveur.
@Test func lesCategoriesOffertesSontCellesQueLeServeurPermet() throws {
    let conseil = try FixturesReferentielsAffaires.lus(moderateur: true)
    let resident = try FixturesReferentielsAffaires.lus(moderateur: false)
    #expect(conseil.permises.count == conseil.categories.count, "le conseil peut tout poser")
    #expect(conseil.permises.first?.code == "actualite", "« Actualité » en tête (`en_tete`)")
    let reservees = Set(resident.categories.filter { !$0.permise }.map(\.code))
    #expect(!reservees.isEmpty)
    #expect(
        resident.permises.allSatisfy { !reservees.contains($0.code) }, "une catégorie non permise n'est pas offerte")
}

@Test func lesEtatsEtLeursLibellesSontServis() throws {
    let servis = try FixturesReferentielsAffaires.lus()
    #expect(servis.proposables.map(\.code) == ["ouvert", "en_ag", "en_cours", "chez_prestataire", "résolu", "annulé"])
    // L'état en clair, par sa seule écriture (#127, #105) : servi avec l'objet d'abord,
    // sinon par les référentiels servis, sinon le code — plus aucune table du site.
    #expect(StatutsAffaire.libelle("en_cours", servi: "En cours (servi)", dans: servis) == "En cours (servi)")
    #expect(StatutsAffaire.libelle("en_cours", servi: nil, dans: servis) == "Chez le syndic")
    #expect(StatutsAffaire.libelle("en_cours", servi: "", dans: servis) == "Chez le syndic", "vide : pas servi")
    #expect(StatutsAffaire.libelle("inconnu", servi: nil, dans: servis) == "inconnu", "jamais vide")
    #expect(StatutsAffaire.libelle("en_cours", servi: nil, dans: .vides) == "en_cours", "rien de servi : le code")
}

/// Glisser une carte au Kanban pose l'état ET son libellé servi : la pastille de la liste
/// ne garde pas l'ancien (le défaut de la mise à jour immédiate, #105).
@MainActor
@Test func deplacerPoseLeLibelleServiDeLEtat() async throws {
    let etat = EtatAffaires()
    let service = ServiceSimule(delai: .zero)
    await etat.charger(ServiceSimule.residence, avec: service)
    let affaire = try #require(etat.affaires.first { $0.statut == "ouvert" && !$0.archivee })
    let versAG = try #require(etat.referentiels?.statut(pourColonne: "ag"))
    await etat.deplacer(affaire, vers: versAG, dans: ServiceSimule.residence, avec: service)
    let deplacee = try #require(etat.affaires.first { $0.id == affaire.id })
    #expect(deplacee.statut == versAG.code && deplacee.statutLibelle == versAG.libelle)
}

// MARK: - Création

@Test func laDescriptionPartEnParagraphesSansBaliseSaisie() {
    let saisie = SaisieAffaire(
        categorie: "panne", titre: "  Fuite  ", description: "Ligne 1\nligne 2\n\n<b>a & b</b>", urgente: false)
    #expect(saisie.descriptionHTML == "<p>Ligne 1<br>ligne 2</p><p>&lt;b&gt;a &amp; b&lt;/b&gt;</p>")
    #expect(saisie.complete)
    #expect(!SaisieAffaire(categorie: "panne", titre: " ", description: "x", urgente: false).complete)
}

/// Un seul modèle de périmètre (#41) : le carnet et le lieu d'une affaire lisent la
/// même liste, par la même méthode des deux services.
@Test func lePerimetreEstUnSeulModelePourLesDeuxMenus() async throws {
    let service = ServiceSimule(delai: .zero)
    let residence: any ServiceResidence = service
    let affaires: any ServiceAffaires = service
    let duCarnet = try await residence.perimetres(ServiceSimule.residence)
    let deLAffaire = try await affaires.perimetres(ServiceSimule.residence)
    let arbre = try FixturesPerimetres.lus()
    #expect(duCarnet == deLAffaire && duCarnet == arbre)
    let _: any ServicePerimetres = ServiceAPI()
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
    let versAG = try #require(etat.referentiels?.statut(pourColonne: "ag"), "référentiels servis et lus")
    for affaire in ouvertes {
        await etat.deplacer(affaire, vers: versAG, dans: ServiceSimule.residence, avec: service)
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
    let coffre = CoffreEnMemoire()
    let connues = InstallationsConnues(reglages: reglages, coffre: coffre)
    let residence = ServiceSimule.residence
    connues.retenir(residence)
    connues.retenir(Installation(adresse: URL(string: "https://autre.exemple.fr")!, nom: "Autre", aUnLogo: false))
    connues.retenir(residence)
    #expect(connues.liste.map(\.nom) == [residence.nom, "Autre"])
    #expect(InstallationsConnues(reglages: reglages, coffre: coffre).liste.count == 2, "relue au lancement suivant")
}

// MARK: - Ce que le serveur sert depuis le contrat 1.8.0 (#54)

/// Le lieu présélectionné est celui que le serveur DÉSIGNE (`par_defaut`) : l'app ne
/// refait pas le tri des racines ; sans désignation, aucun.
@Test func lePerimetreParDefautEstCeluiQueLeServeurDesigne() throws {
    let arbre = try FixturesPerimetres.lus()
    #expect(Perimetre.codeParDefaut(arbre) == "copropriete")
    let sansDefaut = arbre.map { Perimetre(code: $0.code, libelle: $0.libelle) }
    #expect(Perimetre.codeParDefaut(sansDefaut) == nil)
    #expect(Perimetre.codeParDefaut([]) == nil, "un arbre vide n'a pas de défaut")
}

/// « Close » et « urgente » se lisent dans `TicketRead` : l'app ne compare plus le statut
/// à une liste d'états clos, ni la priorité à « haute ».
@Test func closeEtUrgenteSontLusDansLAffaireServie() async throws {
    // L'état historique `fermé` n'est PAS clos pour le serveur (#54) ; et une priorité
    // « normale » peut être urgente : seul ce que le serveur sert compte.
    let json = #"""
        [{"id": 9, "numero": "TK-9", "titre": "Essai", "description": "", "categorie": "panne", "statut": "fermé",
          "suivi_actualite_libelle": "", "frequence_libelle": "",
          "priorite": "normale", "cree_le": "2026-11-02T09:00:00", "urgente": true, "categorie_libelle": "Panne",
          "statut_libelle": "Fermé", "close": false, "colonne_kanban": null, "nouveau": false,
          "nom_proprietaire": "Camille Essai"}]
        """#
    let lue = try #require(try await client(servant: json).getTickets().ok.body.json.first)
    let affaire = Affaire(ticket: lue)
    #expect(!affaire.close && affaire.urgente)
}
