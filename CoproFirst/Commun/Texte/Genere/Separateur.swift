// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.101.0 (commit e6e8ecdbbd269ccb2b25081a0c12828176047a5c), front/src/lib/separateurs.ts.

/// Les séparateurs du site : une espace sécable avant, insécable après — la ligne se coupe devant eux, jamais après.
enum Separateur {
    /// sépare deux éléments d'une même ligne : « 3/5 · PDF »
    static let point = " ·\u{00A0}"
    /// introduit un complément : « 📞 01 02 — la gérante »
    static let tiret = " —\u{00A0}"
    /// borne un intervalle : « 18:00 → 20:00 »
    static let fleche = " →\u{00A0}"
}
