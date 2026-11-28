// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI
import UIKit

#if DEBUG
/// Une « photo » de l'API simulée : un aplat de la charte, choisi par le chemin, et un
/// pictogramme. L'iPhone la sert pour un fichier de `/uploads/` (`ServiceSimule`), l'écran de
/// hall pour les photos du Fil (#429) — une seule fabrique, aucune image embarquée.
enum PhotoDessinee {
    static func jpeg(_ chemin: String) -> Data {
        let teintes = [Palette.seine.filIndigoFond, Palette.seine.filCyanFond, Palette.seine.infoFond]
        let teinte = UIColor(teintes[chemin.unicodeScalars.reduce(0) { $0 + Int($1.value) } % teintes.count])
        let image = UIGraphicsImageRenderer(size: CGSize(width: 640, height: 480)).image { contexte in
            teinte.setFill()
            contexte.fill(CGRect(x: 0, y: 0, width: 640, height: 480))
            let symbole = UIImage(systemName: "drop.fill")?.withTintColor(UIColor(Palette.seine.primary))
            symbole?.draw(in: CGRect(x: 260, y: 180, width: 120, height: 120))
        }
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }
}
#endif
