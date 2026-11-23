// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// « Écrans du hall » de l'Espace CS (#295), contre l'API simulée (un compte du conseil) :
/// la liste, l'appairage par le code qu'affiche l'écran — refusé, puis confirmé —, et le
/// retrait confirmé. Chaque toucher passe par `app.toucher`, et chaque geste se prouve par
/// l'état qui reste (la liste relue), jamais par l'avis, qui passe.
final class EcransHallUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testListerAppairerEtRetirerUnEcran() throws {
        let app = LancementCaptures.lancer()
        let plus = app.descendants(matching: .any)["Plus"].firstMatch
        XCTAssertTrue(plus.apparait())
        app.toucher(plus)
        app.toucher(app.libelleAcces("Espace CS"))
        let onglet = app.elementAcces("onglet.ecrans")
        XCTAssertTrue(app.amenerDansSaRangee(onglet), "l'onglet au bout de la barre")
        // La liste : trois écrans servis, dont un échu.
        app.toucher(onglet, jusqua: app.elementAcces("ecran.3"))
        XCTAssertTrue(app.elementAcces("ecran.1.echu").exists, "l'écran échu le dit")
        LancementCaptures.capturer("cs-ecrans-1-liste")

        appairer(app)
        retirer(app)
    }

    /// Un code faux rend la phrase du serveur, la feuille ouverte ; le bon, saisi en
    /// minuscules et sans tiret (le site le lit lettre à lettre), appaire.
    @MainActor
    private func appairer(_ app: XCUIApplication) {
        remplir(app, code: "bcdf-ghjx", nom: "Hall du parking")
        let refus = app.libelleAcces("Code inconnu ou expiré — affichez un nouveau code sur l'écran.")
        XCTAssertTrue(refus.apparait(), "la phrase du serveur, la feuille ouverte")
        LancementCaptures.capturer("cs-ecrans-2-code-refuse")
        let annuler = app.descendants(matching: .any)["Annuler"].firstMatch
        app.toucher(annuler)
        XCTAssertTrue(annuler.disparait(), "la feuille se ferme sans rien appairer")

        remplir(app, code: "bcdf ghjk", nom: "Hall du parking")
        XCTAssertTrue(app.elementAcces("ecrans.feuille.code").disparait(), "la feuille se ferme")
        // La liste se relit quand l'écran a eu le temps de venir chercher son accès.
        XCTAssertTrue(app.elementAcces("ecran.5").apparait(), "l'écran appairé paraît dans la liste")
        LancementCaptures.capturer("cs-ecrans-3-appaire")
    }

    /// Ouvre la feuille, la remplit (le parking pour lieu) et touche « Enregistrer ».
    @MainActor
    private func remplir(_ app: XCUIApplication, code texte: String, nom saisi: String) {
        app.toucher(app.elementAcces("ecrans.appairer"))
        let code = app.elementAcces("ecrans.feuille.code")
        XCTAssertTrue(code.apparait(), "la feuille d'appairage")
        let enregistrer = "ecrans.feuille.enregistrer"
        XCTAssertTrue(desactive(app, enregistrer), "« Enregistrer » grisé tant que rien n'est saisi")
        app.toucher(code)
        XCTAssertTrue(code.attendre("hasKeyboardFocus == true"))
        code.typeText(texte)
        let nom = app.elementAcces("ecrans.feuille.nom")
        app.toucher(nom)
        XCTAssertTrue(nom.attendre("hasKeyboardFocus == true"))
        nom.typeText(saisi)
        app.toucher(app.elementAcces("ecrans.feuille.perimetre.parking"))
        app.toucher(app.elementAcces(enregistrer))
    }

    /// « Retirer » se confirme, en rouge ; l'écran quitte la liste.
    @MainActor
    private func retirer(_ app: XCUIApplication) {
        let retirer = app.elementAcces("ecran.4.retirer")
        app.amener(retirer)
        app.toucher(retirer)
        let confirmer = app.elementAcces("ecrans.retirer.confirmer")
        XCTAssertTrue(confirmer.apparait(), "la confirmation")
        app.toucher(confirmer)
        XCTAssertTrue(app.elementAcces("ecran.4").disparait(), "l'écran retiré quitte la liste")
        XCTAssertTrue(app.elementAcces("ecran.3").exists, "les autres restent")
    }

    /// L'état se lit sur tous les éléments de l'identifiant (`swiftui-patterns`, tests d'interface, 2).
    @MainActor
    private func desactive(_ app: XCUIApplication, _ identifiant: String) -> Bool {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND isEnabled == false", identifiant))
            .firstMatch.apparait()
    }
}
