// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.89.0 (commit 10b85f3356d538254bfdca6f54270063c9008d4b), front/src/lib/theme.ts#COOKIE_THEME, front/src/lib/theme.ts#THEME_PAR_DEFAUT, front/src/lib/theme.ts#OPTIONS_THEME, front/src/lib/preferences.ts#CANAUX_NOTIFS, front/src/lib/roles.ts#STATUTS_DEMANDABLES (tables-clients.json) ; api/app/utils/preferences_mail.py et mots_de_passe.py.

/// Ce que le site écrit du Profil et que le contrat ne sert pas.
enum TablesProfil {
    /// Le thème : une préférence de l'APPAREIL (le cookie du site), ses choix (`OPTIONS_THEME`).
    static let cleTheme = "theme"
    static let themeParDefaut = "auto"
    static let optionsTheme: [OptionTheme] = [
        OptionTheme(code: "auto", libelle: "Automatique", detail: "Suit le réglage de l’appareil"),
        OptionTheme(code: "clair", libelle: "Clair", detail: "Toujours clair"),
        OptionTheme(code: "sombre", libelle: "Sombre", detail: "Toujours sombre"),
    ]
    /// Les défauts d'une préférence jamais réglée — ceux du SERVEUR (`DEFAUTS`).
    static let defautsPreferences: [String: Bool] = [
        "mon_batiment_mail": true,
        "autres_batiments_mail": false,
        "mon_batiment_app": true,
        "autres_batiments_app": true,
    ]
    /// Les deux canaux et leurs deux cases (`CANAUX_NOTIFS`).
    static let canauxNotifications: [CanalNotifications] = [
        CanalNotifications(
            titre: "Notifications par e-mail",
            mon: "mon_batiment_mail",
            autres: "autres_batiments_mail"),
        CanalNotifications(
            titre: "Notifications dans l'application",
            mon: "mon_batiment_app",
            autres: "autres_batiments_app"),
    ]
    /// Les profils qu'on peut demander depuis son profil (`STATUTS_DEMANDABLES`).
    static let statutsDemandables: [String] = [
        "copropriétaire_résident",
        "copropriétaire_bailleur",
        "locataire",
        "mandataire",
        "syndic",
    ]
    /// La longueur minimale d'un nouveau mot de passe (`verifier_robustesse`, serveur).
    static let longueurMinimaleMotDePasse = 8
}
