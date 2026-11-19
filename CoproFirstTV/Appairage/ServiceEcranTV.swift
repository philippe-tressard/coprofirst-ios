// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce que l'écran de hall demande au serveur (#218, lot 3 ; serveur coprofirst#2770) : la
/// part de l'ÉCRAN, que le conseil ne voit pas — l'appairage sans saisie (RFC 8628), puis la
/// lecture des affiches de son périmètre avec SON jeton. Les gestes du conseil (confirmer,
/// retirer) sont l'onglet « Écrans du hall » de l'iPhone (#295).
protocol ServiceEcranTV: Sendable {
    /// POST /ecrans/appairage (public) : un code d'appareil secret et un code court à afficher.
    func demander(_ adresse: URL) async throws -> DemandeAppairageTV
    /// POST /ecrans/appairage/jeton : le jeton, une fois le code confirmé par le conseil.
    func interroger(_ codeAppareil: String, _ adresse: URL) async throws -> ReponseAppairage
    /// GET /ecrans/moi/affiches : les affiches de son périmètre. Jeton retiré ou échu :
    /// `ErreurService.sessionExpiree`.
    func affiches(_ adresse: URL, jeton: String) async throws -> [AfficheHall]
    /// GET /ecrans/moi/affiches/{id}/images/{rang} : une image d'une affiche montrée.
    func image(_ affiche: Int, rang: Int, _ adresse: URL, jeton: String) async throws -> Data
}

/// Ce que l'écran affiche et garde (`DemandeAppairage`) — rien sur l'installation.
struct DemandeAppairageTV: Equatable, Sendable {
    /// Le secret de l'écran, jamais affiché.
    let codeAppareil: String
    /// Le code à lire de loin (`BCDF-GHJK`), tel que le serveur le présente.
    let codeCourt: String
    /// Sa vie, en secondes (dix minutes).
    let expireDans: Int
    /// L'intervalle imposé entre deux interrogations, en secondes.
    let intervalle: Int
}

/// La réponse d'une interrogation (RFC 8628 §3.5) : le jeton, ou ce qu'il faut faire.
enum ReponseAppairage: Equatable, Sendable {
    case jeton(String, expireLe: Date)
    /// Le conseil n'a pas encore confirmé : réinterroger après l'intervalle.
    case enAttente
    /// Trop tôt : l'intervalle a grandi de `ReponseAppairage.ralentissement` secondes.
    case ralentir
    /// Code inconnu ou échu : recommencer l'appairage.
    case inconnu

    /// Le `detail` d'un refus (400), tel que le serveur l'écrit (`appairage_ecran`).
    static func depuis(detail: String?) -> ReponseAppairage? {
        switch detail {
        case "en_attente": .enAttente
        case "ralentir": .ralentir
        case "inconnu": .inconnu
        default: nil
        }
    }

    /// Ce qu'ajoute le serveur à l'intervalle d'une interrogation pressée (`INTERVALLE`).
    static let ralentissement = 5
}

/// Une affiche telle que la montre un écran de hall (`AfficheEcran`) : titre, message assaini
/// par le serveur, images, dates — ni auteur, ni destinataires, ni gestes.
struct AfficheHall: Hashable, Sendable, Identifiable {
    let id: Int
    let titre: String
    /// Le HTML de l'affiche : `TexteRiche(html:)`, jamais `Text(html)`.
    let message: String
    /// Le nombre d'images : chacune se lit par son rang, avec le jeton.
    let images: Int
    let creeLe: Date
}
