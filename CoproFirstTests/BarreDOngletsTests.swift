// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Testing

@testable import CoproFirst

/// La barre du bas : un libellé court par page, sauf si l'administration l'a renommée.
@Test func laBarreParDefautSeLitFilResidenceAffairesAccesPlus() {
    let pages = OrdrePages.ordonner(PagesParDefaut.toutes, ordre: nil, surcharges: [:])
    #expect(pages.prefix(4).map(\.libelle) == ["Fil", "Résidence", "Affaires", "Accès"])
    #expect(pages.count > 4, "au-delà de quatre, « Plus »")
    // L'écran garde le titre de la page, comme le site.
    #expect(pages.first { $0.id == "mon-lot" }?.titre == "Mes lots & accès")
}

@Test func unePageRenommeeGardeLeNomDeLAdministration() {
    let parLeMenu = OrdrePages.ordonner(
        PagesParDefaut.toutes, ordre: nil, surcharges: ["mon-lot": SurchargePage(navLabel: "Clés et badges")])
    #expect(parLeMenu.first { $0.id == "mon-lot" }?.libelle == "Clés et badges")

    let parLeTitre = OrdrePages.ordonner(
        PagesParDefaut.toutes, ordre: nil, surcharges: ["mon-lot": SurchargePage(titre: "Badges de la résidence")])
    let page = parLeTitre.first { $0.id == "mon-lot" }
    #expect(page?.libelle == "Badges de la résidence", "jamais un raccourci qui contredit l'administration")
    #expect(page?.titre == "Badges de la résidence")
}

@Test func uneSurchargeIdentiqueAuSiteNeChasseLePasLeRaccourci() {
    let pages = OrdrePages.ordonner(
        PagesParDefaut.toutes, ordre: nil,
        surcharges: ["mon-lot": SurchargePage(navLabel: "Mes lots & accès", titre: "Mes lots & accès")])
    #expect(pages.first { $0.id == "mon-lot" }?.libelle == "Accès")
}

@Test func chaqueRaccourciDesigneUnePageDuSite() {
    let ids = Set(PagesParDefaut.toutes.map(\.id))
    #expect(Set(LibellesBarre.courts.keys).isSubset(of: ids), "un raccourci orphelin ne servirait à rien")
}
