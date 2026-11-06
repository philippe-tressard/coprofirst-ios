// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.66.0 (commit 14fec7b6ba683cd74161d874e48a47f2d007ff5f), front/src/lib/sanitize.ts (ALLOWED_TAGS, ALLOWED_ATTR) et api/app/utils/html_sur.py.

/// La liste blanche du texte riche du site : ce que l'app rend, et rien d'autre (#22).
enum BalisesDuSite {
    static let balises: Set<String> = ["p", "br", "b", "i", "u", "s", "strong", "em", "ul", "ol", "li", "blockquote", "pre", "code", "h1", "h2", "h3", "h4", "h5", "h6", "a", "img", "hr", "span", "div", "details", "summary"]
    static let attributs: Set<String> = ["href", "src", "alt", "title", "class", "target", "rel"]
    /// Les schémas d'un lien touchable (`SCHEMAS_URL`, appliqué par l'API).
    static let schemasDeLien: Set<String> = ["http", "https", "mailto"]
}
