// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
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

extension ContexteOnglet {
    var serviceAnnoncesHall: (any ServiceAnnoncesHallCS)? { service as? any ServiceAnnoncesHallCS }
}

/// Une affiche, telle que le serveur la sert (`AnnonceHallRead`, coprofirst#2525).
struct AnnonceHall: Hashable, Sendable, Identifiable {
    let id: Int
    var titre: String
    /// Le texte de l'éditeur du site (HTML) : `TexteRiche(html:)`, jamais `Text(html)`.
    var message: String
    var assisteIa: Bool?
    /// Le texte simple, composé par le serveur pour une carte.
    var apercu: String
    /// Le lieu d'avant #130 (« Toute la copropriété » pour le défaut) : le seul repli.
    var perimetreLabel: String
    var formatLabel: String
    var images: [String]
    var destinataires: [String]
    var envoyeLe: Date?
    /// L'état EFFECTIF : archivée à la main, ou par le temps.
    var archivee: Bool
    /// L'actualité reprise, s'il y en a une.
    var ticketId: Int?
    var creeLe: Date
    var auteurNom: String
    /// Les gestes que le serveur ouvre au compte qui lit (#56) : restaurer, seulement une
    /// affiche rangée à la main (coprofirst#515) ; supprimer, l'administrateur.
    var peutArchiver = false
    var peutRestaurer = false
    var peutSupprimer = false
    /// Le lieu servi (`perimetre_libelle`, contrat 1.24.0, #130) : `""` pour le défaut.
    var perimetreLibelle: String?

    /// Le lieu à montrer : servi, il fait foi (le défaut se tait, comme `BadgePerimetre`
    /// du site) ; sinon `perimetre_label`, comme avant.
    var lieu: String? { LieuServi.lieu(perimetreLibelle, repli: perimetreLabel) }
}

extension AnnonceHall {
    init(_ lue: Components.Schemas.AnnonceHallRead) {
        self.init(
            id: lue.id, titre: lue.titre, message: lue.message, assisteIa: lue.assisteIa, apercu: lue.apercu,
            perimetreLabel: lue.perimetreLabel, formatLabel: lue.formatLabel, images: lue.images,
            destinataires: lue.destinataires, envoyeLe: lue.envoyeLe, archivee: lue.archivee, ticketId: lue.ticketId,
            creeLe: lue.creeLe, auteurNom: lue.auteurNom, peutArchiver: lue.peutArchiver,
            peutRestaurer: lue.peutRestaurer, peutSupprimer: lue.peutSupprimer, perimetreLibelle: lue.perimetreLibelle)
    }
}

/// La saisie de « Nouvelle annonce » (`AnnonceHallCreate`), sans photo ni assistant —
/// ceux-là restent au site.
struct SaisieAnnonceHall: Hashable, Sendable {
    var titre = ""
    /// Du texte simple, envoyé en paragraphes (`HTMLDeSaisie`).
    var message = ""
    /// Les lieux retenus (`ChoixPerimetres`) ; aucun : le serveur pose le défaut (coprofirst#2514).
    var perimetres = ChoixDePerimetres()
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
