// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le statut d'une affaire, en pastille (`BadgeEtatAffaire` du site) : la teinte du
/// site par son CODE (`StatutsAffaire`, généré depuis tickets.ts ; la classe `badge-*` y
/// désigne la couleur d'état de la charte), le libellé tel que le serveur le SERT
/// (`StatutsAffaire.libelle(_:servi:)`, #127). Le cas particulier de `PastilleTeinte`.
struct PastilleStatut: View {
    let statut: String
    var libelle: String?

    init(statut: String, libelle: String? = nil) {
        self.statut = statut
        self.libelle = libelle
    }

    init(_ etat: EtatServi) {
        self.init(statut: etat.code, libelle: etat.libelle)
    }

    var body: some View {
        let libelle = StatutsAffaire.libelle(statut, servi: libelle)
        PastilleTeinte(libelle: libelle, badge: StatutsAffaire.parCode[statut]?.pastille ?? "badge-gray")
            .accessibilityLabel(Text("Statut : \(libelle)"))
    }
}

extension StatutsAffaire {
    /// Un état en clair : tel que le serveur le SERT (`statut_libelle`,
    /// `nouveau_statut_libelle`, `suivi_actualite_libelle`…, #127) ; à défaut — une
    /// installation antérieure, un état que le serveur ne met pas en clair —, la table du
    /// site, puis le code brut.
    static func libelle(_ code: String, servi: String?) -> String {
        servi?.nulSiVide ?? parCode[code]?.libelle ?? code
    }
}
