// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La NATURE d'une carte du fil (#78) : ce que la gouttière du site écrit en « CAL. »,
/// « ACTU. », « AFF. » (`classeDuFlux`, `flux.ts`). Une affaire se classe par sa nature, pas
/// par le type de l'événement : une affaire à laquelle on ajoute une date est du
/// calendrier, que l'événement soit son ouverture, sa mise à jour ou sa clôture.
///
/// 🔴 Les natures viennent du serveur (`meta.affaire.natures`), jamais redérivées ; la table
/// (libellé, teinte) est celle du site, générée (`TablesAffaires.natures`).
extension ElementDuFil {
    /// `natureDe` du site : une affaire peut en porter deux (une actualité datée) ; l'actualité
    /// prime, puis la date — l'ordre de la table. `nil` pour une rubrique sans nature
    /// (document, annonce, sondage…), que sa rubrique classe déjà.
    var natureDeLAffaire: NatureAffaire? {
        guard !natures.isEmpty else { return nil }
        let table = TablesAffaires.natures
        return table.first { natures.contains($0.code) } ?? table.last
    }

    /// Le pictogramme de la gouttière (`classeDuFlux` du site) : celui de la NATURE pour une
    /// affaire, celui de la rubrique sinon. « Affaire mise à jour » est déjà écrit sur la
    /// carte ; la flèche de mise à jour le répétait, à la place de ce qu'est l'affaire.
    var pictogramme: String { natureDeLAffaire?.icone ?? nature.icone }

    /// La nature à montrer en pastille : celle de `natureDeLAffaire`, sauf si la rubrique de
    /// la carte la dit déjà (« Affaire », « Affaire mise à jour » pour une nature « Affaire » ;
    /// « Actualité » pour une actualité) — la même chose ne s'écrit pas deux fois sur la ligne.
    var natureEnPastille: NatureAffaire? {
        guard let classe = natureDeLAffaire else { return nil }
        let dejaDit = nature.libelle.range(
            of: classe.libelle, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil
        return dejaDit ? nil : classe
    }
}

/// La pastille de nature d'une carte, à la teinte que le site lui donne (`[data-nature]`).
/// Le libellé entier de la table (« Calendrier »), pas l'abrégé de la gouttière : la carte
/// du téléphone a la place, et « CAL. » n'y est qu'un mot de plus à deviner.
struct PastilleNature: View {
    let nature: NatureAffaire

    var body: some View {
        PastilleTeinte(libelle: nature.libelle, badge: nature.badge, compacte: true)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            // Comme le pictogramme de la carte : une pastille ne grandit pas sans fin — aux
            // tailles d'accessibilité elle dépassait la carte. La nature se lit aussi dans le
            // libellé vocal de la carte.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}
