// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.105.0 (commit 74da8ebb2f9a71a5a62b3584b358e96d9f8b8efd), front/src/lib/separateurs.ts#SEPARATEUR (tables-clients.json).

/// Les séparateurs du site : une espace sécable avant, insécable après — la ligne se coupe devant eux, jamais après.
enum Separateur {
    /// `SEPARATEUR.point`
    static let point = " ·\u{00A0}"
    /// `SEPARATEUR.tiret`
    static let tiret = " —\u{00A0}"
    /// `SEPARATEUR.fleche`
    static let fleche = " →\u{00A0}"
}
