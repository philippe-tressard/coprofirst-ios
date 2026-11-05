// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce que l'onglet « Annonces Hall » de l'Espace CS demande (#15) : les affiches déjà
/// produites, leurs gestes, et la création d'une affiche. Réalisé par `ServiceAPI`
/// (client généré) et `ServiceSimule`, dans ce dossier. Le lieu d'une affiche se choisit
/// parmi les périmètres (`ServicePerimetres`, une seule lecture pour l'app).
protocol ServiceAnnoncesHallCS: ServicePerimetres {
    /// GET /annonces-hall?archivees= : les affiches en cours, ou les archivées.
    func annoncesHall(archivees: Bool, dans installation: Installation) async throws -> [AnnonceHall]
    /// POST /annonces-hall : l'affiche créée — son PDF rendu, ses envois faits.
    func creerAnnonceHall(_ saisie: SaisieAnnonceHall, dans installation: Installation) async throws -> AnnonceHall
    /// PATCH /annonces-hall/{id} : archiver, ou restaurer une affiche archivée à la main.
    func archiverAnnonceHall(_ id: Int, archivee: Bool, dans installation: Installation) async throws
    /// POST /annonces-hall/{id}/renvoyer-email : de nouveau aux membres du CS du périmètre.
    func renvoyerAnnonceHall(_ id: Int, dans installation: Installation) async throws
    /// DELETE /annonces-hall/{id} (administrateur) : la ligne et son PDF ; ses images restent.
    func supprimerAnnonceHall(_ id: Int, dans installation: Installation) async throws
}

extension ContexteOngletCS {
    var serviceAnnoncesHall: (any ServiceAnnoncesHallCS)? { service as? any ServiceAnnoncesHallCS }
}

/// Une affiche (`AnnonceHall` du site) — relue en miroir : la route n'a pas de
/// `response_model` (coprofirst#2525).
struct AnnonceHall: Decodable, Hashable, Sendable, Identifiable {
    let id: Int
    var titre: String
    /// Le texte de l'éditeur du site (HTML) : `TexteRiche(html:)`, jamais `Text(html)`.
    var message: String
    var assisteIa: Bool?
    /// Le texte simple, composé par le serveur pour une carte.
    var apercu: String
    var perimetreLabel: String
    var formatLabel: String
    var images: [String]
    var destinataires: [String]
    var envoyeLe: Date?
    /// L'état EFFECTIF : archivée à la main, ou par la règle du site (30 jours après l'envoi).
    var archivee: Bool
    /// La décision HUMAINE seule : « Restaurer » n'a d'effet que sur elle.
    var archiveeManuellement: Bool?
    /// L'actualité reprise, s'il y en a une.
    var ticketId: Int?
    var creeLe: Date
    var auteurNom: String

    /// Le geste « Archiver / Restaurer » n'est offert que s'il a un effet (coprofirst#515) :
    /// une affiche archivée par le TEMPS ne se restaure pas.
    var archivable: Bool { !archivee || archiveeManuellement == true }
}

/// La saisie de « Nouvelle annonce » (`AnnonceHallCreate`), sans photo ni assistant —
/// ceux-là restent au site.
struct SaisieAnnonceHall: Hashable, Sendable {
    var titre = ""
    /// Du texte simple, envoyé en paragraphes (`HTMLDeSaisie`).
    var message = ""
    /// Aucun lieu choisi : le serveur pose le sien (coprofirst#2514).
    var perimetres: Set<String> = []
    var format = TablesAnnoncesHall.formats.first?.code ?? "auto"
    /// La Diffusion : la valeur par défaut d'un envoi est « ne pas envoyer ».
    var envoyerCS = false
    var envoyerSyndic = false
    var envoyerAuteur = false

    /// La règle de `_valider` côté API : un titre, et un message (sans photo, ici).
    var complete: Bool {
        ![titre, message].contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}
