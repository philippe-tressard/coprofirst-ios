// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Testing

@testable import CoproFirst

/// Le registre des menus (#10) : une page du site → son écran natif, « Bientôt » sinon.
@MainActor
@Test func leFilEtLesAffairesSontInscrits() {
    #expect(RegistreDesMenus.ecrans[OrdrePages.idFil] == FilView.self)
    #expect(RegistreDesMenus.ecrans["mes-demandes"] == AffairesView.self)
}

/// Une page que le site ne connaît pas n'a rien à faire dans le registre : son
/// identifiant ne viendrait jamais de `pages_order`, l'écran serait inatteignable.
@MainActor
@Test func chaqueMenuInscritEstUnePageDuSite() {
    let pagesDuSite = Set(PagesParDefaut.toutes.map(\.id))
        .union(["profil", "notifications", "espace-cs", "admin", "delegations"])
    for id in RegistreDesMenus.ecrans.keys {
        #expect(pagesDuSite.contains(id), "« \(id) » : inconnu des pages du site")
    }
}

/// Une page sans écran inscrit s'ouvre quand même : « Bientôt », jamais un vide.
@MainActor
@Test func unePageNonInscriteDitBientot() {
    // Les huit pages de la barre ont toutes un ticket (#11 à #14), les Délégations
    // sont arrivées (#15) : la page témoin est l'administration, réservée à un rôle.
    #expect(RegistreDesMenus.ecrans["admin"] == nil, "si l'administration arrive (#16), choisir une autre page")
}
