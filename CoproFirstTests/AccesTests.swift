// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// « Mes lots & accès » et « Prestataires » (#13) : services, droits, formats, règles.

/// Les deux services de l'app réalisent les services des deux menus — sinon l'écran
/// tomberait sur « Bientôt » (`Parcours.serviceAcces`).
@Test func lesDeuxServicesRealisentLesMenus() {
    let services: [any ServiceCoproFirst] = [ServiceAPI(), ServiceSimule(delai: .zero)]
    for service in services {
        #expect(service is any ServiceAcces)
        #expect(service is any ServicePrestataires)
    }
}

@MainActor
@Test func lesDeuxMenusSontInscrits() {
    #expect(RegistreDesMenus.ecrans["mon-lot"] == AccesView.self)
    #expect(RegistreDesMenus.ecrans["prestataires"] == PrestatairesView.self)
}

// MARK: - Droits : ce qui s'affiche selon ce que l'on est

@Test func leLocataireNeGerePasDeBaux() {
    let droits = DroitsAcces(ProfilResidence(statut: "locataire", roles: ["résident"]))
    #expect(droits.locataire)
    #expect(droits.baux == nil)
    #expect(!droits.voitLocation(bauxTermines: 3))
}

@Test func leBailleurLitSesBauxEtVoitLaGestionLocative() {
    let droits = DroitsAcces(ProfilResidence(statut: "copropriétaire_bailleur", roles: ["propriétaire"]))
    #expect(droits.baux == .siens)
    #expect(droits.voitLocation(bauxTermines: 0))
}

@Test func leResidentNeVoitLaGestionLocativeQuAvecDesBauxTermines() {
    let droits = DroitsAcces(ProfilResidence(statut: "copropriétaire_résident", roles: ["propriétaire"]))
    #expect(!droits.voitLocation(bauxTermines: 0))
    #expect(droits.voitLocation(bauxTermines: 1))
}

@Test func leConseilLitTousLesBauxSAilNEstPasCoproprietaire() {
    let conseil = DroitsAcces(ProfilResidence(statut: nil, roles: ["conseil_syndical"]))
    #expect(conseil.baux == .tous)
    // Copropriétaire ET conseil : ses baux d'abord, comme `lireBaux` du site.
    let lesDeux = DroitsAcces(ProfilResidence(statut: "copropriétaire_bailleur", roles: ["conseil_syndical"]))
    #expect(lesDeux.baux == .siens)
}

/// « Nouvel accès » n'est offert qu'à qui a un lot : la route exige qu'il soit le sien.
@Test func nouvelAccesExigeUnLot() {
    let droits = DroitsAcces(nil)
    #expect(!droits.peutDemander(lots: []))
    #expect(droits.peutDemander(lots: LotsSimules.lots))
}

@Test func uneDemandeHorsDeSesLotsEstRefusee() async {
    let service = ServiceSimule(delai: .zero)
    let voisin = DemandeAcces(type: .vigik, lotId: 999)
    await #expect(throws: RefusDuServeur.self) {
        try await service.demander(voisin, dans: ServiceSimule.residence)
    }
}

// MARK: - Formats du site

@Test func lesDatesSuiventLeSite() {
    #expect(FormatsDuSite.dateCourte("2026-04-10") == "10/04/2026")
    #expect(FormatsDuSite.date("2026-04-02") == "2 avr. 2026")
    #expect(FormatsDuSite.dateCourte(nil as String?) == "—")
}

@Test func lesNombresSuiventLeSite() {
    // `Intl.NumberFormat('fr-FR')` : espace fine insécable, virgule décimale.
    #expect(FormatsDuSite.nombre(47_047) == "47\u{202F}047")
    #expect(FormatsDuSite.nombre(64.5) == "64,5")
    #expect(FormatsDuSite.nombre(nil as Int?) == "—")
}

// MARK: - Règles recopiées (provisoires)

