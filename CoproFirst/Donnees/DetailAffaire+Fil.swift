// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Un compte rendu où l'affaire a été abordée — un point CS / Syndic VALIDÉ, tel que
/// `GET /points-conseil/affaires/{id}` le sert (`CrPublieRead`). Le serveur ne rend que
/// ceux que CE lecteur peut lire (« Conseil seul » tu aux autres) : l'app ne filtre rien.
struct CompteRenduAffaire: Identifiable, Hashable, Sendable {
    let id: Int
    /// Le début du point.
    let debut: Date
    /// « En salle », « À distance »… tel que servi.
    let ou: String
    /// Ce que le point a dit de l'affaire (HTML de l'éditeur).
    let contenu: String
    /// Réservé au conseil et aux présents (`conseil_seul`).
    let conseilSeul: Bool
}

/// La synthèse d'une affaire close (`GET /tickets/{id}/synthese` → `SyntheseLue`) :
/// la conclusion, ce qui a coincé, ce qui s'améliore. Produite et validée sur le site.
struct SyntheseAffaire: Hashable, Sendable {
    let statut: String
    let texte: String?
    let difficultes: String?
    let amelioration: String?
    let valideeLe: Date?

    /// Validée : la conclusion de l'affaire. Sinon, un brouillon que le conseil relit.
    var validee: Bool { statut == "validee" }
}

extension CompteRenduAffaire {
    init(_ lu: Components.Schemas.CrPublieRead) {
        self.init(id: lu.crId, debut: lu.debut, ou: lu.ou, contenu: lu.contenu, conseilSeul: lu.conseilSeul)
    }
}

extension SyntheseAffaire {
    /// `nil` quand le serveur n'en sert pas (affaire sans synthèse, ou à produire).
    init?(_ etat: Components.Schemas.SyntheseEtat) {
        guard let lue = etat.synthese else { return nil }
        self.init(
            statut: lue.statut, texte: lue.synthese, difficultes: lue.difficultes,
            amelioration: lue.amelioration, valideeLe: lue.valideeLe)
    }
}
