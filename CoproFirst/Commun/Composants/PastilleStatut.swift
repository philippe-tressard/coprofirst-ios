// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le statut d'une affaire, en pastille (`BadgeEtatAffaire` du site) : la teinte du
/// site par son CODE (`StatutsAffaire`, généré depuis tickets.ts ; la classe `badge-*` y
/// désigne la couleur d'état de la charte — une teinte, pas une règle), le libellé EN
/// CLAIR, que l'appelant tient du serveur (`statut_libelle`, `libelle_statut`, ou
/// `StatutsAffaire.libelle(_:servi:dans:)`, #127, #105). Le cas particulier de `PastilleTeinte`.
struct PastilleStatut: View {
    let statut: String
    let libelle: String

    init(statut: String, libelle: String) {
        self.statut = statut
        self.libelle = libelle
    }

    init(_ etat: EtatServi) {
        self.init(statut: etat.code, libelle: etat.libelle)
    }

    var body: some View {
        PastilleTeinte(libelle: libelle, badge: StatutsAffaire.pastilles[statut] ?? "badge-gray")
            .accessibilityLabel(Text("Statut : \(libelle)"))
    }
}

extension StatutsAffaire {
    /// Un état en clair — LA seule écriture (#127, #105) : tel que le serveur le SERT avec
    /// l'objet (`statut_libelle`, `nouveau_statut_libelle`, `suivi_actualite_libelle`…) ; à
    /// défaut — un état que le serveur ne met pas en clair avec l'objet (l'ancien état
    /// d'une Suite), un geste fait ici —, le libellé que ses
    /// référentiels SERVENT (`statuts[].libelle`, `GET /tickets/referentiels`) ; puis le
    /// code brut. Plus aucune table du site : seule la teinte se génère.
    static func libelle(_ code: String, servi: String?, dans referentiels: ReferentielsAffaires) -> String {
        servi?.nulSiVide ?? referentiels.statuts.first { $0.code == code }?.libelle ?? code
    }
}
