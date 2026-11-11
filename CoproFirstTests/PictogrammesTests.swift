// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Testing

@testable import CoproFirst

/// Chaque pictogramme que le site nomme a sa traduction en SF Symbols (#85).
///
/// `Pictogrammes.symbole` rend `repli` pour un nom inconnu : une icône ajoutée au site
/// s'afficherait en point, sans erreur. Ce test MESURE le repli : il cite chaque nom des
/// tables générées, et nomme ceux qui y tomberaient.

/// Les noms Lucide que l'app peut avoir à rendre : ceux des tables générées, et le
/// pictogramme du type inconnu.
private let nomsCites: [(source: String, nom: String)] =
    NaturesDuFil.parType.map { ("NaturesDuFil[\($0.key)]", $0.value.icone) }
    + PagesParDefaut.toutes.map { ("PagesParDefaut[\($0.id)]", $0.icone) }
    + [("NatureDuFil.inconnue", NatureDuFil.inconnue.icone)]

@Test func chaqueNomDIconeDesTablesGenereesASonSymbole() {
    let auRepli = nomsCites.filter { Pictogrammes.table[$0.nom] == nil }
        .map { "\($0.source) = \($0.nom)" }.sorted().joined(separator: ", ")
    #expect(auRepli.isEmpty, "rendus en « \(Pictogrammes.repli) » faute d'entrée dans Pictogrammes.table : \(auRepli)")
}

@Test func lesTablesCitentBienDesPictogrammes() {
    // Une table vide rendrait le test précédent vert sans rien vérifier (standards/04).
    #expect(NaturesDuFil.parType.count >= 10)
    #expect(PagesParDefaut.toutes.count >= 5)
    #expect(nomsCites.allSatisfy { !$0.nom.isEmpty })
}

@Test func unNomInconnuTombeAuRepliEtUnNomConnuNon() {
    #expect(Pictogrammes.symbole("nom-qui-n-existe-pas") == Pictogrammes.repli)
    #expect(Pictogrammes.symbole("book-open") == "book.fill")
}
