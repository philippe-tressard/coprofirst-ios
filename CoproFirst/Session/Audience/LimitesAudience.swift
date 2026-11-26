// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.126.5 (commit 62852e89915e6bfaf695125a8cca5affa72abdcf), pièce jointe openapi.json de la release (LotAudience, EvenementAudience).

/// Ce que le contrat borne d'un lot de mesure d'audience — au-delà, le serveur refuse le lot entier (422).
enum LimitesAudience {
    /// Les évènements qu'accepte UN POST /telemetry/collect (`maxItems` de `LotAudience.events`).
    static let evenementsParLot = 20
    /// La longueur maximale d'une page (`maxLength` de `EvenementAudience.page`).
    static let page = 200
    /// La longueur maximale d'une action (`maxLength` de `EvenementAudience.action`).
    static let action = 20
}
