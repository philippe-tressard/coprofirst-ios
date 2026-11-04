// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le texte riche du site dans un détail : les blocs de `TexteDuSite`, mis en page.
///
/// Un élément de liste garde son marqueur et son texte sur la même ligne, et les
/// lignes suivantes s'alignent sur le texte, pas sous le marqueur — le retrait
/// suspendu qu'un seul `Text` ne sait pas faire (#25). Police, couleur et teinte des
/// liens viennent de l'appelant (`.font`, `.foregroundStyle`, `.tint`).
struct TexteRiche: View {
    let blocs: [BlocDuSite]
    /// La colonne du marqueur (« • », « 12. ») et le retrait d'un niveau : ils suivent
    /// Dynamic Type.
    @ScaledMetric(relativeTo: .body) private var colonne: CGFloat = 26

    init(html: String) {
        blocs = TexteDuSite.blocs(html)
    }

    var vide: Bool { blocs.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocs.enumerated()), id: \.offset) { rang, bloc in
                ligne(bloc)
                    .padding(.top, rang == 0 ? 0 : (bloc.ecart ? 12 : 4))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private func ligne(_ bloc: BlocDuSite) -> some View {
        if bloc.niveau == 0 {
            Text(bloc.texte)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(bloc.marqueur ?? "")
                    .monospacedDigit()
                    .frame(minWidth: colonne, alignment: .leading)
                    .accessibilityHidden(bloc.marqueur == nil)
                Text(bloc.texte)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, colonne * CGFloat(bloc.niveau - 1))
        }
    }
}
