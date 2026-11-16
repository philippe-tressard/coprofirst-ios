// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.105.0 (commit 74da8ebb2f9a71a5a62b3584b358e96d9f8b8efd), api/app/utils/fichiers.py#_EXTENSIONS_IMAGE, api/app/utils/fichiers.py#_PREFIXE_UUID (constantes-clients.json), front/src/lib/fichiers.ts (typeFichier).
// swiftlint:disable line_length

/// Les pièces jointes comme le site les range et les nomme.
enum FichiersDuSite {
    /// Les extensions d'une image affichable en vignette (`motifImage`).
    static let extensionsImage: Set<String> = ["avif", "bmp", "gif", "heic", "heif", "jpeg", "jpg", "png", "tif", "tiff", "webp"]

    /// Le préfixe que le serveur ajoute au nom téléversé : tant de chiffres
    /// hexadécimaux, puis « _ » (`prefixeStockage`) — retiré du nom montré.
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
