// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le logo de la RÉSIDENCE — celui qu'elle a téléversé, sinon celui de CoproFirst, comme
/// le site montre son logo neutre (`LogoResidence.svelte`). Le seul composant qui le
/// porte : pastille « où suis-je », feuille de la résidence, résidence reconnue à la
/// connexion. Le logo de CoproFirst lui-même (la marque) est `Medaillon`.
///
/// Au thème sombre, la variante du fond sombre quand l'installation la sert (#70, règle
/// dans `Installation.adresseLogo(sombre:)`). Le logo suit le thème sans relancer
/// l'app : au changement, l'ancien reste affiché jusqu'à ce que l'autre soit lu, puis
/// un fondu les échange — jamais un passage par le logo de CoproFirst.
struct LogoResidence: View {
    let installation: Installation?
    @Environment(Parcours.self) private var parcours
    @Environment(\.colorScheme) private var schema
    @Environment(\.accessibilityReduceMotion) private var reduireMouvement
    @Environment(\.palette) private var palette
    /// La dernière adresse affichée : gardée à l'écran pendant la lecture de la suivante.
    @State private var affichee: URL?
    /// L'adresse dont la lecture a échoué : le logo de CoproFirst prend sa place.
    @State private var echec: URL?
    private var logos: LogosEnMemoire { .commun }

    var body: some View {
        let voulue = installation?.adresseLogo(sombre: schema == .dark)
        // L'ancienne adresse ne sert que pour la MÊME résidence : jamais le logo d'une autre.
        let repli = affichee.flatMap { $0.host() == voulue?.host() ? $0 : nil }
        let montree = [voulue, repli].compactMap { $0 }.first { logos.image($0) != nil }
        ZStack {
            if let montree, let image = logos.image(montree) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .id(montree)
                    .transition(.opacity)
            } else if voulue == nil || echec == voulue {
                MedaillonPlein()
            } else {
                // Le temps de la première lecture : une tuile discrète, pas la marque
                // de CoproFirst, qui laisserait croire à un logo absent.
                palette.primaryLight
            }
        }
        .clipShape(.rect(cornerRadius: 5, style: .continuous))
        .animation(reduireMouvement ? nil : .smooth(duration: 0.25), value: montree)
        .accessibilityHidden(true)
        .task(id: voulue) {
            guard let voulue else { return }
            let service = parcours.service
            let image = await logos.charger(voulue) { try await service.logo($0) }
            echec = image == nil ? voulue : nil
            if image != nil { affichee = voulue }
        }
    }
}

/// Le logo de CoproFirst qui remplit son cadre (pastille, ligne de liste).
struct MedaillonPlein: View {
    var body: some View {
        Image("Logo")
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
    }
}
