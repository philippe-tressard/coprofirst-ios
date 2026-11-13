// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.89.0 (commit 10b85f3356d538254bfdca6f54270063c9008d4b), front/src/lib/plateforme.ts, piedDePage.ts.
// swiftlint:disable line_length

/// Ce que le pied de page du site dit sur chaque page : le logiciel, sa licence, ses liens.
enum TextesDuPied {
    static let nomPlateforme = "CoproFirst"
    static let sitePlateforme = "https://coprofirst.fr"
    static let depotSource = "https://github.com/philippe-tressard/coprofirst"
    static let licenceSPDX = "AGPL-3.0-or-later"
    static let licenceNom = "GNU Affero General Public License, version 3 ou ultérieure"
    static let licenceURL = "https://github.com/philippe-tressard/coprofirst/blob/main/LICENSE"
    /// Les liens du pied de page : libellé, et l'infobulle du site s'il en a une.
    static let site = (libelle: "À propos de CoproFirst", aide: "Le site de présentation de CoproFirst, le logiciel qui fait tourner ce site")
    static let source = (libelle: "Logiciel libre", aide: "Le code source de la version en service")
    static let mentions = (libelle: "Mentions légales", aide: "")
    static let confidentialite = (libelle: "Confidentialité", aide: "")
    /// Les clés de GET /config qui règlent la mention (`CLES_PIED`).
    static let cleAnneeDebut = "pied_de_page_annee_debut"
    static let cleTexte = "pied_de_page_texte"
}
// swiftlint:enable line_length
