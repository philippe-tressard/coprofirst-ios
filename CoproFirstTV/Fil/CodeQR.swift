// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

/// Le QR code d'un élément (#429) : l'adresse de sa page sur le site de la résidence, qui
/// l'ouvre dans l'app (lien universel) ou sur le site — derrière la connexion, donc sans rien
/// ouvrir à qui le scanne. Généré sur l'appareil par Core Image, sans dépendance.
enum CodeQR {
    /// Les codes déjà dessinés, par adresse : un même élément reste à l'écran des minutes.
    @MainActor private static var dessines: [String: CGImage] = [:]
    private static let contexte = CIContext()

    /// Le code d'un texte, un pixel par module, marge comprise ; `nil` si Core Image échoue.
    @MainActor
    static func image(_ texte: String) -> CGImage? {
        if let connu = dessines[texte] { return connu }
        let filtre = CIFilter.qrCodeGenerator()
        filtre.message = Data(texte.utf8)
        // « M » : 15 % du code peut manquer — un reflet sur l'écran du hall.
        filtre.correctionLevel = "M"
        guard let sortie = filtre.outputImage, let image = contexte.createCGImage(sortie, from: sortie.extent)
        else { return nil }
        dessines[texte] = image
        return image
    }
}

/// Le QR code à l'écran : net (aucun lissage entre les modules), sombre sur clair.
struct CodeQRView: View {
    let adresse: URL?
    let cote: CGFloat
    /// Le titre de l'élément, pour VoiceOver.
    let titre: String
    @Environment(\.palette) private var palette

    var body: some View {
        if let adresse, let image = CodeQR.image(adresse.absoluteString) {
            Image(decorative: image, scale: 1)
                .interpolation(.none)
                .resizable()
                .frame(width: cote, height: cote)
                .padding(cote / 16)
                .background(palette.surface, in: .rect(cornerRadius: MiseTV.rayon / 2, style: .continuous))
                .accessibilityElement()
                .accessibilityLabel(EcranDeHall.codeQR(titre))
        }
    }
}
