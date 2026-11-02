// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce que les écrans demandent à une installation. Deux réalisations : le client
/// généré (`ServiceAPI`) et une API simulée pour les aperçus et les tests
/// (`ServiceSimule`) — aucun écran n'appelle le réseau lui-même.
protocol ServiceCoproFirst: Sendable {
    /// GET /config : l'adresse mène-t-elle à une résidence ? Son nom, son logo.
    func decouvrir(_ adresse: URL) async throws -> Installation
    /// POST /auth/login : ouvre la session de cette installation (cookies).
    func connecter(_ installation: Installation, email: String, motDePasse: String) async throws
    /// Une session gardée au Trousseau pour cette installation ?
    func aUneSessionGardee(_ installation: Installation) -> Bool
    /// Reprend la session gardée, après Face ID (POST /auth/refresh).
    func reprendre(_ installation: Installation) async throws
    /// GET /tickets : les affaires lisibles par l'utilisateur connecté.
    func affaires(_ installation: Installation) async throws -> [Affaire]
    /// L'utilisateur peut-il archiver ? L'écran n'offre que ce que le serveur permet.
    func peutArchiver(_ installation: Installation) -> Bool
    func archiver(_ affaire: Affaire, dans installation: Installation) async throws
}
