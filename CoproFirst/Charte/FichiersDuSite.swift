// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.76.0 (commit 92633e233a414f3d20d189055d71ea62a0b36b41), front/src/lib/fichiers.ts (EXTENSIONS_IMAGE, PREFIXE_UUID, typeFichier).
// swiftlint:disable line_length

/// Les pièces jointes comme le site les range et les nomme.
enum FichiersDuSite {
    /// Les extensions d'une image affichable en vignette (`EXTENSIONS_IMAGE`).
    static let extensionsImage: Set<String> = ["avif", "bmp", "gif", "heic", "heif", "jpeg", "jpg", "png", "tif", "tiff", "webp"]

    /// Le préfixe que le serveur ajoute au nom téléversé : tant de chiffres
    /// hexadécimaux, puis « _ » (`PREFIXE_UUID`) — retiré du nom montré.
    static let longueurPrefixe = 32

    /// L'extension en capitales, ramenée à sa famille (`typeFichier`).
    static let familles: [String: String] = [
        "JPEG": "JPG",
        "XLSX": "EXCEL",
        "XLS": "EXCEL",
        "DOCX": "WORD",
        "DOC": "WORD",
        "PPTX": "POWERPOINT",
        "PPT": "POWERPOINT",
        "TXT": "TEXTE",
    ]
}
// swiftlint:enable line_length
