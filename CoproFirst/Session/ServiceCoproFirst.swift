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
    /// Après la première connexion : garder la session au Trousseau, sous Face ID.
    func activerFaceID(_ installation: Installation) async -> Bool
    /// GET /flux : le fil de la résidence, celui du tableau de bord du site.
    func fil(_ installation: Installation) async throws -> [ElementDuFil]
    /// Entrer dans la démo sous un personnage, d'un toucher — ou `nil` quand aucune
    /// route ne sert ses identifiants (coprofirst#2460) : l'écran pré-remplit alors.
    func entrerEnDemo(_ code: String) async throws -> Installation?
    /// GET /tickets/{id}, ses évolutions, et le droit de répondre.
    func affaire(_ id: Int, dans installation: Installation) async throws -> DetailAffaire
    /// POST /tickets/{id}/evolutions : une suite écrite (type `commentaire`).
    func repondre(_ texte: String, a affaire: Int, dans installation: Installation) async throws
    /// GET /documents/{id}/télécharger : le fichier, écrit dans un dossier temporaire.
    func document(_ id: Int, nom: String?, dans installation: Installation) async throws -> URL
    /// Une photo protégée (`/uploads/…`), lue avec la session de l'installation.
    func photo(_ chemin: String, dans installation: Installation) async throws -> Data
    /// GET /auth/me : statut et rôles dans CETTE résidence.
    func profil(_ installation: Installation) async throws -> ProfilResidence
    /// Se déconnecter, à une seule porte : POST /auth/logout (le serveur révoque le
    /// jeton), puis TOUJOURS l'effacement local — jeton du Trousseau, cookies, session
    /// HTTP de cet hôte. Rend `false` si le serveur n'a pas pu être joint.
    func deconnecter(_ installation: Installation) async -> Bool
}
