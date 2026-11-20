// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

// Le Registre R6 (coprofirst#1882, #262) : une installation suspendue le dit par GET /config,
// et ses refus — 403 en lecture seule, 409 au sixième compte du mode limité — se lisent
// avec la phrase du serveur, mot pour mot.

private let adresse = URL(string: "https://residence.example.com") ?? ServiceSimule.residence.adresse

/// `installation_suspendue` est une CHAÎNE (`'1'` ou `'0'`) : seul « 1 », espaces autour
/// ignorés, suspend ; absente sous v3.111.0, elle vaut « non suspendue » (la règle de
/// l'Android, coprofirst-android#233).
@Test(arguments: [("1", true), (" 1 ", true), ("0", false), (nil, false), ("true", false)] as [(String?, Bool)])
func laSuspensionSeLitDansLaConfiguration(_ valeur: String?, _ attendue: Bool) throws {
    var cles = ["site_nom": "Les Tilleuls"]
    cles["installation_suspendue"] = valeur
    let installation = try #require(Installation(adresse: adresse, config: cles))
    #expect((installation.suspendue == true) == attendue)
}

/// Les phrases du serveur, recopiées ici comme DONNÉES de test seulement (`suspension.py`
/// et `plafond.py` de coprofirst v3.117.0) : l'app les rend, elle ne les écrit pas.
private let suspendue =
    "Installation suspendue par la référence CoproFirst : elle est en lecture seule. Tout reste consultable, "
    + "et l'administrateur de la copropriété peut en exporter les données (Administration › Maintenance › "
    + "Export vérifié). Pour la rétablir, l'opérateur de l'installation s'adresse à la référence."
private let modeLimite =
    "Mode limité : cette installation compte déjà 5 comptes actifs, le plafond tant qu'elle n'a pas de bail "
    + "actif de la référence CoproFirst. Aucun compte existant n'est touché. Pour ouvrir celui-ci, désactivez "
    + "d'abord un autre compte (Administration › Utilisateurs), ou demandez à l'opérateur de l'installation de "
    + "l'inscrire au registre (Administration › Installation)."

@Test(arguments: [(403, suspendue), (409, modeLimite)])
func unRefusDuRegistreSeDitMotPourMot(_ statut: Int, _ phrase: String) throws {
    let corps = try JSONSerialization.data(withJSONObject: ["detail": phrase])
    let erreur = ErreurService.depuisRefus(statut, corps: corps)
    #expect(erreur.phrase == phrase, "la phrase du serveur, jamais une erreur générique")
    #expect(ErreurService.phrase(erreur, sinon: "Erreur lors de l'enregistrement.") == phrase)
}

/// Rouverte par Face ID, une résidence ne repasse pas par la découverte : sa suspension se
/// relit à l'ouverture, et seule elle change — le reste attend la découverte.
@MainActor
@Test func laSuspensionRelueNeToucheQuASaCle() throws {
    let suite = "suspension.\(UUID().uuidString)"
    let reglages = try #require(UserDefaults(suiteName: suite))
    defer { reglages.removePersistentDomain(forName: suite) }
    let connues = InstallationsConnues(reglages: reglages, coffre: CoffreEnMemoire())
    let residence = Installation(adresse: adresse, nom: "Les Tilleuls", aUnLogo: false, codePalette: "prune")
    connues.retenir(residence)
    connues.noterSuspension(true, pour: residence)
    #expect(connues.liste.first?.suspendue == true)
    #expect(connues.liste.first?.codePalette == "prune")
    let relue = InstallationsConnues(reglages: reglages, coffre: CoffreEnMemoire())
    #expect(relue.liste.first?.suspendue == true, "gardée d'un lancement à l'autre")
    connues.noterSuspension(false, pour: residence)
    #expect(connues.liste.first?.suspendue == false, "rétablie : le bandeau se retire")
}

/// Le bandeau compose le titre comme le site : `titre` + tiret + `precision` + « . ».
@Test func leBandeauSeComposeCommeLeSite() {
    #expect(BandeauInstallation.titre == "Installation suspendue\(Separateur.tiret)lecture seule.")
    #expect(BandeauInstallation.phrase.hasSuffix(TexteBandeauSuspendue.texte))
}
