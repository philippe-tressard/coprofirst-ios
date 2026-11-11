// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

extension EnvironmentValues {
    /// La palette en vigueur : la charte (`seine`) avant toute résidence, puis celle
    /// que la résidence a choisie (`site_palette` de GET /config), posée par la racine.
    @Entry var palette: Palette = .seine
}

extension Palette {
    /// La palette d'un code servi par une installation ; un code inconnu garde la charte.
    static func pour(code: String?) -> Palette {
        code.flatMap { parCode[$0] } ?? .seine
    }
}

/// Ce que le fil montre d'un type d'élément (table générée : NaturesDuFil.swift).
struct NatureDuFil: Sendable {
    let libelle: String
    let couleur: KeyPath<Palette, Color> & Sendable
    let fond: KeyPath<Palette, Color> & Sendable
    /// Le nom Lucide du site ; `Pictogrammes.symbole` le traduit en SF Symbol.
    let icone: String

    /// Un type que la table ne connaît pas : neutre, jamais une erreur.
    static let inconnue = NatureDuFil(
        libelle: "Élément", couleur: \.filInconnu, fond: \.filInconnuFond, icone: "circle")
}

/// Les pictogrammes Lucide du site, rendus par leur équivalent SF Symbols.
/// La traduction d'un dessin, pas une donnée : le nom vient toujours du site.
///
/// Un nom absent de `table` se rend par `repli` — jamais une erreur à l'écran, mais
/// jamais en silence non plus : chaque nom que citent les tables générées a son entrée
/// (`PictogrammesTests`, #85), et une icône ajoutée au site fait échouer le test.
enum Pictogrammes {
    /// Le point neutre d'un nom que la table ne connaît pas.
    static let repli = "circle.fill"

    static func symbole(_ lucide: String) -> String {
        table[lucide] ?? repli
    }

    static let table: [String: String] = [
        "activity": "waveform.path.ecg",
        "bar-chart-3": "chart.bar.fill",
        "bell": "bell.fill",
        "book-open": "book.fill",
        "building-2": "building.2.fill",
        "calendar": "calendar",
        // Le pictogramme de `NatureDuFil.inconnue` : le point neutre, comme avant #85.
        "circle": "circle.fill",
        "circle-check": "checkmark.circle.fill",
        "file-text": "doc.text.fill",
        "hard-hat": "wrench.and.screwdriver.fill",
        "heart-handshake": "hands.sparkles.fill",
        "help-circle": "questionmark.circle.fill",
        "key-round": "key.fill",
        "layout-dashboard": "list.bullet.rectangle.portrait",
        "lightbulb": "lightbulb.fill",
        "message-square-text": "exclamationmark.bubble.fill",
        "newspaper": "newspaper.fill",
        "refresh-cw": "arrow.triangle.2.circlepath",
        "shield-half": "shield.lefthalf.filled",
        "sliders-horizontal": "slider.horizontal.3",
        "user": "person.crop.circle",
        "users": "person.2.fill",
        "users-round": "person.3.fill",
        "wrench": "wrench.adjustable.fill",
    ]
}
