// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// La saisie d'un avis (`FormulaireNotation.svelte`, `GesteNoter.svelte`, #207) : l'état,
/// les motifs cochés, le texte libre, l'affaire jugée et la confirmation de l'ajout.
///
/// Le commentaire enregistré se COMPOSE comme sur le site : la phrase générée par les
/// cases (`phraseGeneree`), puis le texte libre (`commentaireComplet`). Corriger un avis
/// RECOCHE ses cases (`decomposerCommentaire`). Les motifs et les débuts de phrase sont
/// générés (`TablesNotations`), et le générateur échoue si la forme de la phrase change.
struct AvisSaisi: Hashable, Sendable {
    var etat: String?
    var forts: Set<String> = []
    var faibles: Set<String> = []
    var libre = ""
    /// L'affaire jugée ; `nil` : un avis sur le prestataire en général.
    var affaire: Int?
    var confirmeAjout = false

    init() {}

    /// Un avis qu'on corrige : son état, ses cases recochées, son texte libre, son affaire.
    init(corrigeant avis: AvisPrestataire) {
        etat = avis.etat
        let lu = Self.decomposer(avis.commentaire)
        (forts, faibles, libre) = (Set(lu.forts), Set(lu.faibles), lu.libre)
        affaire = avis.ticketId
    }

    /// La phrase des cases cochées, dans l'ordre du site ; vide si rien n'est coché.
    var genere: String {
        Self.phrase(
            forts: TablesNotations.pointsForts.filter(forts.contains),
            faibles: TablesNotations.pointsFaibles.filter(faibles.contains))
    }

    /// Le commentaire enregistré : la phrase générée, puis le texte libre.
    var commentaire: String {
        [genere, libre.trimmingCharacters(in: .whitespacesAndNewlines)].filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// Ce qui retient l'avis, avec les mots du site — `nil` quand il peut partir.
    /// `ajoutRequis` : l'affaire choisie n'a pas encore ce prestataire pour intervenant.
    func refus(ajoutRequis: Bool, prestataire: String) -> String? {
        guard let etat else { return TextesSaisieAvis.choisirEtat }
        if etat == "mauvais" && commentaire.isEmpty { return TextesSaisieAvis.mauvaisSansCommentaire }
        if ajoutRequis && !confirmeAjout { return TextesSaisieAvis.confirmerAjout(prestataire) }
        return nil
    }

    /// Ce qui part, quand rien ne retient l'avis.
    func envoi(prestataire: Int, contrat: Int?, ajoutRequis: Bool) -> EnvoiAvis? {
        guard let etat, refus(ajoutRequis: ajoutRequis, prestataire: "") == nil else { return nil }
        return EnvoiAvis(
            prestataireId: prestataire, contratId: contrat, etat: etat,
            commentaire: commentaire.isEmpty ? nil : commentaire, affaire: affaire,
            confirmerAjout: ajoutRequis && confirmeAjout)
    }
}

extension AvisSaisi {
    /// `phraseGeneree` : « Points forts : a, b. Points faibles : c. ».
    static func phrase(forts: [String], faibles: [String]) -> String {
        [(TablesNotations.phraseForts, forts), (TablesNotations.phraseFaibles, faibles)]
            .filter { !$0.1.isEmpty }
            .map { "\($0.0)\($0.1.joined(separator: ", "))." }
            .joined(separator: " ")
    }

