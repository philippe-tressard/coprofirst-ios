// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

// Les avis d'un prestataire (#207, coprofirst#2728 à #2745) : trois états, leurs libellés,
// teintes et seuils GÉNÉRÉS du site ; le récapitulatif par exercice et par intervention
// SERVI par l'API — rien n'est regroupé ni compté dans l'app.

@Test func lEtatDUneMoyenneSuitLesSeuilsDuSite() {
    #expect(EtatAvis.deMoyenne(1) == "mauvais")
    #expect(EtatAvis.deMoyenne(2.49) == "mauvais")
    #expect(EtatAvis.deMoyenne(2.5) == "neutre", "la borne appartient à l'état suivant")
    #expect(EtatAvis.deMoyenne(3.99) == "neutre")
    #expect(EtatAvis.deMoyenne(4) == "excellent")
    #expect(EtatAvis.deMoyenne(5) == "excellent")
}

@Test func lesTroisEtatsSeDisentEtSeTeintentCommeAuSite() {
    #expect(TablesNotations.etats.map(EtatAvis.libelle) == ["Mauvais", "Neutre", "Excellent"])
    #expect(TablesNotations.etats.map(EtatAvis.teinte) == ["badge-red", "badge-gray", "badge-green"])
    #expect(EtatAvis.libelle("inconnu") == "inconnu" && EtatAvis.teinte("inconnu") == "badge-gray", "brut, en gris")
}

@Test func leBadgeDeMoyenneDitLEtatPuisLaNote() {
    #expect(TextesAvisPrestataire.moyenne(4.333) == "Excellent ·\u{00A0}4,333/5")
    #expect(TextesAvisPrestataire.moyenne(2) == "Mauvais ·\u{00A0}2/5")
    #expect(TextesAvisPrestataire.moyenneEnClair(4.5, nombre: 3) == "Excellent, 4,5 sur 5, 3 avis")
}

@Test func leRecapitulatifSeLitTelQueServi() throws {
    let exercices = try FixturesNotations.lus(1)
    #expect(exercices.map(\.annee) == [2026, 2025], "le plus récent d'abord, dans l'ordre servi")
    let courant = try #require(exercices.first)
    #expect(TextesAvisPrestataire.exercice(courant.libelle) == "Exercice 2026")
    #expect(TextesAvisPrestataire.nombres(courant) == "2 interventions ·\u{00A0}1 notée")
    #expect(courant.comptes.map(\.etat) == ["excellent"] && courant.comptes.first?.nombre == 2)
    #expect(courant.lignes.map(\.titre) == [
        "Contrôle annuel de l'ascenseur", "Cabine bloquée au 3e étage", TextesAvisPrestataire.sansAffaire,
    ])
    #expect(courant.lignes[1].avis.isEmpty, "une intervention non notée")
    #expect(courant.lignes[2].date == nil, "les avis sans affaire n'ont pas de date de ligne")
    let avis = try #require(courant.lignes.first?.avis.first)
    #expect(avis.etat == "excellent" && avis.auteurNom == "Conseil syndical" && !avis.peutModifier)
    #expect(try FixturesNotations.lus(2).isEmpty, "sans avis ni intervention : rien")
}

@Test func unCommentaireVideNeSAffichePas() throws {
    let precedent = try #require(try FixturesNotations.lus(1).last)
    #expect(precedent.comptes.map(\.etat) == ["neutre"])
    #expect(precedent.lignes.first?.avis.first?.commentaire?.contains("\n") == true, "le commentaire tel quel")
}

@MainActor
@Test func laMoyenneServieSeLitAvecLaFiche() async throws {
    let fiches = try await ServiceSimule(delai: .zero).prestataires(ServiceSimule.residence, archives: false)
    let ascenseurs = try #require(fiches.first { $0.id == 1 })
    #expect(ascenseurs.noteMoyenne == 4.333 && ascenseurs.nbNotations == 3)
    #expect(fiches.first { $0.id == 2 }?.noteMoyenne == nil, "sans avis : pas de moyenne, jamais 0")
}