@Test func lesEtagesEtLesTypesDeLot() {
    #expect(LibellesAcces.etage(0) == "RDC")
    #expect(LibellesAcces.etage(-1) == "SS 1")
    #expect(LibellesAcces.etage(1) == "1er")
    #expect(LibellesAcces.etage(2, suffixe: true) == "2ème étage")
    #expect(LibellesAcces.typeComplet("appartement", "T3") == "Appartement – T3")
    #expect(LibellesAcces.typeDeLot("local_commercial") == "Local commercial")
    #expect(LibellesAcces.nomAffiche(" Marie ", "Durand") == "Marie DURAND")
    #expect(LibellesAcces.nomLocataire(nil, nil) == "Locataire non renseigné")
}

@Test func uneValeurInconnueSAfficheBrute() {
    #expect(LibellesAcces.statutAcces("inconnu") == LibelleTeinte("inconnu", "badge-gray"))
    #expect(LibellesAcces.statutAcces("perdu").libelle == "Perdu")
}

@Test func lesBauxSeGroupentParLocataire() {
    let groupes = GroupesDeBaux.parLocataire(LotsSimules.baux)
    // Le bail 4 n'a pas de locataire inscrit : il fait groupe seul.
    #expect(groupes.map(\.cle) == ["81", "ext_4", "80"])
}

@Test func laVueParLocataireRattacheLesObjetsConfies() {
    let bail = LotsSimules.baux[0]
    let confie = AccesDetenu(id: 1, code: "X", statut: "actif", type: "vigik", chezLocataire: true, bailId: bail.id)
    let garde = AccesDetenu(id: 2, code: "Y", statut: "actif", type: "vigik", chezLocataire: false, bailId: bail.id)
    let groupes = GroupeAcces.grouper([bail], objets: [confie, garde])
    #expect(groupes.count == 1)
    #expect(groupes[0].objets == [confie])
}

@Test func lesFrequencesEtLesNotes() {
    #expect(LibellesPrestataires.frequence("mois", 1) == "↺ Mensuel")
    #expect(LibellesPrestataires.frequence("fois_par_an", 2) == "↺ 2×/an")
    #expect(LibellesPrestataires.frequence("inconnue", 2) == "")
    #expect(LibellesPrestataires.moyenne([4, 5]) == "4.5")
    #expect(LibellesPrestataires.moyenne([4, 4]) == "4")
    #expect(LibellesPrestataires.moyenne([]) == nil)
    #expect(LibellesPrestataires.etoiles(4.5) == "★★★★★")
    #expect(LibellesPrestataires.etoiles(3) == "★★★☆☆")
}

@Test func uneVisitePasseeEstEnRetard() throws {
    let jour = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 15)))
    #expect(LibellesPrestataires.enRetard("2026-11-03", aujourdhui: jour))
    #expect(!LibellesPrestataires.enRetard("2026-11-04", aujourdhui: jour))
    #expect(!LibellesPrestataires.enRetard(nil, aujourdhui: jour))
}

@Test func laRechercheIgnoreAccentsCasseEtOrdre() {
    let fiche = PrestatairesSimules.prestataires[1]
    #expect(LibellesPrestataires.correspond(fiche, equipement: "Sécurité incendie", recherche: "INCENDIE controles"))
    #expect(!LibellesPrestataires.correspond(fiche, equipement: "Sécurité incendie", recherche: "ascenseur"))
}

@Test func unContratAutreHeriteDeLaSpecialiteDuPrestataire() {
    let contrat = PrestatairesSimules.contrats[2]
    #expect(LibellesPrestataires.equipementDuContrat(contrat, prestataires: PrestatairesSimules.prestataires) == "eau")
}

// MARK: - Les libellés d'onglets, contre la table générée depuis le site

/// Tant que `Charte/OngletsDuSite.swift` n'existe pas, les libellés sont déclarés à
/// la main : ce test les compare à `Parite/ONGLETS-DU-SITE.md`, GÉNÉRÉ depuis `pages.ts`.
@Test func lesLibellesDOngletsSontCeuxDuSite() throws {
    let racine = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let table = try String(contentsOf: racine.appending(path: "Parite/ONGLETS-DU-SITE.md"), encoding: .utf8)
    for (page, onglets) in [("mon-lot", LibellesAcces.onglets), ("prestataires", LibellesPrestataires.onglets)] {
        for onglet in onglets {
            #expect(
                table.contains("| `\(page)` | `\(onglet.id)` | \(onglet.libelle) |"),
                "« \(onglet.libelle) » (\(page)/\(onglet.id)) diffère du site")
        }
    }
}
