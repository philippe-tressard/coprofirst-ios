// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.126.10 (commit 803696b615c922d3c0b93f69e2c81c6fa44c3e4c), api/app/utils/fichiers.py#_EXTENSIONS_IMAGE, api/app/utils/fichiers.py#_PREFIXE_UUID (constantes-clients.json), front/src/lib/fichiers.ts#FAMILLES_AFFICHAGE (tables-clients.json).
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
