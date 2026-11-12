// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Ma demande de suppression de compte (`DemandeSuppressionRead`, coprofirst#2699).
/// La personne DEMANDE, l'administration de la résidence traite (arbitrage du 12/11/2026).
struct DemandeSuppressionCompte: Hashable, Sendable {
    let id: Int
    /// `ouverte`, `traitee`, `retiree`.
    let statut: String
    let creeLe: Date
    let traiteeLe: Date?
    /// Le délai maximal annoncé pour la traiter, SERVI ; absent, la phrase s'en passe.
    let delaiJours: Int?
}

/// `GET /auth/demande-suppression` : ma demande en cours (ou rien), le délai annoncé et
/// ce qui sera effacé — SERVIS : le site et l'app lisent le même texte (#166).
struct EtatSuppressionCompte: Hashable, Sendable {
    let demande: DemandeSuppressionCompte?
    let delaiJours: Int?
    /// Ce qui est effacé et ce qui reste, phrase par phrase.
    let consequences: [String]
}

/// Ce que le geste « Supprimer mon compte » du Profil demande à une installation (#166).
/// Les trois routes sont au plancher (contrat 1.27.0) : toute installation connue les sert.
protocol ServiceSuppressionCompte: Sendable {
    func etatSuppression(_ installation: Installation) async throws -> EtatSuppressionCompte
    /// POST : le mot de passe confirme ; « Mot de passe incorrect. » et « déjà en cours » sont
    /// des phrases du serveur.
    func demanderSuppression(motDePasse: String, motif: String, dans installation: Installation) async throws
        -> DemandeSuppressionCompte
    /// DELETE : je retire ma demande tant qu'elle n'est pas traitée.
    func retirerDemandeSuppression(_ installation: Installation) async throws
}

extension Parcours {
    /// Les deux réalisations s'y conforment (`SuppressionCompteTests` le vérifie à la compilation).
    var serviceSuppressionCompte: any ServiceSuppressionCompte {
        // swiftlint:disable:next force_cast
        service as! any ServiceSuppressionCompte
    }
}

// MARK: - Lues du type généré, par le service réel ET par l'API simulée

extension DemandeSuppressionCompte {
    init(_ lu: Components.Schemas.DemandeSuppressionRead) {
        self.init(
            id: lu.id, statut: lu.statut.rawValue, creeLe: lu.creeLe, traiteeLe: lu.traiteeLe,
            delaiJours: lu.delaiAnnonceJours)
    }

    var ouverte: Bool { statut == Components.Schemas.StatutDemandeSuppression.ouverte.rawValue }
}

extension EtatSuppressionCompte {
    init(_ lu: Components.Schemas.EtatDemandeSuppression) {
        let demande = lu.demande.map(DemandeSuppressionCompte.init)
        self.init(
            demande: demande?.ouverte == true ? demande : nil, delaiJours: lu.delaiAnnonceJours,
            consequences: lu.consequences)
    }
}
