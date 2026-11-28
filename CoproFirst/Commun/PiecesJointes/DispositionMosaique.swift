// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La règle de la mosaïque, comme Messages groupe les photos, écrite une fois : une photo
/// occupe tout le cadre ; deux, côte à côte ; trois et plus, une grande à gauche et deux
/// petites à droite, la dernière recevant le nombre de photos restantes (« +N »). Le cadre
/// garde la même hauteur quel que soit le nombre : le texte qui suit ne saute pas.
///
/// La tuile est celle de l'appelant : une photo touchable de l'iPhone (`MosaiquePhotos`),
/// une photo lue avec le jeton de l'écran de hall (#429), qui ne fait que montrer.
struct DispositionMosaique<Tuile: View>: View {
    let nombre: Int
    let hauteur: CGFloat
    /// Le rang de la photo, et ce qu'il reste après elle (« +N », sur la dernière tuile seule).
    @ViewBuilder let tuile: (_ rang: Int, _ reste: Int) -> Tuile

    /// L'écart entre deux tuiles : un filet, comme Messages.
    private let joint: CGFloat = 2

    var body: some View {
        Group {
            switch nombre {
            case ...0:
                EmptyView()
            case 1:
                tuile(0, 0)
            case 2:
                HStack(spacing: joint) {
                    tuile(0, 0)
                    tuile(1, 0)
                }
            default:
                GeometryReader { cadre in
                    HStack(spacing: joint) {
                        tuile(0, 0)
                        VStack(spacing: joint) {
                            tuile(1, 0)
                            tuile(2, nombre - 3)
                        }
                        .frame(width: (cadre.size.width - joint) / 3)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: hauteur)
        .clipShape(.rect(cornerRadius: Mise.rayon, style: .continuous))
    }
}
