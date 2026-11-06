// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Testing

@testable import CoproFirst

// L'avis éphémère (#48) : la phrase vit dans un objet que seul l'avis lit, et son
// retrait n'efface jamais la phrase qui l'a remplacée.

@MainActor @Test func unAvisRemplacePuisRetireGardeLeSuivant() {
    let avis = AvisDuGeste()
    avis.dire("Signalement enregistré")
    avis.dire("Accès enregistré")
    // La minuterie du premier avis arrive à son terme : elle ne retire que LUI.
    avis.retirer("Signalement enregistré")
    #expect(avis.texte == "Accès enregistré")
    avis.retirer("Accès enregistré")
    #expect(avis.texte == nil)
}

@MainActor @Test func lEtatDesAccesAnnonceParLAvis() {
    let etat = EtatAcces()
    etat.annoncer("Accès enregistré")
    #expect(etat.avis.texte == "Accès enregistré")
}

@MainActor @Test func lAvisDUneFeuilleAttendSaFermeture() {
    let avis = AvisDuGeste()
    avis.direApresFermeture("Accès enregistré")
    #expect(avis.texte == nil, "rien derrière la feuille")
    avis.feuilleFermee()
    #expect(avis.texte == "Accès enregistré", "dit une fois la feuille fermée")
    avis.retirer("Accès enregistré")
    avis.feuilleFermee()
    #expect(avis.texte == nil, "une feuille fermée sans geste ne redit rien")
}
