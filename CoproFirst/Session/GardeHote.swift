// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Observation

/// D'où vient l'adresse de la résidence : un QR collé dans un hall peut mener à un
/// serveur qui imite une résidence (#82).
enum OrigineAdresse: Sendable {
    /// Saisie, ou pré-remplie depuis une résidence connue.
    case saisie
    /// Lue dans un QR code.
    case scan
    /// Venue d'un lien (#18) : n'importe quelle page peut en tendre un.
    case lien
}

/// Un hôte auquel un mot de passe peut partir : seule `GardeHote` en fabrique un
/// (initialiseur `fileprivate`). `ServiceCoproFirst.connecter` n'accepte que lui —
/// aucun écran ne peut envoyer un mot de passe sans être passé par la garde.
struct HoteConfirme: Sendable {
    let installation: Installation

    fileprivate init(_ installation: Installation) {
        self.installation = installation
    }
}

/// La garde du mot de passe, en un seul endroit (#82) : avant le premier mot de passe
/// envoyé à un hôte JAMAIS VU, l'écran de confirmation montre l'hôte en entier et la
/// preuve qu'il sert (`PreuveHote`). Toujours après un scan ; pour une saisie, quand
/// l'hôte n'est pas celui d'une résidence connue (une connexion y a déjà réussi) ni la
/// démonstration de CoproFirst. Sans preuve, il faut un second accord.
///
/// Une garde par lancement (`Parcours.garde`) : une confirmation vit en mémoire, et
/// l'hôte devient une résidence connue à la première connexion réussie.
@MainActor @Observable
final class GardeHote {
    /// L'installation dont l'écran de confirmation est ouvert — `nil` sinon.
    private(set) var aConfirmer: Installation?
    /// Ce que sert l'hôte à confirmer — `nil` tant que la vérification court.
    private(set) var preuve: PreuveHote?
    private var confirmes: Set<URL> = []
    private let service: any ServiceCoproFirst
    private let connues: () -> [Installation]

    /// L'adresse de la démonstration, écrite dans l'app : elle ne se confirme pas.
    static let integrees: Set<URL> = Set([AdresseInstallation.normaliser(ContenuVitrine.adresseDemo)].compactMap { $0 })

    init(service: any ServiceCoproFirst, connues: @escaping () -> [Installation]) {
        self.service = service
        self.connues = connues
    }

    /// Faut-il l'écran de confirmation avant d'envoyer un mot de passe à cette adresse ?
    func exigeConfirmation(_ adresse: URL, origine: OrigineAdresse) -> Bool {
        if confirmes.contains(adresse) { return false }
        // Un QR ou un lien : l'adresse n'a pas été écrite par l'utilisateur.
        if origine != .saisie { return true }
        return !Self.integrees.contains(adresse) && !connues().contains { $0.adresse == adresse }
    }

    /// Le seul chemin du mot de passe. Rend `false` sans RIEN envoyer quand l'hôte est à
    /// confirmer : l'écran de confirmation s'ouvre (`aConfirmer`).
    func connecter(
        _ installation: Installation, origine: OrigineAdresse, email: String, motDePasse: String
    ) async throws -> Bool {
        guard !exigeConfirmation(installation.adresse, origine: origine) else {
            // Le même hôte, déjà à l'écran : sa preuve lue reste valable.
            if aConfirmer?.adresse != installation.adresse { preuve = nil }
            aConfirmer = installation
            return false
        }
        try await service.connecter(HoteConfirme(installation), email: email, motDePasse: motDePasse)
        return true
    }

    /// Lit la preuve servie par l'hôte à confirmer (son `apple-app-site-association`).
    func verifier() async {
        guard let installation = aConfirmer else { return }
        let lue = await service.preuve(installation.adresse)
        guard aConfirmer?.adresse == installation.adresse else { return }
        preuve = lue
    }

    /// « Me connecter à cette adresse ». Refusé tant que la preuve n'est pas lue ; sans
    /// preuve, refusé sans le second accord. Rend `true` si l'hôte est confirmé.
    func confirmer(secondAccord: Bool = false) -> Bool {
        guard let installation = aConfirmer, let preuve else { return false }
        guard preuve.reconnue || secondAccord else { return false }
        confirmes.insert(installation.adresse)
        aConfirmer = nil
        self.preuve = nil
        return true
    }

    /// « Annuler », ou la feuille balayée : rien n'est confirmé.
    func renoncer() {
        aConfirmer = nil
        preuve = nil
    }
}
