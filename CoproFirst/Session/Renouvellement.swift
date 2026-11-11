// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import HTTPTypes
import OpenAPIRuntime

/// LA porte du renouvellement de session (#81) : la reprise après Face ID (`reprendre`)
/// et le 401 d'une requête en cours d'usage y passent tous deux. Un seul POST
/// /auth/refresh à la fois par hôte : le serveur fait tourner le jeton de
/// rafraîchissement, et un second renouvellement concurrent présenterait un jeton
/// déjà révoqué.
actor Renouvellement {
    /// Les renouvellements réussis, par hôte.
    private var reussis: [String: Int] = [:]
    private var enCours: [String: Task<Bool, any Error>] = [:]

    /// Relevé AVANT d'envoyer une requête : revenue refusée alors qu'un renouvellement a
    /// réussi depuis, elle partait avec l'ancien jeton — elle se rejoue sans renouveler.
    func releve(_ hote: String) -> Int { reussis[hote, default: 0] }

    /// Renouvelle la session de cet hôte : `true` si le serveur l'a renouvelée, `false`
    /// s'il la refuse ; une erreur de réseau remonte. Un renouvellement en cours est
    /// attendu, jamais doublé ; un renouvellement réussi depuis `releve` suffit.
    func renouveler(
        _ hote: String, depuis releve: Int? = nil, par rafraichir: @escaping @Sendable () async throws -> Bool
    ) async throws -> Bool {
        if let releve, reussis[hote, default: 0] > releve { return true }
        if let tache = enCours[hote] { return try await tache.value }
        // Une tâche à part : l'appelant annulé n'annule pas le renouvellement des autres.
        let tache = Task { try await rafraichir() }
        enCours[hote] = tache
        defer { enCours[hote] = nil }
        let renouvele = try await tache.value
        if renouvele { reussis[hote, default: 0] += 1 }
        return renouvele
    }

    /// Envoie ; sur un 401, renouvelle puis renvoie UNE fois. Un renouvellement refusé
    /// rend la première réponse, un second 401 la seconde : l'appelant y lit la session
    /// expirée, comme avant.
    nonisolated func rejouer<Reponse>(
        _ hote: String, par rafraichir: @escaping @Sendable () async throws -> Bool,
        statut: (Reponse) -> Int, envoyer: () async throws -> Reponse
    ) async throws -> Reponse {
        let avant = await releve(hote)
        let reponse = try await envoyer()
        guard statut(reponse) == 401, try await renouveler(hote, depuis: avant, par: rafraichir) else {
            return reponse
        }
        return try await envoyer()
    }
}

/// Le renouvellement glissé entre le client généré et le transport : TOUTE route du
/// contrat y passe (`appeler`, `fichierServi`, la déconnexion) — sauf la connexion, dont
/// le 401 dit des identifiants refusés, et le renouvellement lui-même.
struct RenouvelerSurRefus: ClientMiddleware {
    let hote: String
    let renouvellement: Renouvellement
    let rafraichir: @Sendable () async throws -> Bool

    static let horsRenouvellement: Set<String> = [Operations.PostAuthLogin.id, Operations.PostAuthRefresh.id]

    func intercept(
        _ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        // Un corps qui ne se lit qu'une fois ne se rejoue pas : sa réponse reste la première.
        guard !Self.horsRenouvellement.contains(operationID), body?.iterationBehavior != .single else {
            return try await next(request, body, baseURL)
        }
        return try await renouvellement.rejouer(
            hote, par: rafraichir, statut: { $0.0.status.code }, envoyer: { try await next(request, body, baseURL) })
    }
}

extension ServiceAPI {
    /// Le renouvellement de l'installation à cette adresse, pour son client.
    func renouvelerSurRefus(_ adresse: URL) -> RenouvelerSurRefus {
        RenouvelerSurRefus(
            hote: SessionsParHote.cle(adresse), renouvellement: renouvellement, rafraichir: rafraichisseur(adresse))
    }

    /// Renouveler la session de l'installation à cette adresse, par LA porte.
    func renouveler(_ adresse: URL) async throws -> Bool {
        try await renouvellement.renouveler(SessionsParHote.cle(adresse), par: rafraichisseur(adresse))
    }

    /// Envoyer une requête hors du client généré (une photo derrière la session),
    /// renouvelée et rejouée sur un 401 comme les autres.
    func rejouerSurRefus<Reponse>(
        _ installation: URL, statut: (Reponse) -> Int, envoyer: () async throws -> Reponse
    ) async throws -> Reponse {
        try await renouvellement.rejouer(
            SessionsParHote.cle(installation), par: rafraichisseur(installation), statut: statut, envoyer: envoyer)
    }

    /// POST /auth/refresh par le client généré : `true` si le serveur a renouvelé. Le
    /// jeton de rafraîchissement tourne : le Trousseau, s'il en garde un pour cet hôte
    /// (Face ID activé), reçoit le neuf — sinon la prochaine ouverture présenterait un
    /// jeton révoqué.
    private func rafraichisseur(_ adresse: URL) -> @Sendable () async throws -> Bool {
        { [self] in
            let sortie: Operations.PostAuthRefresh.Output
            do {
                sortie = try await client(adresse).postAuthRefresh()
            } catch {
                throw ClientCoproFirst.cause(error)
            }
            guard case .ok = sortie else { return false }
            let hote = SessionsParHote.cle(adresse)
            if Trousseau.contient(pour: hote), let neuf = cookie("refresh_token", adresse) {
                Trousseau.enregistrer(neuf, pour: hote)
            }
            return true
        }
    }
}
