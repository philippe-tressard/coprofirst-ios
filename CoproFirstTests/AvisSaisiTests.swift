// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

// Noter, corriger, retirer un avis et choisir l'affaire (#207, second lot) : la saisie
// compose le commentaire comme le site (`notations.ts`), le recoche à la correction, et
// retient l'avis avec les phrases du site ; le choix de l'affaire suit `ChoixAffaireAvis`.

@Test func laPhraseGenereeSuitLOrdreDuSite() {
    #expect(AvisSaisi.phrase(forts: [], faibles: []).isEmpty)
    #expect(
        AvisSaisi.phrase(forts: ["délai respecté", "travail soigné"], faibles: ["retard"])
            == "Points forts : délai respecté, travail soigné. Points faibles : retard.")
    var saisie = AvisSaisi()
    saisie.forts = ["interlocuteur réactif", "délai respecté"]
    #expect(
        saisie.genere == "Points forts : délai respecté, interlocuteur réactif.", "l'ordre des listes, pas du toucher")
    saisie.libre = "  Merci.  "
    #expect(saisie.commentaire == "Points forts : délai respecté, interlocuteur réactif.\nMerci.")
    saisie.forts = []
    #expect(saisie.commentaire == "Merci.", "sans case, le texte libre seul")
}

@Test func corrigerRecocheLesCasesEtGardeLeTexteLibre() {
    let lu = AvisSaisi.decomposer("Points faibles : retard.\nRéparé au second passage.")
    #expect(lu.forts.isEmpty && lu.faibles == ["retard"] && lu.libre == "Réparé au second passage.")
    let deux = AvisSaisi.decomposer(
        "Points forts : délai respecté, travail soigné. Points faibles : facture contestée.")
    #expect(deux.forts == ["délai respecté", "travail soigné"] && deux.faibles == ["facture contestée"])
    #expect(deux.libre.isEmpty)
    // Un texte qui RESSEMBLE à la phrase, avec un motif inconnu, reste libre — entier.
    let libre = "Points forts : rapide.\nSuite"
    #expect(AvisSaisi.decomposer(libre) == CommentaireDecompose(libre: libre))
    #expect(AvisSaisi.decomposer(nil) == CommentaireDecompose(libre: ""))
    #expect(AvisSaisi.decomposer("Simple remarque") == CommentaireDecompose(libre: "Simple remarque"))
}

@Test func lAvisCorrigeRepartDeLAvisServi() {
    let avis = AvisPrestataire(
        id: 9, etat: "neutre", commentaire: "Points faibles : retard.\nRéparé.", auteurNom: "Conseil syndical",
        creeLe: .now, peutModifier: true, ticketId: 21)
    let saisie = AvisSaisi(corrigeant: avis)
    #expect(saisie.etat == "neutre" && saisie.faibles == ["retard"])
    #expect(saisie.libre == "Réparé." && saisie.affaire == 21)
    #expect(saisie.commentaire == avis.commentaire, "rien de changé : le même commentaire repart")
}

@Test func lAvisEstRetenuAvecLesPhrasesDuSite() {
    var saisie = AvisSaisi()
    #expect(saisie.refus(ajoutRequis: false, prestataire: "X") == "Choisissez l'état : Mauvais, Neutre ou Excellent")
    saisie.etat = "mauvais"
    let justifier = "Un avis « Mauvais » doit être justifié par un commentaire"
    #expect(saisie.refus(ajoutRequis: false, prestataire: "X") == justifier)
    saisie.faibles = ["retard"]
    #expect(saisie.refus(ajoutRequis: false, prestataire: "X") == nil, "une case cochée justifie")
    #expect(
        saisie.refus(ajoutRequis: true, prestataire: "Ascenseurs du Parc")
            == "Confirmez l'ajout de Ascenseurs du Parc à l'affaire choisie")
    #expect(saisie.envoi(prestataire: 1, contrat: nil, ajoutRequis: true) == nil, "retenu : rien ne part")
    saisie.confirmeAjout = true
    saisie.affaire = 52
    let envoi = saisie.envoi(prestataire: 1, contrat: 3, ajoutRequis: true)
    #expect(envoi?.confirmerAjout == true && envoi?.affaire == 52 && envoi?.contratId == 3)
    #expect(envoi?.commentaire == "Points faibles : retard.")
    // La case reste cochée d'une affaire précédente : elle ne part que si l'ajout est requis.
    #expect(saisie.envoi(prestataire: 1, contrat: nil, ajoutRequis: false)?.confirmerAjout == false)
    saisie.etat = "neutre"
    saisie.faibles = []
    #expect(saisie.envoi(prestataire: 1, contrat: nil, ajoutRequis: false)?.commentaire == nil, "vide : nul")
}

@Test func leRetraitSeConfirmeAvecLesMotsDuSite() {
    let avis = AvisPrestataire(id: 9, etat: "neutre", commentaire: "Retard.", auteurNom: nil, creeLe: .now)
    #expect(
        TextesSaisieAvis.retrait(avis)
            == "État « Neutre » de un membre du CS —\u{00A0}« Retard. »\n\n"
            + "La suppression est définitive, et la moyenne du prestataire sera recalculée.")
}

private let affaires = [
    AffaireANoter(id: 45, numero: "A-0045", titre: "Contrôle annuel", intervient: true, intervenants: "P"),
    AffaireANoter(id: 38, numero: "A-0038", titre: "Cabine bloquée", intervient: true, intervenants: "P"),
    AffaireANoter(id: 52, numero: "A-0052", titre: "Infiltration en toiture", intervient: false, intervenants: "T"),
    AffaireANoter(id: 50, numero: "A-0050", titre: "Éclairage du hall", intervient: false, intervenants: ""),
]

