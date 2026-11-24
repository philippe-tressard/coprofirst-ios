// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// L'adresse qu'ouvre un courriel ou un numéro touché (`mailto:`, `tel:`), écrite une fois
/// (#348) : la fiche d'un lot, une carte de l'annuaire, un prestataire, une annonce. Chaque
/// écran garde son rendu ; l'adresse, elle, se forme ici seulement.
enum LienDeContact {
    /// `mailto:` — `nil` sans courriel.
    static func courriel(_ adresse: String?) -> URL? {
        guard let adresse, !adresse.isEmpty else { return nil }
        return URL(string: "mailto:\(adresse)")
    }

    /// `tel:` — les chiffres et le « + » du numéro tel qu'il est saisi ; `nil` sans numéro.
    static func appel(_ numero: String?) -> URL? {
        guard let numero, !numero.isEmpty else { return nil }
        return URL(string: "tel:\(numero.filter { $0.isNumber || $0 == "+" })")
    }
}
