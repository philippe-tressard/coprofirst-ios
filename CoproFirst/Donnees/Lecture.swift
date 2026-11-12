// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// « Qui la lit » : la pastille de lecture d'un contenu, telle que le serveur la SERT
/// (`lecture`, coprofirst#2633, #129) — avec une affaire, une ligne du fil, une petite
/// annonce, une idée, un sondage.
///
/// 🔴 L'app ne la recompose pas : qui lit dépend de la catégorie, de l'état, des
/// Destinataires, du périmètre et de son arbre — la règle de `ticket_visible`, écrite
/// au serveur seul (`standards/09` §8). Non servie : aucune pastille.
struct Lecture: Codable, Hashable, Sendable {
    /// `tous`, `residents`, `coproprietaires`, `cs`, `concerne`, ou des codes joints par « + ».
    let cle: String
    /// Les pictogrammes du site (noms Lucide), dans l'ordre : `Pictogrammes.symbole`.
    let icones: [String]
    /// Le libellé de la carte — « Copropriétaires », « CS ».
    let court: String
    /// Le titre de la pastille longue : le libellé, et le cadenas en toutes lettres.
    let titre: String
    /// Le cadenas : seuls ceux du périmètre lisent.
    let perimetreReserve: Bool
    /// « Lue par… » — la bulle du site.
    let phrase: String
    /// « Pas les locataires, ni… » ; vide quand personne n'est exclu.
    let exclus: String
    /// Personne n'est exclu : rien sur la carte (`PastilleLecture` du site).
    let parDefaut: Bool

    /// Ce que dit la bulle du site, et ce que VoiceOver lit : « Qui la lit : CS. Lue par
    /// le conseil syndical seul. » — « Qui le lit » pour un sondage.
    func enClair(masculin: Bool = false) -> String {
        "Qui \(masculin ? "le" : "la") lit : \(titre). \(phrase)"
    }

    /// La phrase entière d'un détail : la bulle, puis ceux qui ne lisent pas.
    var phraseEntiere: String { [phrase, exclus].filter { !$0.isEmpty }.joined(separator: " ") }

    /// La pastille à MONTRER : `nil` quand personne n'est exclu (`par_defaut`) ou qu'elle
    /// n'est pas servie — la règle du site, écrite une fois pour la vue et VoiceOver.
    static func aMontrer(_ lecture: Lecture?) -> Lecture? { lecture.flatMap { $0.parDefaut ? nil : $0 } }
}

extension Lecture {
    /// La pastille servie par une route TYPÉE (`Lecture` du contrat) — le fil, lui, la
    /// relit de son `meta` libre (`MetaDuFil`), par le même modèle.
    init(_ servie: Components.Schemas.Lecture) {
        self.init(
            cle: servie.cle, icones: servie.icones, court: servie.court, titre: servie.titre,
            perimetreReserve: servie.perimetreReserve, phrase: servie.phrase, exclus: servie.exclus,
            parDefaut: servie.parDefaut)
    }
}

/// Une valeur relue d'un JSON libre (`meta` du fil) qui ne fait pas échouer son
/// conteneur : illisible, elle vaut `nil` — la ligne garde ses autres champs.
struct Tolere<Valeur: Decodable & Sendable>: Decodable, Sendable {
    let valeur: Valeur?

    init(from decodeur: any Decoder) throws {
        valeur = try? Valeur(from: decodeur)
    }
}
