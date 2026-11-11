// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// Le choix des périmètres d'une annonce Hall (`PerimetrePicker.svelte`) : des têtes, puis
/// les espaces d'une seule — et la règle en cinq lignes du site, sur l'arbre simulé (à la
/// forme de l'arbre semé : un défaut, le regroupement « Bâtiments », deux espaces sous A).
struct ChoixDePerimetresTests {
    private let arbre = ArbreDesPerimetres(try! FixturesPerimetres.lus())  // swiftlint:disable:this force_try

    @Test func lesTetesSontLesBatimentsEtLesLieuxPasLeRegroupementNiLeDefaut() {
        #expect(arbre.defaut?.code == "copropriete")
        #expect(arbre.tetes.map(\.code) == ["bat_a", "bat_b", "parking", "jardin"])
        #expect(arbre.espaces(de: "bat_a").map(\.code) == ["bat_a/hall", "bat_a/toit", "bat_a_terrasses"])
        // Les terrasses, au niveau 3, n'ouvrent pas un niveau de plus (#88).
        #expect(arbre.espaces(de: "bat_a_terrasses").isEmpty)
        #expect(arbre.tete(de: "bat_a/toit") == "bat_a")
    }

    @Test func uneTeteSAjouteEtOuvreSesEspacesPuisSeRetireEtLesReferme() {
        var choix = ChoixDePerimetres()
        choix.choisirDefaut(arbre)
        #expect(choix.estDefaut(arbre) && choix.ouverte(arbre) == nil)
        choix.basculer("bat_a", arbre)
        #expect(choix.codes == ["bat_a"] && choix.ouverte(arbre) == "bat_a")
        choix.basculer("bat_a", arbre)
        #expect(choix.codes == ["copropriete"] && choix.ouverte(arbre) == nil, "vide : retour au défaut")
    }

    @Test func unEspaceRemplaceSonBatimentEtRevenirSurLeBatimentNeLEfacePas() {
        var choix = ChoixDePerimetres()
        choix.basculer("bat_a", arbre)
        choix.basculer("bat_a/toit", arbre)
        #expect(choix.codes == ["bat_a/toit"], "« le toit du bâtiment A », pas les deux")
        choix.basculer("parking", arbre)
        // Rouvrir le bâtiment A pour vérifier son toit ne change rien à la sélection.
        choix.basculer("bat_a", arbre)
        #expect(choix.codes == ["bat_a/toit", "parking"] && choix.ouverte(arbre) == "bat_a")
        #expect(choix.espacesRetenus(de: "bat_a", arbre).map(\.code) == ["bat_a/toit"])
    }

    @Test func leDefautVideToutLeReste() {
        var choix = ChoixDePerimetres()
        choix.basculer("bat_b", arbre)
        choix.basculer("jardin", arbre)
        choix.choisirDefaut(arbre)
        #expect(choix.codes == ["copropriete"] && choix.estDefaut(arbre))
    }
}
