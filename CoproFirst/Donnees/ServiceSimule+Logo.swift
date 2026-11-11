// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

#if DEBUG
/// Le logo d'une résidence simulée (#70) : un dessin inventé, rendu à la demande — aucun
/// fichier, aucune marque réelle. Ses deux variantes se distinguent à l'œil, pour que
/// les captures disent laquelle s'affiche : au clair, une feuille sur une tuile claire
/// (un logo « composé sur fond blanc ») ; au sombre, la feuille seule, claire, sur fond
/// transparent — le dessin que la 1.15.0 sert pour le fond sombre.
extension ServiceSimule {
    func logo(_ adresse: URL) async throws -> Data {
        try await Task.sleep(for: .milliseconds(150))
        let sombre =
            URLComponents(url: adresse, resolvingAgainstBaseURL: false)?
            .queryItems?.contains { $0.name == "variante" && $0.value == "sombre" } ?? false
        return Self.logoDessine(sombre: sombre)
    }

    /// Le dessin, aux teintes de la palette de la résidence simulée (`bouteille`).
    static func logoDessine(sombre: Bool) -> Data {
        let palette = Palette.pour(code: residence.codePalette)
        let style = UITraitCollection(userInterfaceStyle: sombre ? .dark : .light)
        func teinte(_ couleur: KeyPath<Palette, Color>) -> UIColor {
            UIColor(palette[keyPath: couleur]).resolvedColor(with: style)
        }
        let cote: CGFloat = 96
        let image = UIGraphicsImageRenderer(size: CGSize(width: cote, height: cote)).image { _ in
            if !sombre {
                teinte(\.primaryLight).setFill()
                UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: cote, height: cote), cornerRadius: 22).fill()
            }
            let symbole = UIImage(systemName: "leaf.fill")?.withTintColor(teinte(\.primary))
            symbole?.draw(in: CGRect(x: 18, y: 20, width: 60, height: 56))
        }
        return image.pngData() ?? Data()
    }
}
#endif
