// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Testing

@testable import CoproFirst

// Qui voit quelle page (#355) : la règle SERVIE — `acces_menu` de GET /auth/me, croisé avec
// le public de chaque page (`acces`, généré) —, plus aucune copie des rôles. Les publics
// servis ci-dessous sont ceux qu'`acces_du_menu` de coprofirst sert à chaque compte.

private let toutes = PagesParDefaut.toutes

private func servis(_ acces: [String]) -> DroitsOnglet {
    DroitsOnglet(profil: ProfilResidence(statut: nil, roles: [], accesMenu: acces))
}

private func ids(_ acces: [String]) -> [String] { PagesOuvertes.filtrer(toutes, droits: servis(acces)).map(\.id) }

@Test func chaquePageDuMenuDeclareSonPublic() {
    for page in toutes { #expect(!page.acces.isEmpty, "« \(page.id) » sans public : elle ne s'afficherait jamais") }
}

@Test func uneEntreeSAfficheSiSonPublicEstServi() {
    let resident = ids(["tous", "resident"])
    #expect(resident.contains("mon-lot") && resident.contains("communaute"))
    #expect(!resident.contains("espace-cs") && !resident.contains("prestataires"))
    #expect(!resident.contains("delegations") && !resident.contains("admin"))

    let conseil = ids(["tous", "resident", "cs", "cs-ou-aidant"])
    #expect(conseil.contains("espace-cs") && conseil.contains("prestataires") && conseil.contains("delegations"))
    #expect(!conseil.contains("admin"), "un membre du conseil n'est pas administrateur")
}

@Test func lAidantALesDelegationsSansLaCommunauteSiLeServeurLeDit() {
    let aidant = ids(["tous", "cs-ou-aidant"])
    #expect(aidant.contains("delegations"))
    #expect(!aidant.contains("communaute"), "ce que le serveur ne sert pas ne s'affiche pas")
}

@Test func leCompteTechniqueNAQueLAdministration() {
    #expect(ids(["admin"]) == ["admin"])
    #expect(OrdrePages.accueil(ids(["admin"])) == "admin", "sans le fil, l'accueil est la première page servie")
}

@Test func sansPublicServiAucunePageEtLAccueilEstLeProfil() {
    #expect(ids([]).isEmpty)
    #expect(OrdrePages.accueil([]) == EntreeFixe.profil.rawValue, "d'où l'on se déconnecte")
}

@Test func unePageInconnueEstFermee() {
    #expect(!PagesOuvertes.ouverte("inconnue", droits: servis(["tous", "resident", "cs", "cs-ou-aidant", "admin"])))
    #expect(PagesOuvertes.ouverte("espace-cs", droits: servis(["cs"])))
    #expect(!PagesOuvertes.ouverte("espace-cs", droits: servis(["tous"])))
}

@Test func unProfilGardeAvantLaRegleNOuvreQueLesPagesDeTous() {
    let ancien = DroitsOnglet(profil: ProfilResidence(statut: "copropriétaire_résident", roles: ["conseil_syndical"]))
    #expect(ancien.accesMenu == Set(PagesOuvertes.avantRelecture))
    let ouvertes = PagesOuvertes.filtrer(toutes, droits: ancien)
    #expect(ouvertes.allSatisfy { $0.acces == "tous" } && ouvertes.contains { $0.id == OrdrePages.idFil })
}

@Test func leProfilLuPorteLesPublicsServis() throws {
    let json = #"""
        {"id": 5, "prenom": "Alix", "nom": "Modèle", "email": "alix@example.com",
         "statut": "admin_technique", "role": "admin", "roles": ["admin"], "actif": true,
         "onboarding_complete": true, "onboarding_etape": 4, "preferences_notifications": "{}",
         "cree_le": "2026-01-01T10:00:00", "nom_affiche": "Alix MODÈLE", "nom_aide_affiche": "",
         "acces_menu": ["admin"]}
        """#
    let profil = ProfilResidence(try Relecture.generee(Components.Schemas.UserRead.self, json: json))
    #expect(profil.accesMenu == ["admin"])
    #expect(profil.motDePasseAChanger == false, "non servi : non (#377)")
}

@Test func uneDemandeHorsDeLaBarreSePoseSurLAccueil() {
    #expect(Aiguillage.aiguiller(.page("mon-lot"), pages: ["admin"], visibles: 4) == .onglet("admin"))
    #expect(Aiguillage.aiguiller(.accueil, pages: [], visibles: 4) == .onglet(EntreeFixe.profil.rawValue))
}
