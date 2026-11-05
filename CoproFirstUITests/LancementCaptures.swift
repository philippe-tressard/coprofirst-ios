// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Lancer l'app sur l'API simulée, dans le rendu que les captures demandent :
/// `TEST_RUNNER_THEME=sombre` (le thème du Profil, posé par `-theme`) et
/// `TEST_RUNNER_GRAND_TEXTE=1` (Accessibilité XXXL) ; `TEST_RUNNER_CAPTURES=<dossier>`
/// y fait laisser une capture à chaque étape, rien sinon.
enum LancementCaptures {
    private static let environnement = ProcessInfo.processInfo.environment

    @MainActor
    static func lancer(ecran: String = "fil") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", ecran]
        app.launchArguments += ["-theme", environnement["THEME"] ?? "auto"]
        if environnement["GRAND_TEXTE"] != nil {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        return app
    }

    /// Une capture, quand un dossier est demandé ; rien sinon.
    @MainActor
    static func capturer(_ nom: String) {
        guard let dossier = environnement["CAPTURES"] else { return }
        let suffixe = [environnement["THEME"], environnement["GRAND_TEXTE"] != nil ? "grand-texte" : nil]
            .compactMap { $0 }.joined(separator: "-")
        let fichier = URL(fileURLWithPath: dossier)
            .appendingPathComponent(nom + (suffixe.isEmpty ? "" : "-" + suffixe) + ".png")
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: fichier)
    }
}