@Test func sansRechercheLesDeuxGroupesDansLOrdreServi() {
    let groupes = ChoixAffaires.groupes(affaires, recherche: "", minimum: 2, trouvees: [], prestataire: "Ascenseurs")
    #expect(groupes.map(\.titre) == ["Avec Ascenseurs", "Autres affaires"])
    #expect(groupes.map { $0.affaires.map(\.id) } == [[45, 38], [52, 50]])
    #expect(ChoixAffaires.groupes([], recherche: "", minimum: 2, trouvees: [], prestataire: "").isEmpty)
    #expect(TextesSaisieAvis.avec("") == "Avec ce prestataire")
}

@Test func uneFrappeFiltreEtLaRechercheDetailleeAjouteSesTrouvailles() {
    // « toi » : le titre ; 50 : trouvée par la recherche détaillée (un mot du suivi).
    let groupes = ChoixAffaires.groupes(affaires, recherche: "toi", minimum: 2, trouvees: [50], prestataire: "P")
    #expect(groupes.flatMap { $0.affaires.map(\.id) } == [52, 50], "le titre trouvé d'abord, puis le serveur")
    #expect(
        ChoixAffaires.groupes(affaires, recherche: "#A-0038", minimum: 2, trouvees: [], prestataire: "P")
            .flatMap { $0.affaires.map(\.id) } == [38], "le dièse d'un numéro copié saute")
    #expect(
        ChoixAffaires.groupes(affaires, recherche: "https://x.example.com/tickets/52?vue=1", minimum: 2, trouvees: [],
            prestataire: "P").flatMap { $0.affaires.map(\.id) } == [52], "un lien collé")
    #expect(!ChoixAffaires.actif("t", minimum: 2), "une lettre n'est pas une recherche")
    #expect(ChoixAffaires.aide(actif: true, enCours: false, vide: true) == "Aucune affaire ne correspond.")
    #expect(ChoixAffaires.aide(actif: false, enCours: false, vide: false) == TextesSaisieAvis.sansAffaire)
    #expect(ChoixAffaires.aide(actif: true, enCours: true, vide: true) == TextesSaisieAvis.rechercheEnCours)
}

// Le faux serveur : ce que les tests d'interface verront.

@MainActor
@Test func noterUneAffaireSansLePrestataireExigeLaConfirmation() async throws {
    let service = ServiceSimule(delai: .zero)
    let residence = ServiceSimule.residence
    var envoi = EnvoiAvis(
        prestataireId: 1, contratId: nil, etat: "mauvais", commentaire: "Fuite revenue.", affaire: 52,
        confirmerAjout: false)
    await #expect(throws: ErreurService.self) { try await service.noter(envoi, dans: residence) }
    envoi.confirmerAjout = true
    try await service.noter(envoi, dans: residence)
    let courant = try #require(try await service.interventions(de: 1, dans: residence).first)
    let ligne = try #require(courant.lignes.first)
    #expect(ligne.titre == "Infiltration en toiture" && ligne.avis.map(\.etat) == ["mauvais"])
    #expect(ligne.avis.first?.peutModifier == true, "l'auteur peut corriger")
    #expect(courant.compte["mauvais"] == 1 && courant.nbInterventions == 3 && courant.nbNotees == 2)
    let ajoutee = try await service.affairesANoter(de: 1, dans: residence).first { $0.id == 52 }
    #expect(ajoutee?.intervient == true, "le prestataire y est ajouté")
    let fiche = try #require(try await service.prestataires(residence, archives: false).first { $0.id == 1 })
    #expect(fiche.nbNotations == 4 && fiche.noteMoyenne == 3.5, "la moyenne servie suit")
}

@MainActor
@Test func corrigerPuisRetirerUnAvis() async throws {
    let service = ServiceSimule(delai: .zero)
    let residence = ServiceSimule.residence
    var envoi = EnvoiAvis(
        prestataireId: 1, contratId: nil, etat: "excellent", commentaire: "Réparé.", affaire: 21, confirmerAjout: false)
    try await service.corriger(9, envoi, dans: residence)
    let garde = try #require(try await service.interventions(de: 1, dans: residence).last)
    #expect(garde.lignes.first { $0.id == "t21" }?.avis.map(\.etat) == ["excellent"], "sur son affaire")
    #expect(garde.nbNotees == 1 && !garde.lignes.contains { $0.id == "generaux" })
    envoi.affaire = 99
    await #expect(throws: ErreurService.self, "une affaire inconnue n'en fait pas un avis général") {
        try await service.corriger(9, envoi, dans: residence)
    }
    (envoi.affaire, envoi.commentaire) = (nil, nil)
    try await service.corriger(9, envoi, dans: residence)
    let precedent = try #require(try await service.interventions(de: 1, dans: residence).last)
    #expect(precedent.annee == 2025, "corrigé, l'avis reste dans son exercice")
    let generaux = try #require(precedent.lignes.first { $0.id == "generaux" })
    #expect(generaux.avis.map(\.id) == [9] && generaux.avis.first?.commentaire == nil, "ramené sans affaire")
    #expect(precedent.compte == ["excellent": 1] && precedent.nbNotees == 0)
    try await service.retirer(9, dans: residence)
    let apres = try #require(try await service.interventions(de: 1, dans: residence).last)
    #expect(!apres.lignes.contains { $0.id == "generaux" } && apres.compte.isEmpty)
    await #expect(throws: ErreurService.self) { try await service.retirer(9, dans: residence) }
}
