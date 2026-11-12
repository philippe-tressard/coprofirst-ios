// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// « Qui la lit » : la pastille de lecture d'un contenu, telle que le serveur la SERT
/// (`lecture`, contrat 1.22.0, coprofirst#2633, #129) — avec une affaire, une ligne du
/// fil, une petite annonce, une idée, un sondage.
///
/// 🔴 L'app ne la recompose pas : qui lit dépend de la catégorie, de l'état, des
/// Destinataires, du périmètre et de son arbre — la règle de `ticket_visible`, écrite
/// au serveur seul (`standards/09` §8). Une installation antérieure ne la sert pas :
/// aucune pastille, comme avant.
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

/// Ce qu'un contenu sert au-dessus du plancher sur QUI le lit et OÙ il se trouve (#129,
/// #130) — relu dans le corps servi (`Relecture.auDessusDuPlancher`), une ligne par `id`.
/// Tous facultatifs : une installation antérieure n'en sert aucun, et l'écran garde
/// alors son rendu d'avant (défaut fermé).
///
/// Une `lecture` illisible ne fait pas perdre le lieu, ni l'inverse : chacun est `Tolere`.
struct ServiAuDessusDuPlancher: Decodable, Identifiable, Sendable {
    let id: Int
    /// La pastille de lecture (contrat 1.22.0).
    var lecture: Tolere<Lecture>?
    /// Le lieu du badge 🔹 (contrat 1.24.0) : `""` pour le périmètre par défaut.
    var perimetreLibelle: Tolere<String>?
    /// Le lieu qu'une Suite déclare, phrase comprise (« Périmètre précisé : 🔹 … »), même
    /// par défaut ; `""` quand elle n'en déclare pas (contrat 1.24.0).
    var perimetrePreciseLibelle: Tolere<String>?

    /// Les lignes d'une liste servie, par `id` — vide d'une installation antérieure.
    static func parLigne(_ corps: Data?) -> [Int: ServiAuDessusDuPlancher] {
        Relecture.auDessusDuPlancher(parLigne: Self.self, corps: corps)
    }

    /// Un seul objet servi — `nil` d'une installation antérieure.
    static func un(_ corps: Data?) -> ServiAuDessusDuPlancher? {
        Relecture.auDessusDuPlancher(Self.self, corps: corps)
    }

    /// Une liste servie, relue : chaque ligne du type GÉNÉRÉ devient son modèle, puis
    /// `poser` y range ce que le corps sert pour son `id` — le MÊME branchement pour le
    /// service réel et l'API simulée.
    static func relire<Genere, Modele>(
        _ generes: [Genere], corps: Data?, id: (Genere) -> Int, en modele: (Genere) -> Modele,
        poser: (inout Modele, ServiAuDessusDuPlancher?) -> Void
    ) -> [Modele] {
        let servis = parLigne(corps)
        return generes.map { genere in
            var relu = modele(genere)
            poser(&relu, servis[id(genere)])
            return relu
        }
    }
}

extension ServiAuDessusDuPlancher? {
    /// La pastille et le lieu à montrer d'un contenu — `(nil, nil)` d'une installation
    /// antérieure. Le lieu passe par `LieuServi` : `""` (le défaut) ne se montre pas.
    var lectureEtLieu: (Lecture?, String?) {
        (self?.lecture?.valeur, LieuServi.lieu(self?.perimetreLibelle?.valeur))
    }
}

/// Une valeur relue qui ne fait pas échouer son conteneur : illisible, elle vaut `nil`
/// — la ligne garde ses autres champs.
struct Tolere<Valeur: Decodable & Sendable>: Decodable, Sendable {
    let valeur: Valeur?

    init(from decodeur: any Decoder) throws {
        valeur = try? Valeur(from: decodeur)
    }
}
