// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

#if DEBUG
/// La fiche d'un sondage sur l'API simulée : les fiches de `FixturesSondage`, que les
/// gestes changent comme le serveur (`participation.py`) — le vote compte, sa précision
/// rejoint les réponses libres, son commentaire rejoint les commentaires.
extension ServiceSimule: ServiceSondage {
    func sondage(_ id: Int, dans installation: Installation) async throws -> DetailSondage {
        try await Task.sleep(for: .milliseconds(450))
        return try modifierSimule(depuis: FixturesSondage.lues) { fiches in try Self.fiche(id, dans: &fiches) }
    }

    func voter(_ vote: VoteSondage, au sondage: Int, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(300))
        try modifierSimule(depuis: FixturesSondage.lues) { fiches in
            var fiche = try Self.fiche(sondage, dans: &fiches)
            guard !fiche.cloture else { throw ErreurService.refus(.init(phrase: "Ce sondage est clôturé")) }
            guard fiche.monVote == nil else { throw ErreurService.refus(.init(phrase: "Vous avez déjà voté")) }
            guard let rang = fiche.options.firstIndex(where: { $0.id == vote.option }) else {
                throw ErreurService.refus(.init(phrase: "Option invalide"))
            }
            fiche.monVote = fiche.options[rang].id
            if fiche.resultatsVisibles { fiche.options[rang].nbVotes = (fiche.options[rang].nbVotes ?? 0) + 1 }
            if let precision = VoteSondage.nettoye(vote.reponseLibre), fiche.resultatsVisibles {
                fiche.options[rang].reponsesLibres.append(precision)
            }
            if let commentaire = VoteSondage.nettoye(vote.commentaire) {
                fiche.commentaires.append(Self.commentaire(commentaire, apres: fiche.commentaires))
            }
            Self.ranger(fiche, dans: &fiches)
        }
    }

    func commenterSondage(_ texte: String, au sondage: Int, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(300))
        guard let contenu = VoteSondage.nettoye(texte) else {
            throw ErreurService.refus(.init(phrase: "Le commentaire ne peut pas être vide"))
        }
        try modifierSimule(depuis: FixturesSondage.lues) { fiches in
            var fiche = try Self.fiche(sondage, dans: &fiches)
            fiche.commentaires.append(Self.commentaire(contenu, apres: fiche.commentaires))
            Self.ranger(fiche, dans: &fiches)
        }
    }

    func supprimerCommentaireSondage(_ id: Int, du sondage: Int, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(250))
        try modifierSimule(depuis: FixturesSondage.lues) { fiches in
            var fiche = try Self.fiche(sondage, dans: &fiches)
            guard fiche.commentaires.contains(where: { $0.id == id && $0.peutSupprimer }) else {
                throw ErreurService.refus(.init(phrase: "Action non autorisée"))
            }
            fiche.commentaires.removeAll { $0.id == id }
            Self.ranger(fiche, dans: &fiches)
        }
    }

    /// La fiche de cet identifiant. Un sondage que les fixtures ne connaissent pas (la carte
    /// du fil, n° 3) prend la forme du premier, sous son propre numéro — et le garde.
    private static func fiche(_ id: Int, dans fiches: inout [DetailSondage]) throws -> DetailSondage {
        if let fiche = fiches.first(where: { $0.id == id }) { return fiche }
        guard let modele = fiches.first else { throw ErreurService.introuvable }
        let fiche = DetailSondage(
            id: id, question: modele.question, description: modele.description, options: modele.options,
            monVote: modele.monVote, cloture: modele.cloture, clotureLe: modele.clotureLe,
            resultatsVisibles: modele.resultatsVisibles, commentaires: modele.commentaires, moi: modele.moi)
        fiches.append(fiche)
        return fiche
    }

    private static func ranger(_ fiche: DetailSondage, dans fiches: inout [DetailSondage]) {
        if let rang = fiches.firstIndex(where: { $0.id == fiche.id }) { fiches[rang] = fiche }
    }

    /// Un commentaire du compte simulé, comme `commenter` le rend : il peut le retirer.
    private static func commentaire(_ contenu: String, apres existants: [ReponseCommunaute]) -> ReponseCommunaute {
        ReponseCommunaute(
            id: (existants.map(\.id).max() ?? 100) + 1, auteurId: FixturesSondage.moi, contenu: contenu,
            creeLe: .now, auteurNom: "Camille Essai", auteurBatiment: "Bât. B", auteurRole: "Résident",
            estCs: false, peutSupprimer: true)
    }
}
#endif