    /// `decomposerCommentaire` : la première ligne n'est reprise comme phrase générée que
    /// si chacun de ses motifs est dans les listes — sinon c'est un texte libre qui y
    /// ressemble, et il reste libre.
    static func decomposer(_ commentaire: String?) -> CommentaireDecompose {
        let texte = commentaire ?? ""
        let lignes = texte.components(separatedBy: "\n")
        let premiere = lignes[0].trimmingCharacters(in: .whitespaces)
        let motif =
            "^(?:\(NSRegularExpression.escapedPattern(for: TablesNotations.phraseForts))(.+?)\\.)?\\s*"
            + "(?:\(NSRegularExpression.escapedPattern(for: TablesNotations.phraseFaibles))(.+?)\\.)?$"
        guard let expression = try? NSRegularExpression(pattern: motif),
            let trouve = expression.firstMatch(
                in: premiere, range: NSRange(premiere.startIndex..., in: premiere))
        else { return CommentaireDecompose(libre: texte) }
        func motifs(_ groupe: Int) -> [String] {
            Range(trouve.range(at: groupe), in: premiere).map { premiere[$0].components(separatedBy: ", ") } ?? []
        }
        let (forts, faibles) = (motifs(1), motifs(2))
        let reconnus =
            forts.count + faibles.count > 0 && forts.allSatisfy(TablesNotations.pointsForts.contains)
            && faibles.allSatisfy(TablesNotations.pointsFaibles.contains)
        guard reconnus else { return CommentaireDecompose(libre: texte) }
        return CommentaireDecompose(forts: forts, faibles: faibles, libre: lignes.dropFirst().joined(separator: "\n"))
    }
}

/// Un commentaire relu (`CommentaireDecompose` du site) : les cases qu'il cochait, et le
/// texte libre qui suit.
struct CommentaireDecompose: Hashable, Sendable {
    var forts: [String] = []
    var faibles: [String] = []
    var libre: String
}

/// Ce qu'un avis envoie (`NotationCreate`, `NotationUpdate`).
struct EnvoiAvis: Hashable, Sendable {
    var prestataireId: Int
    var contratId: Int?
    var etat: String
    var commentaire: String?
    var affaire: Int?
    /// Vrai seulement quand l'affaire n'a pas ce prestataire et que l'ajout est confirmé.
    var confirmerAjout: Bool
}

/// Une affaire qu'un avis peut juger (`AffaireAvis`, `GET /prestataires/affaires-a-noter`) —
/// servies triées : celles où le prestataire intervient, puis les autres.
struct AffaireANoter: Hashable, Sendable, Identifiable {
    let id: Int
    var numero: String
    var titre: String
    /// Le prestataire y figure déjà ; sinon, le noter l'y ajoute, après confirmation.
    var intervient: Bool
    var intervenants: String
}

extension AffaireANoter {
    init(_ lue: Components.Schemas.AffaireAvis) {
        self.init(
            id: lue.id, numero: lue.numero, titre: lue.titre, intervient: lue.intervient,
            intervenants: lue.intervenants)
    }
}

/// Les mots de la saisie d'un avis — ceux de `GesteNoter`, `FormulaireNotation`,
/// `ChoixAffaireAvis` et `NotationsPrestataire`.
enum TextesSaisieAvis {
    static let noter = "⭐ Noter"
    static let titreNoter = "Noter"
    static let modifier = "Modifier cet avis"
    static let retirer = "Retirer cet avis"
    static let gestes = "Gestes de l'avis"
    static let etatGroupe = "État de l'intervention"
    static let pointsForts = "Points forts"
    static let pointsFaibles = "Points faibles"
    static let commentaireGenere = "Commentaire généré"
    static let rienDeCoche = "Rien de coché pour l’instant."
    static let commentaireLibre = "Commentaire libre"
    static let aideLibre = "(facultatif, sauf pour « Mauvais »)"
    static let choisirEtat = "Choisissez l'état : Mauvais, Neutre ou Excellent"
    static let mauvaisSansCommentaire = "Un avis « Mauvais » doit être justifié par un commentaire"
    static func confirmerAjout(_ prestataire: String) -> String {
        "Confirmez l'ajout de \(prestataire) à l'affaire choisie"
    }
    static let enregistree = "Notation enregistrée"
    static let modifie = "Avis modifié"
    static let retire = "Avis retiré."
    static let suppressionImpossible = "Suppression impossible"

    // Le choix de l'affaire (`ChoixAffaireAvis.svelte`)
    static let affaireConcernee = "Affaire concernée"
    static let rechercheAffaire = "Numéro, titre, équipement, mot du suivi…"
    static let changer = "Changer"
    static func avec(_ prestataire: String) -> String { "Avec \(prestataire.isEmpty ? "ce prestataire" : prestataire)" }
    static let autresAffaires = "Autres affaires"
    static let rechercheEnCours = "Recherche dans le suivi, les messages et les pièces jointes…"
    static let aucuneAffaire = "Aucune affaire ne correspond."
    static let sansAffaire = "Sans affaire, l’avis porte sur le prestataire en général."
    static func ajouter(_ prestataire: String, a titre: String) -> String {
        "Ajouter \(prestataire) comme intervenant de « \(titre) » (son avis y sera rattaché)"
    }

    // Le retrait (`NotationsPrestataire.supprimer`)
    static let confirmerRetrait = "Retirer l’avis"
    /// Ce que VoiceOver lit du bouton : « Retirer l’avis de Conseil syndical ».
    static func retirerDe(_ avis: AvisPrestataire) -> String { "Retirer l’avis de \(avis.auteurNom ?? "ce membre")" }
    static func retrait(_ avis: AvisPrestataire) -> String {
        "État « \(EtatAvis.libelle(avis.etat)) » de \(avis.auteurNom ?? "un membre du CS")"
            + (avis.commentaire.map { "\(Separateur.tiret)« \($0) »" } ?? "")
            + "\n\nLa suppression est définitive, et la moyenne du prestataire sera recalculée."
    }
}
