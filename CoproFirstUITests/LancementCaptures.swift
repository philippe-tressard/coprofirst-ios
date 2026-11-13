// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Lancer l'app sur l'API simulée, dans le rendu que les captures demandent :
/// `TEST_RUNNER_THEME=sombre` (le thème du Profil, posé par `-theme`) et
/// `TEST_RUNNER_GRAND_TEXTE=1` (Accessibilité XXXL) ; `TEST_RUNNER_CAPTURES=<dossier>`
/// y fait laisser une capture à chaque étape, rien sinon.
enum LancementCaptures {
    private static let environnement = ProcessInfo.processInfo.environment

    /// Une taille de texte imposée au lancement, quoi que dise l'environnement — et
    /// quoi qu'on ait réglé sur le simulateur, qui l'emporte sinon.
    enum Taille: String {
        case parDefaut = "UICTContentSizeCategoryL"
        case ax5 = "UICTContentSizeCategoryAccessibilityXXXL"
    }

    @MainActor
    static func lancer(ecran: String = "fil", taille: Taille? = nil, arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        // L'avis qui suit un geste dure 4 s dans l'app : sous les tests, il reste jusqu'au
        // suivant (`-avis-durable`), sinon il repart avant d'être lu par un runner qui met
        // 30 s à une requête — SondageUITests rouge en CI le 12/11/2026, comme Accès (#123).
        app.launchArguments = ["-api-simulee", "-ecran", ecran, "-avis-durable"] + arguments
        app.launchArguments += ["-theme", environnement["THEME"] ?? "auto"]
        if let taille = taille ?? (environnement["GRAND_TEXTE"] != nil ? .ax5 : nil) {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", taille.rawValue]
        }
        app.launch()
        return app
    }

    /// Une capture, quand un dossier est demandé ; rien sinon.
    @MainActor
    static func capturer(_ nom: String) {
        guard let dossier = environnement["CAPTURES"] else { return }
        let suffixe = [environnement["THEME"], environnement["GRAND_TEXTE"] != nil ? "grand-texte" : nil]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "-")
        let fichier = URL(fileURLWithPath: dossier)
            .appendingPathComponent(nom + (suffixe.isEmpty ? "" : "-" + suffixe) + ".png")
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: fichier)
    }
}
