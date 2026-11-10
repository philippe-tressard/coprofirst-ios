// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Un sondage, tel que GET /sondages/{id} le sert (`SondageDetail`, typé par le contrat),
/// et l'identifiant du compte (GET /auth/me) : on ne signale pas son propre commentaire.
struct DetailSondage: Hashable, Sendable {
    let id: Int
    let question: String
    let description: String?
    var options: [OptionSondage]
    var monVote: Int?
    let cloture: Bool
    let clotureLe: Date?
    /// La décision du serveur (`resultats_visibles`) — jamais recomposée (#397 du site).
    let resultatsVisibles: Bool
    var commentaires: [ReponseCommunaute]
    let moi: Int?

    /// `nb_votes` absent compte pour 0 : sans ce repli, la somme n'aurait pas de sens.
    var totalVotes: Int { options.reduce(0) { $0 + ($1.nbVotes ?? 0) } }
    /// Ouvert et pas encore voté : la règle de la fiche du site, sur les champs servis.
    var peutVoter: Bool { !cloture && monVote == nil }
}

struct OptionSondage: Hashable, Sendable, Identifiable {
    let id: Int
    let libelle: String
    /// L'option demande une précision (« Précisez votre réponse »).
    let champLibre: Bool
    /// Absent quand les résultats sont masqués — jamais 0 : « personne n'a voté » serait faux.
    var nbVotes: Int?
    /// Les précisions des votants, servies avec les résultats.
    var reponsesLibres: [String]
}

/// Ce que POST /sondages/{id}/voter reçoit (`VoteBody`) : un texte vide n'est pas envoyé.
struct VoteSondage: Hashable, Sendable {
    var option: Int?
    var reponseLibre = ""
    var commentaire = ""
    var charteAcceptee = false

    static func nettoye(_ texte: String) -> String? {
        let propre = texte.trimmingCharacters(in: .whitespacesAndNewlines)
        return propre.isEmpty ? nil : propre
    }

    /// Ce qui manque encore, dans l'ordre où le site le dit ; `nil` : le vote peut partir.
    func manque(champLibre: Bool) -> String? {
        if option == nil { return TextesSondage.choisir }
        if champLibre, Self.nettoye(reponseLibre) == nil { return TextesSondage.preciserManque }
        if !charteAcceptee { return TextesSondage.charteManque }
        return nil
    }
}

/// Les mots de la fiche d'un sondage du site (`sondages/[id]/+page.svelte`,
/// `ResultatsSondage.svelte`), écrits une fois.
enum TextesSondage {
    static let titre = "Sondage"
    static let ouvert = "Ouvert"
    static let cloture = "Clôturé"
    static let choisir = "Sélectionnez une option"
    static let preciser = "Précisez votre réponse"
    static let preciserInvite = "Décrivez votre réponse…"
    static let preciserManque = "Merci de préciser votre réponse dans le champ prévu"
    static let commentaire = "Commentaire"
    static let commentaireInvite = "Partagez votre point de vue…"
    static let charte = "Je m'engage à rester respectueux envers tous les membres de la résidence. Tout propos "
        + "irrespectueux pourra entraîner la suppression du commentaire et la suspension de mon compte."
    static let charteManque = "Vous devez accepter la charte de respect"
    static let voter = "Voter"
    static let envoi = "Envoi…"
    static let voteEnregistre = "Vote enregistré"
    static let monVote = "Mon vote ✓"
    static let resultatsMasques = "Les résultats de ce sondage ne seront visibles qu'après sa clôture."
    static let commentaireInviteFil = "Votre commentaire sur ce sondage…"
    static let commentairePublie = "Commentaire publié"
    static let commentaireSupprime = "Commentaire supprimé"
    static let signalementTransmis = "Signalement transmis au conseil syndical"

    /// « Clôturé le 02/04/2026 », « Clôture le 02/04/2026 ».
    static func clotureLe(_ date: Date, close: Bool) -> String {
        "\(close ? "Clôturé" : "Clôture") le \(FormatsDuSite.dateCourte(date))"
    }

    /// « 1 vote », « 12 votes ».
    static func votes(_ nombre: Int) -> String {
        "\(FormatsDuSite.nombre(nombre)) vote\(nombre > 1 ? "s" : "")"
    }

    /// « 💬 Commentaires (3) ».
    nonisolated static func commentaires(_ nombre: Int) -> String { "💬 Commentaires (\(nombre))" }

    /// Le pourcentage du site : arrondi, 0 sans aucun vote.
    static func pourcentage(_ votes: Int, sur total: Int) -> Int {
        total == 0 ? 0 : Int((Double(votes) / Double(total) * 100).rounded())
    }
}

extension DetailSondage {
    /// Un sondage tel que le contrat le type (`SondageDetail`).
    init(_ lu: Components.Schemas.SondageDetail, moi: Int?) {
        self.init(
            id: lu.id, question: lu.question, description: lu.description,
            options: (lu.options ?? []).map(OptionSondage.init),
            monVote: lu.monVote, cloture: lu.cloture ?? false, clotureLe: lu.clotureLe,
            resultatsVisibles: lu.resultatsVisibles ?? false,
            commentaires: (lu.commentaires ?? []).map(ReponseCommunaute.init), moi: moi)
    }
}

extension OptionSondage {
    init(_ lue: Components.Schemas.OptionFiche) {
        self.init(
            id: lue.id, libelle: lue.libelle, champLibre: lue.champLibre ?? false, nbVotes: lue.nbVotes,
            reponsesLibres: lue.reponsesLibres ?? [])
    }
}
